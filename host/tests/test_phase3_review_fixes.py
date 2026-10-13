"""Regression tests for the Phase 3 Part A review: one test (or a few) per finding. Invented data only."""

from __future__ import annotations

import asyncio
import io
import json
import logging
import os
import re
import stat
import sys
import threading
import time
from datetime import datetime, timedelta

import httpx
import httpx2
import pytest
from mcp import Client
from mcp.client.streamable_http import streamable_http_client

import fake_dav
from fake_dav import FakeDav
from fake_dav.data import vcard, vevent, vevent_calendar
from mydata.orchestrator.engine import SYSTEM_PROMPT
from mydata.service.assistant import Assistant
from mydata.service.config import Settings, load_settings
from mydata.service.logs import JsonFormatter, setup_logging
from mydata.service.model import ModelManager
from mydata.service.modes import REAL_SYSTEM_PROMPT, ModeController
from mydata.service.sync import BACKOFF, INTERVAL, SyncService
from mydata.sources.accounts import Accounts
from mydata.sources.calendar_store import CalendarStore
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.dav.client import DavClient
from mydata.sources.dav.discovery import discover
from mydata.sources.dav.sync import CollectionState, sync_collection
from mydata.sources.ical import summarise
from mydata.sources.secrets import MemorySecretStore
from mydata.sources.vcard import parse_vcard
from mydata.tools.mirror import MODEL_EVENT_LIMIT, mirror_tools

from service_helpers import TODAY, TOKEN, Scripted, call, make_app, serve, spied_registry

CONTACTS = "https://contacts.icloud.com"
CALENDAR = "https://caldav.icloud.com"
POSIX = not sys.platform.startswith("win")


class Clock:
    def __init__(self, t: float = 1_800_000_000.0):
        self.t = t

    def __call__(self) -> float:
        return self.t


def _service(tmp_path, fake, transport=None, **kw):
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()),
                          transport=transport or fake.transport, **kw)
    account = sources.add_account("icloud", fake_dav.USERNAME, fake_dav.PASSWORD)
    return sources, account


def _wrap(fake, before=None, after=None):
    """A transport over the fake server that can answer a request itself (before) or edit the answer."""
    def handler(request: httpx.Request) -> httpx.Response:
        if before is not None:
            early = before(request)
            if early is not None:
                return early
        resp = fake.transport.handle_request(request)
        if after is not None:
            body = after(request, resp.read())
            if body is not None:
                return httpx.Response(resp.status_code, headers=resp.headers, content=body)
        return resp
    return httpx.MockTransport(handler)


def _is(request, report: bytes) -> bool:
    return request.method == "REPORT" and report in request.content


def _drop_response(body: bytes, name: str) -> bytes:
    """Remove the <D:response> for one member from a multistatus."""
    return re.sub(rb"<D:response>(?:(?!</D:response>).)*?" + re.escape(name.encode()) + rb".*?</D:response>",
                  b"", body, flags=re.S)


def _strip_etags(body: bytes) -> bytes:
    return re.sub(rb"<D:getetag>.*?</D:getetag>", b"", body, flags=re.S)


# ---------------------------------------------------------------- 1. no FTS residue after removing an account


def test_removing_an_account_leaves_no_contact_or_event_words_in_the_files(tmp_path):
    sources, account = _service(tmp_path, FakeDav())
    sources.sync_account(account.id)
    assert sources.contacts.search("madeup") and sources.calendar.counts(account.id)["events"] == 5
    sources.remove_account(account.id)

    files = sorted(p for p in tmp_path.iterdir() if p.name.startswith(("contacts.sqlite", "calendar.sqlite")))
    assert any(p.name == "contacts.sqlite" for p in files)
    raw = b"".join(p.read_bytes() for p in files).lower()
    for word in (b"madeup", b"fictional", b"someone@example", b"acme", b"plumbing", b"dentist", b"lake trip",
                 b"standup"):
        assert word not in raw, f"{word!r} is still in the mirror files"
    with sources.contacts.db.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM contacts_fts").fetchone()[0] == 0


# ---------------------------------------------------------------- 2. no collection URL (DSID) in the logs


