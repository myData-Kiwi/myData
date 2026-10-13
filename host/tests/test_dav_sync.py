"""Collection sync against the fake server: full, incremental (RFC 6578), expired tokens, ctag/etag."""

import httpx
import pytest

from fake_dav import FakeDav
from fake_dav.data import vcard
from mydata.sources.dav.client import ALLOWED_METHODS, DavError
from mydata.sources.dav.discovery import discover
from mydata.sources.dav.sync import MULTIGET_BATCH, CollectionState, sync_collection

CONTACTS = "https://contacts.icloud.com"
CALENDAR = "https://caldav.icloud.com"


def _book(fake, client=None):
    client = client or fake.client()
    return client, discover(client, CONTACTS, "contacts").collections[0]


def _names(result):
    return sorted(i.href.rsplit("/", 1)[1] for i in result.changed)


def _multigets(fake):
    return [n for r, n in fake.reports if r.endswith("multiget")]


def test_first_sync_is_full_and_fetches_everything():
    fake = FakeDav()
    client, book = _book(fake)
    r = sync_collection(client, book, CollectionState())
    assert r.full and r.deleted == []
    assert _names(r) == sorted(fake.collection("card").items)
    ava = next(i for i in r.changed if i.href.endswith("/ava-fictional.vcf"))
    assert ava.href == "/1234567/carddavhome/card/ava-fictional.vcf"
    assert ava.data == fake.collection("card").items["ava-fictional.vcf"].data  # CRLF kept
    assert ava.etag == fake.collection("card").items["ava-fictional.vcf"].etag
    assert r.state.sync_token == fake.token("card")
    assert r.state.ctag == fake.collection("card").ctag
    assert set(r.state.etags) == {i.href for i in r.changed}
    assert _multigets(fake) == [6]


def test_calendar_items_are_fetched_with_calendar_multiget():
    fake = FakeDav()
    client = fake.client()
    cals = {c.display_name: c for c in discover(client, CALENDAR, "calendar").collections}
    r = sync_collection(client, cals["Work"], CollectionState())
    assert len(r.changed) == 1 and "RECURRENCE-ID" in r.changed[0].data and "BEGIN:VTIMEZONE" in r.changed[0].data
    assert ("calendar-multiget", 1) in fake.reports


def test_incremental_sync_detects_add_modify_delete():
    fake = FakeDav()
    client, book = _book(fake)
    first = sync_collection(client, book, CollectionState())
    before = list(fake.reports)

    fake.add_item("card", "new-person.vcf", vcard("fake-uid-new", "Nora Newperson", n="Newperson;Nora;;;"))
    fake.update_item("card", "ben-madeup.vcf", vcard("fake-uid-ben", "Ben Madeup", n="Madeup;Ben;;;",
                                                     emails=[("WORK", "ben.new@example.org")]))
    fake.delete_item("card", "sam-example-2.vcf")

    r = sync_collection(client, book, first.state)
    assert not r.full
    assert _names(r) == ["ben-madeup.vcf", "new-person.vcf"]
    assert "ben.new@example.org" in next(i.data for i in r.changed if "ben" in i.href)
    assert r.deleted == ["/1234567/carddavhome/card/sam-example-2.vcf"]
    assert r.state.sync_token == fake.token("card") != first.state.sync_token
    assert set(r.state.etags) == {fake.href("card", n) for n in fake.collection("card").items}
    new_reports = fake.reports[len(before):]
    assert new_reports == [("sync-collection", 0), ("addressbook-multiget", 2)]
    # No full listing was needed.
    assert not any(m == "PROPFIND" for m, _, _ in fake.requests[-2:])


def test_incremental_sync_with_no_changes_fetches_nothing():
    fake = FakeDav()
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state
    n = len(fake.reports)
    r = sync_collection(client, book, state)
    assert (r.changed, r.deleted, r.full) == ([], [], False)
    assert fake.reports[n:] == [("sync-collection", 0)]


