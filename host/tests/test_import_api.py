"""Contact import and merge through the host as mydatad builds it (service/api.py, service/imports.py): the raw
upload, a preview that writes nothing, commit after a snapshot, history and undo (also after a restart), the caps,
the loss report, "Import a copy" of a followed iCloud account (never This Mac) with the shadowing rule seen through
find_contact, merge and its undo through /undo, which apps may import, and logs that hold no contact data.
Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import logging

import pytest
from starlette.testclient import TestClient

import import_corpus as corpus
import test_contacts_store as con
from fake_dav import FakeDav
from mydata.service import imports as imports_service
from mydata.service.auth import AgentStore
from mydata.service.backup import BackupError, list_snapshots
from mydata.sources import import_files
from mydata.sources._db import table_counts

from service_helpers import Host, call, parse_sse

SECRETS = ("Ava", "Fictional", "ava@example.org", "555-0100", "Sam Sample", "sam@example.org", "Zoë", "Book club",
           "Takeout", "Apple.vcf", "private-name")


def bearer(host: Host, app: str) -> dict:
    return {"Authorization": f"Bearer {(host.home / 'app-tokens' / app).read_text().strip()}"}


@pytest.fixture
def host(tmp_path):
    return Host(tmp_path, FakeDav(), scripts=[[[call("find_contact", name="Ava")]]] * 3)


@pytest.fixture
def client(host):
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        yield c


def upload(client, host, data: bytes, filename="contacts.vcf", app="mydata"):
    return client.post("/import/contacts/preview", params={"filename": filename}, content=data,
                       headers={**bearer(host, app), "Content-Type": "application/octet-stream"})


def counts(host) -> dict:
    with host.sources.contacts.db.connect() as db:
        return table_counts(db)


def test_preview_commit_history_and_undo(host, client):
    status = client.get("/status", headers=host.auth).json()
    assert status["mode"] == "demo"
    host.sources.contacts  # the file exists before the preview, to compare
    before = counts(host)
    r = upload(client, host, corpus.several(), filename="/Users/someone/Takeout.zip")
    assert r.status_code == 201, r.text
    preview = r.json()
    assert preview["label"] == "Takeout.zip" and preview["source"] == "file" and preview["needs_acceptance"] is False
    assert preview["counts"]["cards"] == 8 and preview["counts"]["groups"] == 1 and preview["counts"]["to_import"] == 8
    assert [c["code"] for c in preview["changes"]] == ["converted_21", "other_files"]
    assert {i["status"] for i in preview["items"]} == {"new"}
    assert counts(host) == before  # nothing written
    assert client.get(f"/import/previews/{preview['id']}", headers=bearer(host, "mydata")).json()["counts"] \
        == preview["counts"]
    r = client.post(f"/import/previews/{preview['id']}/commit", headers=bearer(host, "mydata"), json={})
    assert r.status_code == 201, r.text
    done = r.json()
    assert done["status"] == "committed" and done["counts"]["created"] == 7 and done["counts"]["groups_created"] == 1
    assert done["label"] == "Takeout.zip" and done["stop_following"] is None
    after = client.get("/status", headers=host.auth).json()
    assert after["mode"] == "real" and after["conversation_epoch"] == status["conversation_epoch"] + 1
    listed = client.get("/contacts", headers=bearer(host, "mydata")).json()
    assert len(listed) == 7 and all(c["source"] == "mydata" and c["on_phone"] is False for c in listed)
    assert [s.manifest["reason"] for s in list_snapshots(host.home)] == ["pre-import"]
    # The preview was used: it is gone.
    assert client.get(f"/import/previews/{preview['id']}", headers=bearer(host, "mydata")).status_code == 404
    history = client.get("/imports", headers=bearer(host, "mydata")).json()
    assert [(h["id"], h["status"]) for h in history] == [(done["id"], "committed")]
    r = client.post(f"/imports/{done['id']}/undo", headers=bearer(host, "mydata"))
    assert r.status_code == 200, r.text
    assert r.json()["removed"] == 7 and r.json()["groups_removed"] == 1 and r.json()["kept"] == []
    assert r.json()["summary"]["status"] == "undone"
    assert client.get("/contacts", headers=bearer(host, "mydata")).json() == []
    assert len(client.get("/trash", headers=bearer(host, "mydata")).json()) == 7  # never deleted for good
    assert client.post(f"/imports/{done['id']}/undo", headers=bearer(host, "mydata")).status_code == 409
    assert client.post("/imports/no-such/undo", headers=bearer(host, "mydata")).status_code == 404


def test_importing_the_same_file_again_adds_nothing(host, client):
    data = corpus.read(corpus.APPLE)
    first = upload(client, host, data).json()
    client.post(f"/import/previews/{first['id']}/commit", headers=bearer(host, "mydata"), json={})
    again = upload(client, host, data).json()
    assert {i["status"] for i in again["items"]} == {"unchanged"} and again["counts"]["to_import"] == 0
    r = client.post(f"/import/previews/{again['id']}/commit", headers=bearer(host, "mydata"), json={})
    assert r.json()["counts"]["created"] == 0 and len(client.get("/contacts", headers=host.auth).json()) == 3


def test_choices_and_losses(host, client):
    client.post("/contacts", headers=bearer(host, "mydata"),
                json={"given_name": "Ava", "family_name": "Fictional", "emails": [{"value": "ava@example.org"}]})
    preview = upload(client, host, corpus.read(corpus.APPLE) + corpus.read(corpus.MALFORMED)).json()
    assert preview["needs_acceptance"] is True
    assert {loss["code"] for loss in preview["losses"]} == {"skipped_no_end", "skipped_version", "skipped_empty",
                                                            "outside_text"}
    ava = preview["items"][0]
    assert (ava["status"], ava["action"], ava["choices"]) == ("duplicate", "skip", ["skip", "import"])
    assert ava["matches"][0]["source"] == "mydata" and ava["matches"][0]["signals"] == ["email", "name"]
    url = f"/import/previews/{preview['id']}/commit"
    r = client.post(url, headers=bearer(host, "mydata"), json={})
    assert r.status_code == 400 and "loss report" in r.json()["detail"] and r.json()["code"] == "losses_not_accepted"
    r = client.post(url, headers=bearer(host, "mydata"),
                    json={"accept_losses": True, "choices": [{"index": 0, "action": "update"}]})
    assert r.status_code == 400 and "Card 0 can only be" in r.json()["detail"] and r.json()["code"] == "choice_refused"
    r = client.post(url, headers=bearer(host, "mydata"),
                    json={"accept_losses": True, "choices": [{"index": 0, "action": "import"}]})
    assert r.status_code == 201 and r.json()["counts"]["created"] == 4  # Ava as new, the org, Sam, Robin
    assert len([c for c in client.get("/contacts", headers=host.auth).json() if c["display_name"].startswith("Ava")]) == 2


def test_a_card_with_an_odd_character_set_never_fails_the_file(host, client):
    r = upload(client, host, corpus.read(corpus.ODD_CHARSETS))
    assert r.status_code == 201, r.text
    assert [(x["code"], x["count"]) for x in r.json()["losses"]] == [("skipped_unreadable", 1)]


def test_a_file_label_holds_no_control_or_format_characters():
    assert imports_service.file_label("C:\\Users\\x\\Ava\u202e\u200bfdp.vcf\x85\x00") == "Avafdp.vcf"
    assert imports_service.file_label("\u202e\u2066") == "Contacts file"


def test_inputs_refused_whole(host, client, monkeypatch):
    r = upload(client, host, corpus.bomb())
    assert r.status_code == 400 and "expands" in r.json()["detail"] and r.json()["code"] == "zip_entry_too_big"
    r = upload(client, host, b"not a vcard at all")
    assert r.status_code == 400 and r.json() == {"detail": "No vCard was found in the file.", "code": "no_vcard"}
    r = upload(client, host, corpus.zipped({"notes.txt": b"hello"}), filename="takeout.zip")
    assert r.status_code == 400 and r.json()["code"] == "zip_no_vcard"
    r = upload(client, host, corpus.traversal(), filename="../../evil.zip")
    assert r.status_code == 201 and r.json()["label"] == "evil.zip" and r.json()["counts"]["cards"] == 8


def test_a_file_over_the_cap_is_refused_before_it_is_read(tmp_path, monkeypatch):
    monkeypatch.setattr(import_files, "MAX_INPUT", 5000)
    host = Host(tmp_path, FakeDav())
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        r = upload(c, host, corpus.over_cap(5000))
        assert r.status_code == 413 and r.json()["code"] == "too_big"
        r = c.post("/import/contacts/preview", headers=bearer(host, "mydata"),
                   content=iter([corpus.over_cap(5000)]))  # streamed, no Content-Length
        assert r.status_code == 413 and r.json()["code"] == "too_big"


def test_nothing_is_imported_when_the_snapshot_fails(host, client, monkeypatch):
    def fail(*_a, **_k):
        raise BackupError("contacts.sqlite could not be copied (invented failure)")
    monkeypatch.setattr(imports_service, "take_snapshot", fail)
    preview = upload(client, host, corpus.read(corpus.APPLE)).json()
    r = client.post(f"/import/previews/{preview['id']}/commit", headers=bearer(host, "mydata"), json={})
    assert r.status_code == 503 and "Nothing was imported" in r.json()["detail"]
    assert client.get("/contacts", headers=host.auth).json() == [] and client.get("/imports", headers=host.auth).json() == []


def test_a_restart_drops_previews_and_keeps_imports_undoable(tmp_path):
    first = Host(tmp_path, FakeDav())
    with TestClient(first.app, base_url="http://127.0.0.1") as c:
        held = upload(c, first, corpus.read(corpus.GOOGLE)).json()
        used = upload(c, first, corpus.read(corpus.APPLE)).json()
        done = c.post(f"/import/previews/{used['id']}/commit", headers=bearer(first, "mydata"), json={}).json()
    again = Host(tmp_path, FakeDav())  # a new host process over the same folder
    with TestClient(again.app, base_url="http://127.0.0.1") as c:
        auth = bearer(again, "mydata")
        r = c.get(f"/import/previews/{held['id']}", headers=auth)
        assert r.status_code == 404 and "restarted" in r.json()["detail"]
        assert c.post(f"/import/previews/{held['id']}/commit", headers=auth, json={}).status_code == 404
        assert c.get("/status", headers=again.auth).json()["mode"] == "real"
        r = c.post(f"/imports/{done['id']}/undo", headers=auth)
        assert r.status_code == 200 and r.json()["removed"] == 3 and r.json()["groups_removed"] == 1


def test_a_preview_belongs_to_the_app_that_made_it_and_can_be_discarded(host, client):
    preview = upload(client, host, corpus.read(corpus.GOOGLE)).json()
    url = f"/import/previews/{preview['id']}"
    assert client.get(url, headers=bearer(host, "cli")).status_code == 404
    assert client.post(f"{url}/commit", headers=bearer(host, "cli"), json={}).status_code == 404
    assert client.delete(url, headers=bearer(host, "cli")).status_code == 404
    assert client.get(url, headers=bearer(host, "mydata")).status_code == 200
    assert client.delete(url, headers=bearer(host, "mydata")).status_code == 204
    assert client.get(url, headers=bearer(host, "mydata")).status_code == 404
    assert client.delete(url, headers=bearer(host, "mydata")).status_code == 404
    assert client.get("/imports", headers=host.auth).json() == []


def test_a_commit_takes_its_preview_before_it_writes(host):
    imports = imports_service.ContactImports(host.sources)
    preview = imports.preview_file(corpus.read(corpus.GOOGLE), "contacts.vcf", "mycontacts")
    seen = []

    def snapshot():
        try:
            imports.get(preview["id"], "mycontacts")
            seen.append("still held")
        except imports_service.PreviewGone:
            seen.append("gone")
    imports._snapshot = snapshot
    imports.commit(preview["id"], address_book_id=None, choices={}, accept_losses=False, actor="mycontacts")
    assert seen == ["gone"]  # a second commit of it, now, would find nothing
    with pytest.raises(imports_service.PreviewGone):
        imports.commit(preview["id"], address_book_id=None, choices={}, accept_losses=False, actor="mycontacts")


def test_previews_expire(tmp_path, monkeypatch):
    monkeypatch.setattr(imports_service, "PREVIEW_TTL", 0.0)  # expired as soon as it is made
    host = Host(tmp_path, FakeDav())
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        held = upload(c, host, corpus.read(corpus.GOOGLE)).json()
        assert held["expires_at"]
        assert c.get(f"/import/previews/{held['id']}", headers=bearer(host, "mydata")).status_code == 404


def test_cards_past_the_limit_are_one_loss_and_the_oldest_preview_goes_before_a_new_read(tmp_path, monkeypatch):
    monkeypatch.setattr(import_files, "MAX_CARDS", 2)
    host = Host(tmp_path, FakeDav())
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        r = upload(c, host, corpus.read(corpus.APPLE))
        preview = r.json()
        assert [i["status"] for i in preview["items"]] == ["new", "new"]
        assert preview["counts"]["cards"] == 4 and preview["counts"]["skipped"] == 2
        assert [(x["code"], x["count"]) for x in preview["losses"]] == [("skipped_too_many", 2)]
    imports = imports_service.ContactImports(host.sources, max_previews=2)
    held = []
    real = imports_service.read_contacts

    def counting(data):
        held.append(len(imports._previews))
        return real(data)
    monkeypatch.setattr(imports_service, "read_contacts", counting)
    for _ in range(4):
        imports.preview_file(corpus.read(corpus.GOOGLE), "contacts.vcf", "mycontacts")
    assert held == [0, 1, 1, 1] and len(imports._previews) == 2  # room is made before each read, not after


# ---------------------------------------------------------------- a copy of a followed source

def _follow(host) -> str:
    account = host.sources.accounts.add("icloud", "ava.fictional@example.com", "invented-app-pw",
                                        verify=lambda e, p: None)
    host.sources.contacts.apply(account.id, con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    host.sources.check_accounts()  # the host notices the account, as its sync loop would
    return account.id


def test_stop_following_says_what_is_not_on_mydata(host, client):
    account = _follow(host)
    auth = bearer(host, "mydata")
    preview = client.post(f"/import/contacts/from-source/{account}/preview", headers=auth).json()
    first = preview["items"][0]["index"]
    done = client.post(f"/import/previews/{preview['id']}/commit", headers=auth,
                       json={"choices": [{"index": first, "action": "skip"}]}).json()
    stop = done["stop_following"]
    assert stop["contacts_followed"] == 1 and stop["contacts_linked"] == 0
    assert stop["message"].startswith("Keep following") and "1 of its contact(s) are not on myData" in stop["message"]


def test_this_mac_is_never_imported(host, client):
    r = client.post("/import/contacts/from-source/mac/preview", headers=bearer(host, "mydata"))
    assert r.status_code == 409 and "never imported" in r.json()["detail"] and "Export vCard" in r.json()["detail"]
    assert client.post("/import/contacts/from-source/no-such/preview", headers=bearer(host, "mydata")).status_code \
        == 404


def test_a_person_imported_from_icloud_while_still_followed_is_found_once(host, client):
    account = _follow(host)
    auth = bearer(host, "mydata")
    assert len([c for c in client.get("/contacts", headers=auth).json() if c["display_name"] == "Ava Fictional"]) == 1
    r = client.post(f"/import/contacts/from-source/{account}/preview", headers=auth)
    assert r.status_code == 201, r.text
    preview = r.json()
    assert preview["source"] == "icloud" and preview["account_id"] == account
    stop = preview["stop_following"]
    assert stop["account_id"] == account and stop["contacts_followed"] == 7 and "Keep following" in stop["message"]
    done = client.post(f"/import/previews/{preview['id']}/commit", headers=auth, json={}).json()
    assert done["counts"]["created"] == 7 and done["stop_following"]["contacts_followed"] == 0
    assert done["stop_following"]["message"].startswith("You can stop following")
    listed = client.get("/contacts", headers=auth).json()
    assert len(listed) == 7 and {c["source"] for c in listed} == {"mydata"}
    events = parse_sse(client.post("/assistant/messages", headers=host.assistant_auth,
                                   json={"text": "Find Ava"}).text)
    result = dict(events)["result"]
    assert result["mode"] == "real" and len(result["items"]) == 1
    owned_ava = result["items"][0]["id"]
    assert client.get(f"/contacts/{owned_ava}", headers=auth).json()["source"] == "mydata"
    # The followed copy changes upstream: the owned one is flagged for review.
    edited = con.card("ava-fictional.vcf").replace("NICKNAME:Avi", "NICKNAME:Avi B")
    host.sources.contacts.apply(account, con.BOOK, con.result([con.Item(
        href="/1/carddavhome/card/ava-fictional.vcf", etag='"2"', data=edited)]))
    detail = client.get(f"/contacts/{owned_ava}", headers=auth).json()
    assert detail["changed_in_source"] == account
    assert detail["changed_in_source_label"] == "the iCloud account ava.fictional@example.com"
    events = parse_sse(client.post("/assistant/messages", headers=host.assistant_auth,
                                   json={"text": "Find Ava"}).text)
    assert len(dict(events)["result"]["items"]) == 1
    sources = client.get("/sources", headers=host.auth).json()["sources"]
    assert [s["counts"]["contacts"] for s in sources if s["id"] == account] == [0]


# ---------------------------------------------------------------- merge

def test_merge_says_what_it_left_out(host, client):
    auth = bearer(host, "mycontacts")
    a = client.post("/contacts", headers=auth, json={"given_name": "Ava", "job_title": "Librarian"}).json()
    b = client.post("/contacts", headers=auth, json={"given_name": "Ava", "job_title": "Chess coach"}).json()
    pair = [{"id": c["contact"]["id"], "etag": c["contact"]["etag"]} for c in (a, b)]
    r = client.post("/contacts/merge", headers=auth, json={"contacts": pair})
    assert r.status_code == 201, r.text
    assert r.json()["left_out"] == [{"property": "TITLE", "count": 1}]


def test_merge_and_undo_through_the_api(host, client):
    auth = bearer(host, "mycontacts")
    a = client.post("/contacts", headers=auth, json={"given_name": "Ava", "family_name": "Fictional",
                                                     "emails": [{"value": "ava@example.org"}]}).json()["contact"]
    b = client.post("/contacts", headers=auth, json={"given_name": "Ava", "phones": [{"value": "+1 202 555 0100"}],
                                                     "emails": [{"value": "Ava@Example.org"}]}).json()["contact"]
    r = client.post("/contacts/merge", headers=auth, json={"contacts": [{"id": a["id"], "etag": '"9-stale"'},
                                                                        {"id": b["id"], "etag": b["etag"]}]})
    assert r.status_code == 412
    r = client.post("/contacts/merge", headers=auth, json={"contacts": [{"id": a["id"], "etag": a["etag"]},
                                                                        {"id": a["id"], "etag": a["etag"]}]})
    assert r.status_code == 400
    r = client.post("/contacts/merge", headers=auth, json={"contacts": [{"id": a["id"], "etag": a["etag"]},
                                                                        {"id": b["id"], "etag": b["etag"]}]})
    assert r.status_code == 201, r.text
    merged = r.json()
    assert merged["contact"]["display_name"] == "Ava Fictional" and merged["merged"] == [a["id"], b["id"]]
    assert [p["value"] for p in merged["contact"]["phones"]] == ["+1 202 555 0100"]
    assert [c["id"] for c in client.get("/contacts", headers=auth).json()] == [merged["contact"]["id"]]
    r = client.post(f"/undo/{merged['undo_id']}", headers=auth)
    assert r.status_code == 200, r.text
    assert set(r.json()["contact_ids"]) == {a["id"], b["id"], merged["contact"]["id"]}
    assert {c["id"] for c in client.get("/contacts", headers=auth).json()} == {a["id"], b["id"]}
    assert client.post(f"/undo/{merged['undo_id']}", headers=auth).status_code == 409


# ---------------------------------------------------------------- who may import, and the logs

IMPORT_ROUTES = [("post", "/import/contacts/preview"), ("post", "/import/contacts/from-source/x/preview"),
                 ("get", "/import/previews/x"), ("delete", "/import/previews/x"), ("post", "/import/previews/x/commit"),
                 ("get", "/imports"), ("post", "/imports/x/undo")]


def _send(client, method, path, headers):
    kwargs = {"headers": headers}
    if method == "post":
        kwargs["content"] = b"{}"
    return client.request(method.upper(), path, **kwargs)


def test_only_the_mydata_app_and_the_command_import_and_agents_get_nothing(host, client):
    for app in ("mycontacts", "mycalendar", "myassistant"):
        for method, path in IMPORT_ROUTES:
            assert _send(client, method, path, bearer(host, app)).status_code == 403, (app, path)
    for app in ("mydata", "cli"):
        for method, path in IMPORT_ROUTES:
            assert _send(client, method, path, bearer(host, app)).status_code != 403, (app, path)
    # Merging stays with editing (contacts:write): myContacts merges.
    for app in ("mycontacts", "mydata", "cli"):
        assert _send(client, "post", "/contacts/merge", bearer(host, app)).status_code != 403, app
    for app in ("mycalendar", "myassistant"):
        assert _send(client, "post", "/contacts/merge", bearer(host, app)).status_code == 403, app
    _, token = AgentStore(host.home).create("Example agent")
    for method, path in [*IMPORT_ROUTES, ("post", "/contacts/merge")]:
        assert _send(client, method, path, {"Authorization": f"Bearer {token}"}).status_code in (401, 403), path
    tools = [t["name"] for t in client.get("/tools", headers=host.auth).json()]
    assert not any("import" in t or "merge" in t for t in tools)


def test_the_logs_hold_no_imported_data(host, client, caplog):
    caplog.set_level(logging.DEBUG)
    account = _follow(host)
    preview = upload(client, host, corpus.several(), filename="Takeout private-name.zip").json()
    done = client.post(f"/import/previews/{preview['id']}/commit", headers=bearer(host, "mydata"), json={}).json()
    client.post(f"/imports/{done['id']}/undo", headers=bearer(host, "mydata"))
    copy = client.post(f"/import/contacts/from-source/{account}/preview", headers=bearer(host, "mydata")).json()
    client.post(f"/import/previews/{copy['id']}/commit", headers=bearer(host, "mydata"), json={})
    upload(client, host, corpus.read(corpus.MALFORMED))
    messages = [r.getMessage() for r in caplog.records]
    assert {"contacts import previewed", "contacts imported", "contacts import undone"} <= set(messages)
    # httpx's records are the test client's own requests (the host sets httpx to WARNING, and its access log
    # leaves out query strings).
    logged = " ".join(f"{r.getMessage()} {getattr(r, 'fields', '')} {r.args}" for r in caplog.records
                      if not r.name.startswith("httpx"))
    for secret in SECRETS:
        assert secret not in logged, secret