@pytest.fixture
def captured():
    buf = io.StringIO()
    handler = logging.StreamHandler(buf)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    old = root.level
    root.addHandler(handler)
    root.setLevel(logging.DEBUG)
    yield buf
    root.removeHandler(handler)
    root.setLevel(old)


def test_token_rejected_unsupported_and_unresolved_paths_log_ids_not_urls(tmp_path, captured):
    fake = FakeDav()
    box = {"omit": False}

    def after(request, body):
        if box["omit"] and _is(request, b"addressbook-multiget"):
            return _drop_response(body, "ben-madeup.vcf")
        return None

    sources, account = _service(tmp_path, fake, transport=_wrap(fake, after=after))
    sources.sync_account(account.id)
    fake.update_item("card", "ben-madeup.vcf", vcard("fake-uid-ben", "Ben Madeup", n="Madeup;Ben;;;"))
    fake.expire_tokens()
    box["omit"] = True
    sources.sync_account(account.id)  # token rejected, and one changed card not returned
    box["omit"] = False
    fake.supports_sync = False
    sources.sync_account(account.id)  # sync-collection no longer answered

    # Our own loggers (httpx's request lines are silenced below WARNING by setup_logging in mydatad).
    lines = [r for r in (json.loads(line) for line in captured.getvalue().splitlines() if line.strip())
             if r["logger"].startswith("mydata")]
    shown = "\n".join(json.dumps(r) for r in lines if r["level"] != "DEBUG")
    assert "icloud.com/" not in shown and fake_dav.PRINCIPAL_ID not in shown
    synced = [r for r in lines if r["msg"] == "collection synced"]
    assert {r["reason"] for r in synced} == {None, "token_rejected", "sync_unsupported"}
    unresolved = [r for r in lines if r["msg"].startswith("changed items were not returned")]
    assert unresolved and unresolved[0]["count"] == 1 and unresolved[0]["collection_id"]
    # The debug lines name hosts only, never paths.
    assert fake_dav.PRINCIPAL_ID not in "\n".join(json.dumps(r) for r in lines)


# ---------------------------------------------------------------- 3. private host folder and logs


@pytest.mark.skipif(not POSIX, reason="POSIX permissions")
def test_host_folder_logs_and_log_files_are_private(tmp_path):
    old = os.umask(0o022)
    try:
        home = tmp_path / "host"
        settings = load_settings(home)
        assert stat.S_IMODE(home.stat().st_mode) == 0o700
        settings.log_dir.mkdir(mode=0o755)
        os.chmod(settings.log_dir, 0o755)  # as an older host left it
        root = logging.getLogger()
        handlers, level = list(root.handlers), root.level
        try:
            setup_logging(settings.log_dir, to_stderr=False)
            logging.getLogger("mydata.test").warning("hello")
        finally:
            for h in root.handlers:
                h.close()
            root.handlers[:] = handlers
            root.setLevel(level)
        assert stat.S_IMODE(settings.log_dir.stat().st_mode) == 0o700
        assert stat.S_IMODE((settings.log_dir / "mydatad.log").stat().st_mode) == 0o600

        registry, _ = spied_registry()
        assistant = Assistant(settings, registry, model_factory=lambda: Scripted([{"content": "Hi."}]),
                              today=lambda: TODAY)
        list(assistant.reply("Hello"))
        assert stat.S_IMODE((settings.log_dir / "assistant.jsonl").stat().st_mode) == 0o600
    finally:
        os.umask(old)


@pytest.mark.skipif(not POSIX, reason="POSIX permissions")
def test_rotated_log_files_stay_private(tmp_path):
    from mydata.service.logs import PrivateRotatingFileHandler
    old = os.umask(0o022)
    try:
        h = PrivateRotatingFileHandler(tmp_path / "x.log", maxBytes=50, backupCount=2, encoding="utf-8")
        lg = logging.getLogger("mydata.test.rotate")
        lg.addHandler(h)
        lg.propagate = False
        for i in range(10):
            lg.warning("line %d with some padding text", i)
        h.close()
        lg.removeHandler(h)
        files = list(tmp_path.glob("x.log*"))
        assert len(files) >= 2 and all(stat.S_IMODE(f.stat().st_mode) == 0o600 for f in files)
    finally:
        os.umask(old)


