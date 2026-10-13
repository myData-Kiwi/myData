"""Mirror one collection: what changed upstream since the last sync.

Three paths, chosen from the saved state and what the server supports:

- **Sync token** (RFC 6578): a sync-collection REPORT with the saved token lists the members that
  changed or were removed since. Used when the state holds a token.
- **Full listing**: PROPFIND Depth 1 for every member's etag, compared with the saved etags. Used on
  the first sync, when the server rejects the token (expired or unknown), and for servers without
  sync-collection. The new token, if the server has one, is read *before* the listing, so a change that
  lands during the listing is reported again next time rather than lost.
- **ctag shortcut**: when the state has no token but has a ctag, and the collection's ctag has not
  changed, nothing is fetched at all.

Changed members are fetched with addressbook-multiget / calendar-multiget, MULTIGET_BATCH at a time.
A member the server lists without a getetag counts as changed (its etag is unknown) and is fetched.
When the multiget does not return some changed members, the change markers (sync token, ctag) are not
advanced, so the next sync asks for them again.

Nothing here logs: collection URLs can hold the account's identifier (iCloud puts the user's DSID in the
path). Why a sync took the path it did is in SyncResult.reason, for the caller to log with a collection id.

SyncResult.full is True for a full listing. Then `state.etags` holds every member present on the server
after the sync (the unchanged ones are not in `changed`), and `deleted` lists the saved members that
are gone. A store should treat anything it holds for the collection that is not in `state.etags` as
deleted upstream.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from . import davxml as X
from .client import DavClient, DavError, expect
from .davxml import CALDAV, CARDDAV, CS, DAV, q
from .discovery import Collection

MULTIGET_BATCH = 100
MAX_SYNC_PAGES = 100  # truncated (507) sync-collection answers followed before giving up


@dataclass
class CollectionState:
    sync_token: str | None = None
    ctag: str | None = None
    etags: dict[str, str] = field(default_factory=dict)  # canonical href -> etag


@dataclass
class Item:
    href: str  # canonical path (see davxml.canonical_path)
    etag: str
    data: str  # the vCard or iCalendar text as the server sent it


@dataclass
class SyncResult:
    changed: list[Item]
    deleted: list[str]
    state: CollectionState
    full: bool
    # Why this path was taken, when it was not the expected one: "token_rejected" (the server refused the
    # saved sync token), "sync_unsupported" (it no longer answers sync-collection). None otherwise.
    reason: str | None = None
    # How many changed members the server listed but did not return; they are asked for again next time.
    unresolved: int = 0


class _TokenInvalid(Exception):
    pass


class _SyncUnsupported(Exception):
    pass


def _data_prop(collection: Collection) -> str:
    return q(CARDDAV, "address-data") if collection.kind == "contacts" else q(CALDAV, "calendar-data")


def _parse(resp_body: bytes, what: str) -> X.Multistatus:
    try:
        return X.parse_multistatus(resp_body)
    except X.XmlError as e:
        raise DavError(f"{what}: {e}") from None


def sync_collection(client: DavClient, collection: Collection, state: CollectionState) -> SyncResult:
    """Fetch what changed in `collection` since `state`. Never modifies `state`; the new state is in the
    result and should be saved together with the applied changes."""
    if state.sync_token:
        try:
            return _incremental(client, collection, state)
        except _TokenInvalid:
            result = _full(client, collection, state, ctag_shortcut=False, use_token=True)
            result.reason = "token_rejected"
            return result
        except _SyncUnsupported:
            result = _full(client, collection, state, ctag_shortcut=False, use_token=False)
            result.reason = "sync_unsupported"
            return result
    return _full(client, collection, state, ctag_shortcut=True, use_token=True)


# --- full listing ---------------------------------------------------------------------------------------

def _full(client: DavClient, collection: Collection, state: CollectionState, *, ctag_shortcut: bool,
          use_token: bool) -> SyncResult:
    head = _parse(expect(client.request("PROPFIND", collection.url, depth="0",
                                        body=X.propfind_body([q(CS, "getctag"), q(DAV, "sync-token")])),
                         207, what="collection lookup").body, "collection lookup")
    self_path = X.canonical_path(collection.url, collection.url)
    ctag = token = None
    for r in head.responses:
        if X.same_path(X.canonical_path(collection.url, r.href), self_path):
            ctag = r.text(q(CS, "getctag")) or None
            token = r.text(q(DAV, "sync-token")) or None
    if ctag_shortcut and not state.sync_token and state.ctag and ctag == state.ctag:
        return SyncResult([], [], _copy(state), full=False)

    listing = _parse(expect(client.request("PROPFIND", collection.url, depth="1",
                                           body=X.propfind_body([q(DAV, "getetag"), q(DAV, "resourcetype")])),
                            207, what="member listing").body, "member listing")
    present: dict[str, str] = {}
    for r in listing.responses:
        href = X.canonical_path(collection.url, r.href)
        if X.same_path(href, self_path) or q(DAV, "collection") in r.resourcetypes():
            continue
        if r.status is not None and not 200 <= r.status < 300:
            continue
        # A member without a getetag is present with an unknown etag (""): fetched, never deleted.
        present[href] = r.text(q(DAV, "getetag")) or ""

    wanted = [h for h, e in present.items() if not e or state.etags.get(h) != e]
    items, gone, unresolved = _multiget(client, collection, wanted)

    etags = dict(present)
    for item in items:
        etags[item.href] = item.etag
    for href in gone:
        etags.pop(href, None)
    for href in unresolved:  # not returned: keep the old etag so it is fetched again next time
        if href in state.etags:
            etags[href] = state.etags[href]
        else:
            etags.pop(href, None)
    deleted = [h for h in state.etags if h not in present] + [h for h in gone if h in state.etags]
    if unresolved:
        # Saving the new token or ctag would hide these members until they change upstream again. Without
        # either, the next sync repeats the listing and fetches them (the others keep their new etags).
        token = ctag = None
    new_state = CollectionState(sync_token=token if use_token else None, ctag=ctag, etags=etags)
    return SyncResult(items, _unique(deleted), new_state, full=True, unresolved=len(unresolved))


# --- RFC 6578 -------------------------------------------------------------------------------------------

def _incremental(client: DavClient, collection: Collection, state: CollectionState) -> SyncResult:
    self_path = X.canonical_path(collection.url, collection.url)
    token = state.sync_token
    reported: dict[str, str | None] = {}  # href -> etag, or None when removed; later pages win
    for _page in range(MAX_SYNC_PAGES):
        resp = client.request("REPORT", collection.url, depth="0",
                              body=X.sync_collection_body(token, [q(DAV, "getetag")]))
        if resp.status != 207:
            _classify_failure(resp.status, resp.body)
        ms = _parse(resp.body, "sync report")
        truncated = False
        for r in ms.responses:
            href = X.canonical_path(collection.url, r.href)
            if X.same_path(href, self_path):
                truncated = truncated or r.status == 507
                continue
            if r.status == 404:
                reported[href] = None
                continue
            if r.status is not None and not 200 <= r.status < 300:
                continue
            # A change reported without a getetag is still a change: fetch it ("" = etag unknown).
            reported[href] = r.text(q(DAV, "getetag")) or ""
        if not ms.sync_token:
            raise DavError("sync report without a new sync token")
        moved = ms.sync_token != token
        token = ms.sync_token
        if not truncated or not moved:
            break
    else:
        raise DavError(f"sync report still truncated after {MAX_SYNC_PAGES} pages")

    wanted = [h for h, e in reported.items() if e is not None and (not e or state.etags.get(h) != e)]
    removed = [h for h, e in reported.items() if e is None]
    items, gone, unresolved = _multiget(client, collection, wanted)

    etags = dict(state.etags)
    for href in removed + gone:
        etags.pop(href, None)
    for item in items:
        etags[item.href] = item.etag
    if unresolved:
        # The server listed a change but would not return the item. Saving the new token would lose
        # that change, so keep the old token: the next sync asks again.
        token = state.sync_token
    new_state = CollectionState(sync_token=token, ctag=None, etags=etags)
    return SyncResult(items, _unique(removed + gone), new_state, full=False, unresolved=len(unresolved))


def _classify_failure(status: int, body: bytes) -> None:
    if (status in (403, 409) and b"valid-sync-token" in body) or status in (409, 412, 400, 404):
        raise _TokenInvalid()
    if status in (403, 405, 501):
        raise _SyncUnsupported()
    raise DavError(f"sync report failed (HTTP {status})", status)


# --- multiget -------------------------------------------------------------------------------------------

def _multiget(client: DavClient, collection: Collection, hrefs: list[str]
              ) -> tuple[list[Item], list[str], list[str]]:
    """Fetch items. Returns (items, gone: 404 at the server, unresolved: not returned at all)."""
    items: list[Item] = []
    gone: list[str] = []
    unresolved: list[str] = []
    data_prop = _data_prop(collection)
    for i in range(0, len(hrefs), MULTIGET_BATCH):
        batch = hrefs[i:i + MULTIGET_BATCH]
        resp = expect(client.request("REPORT", collection.url, body=X.multiget_body(collection.kind, batch)),
                      207, what="multiget")
        ms = _parse(resp.body, "multiget")
        answered: set[str] = set()
        for r in ms.responses:
            href = X.canonical_path(collection.url, r.href)
            if href not in batch or href in answered:
                continue
            if r.status == 404:
                gone.append(href)
                answered.add(href)
                continue
            data, etag = r.raw_text(data_prop), r.text(q(DAV, "getetag"))
            if data is None or etag is None:
                continue  # 404 propstat on the data, or no etag: treat as not returned
            items.append(Item(href=href, etag=etag, data=data))
            answered.add(href)
        unresolved.extend(h for h in batch if h not in answered)
    return items, gone, unresolved


def _copy(state: CollectionState) -> CollectionState:
    return CollectionState(sync_token=state.sync_token, ctag=state.ctag, etags=dict(state.etags))


def _unique(hrefs: list[str]) -> list[str]:
    return list(dict.fromkeys(hrefs))