def test_sync_does_not_modify_the_given_state():
    fake = FakeDav()
    client, book = _book(fake)
    state = CollectionState()
    sync_collection(client, book, state)
    assert state == CollectionState()


def test_expired_token_triggers_a_full_resync():
    fake = FakeDav()
    client, book = _book(fake)
    first = sync_collection(client, book, CollectionState())
    fake.update_item("card", "ava-fictional.vcf", vcard("fake-uid-ava", "Ava Fictional", n="Fictional;Ava;;;"))
    fake.delete_item("card", "plumbing.vcf")
    fake.expire_tokens("card")
    n = len(fake.reports)

    r = sync_collection(client, book, first.state)
    assert r.full
    assert _names(r) == ["ava-fictional.vcf"]  # unchanged etags are not fetched again
    assert r.deleted == ["/1234567/carddavhome/card/plumbing.vcf"]
    assert set(r.state.etags) == {fake.href("card", n) for n in fake.collection("card").items}
    assert fake.reports[n:] == [("sync-collection", 0), ("addressbook-multiget", 1)]
    # The new token works.
    again = sync_collection(client, book, r.state)
    assert not again.full and again.changed == []


@pytest.mark.parametrize("status,body", [(409, b""), (412, b""), (400, b""), (404, b""),
                                         (403, b'<D:error xmlns:D="DAV:"><D:valid-sync-token/></D:error>')])
def test_rejected_token_statuses_mean_full_resync(status, body):
    fake = FakeDav()
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state

    def handler(request):
        if request.method == "REPORT" and b"sync-collection" in request.content:
            return httpx.Response(status, content=body)
        return fake.transport.handle_request(request)

    client2 = fake.client(transport=httpx.MockTransport(handler))
    r = sync_collection(client2, book, state)
    assert r.full and r.changed == [] and r.deleted == []
    assert r.state.sync_token == fake.token("card")  # still a sync-capable server


@pytest.mark.parametrize("status", [501, 405, 403])
def test_report_not_supported_falls_back_to_etag_listing(status):
    fake = FakeDav()
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state
    fake.delete_item("card", "no-name.vcf")

    def handler(request):
        if request.method == "REPORT" and b"sync-collection" in request.content:
            return httpx.Response(status)
        return fake.transport.handle_request(request)

    r = sync_collection(fake.client(transport=httpx.MockTransport(handler)), book, state)
    assert r.full and r.deleted == ["/1234567/carddavhome/card/no-name.vcf"]
    assert r.state.sync_token is None and r.state.ctag == fake.collection("card").ctag


def test_server_turning_off_sync_collection():
    fake = FakeDav()
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state
    fake.supports_sync = False
    r = sync_collection(client, book, state)
    assert r.full and r.state.sync_token is None
    # From now on: ctag path, which skips an unchanged collection.
    n = len(fake.requests)
    r2 = sync_collection(client, book, r.state)
    assert (r2.changed, r2.deleted, r2.full) == ([], [], False)
    assert len(fake.requests) == n + 1


def test_ctag_path_without_sync_collection():
    fake = FakeDav(supports_sync=False)
    client, book = _book(fake)
    first = sync_collection(client, book, CollectionState())
    assert first.full and len(first.changed) == 6
    assert first.state.sync_token is None and first.state.ctag == fake.collection("card").ctag

    # ctag unchanged: one Depth 0 PROPFIND and nothing else.
    n_req, n_rep = len(fake.requests), len(fake.reports)
    r = sync_collection(client, book, first.state)
    assert (r.changed, r.deleted, r.full) == ([], [], False)
    assert r.state == first.state
    assert len(fake.requests) == n_req + 1 and fake.requests[-1][0] == "PROPFIND"
    assert len(fake.reports) == n_rep

    # A change moves the ctag: listing, diff, multiget of the changed only.
    fake.add_item("card", "zoe.vcf", vcard("fake-uid-zoe", "Zoe Invented", n="Invented;Zoe;;;"))
    fake.delete_item("card", "ben-madeup.vcf")
    r = sync_collection(client, book, r.state)
    assert r.full and _names(r) == ["zoe.vcf"]
    assert r.deleted == ["/1234567/carddavhome/card/ben-madeup.vcf"]
    assert _multigets(fake)[-1] == 1
    assert r.state.ctag == fake.collection("card").ctag