# ---------------------------------------------------------------- 4. a full sync with unreturned items


@pytest.mark.parametrize("supports_sync", [True, False])
def test_items_the_multiget_left_out_arrive_on_the_next_sync(supports_sync):
    fake = FakeDav(supports_sync=supports_sync)
    omitting = _wrap(fake, after=lambda req, body: _drop_response(body, "ben-madeup.vcf")
                     if _is(req, b"addressbook-multiget") else None)
    client = fake.client(transport=omitting)
    book = discover(client, CONTACTS, "contacts").collections[0]
    first = sync_collection(client, book, CollectionState())
    assert first.unresolved == 1 and not any("ben-madeup" in i.href for i in first.changed)
    assert first.state.sync_token is None and first.state.ctag is None  # markers not advanced

    second = sync_collection(fake.client(), book, first.state)
    assert [i.href.rsplit("/", 1)[1] for i in second.changed] == ["ben-madeup.vcf"]
    assert second.unresolved == 0 and second.deleted == []
    assert second.state.ctag == fake.collection("card").ctag
    assert (second.state.sync_token is not None) == supports_sync
    assert set(second.state.etags) == {fake.href("card", n) for n in fake.collection("card").items}


# ---------------------------------------------------------------- 5. calendar resources at datetime's edges


FOREVER = vevent_calendar(vevent("fake-uid-forever", "Forever invented", "DTSTART:20260302T090000Z",
                                 "DTEND:20260302T100000Z", extra="RRULE:FREQ=WEEKLY;UNTIL=99991231T000000Z"))
YEAR_ONE = vevent_calendar(vevent("fake-uid-year-one", "Year one invented", "DTSTART;VALUE=DATE:00010101",
                                  extra="RRULE:FREQ=YEARLY"))


def test_series_reaching_the_edges_of_datetime_are_stored_and_expanded(tmp_path):
    assert summarise(FOREVER).range_end is None
    assert summarise(YEAR_ONE).range_start is None
    fake = FakeDav(calendars={"edge": {"name": "Edge", "components": ("VEVENT",),
                                       "items": {"forever.ics": FOREVER, "year-one.ics": YEAR_ONE}}})
    client = fake.client()
    cal = discover(client, CALENDAR, "calendar").collections[0]
    store = CalendarStore(tmp_path / "calendar.sqlite")
    store.apply("acct", cal, sync_collection(client, cal, CollectionState()))
    from zoneinfo import ZoneInfo
    tz = ZoneInfo("UTC")
    got = store.events_between(datetime(2026, 1, 1, tzinfo=tz), datetime(2026, 3, 10, tzinfo=tz), tz=tz)
    assert {e["title"] for e in got} == {"Forever invented", "Year one invented"}


def test_one_unreadable_resource_is_skipped_and_the_rest_stored(tmp_path, monkeypatch):
    import mydata.sources.calendar_store as cs

    real = cs.summarise

    def flaky(text):
        if "fake-uid-dentist" in text:
            raise OverflowError("date value out of range")
        return real(text)

    monkeypatch.setattr(cs, "summarise", flaky)
    fake = FakeDav()
    client = fake.client()
    home = next(c for c in discover(client, CALENDAR, "calendar").collections if c.display_name == "Home")
    store = CalendarStore(tmp_path / "calendar.sqlite")
    store.apply("acct", home, sync_collection(client, home, CollectionState()))
    assert store.counts("acct") == {"calendars": 1, "events": 2}


# ---------------------------------------------------------------- 6. one failure does not stop the account


def test_a_failing_calendar_does_not_stop_the_others(tmp_path):
    fake = FakeDav()
    broken = fake.collection("home").path

    def before(request):
        if request.method == "REPORT" and request.url.path == broken:
            return httpx.Response(500)
        return None

    clock = Clock()
    sources, account = _service(tmp_path, fake, transport=_wrap(fake, before=before), clock=clock)
    status = sources.sync_account(account.id)
    assert status["state"] == "error" and "HTTP 500" in status["last_error"]
    assert status["counts"]["contacts"] == 6 and status["counts"]["events"] == 2  # work + holidays
    entry = sources._entry(account.id)
    assert entry.due == clock.t + INTERVAL and entry.failures == 0  # the usual interval, no backoff


def test_a_failed_discovery_keeps_that_kinds_data_and_syncs_the_other(tmp_path):
    fake = FakeDav()
    box = {"down": False}

    def before(request):
        if box["down"] and request.url.host in (fake.contacts_host, fake.contacts_partition):
            return httpx.Response(503)
        return None

    sources, account = _service(tmp_path, fake, transport=_wrap(fake, before=before))
    assert sources.sync_account(account.id)["state"] == "idle"
    box["down"] = True
    fake.add_item("home", "new.ics", vevent_calendar(vevent("fake-uid-new", "New invented thing",
                                                            "DTSTART:20260325T020000Z", "DTEND:20260325T030000Z")))
    status = sources.sync_account(account.id)
    assert status["state"] == "error"
    assert status["counts"]["contacts"] == 6 and status["counts"]["address_books"] == 1  # not marked gone
    assert status["counts"]["events"] == 6


def test_nothing_synced_backs_off(tmp_path):
    fake = FakeDav()
    box = {"down": False}
    clock = Clock()
    sources, account = _service(tmp_path, fake, clock=clock, transport=_wrap(
        fake, before=lambda r: httpx.Response(500) if box["down"] else None))
    box["down"] = True
    status = sources.sync_account(account.id)
    entry = sources._entry(account.id)
    assert status["state"] == "error" and entry.failures == 1 and entry.due == clock.t + BACKOFF[0]


# ---------------------------------------------------------------- 7. relative hrefs after a redirect


def _ms(*responses: str) -> bytes:
    return ('<?xml version="1.0"?><D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
            + "".join(responses) + "</D:multistatus>").encode()


def _resp(href: str, props: str) -> str:
    return (f"<D:response><D:href>{href}</D:href><D:propstat><D:prop>{props}</D:prop>"
            "<D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>")


def test_relative_hrefs_resolve_against_the_host_that_answered():
    seen: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        host, path = request.url.host, request.url.path
        seen.append(f"{host}{path}")
        if host == "contacts.icloud.com" and path == "/.well-known/carddav":
            return httpx.Response(207, content=_ms(_resp(path, "<D:current-user-principal><D:href>/123/principal/"
                                                               "</D:href></D:current-user-principal>")))
        if host == "contacts.icloud.com" and path.startswith("/123/"):
            return httpx.Response(301, headers={"Location": f"https://p42-contacts.icloud.com{path}"})
        if host == "p42-contacts.icloud.com" and path == "/123/principal/":
            return httpx.Response(207, content=_ms(_resp(path, "<C:addressbook-home-set><D:href>/123/carddavhome/"
                                                               "</D:href></C:addressbook-home-set>")))
        if host == "p42-contacts.icloud.com" and path == "/123/carddavhome/":
            return httpx.Response(207, content=_ms(
                _resp("/123/carddavhome/", "<D:resourcetype><D:collection/></D:resourcetype>"),
                _resp("card/", "<D:resourcetype><D:collection/><C:addressbook/></D:resourcetype>"
                               "<D:displayname>Contacts</D:displayname>")))
        return httpx.Response(404)

    client = DavClient("ava.fictional@example.com", "invented-pw", transport=httpx.MockTransport(handler))
    found = discover(client, CONTACTS, "contacts")
    assert found.home_urls == ["https://p42-contacts.icloud.com/123/carddavhome/"]
    assert [c.url for c in found.collections] == ["https://p42-contacts.icloud.com/123/carddavhome/card/"]


# ---------------------------------------------------------------- 8. commas in vCard text values