def test_multiget_batches_of_100():
    contacts = {f"person-{i:03d}.vcf": vcard(f"fake-uid-{i}", f"Invented Person {i}") for i in range(250)}
    fake = FakeDav(contacts=contacts)
    client, book = _book(fake)
    r = sync_collection(client, book, CollectionState())
    assert len(r.changed) == 250 and MULTIGET_BATCH == 100
    assert _multigets(fake) == [100, 100, 50]


def test_truncated_sync_answers_are_followed():
    fake = FakeDav(sync_page_size=2)
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state
    for i in range(5):
        fake.add_item("card", f"extra-{i}.vcf", vcard(f"fake-uid-extra-{i}", f"Extra Invented {i}"))
    fake.delete_item("card", "ava-fictional.vcf")
    r = sync_collection(client, book, state)
    assert _names(r) == [f"extra-{i}.vcf" for i in range(5)]
    assert r.deleted == ["/1234567/carddavhome/card/ava-fictional.vcf"]
    assert [n for n in fake.reports if n[0] == "sync-collection"] == [("sync-collection", 0)] * 3  # 6 changes, 2 a page
    assert r.state.sync_token == fake.token("card")


def test_item_deleted_between_listing_and_multiget():
    fake = FakeDav()
    client, book = _book(fake)

    def handler(request):
        if request.method == "REPORT" and b"addressbook-multiget" in request.content \
                and "ben-madeup.vcf" in fake.collection("card").items:
            fake.delete_item("card", "ben-madeup.vcf")
        return fake.transport.handle_request(request)

    r = sync_collection(fake.client(transport=httpx.MockTransport(handler)), book, CollectionState())
    assert "ben-madeup.vcf" not in _names(r)
    assert "/1234567/carddavhome/card/ben-madeup.vcf" not in r.state.etags
    assert r.deleted == []  # it was never known, so nothing to delete


def test_hrefs_are_canonical_across_paths():
    fake = FakeDav()
    fake.add_item("card", "odd name@x.vcf", vcard("fake-uid-odd", "Odd Invented"))
    client, book = _book(fake)
    full = sync_collection(client, book, CollectionState())
    odd = [i.href for i in full.changed if "odd" in i.href]
    assert odd == ["/1234567/carddavhome/card/odd%20name@x.vcf"]
    fake.update_item("card", "odd name@x.vcf", vcard("fake-uid-odd", "Odd Invented Two"))
    inc = sync_collection(client, book, full.state)
    assert [i.href for i in inc.changed] == odd
    assert set(inc.state.etags) == set(full.state.etags)


def test_server_errors_raise_dav_error():
    fake = FakeDav()
    client, book = _book(fake)
    state = sync_collection(client, book, CollectionState()).state

    def handler(request):
        return httpx.Response(500)

    with pytest.raises(DavError) as info:
        sync_collection(fake.client(transport=httpx.MockTransport(handler)), book, state)
    assert info.value.status == 500


def test_full_scenario_uses_only_read_methods():
    fake = FakeDav(sync_page_size=3)
    client = fake.client()
    for start, kind in ((CONTACTS, "contacts"), (CALENDAR, "calendar")):
        for coll in discover(client, start, kind).collections:
            s = sync_collection(client, coll, CollectionState()).state
            fake.expire_tokens()
            s = sync_collection(client, coll, s).state
            sync_collection(client, coll, s)
    assert fake.methods <= ALLOWED_METHODS
    assert fake.methods == {"PROPFIND", "REPORT"}