def test_vcard_nickname_lists_and_unescaped_commas_are_kept_whole(tmp_path):
    text = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:fake-uid-zed\r\nFN:Zed Invented, Jr\r\nN:Invented;Zed;;;\r\n"
            "NICKNAME:Zeddy,Zo\r\nitem1.NICKNAME:Zee\\, the second\r\nNOTE:met at a made-up conf, nice\\nline two\r\n"
            "END:VCARD\r\n")
    card = parse_vcard(text)
    assert card.full_name == "Zed Invented, Jr"
    assert card.nickname == "Zeddy, Zo, Zee, the second"
    assert card.note == "met at a made-up conf, nice\nline two"

    fake = FakeDav(contacts={"zed.vcf": text})
    client = fake.client()
    book = discover(client, CONTACTS, "contacts").collections[0]
    store = ContactsStore(tmp_path / "contacts.sqlite")
    store.apply("acct", book, sync_collection(client, book, CollectionState()))
    assert [c["name"] for c in store.find_by_name("Zo")] == ["Zed Invented, Jr"]
    assert [c["display_name"] for c in store.search("jr")] == ["Zed Invented, Jr"]


# ---------------------------------------------------------------- 9. members without a getetag


def test_a_change_reported_without_an_etag_is_fetched():
    fake = FakeDav()
    client = fake.client()
    book = discover(client, CONTACTS, "contacts").collections[0]
    state = sync_collection(client, book, CollectionState()).state
    fake.add_item("card", "nora.vcf", vcard("fake-uid-nora", "Nora Invented", n="Invented;Nora;;;"))
    no_etags = _wrap(fake, after=lambda req, body: _strip_etags(body) if _is(req, b"sync-collection") else None)
    r = sync_collection(fake.client(transport=no_etags), book, state)
    assert [i.href.rsplit("/", 1)[1] for i in r.changed] == ["nora.vcf"]
    assert r.state.sync_token == fake.token("card")


def test_a_listed_member_without_an_etag_is_fetched_not_deleted():
    fake = FakeDav(supports_sync=False)
    client = fake.client()
    book = discover(client, CONTACTS, "contacts").collections[0]
    state = sync_collection(client, book, CollectionState()).state
    fake.add_item("card", "nora.vcf", vcard("fake-uid-nora", "Nora Invented", n="Invented;Nora;;;"))

    def after(req, body):
        if req.method == "PROPFIND" and req.headers.get("depth") == "1":
            return _strip_etags(body)
        return None

    r = sync_collection(fake.client(transport=_wrap(fake, after=after)), book, state)
    assert r.deleted == []
    assert len(r.changed) == 7  # every etag unknown: all fetched
    assert set(r.state.etags) == {fake.href("card", n) for n in fake.collection("card").items}


# ---------------------------------------------------------------- 11. list_events is capped for the model


class _Contacts:
    def find_by_name(self, name):
        return [{"id": "c1", "name": "Ava Fictional", "emails": ["ava.fictional@example.com"], "phones": []}]


class _Daily:
    """A daily series: one occurrence per day in the window."""

    def events_between(self, start, end, calendar_ids=None, tz=None):
        out, day = [], start
        while day < end:
            out.append({"event_id": "e1", "calendar_id": "k", "uid": "u", "recurrence_id": day.isoformat(),
                        "title": "Invented daily standup", "location": "", "notes": "", "all_day": False,
                        "start": day.replace(hour=9).isoformat(), "end": day.replace(hour=9, minute=15).isoformat(),
                        "time_zone": "UTC"})
            day += timedelta(days=1)
        return out


def test_list_events_sends_the_model_at_most_the_limit_and_shows_the_app_everything(tmp_path):
    from zoneinfo import ZoneInfo
    from mydata.orchestrator.engine import Engine
    from mydata.tools.registry import Registry

    registry = Registry(mirror_tools(_Contacts(), _Daily(), tz=lambda: ZoneInfo("UTC")), today=lambda: TODAY,
                        mode="real")
    inv = registry.invoke("list_events", {}, caller="test")
    assert inv.status == "ok"
    assert len(inv.result["events"]) == MODEL_EVENT_LIMIT
    assert inv.result["count"] == 61 and inv.result["truncated"] is True  # today and the next 60 days
    assert len(inv.display["events"]) == 61
    assert "display" not in inv.to_json()

    seen: list[list[dict]] = []

    class Model(Scripted):
        def chat(self, messages, tools):
            seen.append(list(messages))
            return super().chat(messages, tools)

    engine = Engine(Model([[call("list_events")], {"content": "A standup every day."}]), TODAY, registry=registry,
                    followup="full")
    run = engine.run("What's coming up?")
    assert run.results[0]["header"] == "61 events coming up" and len(run.results[0]["items"]) == 61
    tool_msg = json.loads(next(m for m in seen[-1] if m["role"] == "tool")["content"])
    assert len(tool_msg["events"]) == MODEL_EVENT_LIMIT and tool_msg["truncated"] is True
    assert "display" not in json.dumps(run.to_json())


# ---------------------------------------------------------------- 12. the request log says the mode


def test_request_log_entries_carry_the_mode_and_real_ones_no_results(tmp_path):
    registry, _ = spied_registry()
    settings = Settings(home=tmp_path)
    scripts = [[[call("find_contact", name="Nisha")], {"content": "Found."}],
               [[call("find_contact", name="Ava")], {"content": "Ava's address is ava.fictional@example.com."}]]
    assistant = Assistant(settings, registry, model_factory=lambda: Scripted(scripts.pop(0)), today=lambda: TODAY)
    list(assistant.reply("Find Nisha"))
    from zoneinfo import ZoneInfo
    assistant.apply_mode("real", mirror_tools(_Contacts(), _Daily(), tz=lambda: ZoneInfo("UTC")),
                         lambda: TODAY, REAL_SYSTEM_PROMPT)
    list(assistant.reply("Find Ava"))
    demo, real = [json.loads(line) for line in (settings.log_dir / "assistant.jsonl").read_text().splitlines()]
    assert demo["mode"] == "demo" and "nisha" in json.dumps(demo["calls"][0]["result"]).lower()
    assert real["mode"] == "real"
    assert real["calls"][0]["tool"] == "find_contact" and real["calls"][0]["status"] == "ok"
    assert real["calls"][0]["result"] == {"matches": 1}
    assert real["results"] == [{"tool": "find_contact", "kind": "contacts", "items": 1}]
    assert "ava.fictional@example.com" not in json.dumps(real["calls"]) + json.dumps(real["results"])


# ---------------------------------------------------------------- 13. agents do not reach real data


async def _mcp(base, token, fn):
    async with httpx2.AsyncClient(headers={"Authorization": f"Bearer {token}"}) as http:
        async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as c:
            return await fn(c)


def test_mcp_agents_get_no_tools_in_real_mode_but_apps_do(tmp_path):
    from zoneinfo import ZoneInfo
    app, registry, _ = make_app(tmp_path)
    _, agent = app.auth.agents.create("helper")
    with serve(app) as (base, _):
        assert len(asyncio.run(_mcp(base, agent, lambda c: c.list_tools())).tools) == 6  # demo: the fake tools
        registry.replace_tools(mirror_tools(_Contacts(), _Daily(), tz=lambda: ZoneInfo("UTC")), mode="real")
        assert asyncio.run(_mcp(base, agent, lambda c: c.list_tools())).tools == []
        refused = asyncio.run(_mcp(base, agent, lambda c: c.call_tool("find_contact", {"name": "Ava"})))
        assert refused.is_error
        payload = json.loads(refused.content[0].text)
        assert payload["status"] == "refused" and "ava.fictional" not in refused.content[0].text
        # The user's own apps still see the two real tools, and event notes never go out.
        tools = asyncio.run(_mcp(base, TOKEN, lambda c: c.list_tools())).tools
        assert [t.name for t in tools] == ["find_contact", "list_events"]
        got = asyncio.run(_mcp(base, TOKEN, lambda c: c.call_tool("list_events", {"date": "today"})))
        assert "notes" not in got.content[0].text


# ---------------------------------------------------------------- 14. the switching machinery


class _WarmRecorder:
    """A model stand-in whose warm() records the prefix it was given; optionally blocks the first call."""

    def __init__(self, block_first: bool = False):
        self.prefixes: list[tuple[str, list[str]]] = []
        self.entered = threading.Event()
        self.release = threading.Event()
        if not block_first:
            self.release.set()

    def factory(self):
        rec = self

        class M(Scripted):
            def warm(self, system, definitions):
                rec.prefixes.append((system["content"], [d["function"]["name"] for d in definitions]))
                rec.entered.set()
                assert rec.release.wait(10)
        return M([])


def _manager(tmp_path, assistant, enabled=True):
    mm = ModelManager(Settings(home=tmp_path), enabled=enabled, warm=assistant.warm)
    mm._reachable = lambda: True
    mm._has_model = lambda: True
    mm._is_loaded = lambda: True
    return mm


def _until(predicate, timeout=10.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.01)
    return False


@pytest.fixture
def switchable(tmp_path):
    registry, _ = spied_registry()
    rec = _WarmRecorder()
    assistant = Assistant(Settings(home=tmp_path), registry, model_factory=rec.factory, today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    return assistant, sources, rec


def test_rewarm_when_ready_uses_the_new_prefix(tmp_path, switchable):
    assistant, sources, rec = switchable
    mm = _manager(tmp_path, assistant)
    modes = ModeController(assistant, sources, on_change=lambda _m: mm.rewarm(), real_today=lambda: TODAY)
    mm.retry()
    assert _until(lambda: mm.status().state == "ready")
    assert rec.prefixes == [(SYSTEM_PROMPT, list(spied_registry()[0].names()))]
    sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)
    assert modes.refresh() == "real"
    assert _until(lambda: len(rec.prefixes) == 2)
    assert rec.prefixes[1] == (REAL_SYSTEM_PROMPT, ["find_contact", "list_events"])


def test_rewarm_does_nothing_when_disabled_or_not_ready(tmp_path, switchable):
    assistant, _, rec = switchable
    off = _manager(tmp_path, assistant, enabled=False)
    off.rewarm()
    broken = _manager(tmp_path, assistant)
    broken._set(state="error", error="invented")
    broken.rewarm()
    time.sleep(0.1)
    assert rec.prefixes == []


def test_a_switch_while_loading_warms_again_with_the_new_prefix(tmp_path):
    registry, _ = spied_registry()
    rec = _WarmRecorder(block_first=True)
    assistant = Assistant(Settings(home=tmp_path), registry, model_factory=rec.factory, today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    mm = _manager(tmp_path, assistant)
    modes = ModeController(assistant, sources, on_change=lambda _m: mm.rewarm(), real_today=lambda: TODAY)
    mm.retry()
    assert rec.entered.wait(10)  # loading: the demo prefix has been sent
    sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)
    modes.refresh()
    assert mm.status().state == "loading"
    rec.release.set()
    assert _until(lambda: mm.status().state == "ready")
    assert [p[0] for p in rec.prefixes] == [SYSTEM_PROMPT, REAL_SYSTEM_PROMPT]


def test_a_switch_waits_for_the_reply_in_progress(tmp_path):
    registry, _ = spied_registry()
    entered, release = threading.Event(), threading.Event()
    seen: list[tuple[str, list[str]]] = []

    class Blocking(Scripted):
        def chat(self, messages, tools):
            seen.append((messages[0]["content"], [t["function"]["name"] for t in tools]))
            entered.set()
            assert release.wait(10)
            return {"content": "Done.", "tool_calls": []}

    assistant = Assistant(Settings(home=tmp_path), registry, model_factory=lambda: Blocking([]), today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    modes = ModeController(assistant, sources, real_today=lambda: TODAY)
    sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)

    replying = threading.Thread(target=lambda: list(assistant.reply("Hello", "c1")))
    replying.start()
    assert entered.wait(10)
    switching = threading.Thread(target=modes.refresh)
    switching.start()
    switching.join(0.3)
    assert switching.is_alive() and registry.mode == "demo"  # held until the reply is done
    release.set()
    replying.join(10)
    switching.join(10)
    assert not switching.is_alive() and registry.mode == "real"
    assert seen == [(SYSTEM_PROMPT, list(spied_registry()[0].names()))]  # the whole reply ran in demo mode
    assert assistant.history("c1") == []  # and the switch ended its conversation
