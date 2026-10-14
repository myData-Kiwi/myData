"""Editing contacts through the host as mydatad builds it (service/api.py): POST, PATCH with If-Match (428,
412), DELETE to Recently deleted, GET /trash, restore, /undo across a restart, followed contacts refused, the
first owned contact switching the host to real mode, which apps may write, and logs that hold no contact
data (the daily trash expiry is in test_trash_expiry.py). Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import logging
import pytest
from starlette.testclient import TestClient

from fake_dav import FakeDav
from mydata.service.auth import AgentStore
from mydata.service.logs import LAST_ERROR

import test_contacts_store as con
from service_helpers import Host, call, parse_sse

AVA = {"given_name": "Ava", "family_name": "Fictional", "emails": [{"label": "work", "value": "ava@example.org"}],
       "phones": [{"label": "mobile", "value": "+1 555 0100"}], "note": "Brings invented biscuits."}
SECRETS = ("Ava", "Fictional", "ava@example.org", "555 0100", "biscuits", "Avi")


def bearer(host: Host, app: str) -> dict:
    return {"Authorization": f"Bearer {(host.home / 'app-tokens' / app).read_text().strip()}"}


@pytest.fixture
def host(tmp_path):
    return Host(tmp_path, FakeDav(), scripts=[[[call("find_contact", name="Ava")]]])


@pytest.fixture
def client(host):
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        yield c


def create(client, host, body=AVA, app="mycontacts"):
    r = client.post("/contacts", headers=bearer(host, app), json=body)
    assert r.status_code == 201, r.text
    return r


def test_creating_the_first_contact_switches_to_real_mode_and_ends_conversations(host, client):
    status = client.get("/status", headers=host.auth).json()
    assert status["mode"] == "demo"
    r = create(client, host)
    body = r.json()
    contact = body["contact"]
    assert r.headers["ETag"] == contact["etag"] and contact["etag"].startswith('"1-')
    assert contact["editable"] is True and contact["source"] == "mydata" and contact["on_phone"] is False
    assert contact["source_label"] == "myData" and contact["account_id"] == "local"
    assert contact["display_name"] == "Ava Fictional" and contact["note"] == "Brings invented biscuits."
    assert [g["kind"] for g in contact["fields"]] == ["phone", "email", "note"] and body["undo_id"]
    after = client.get("/status", headers=host.auth).json()
    assert after["mode"] == "real" and after["conversation_epoch"] == status["conversation_epoch"] + 1
    assert host.models.rewarms == 1
    create(client, host, {"company": "Example Library"})
    assert client.get("/status", headers=host.auth).json()["conversation_epoch"] == after["conversation_epoch"]
    assert [t["name"] for t in client.get("/tools", headers=host.auth).json()] == ["find_contact", "list_events"]


def test_find_contact_and_the_lists_include_owned_contacts(host, client):
    contact_id = create(client, host).json()["contact"]["id"]
    listed = client.get("/contacts", headers=bearer(host, "mycontacts")).json()
    assert [(x["id"], x["editable"], x["on_phone"], x["source"]) for x in listed] == [
        (contact_id, True, False, "mydata")]
    assert [x["id"] for x in client.get("/contacts?query=ava", headers=host.auth).json()] == [contact_id]
    events = parse_sse(client.post("/assistant/messages", headers=host.assistant_auth,
                                   json={"text": "Find Ava"}).text)
    result = dict(events)["result"]
    assert result["mode"] == "real" and [i["id"] for i in result["items"]] == [contact_id]
    logged = (host.assistant.settings.log_dir / "assistant.jsonl").read_text()  # real mode: shapes only
    assert '"mode": "real"' in logged and "ava@example.org" not in logged and "555 0100" not in logged


def test_patch_needs_if_match_and_refuses_a_stale_one(host, client):
    contact = create(client, host).json()["contact"]
    path = f"/contacts/{contact['id']}"
    auth = bearer(host, "mycontacts")
    r = client.patch(path, headers=auth, json={"nickname": "Avi"})
    assert r.status_code == 428
    r = client.patch(path, headers={**auth, "If-Match": contact["etag"]}, json={"nickname": "Avi"})
    assert r.status_code == 200, r.text
    new = r.json()["contact"]
    assert new["nickname"] == "Avi" and new["etag"] != contact["etag"] and r.headers["ETag"] == new["etag"]
    assert new["given_name"] == "Ava" and new["emails"] == contact["emails"]  # fields left out are kept
    r = client.patch(path, headers={**auth, "If-Match": contact["etag"]}, json={"nickname": "Lost"})
    assert r.status_code == 412
    assert r.json() == {"detail": "This contact changed since it was read. Reload it and try again.",
                        "etag": new["etag"]}
    assert r.headers["ETag"] == new["etag"]
    detail = client.get(path, headers=auth)
    assert detail.json()["nickname"] == "Avi" and detail.headers["ETag"] == new["etag"]
    # null clears a field; the edit form's values are all there
    r = client.patch(path, headers={**auth, "If-Match": new["etag"]}, json={"nickname": None, "phones": []})
    cleared = r.json()["contact"]
    assert cleared["nickname"] == "" and cleared["phones"] == [] and cleared["emails"] == contact["emails"]
    assert {k: cleared[k] for k in ("middle_name", "name_prefix", "name_suffix", "company", "department")} == {
        "middle_name": "", "name_prefix": "", "name_suffix": "", "company": "", "department": ""}


def test_errors_are_given_per_field_without_the_values(host, client):
    r = client.post("/contacts", headers=bearer(host, "mycontacts"),
                    json={"given_name": "Ava", "emails": [{"label": "", "value": "ava-at-example"}],
                          "phones": [{"value": "call me"}], "birthday": "18 March"})
    assert r.status_code == 400
    assert r.json() == {"detail": "Some fields are not valid.", "fields": {
        "emails[0].value": "Not an email address.", "phones[0].value": "Not a phone number.",
        "birthday": "Not a date: YYYY-MM-DD, or --MM-DD without a year."}}
    assert "ava-at-example" not in r.text and "call me" not in r.text
    assert client.get("/status", headers=host.auth).json()["mode"] == "demo"  # nothing was made


def test_delete_trash_restore_and_undo(host, client):
    auth = bearer(host, "mycontacts")
    contact = create(client, host).json()["contact"]
    path = f"/contacts/{contact['id']}"
    r = client.delete(path, headers=auth)
    assert r.status_code == 200, r.text
    deleted, undo_delete = r.json()["contact"], r.json()["undo_id"]
    assert deleted["deleted_at"] and deleted["purge_after"] > deleted["deleted_at"]
    assert client.get(path, headers=auth).status_code == 404
    assert client.get("/contacts", headers=auth).json() == []
    trash = client.get("/trash?kind=contact", headers=auth).json()
    assert [(t["id"], t["kind"], t["title"], t["purge_after"]) for t in trash] == [
        (contact["id"], "contact", "Ava Fictional", deleted["purge_after"])]
    assert client.patch(path, headers={**auth, "If-Match": deleted["etag"]}, json={"nickname": "x"}).status_code == 409
    assert client.delete(path, headers=auth).status_code == 409
    r = client.post(f"/trash/{contact['id']}/restore", headers=auth)
    assert r.status_code == 200 and r.json()["contact"]["deleted_at"] is None
    assert client.get("/trash", headers=auth).json() == []
    assert client.post(f"/trash/{contact['id']}/restore", headers=auth).status_code == 404
    # The delete's undo now comes after the restore: refused, nothing changes.
    r = client.post(f"/undo/{undo_delete}", headers=auth)
    assert r.status_code == 409 and "changed since" in r.json()["detail"]
    undo_restore = client.delete(path, headers=auth).json()["undo_id"]
    r = client.post(f"/undo/{undo_restore}", headers=bearer(host, "mydata"))
    assert r.status_code == 200 and r.json()["contact"]["deleted_at"] is None and r.json()["undo_id"] == undo_restore
    assert client.post(f"/undo/{undo_restore}", headers=auth).status_code == 409
    assert client.post("/undo/no-such-id", headers=auth).status_code == 404


def test_undo_across_a_restart_of_the_host(tmp_path):
    first = Host(tmp_path, FakeDav())
    with TestClient(first.app, base_url="http://127.0.0.1") as c:
        contact = create(c, first).json()["contact"]
        r = c.patch(f"/contacts/{contact['id']}", headers={**bearer(first, "mycontacts"), "If-Match": contact["etag"]},
                    json={"job_title": "Inventor"})
        undo_id = r.json()["undo_id"]
    again = Host(tmp_path, FakeDav())  # a new host process over the same folder
    with TestClient(again.app, base_url="http://127.0.0.1") as c:
        assert c.get("/status", headers=again.auth).json()["mode"] == "real"  # owned data: real from the start
        r = c.post(f"/undo/{undo_id}", headers=bearer(again, "mycontacts"))
        assert r.status_code == 200 and r.json()["contact"]["job_title"] == ""
        assert r.json()["contact"]["etag"] not in (contact["etag"],)
        assert c.post(f"/undo/{undo_id}", headers=bearer(again, "mycontacts")).status_code == 409


def test_followed_contacts_cannot_be_changed(host, client):
    host.sources.contacts.apply("acc-1", con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    auth = bearer(host, "mycontacts")
    followed = client.get("/contacts", headers=auth).json()
    assert followed and all(x["editable"] is False and x["on_phone"] is None for x in followed)
    target = followed[0]
    r = client.patch(f"/contacts/{target['id']}", headers={**auth, "If-Match": target["etag"]},
                     json={"given_name": "Changed"})
    assert r.status_code == 409 and "followed" in r.json()["detail"]
    assert client.delete(f"/contacts/{target['id']}", headers=auth).status_code == 409
    assert client.get(f"/contacts/{target['id']}", headers=auth).json()["display_name"] == target["display_name"]


WRITES = [("post", "/contacts", {"given_name": "Pip"}), ("patch", "/contacts/x", {"given_name": "Pip"}),
          ("delete", "/contacts/x", None), ("post", "/trash/x/restore", None), ("post", "/undo/x", None)]


def _send(client, method, path, body, headers):
    kwargs = {"headers": {**headers, "If-Match": '"1-x"'}}
    if body is not None:
        kwargs["json"] = body
    return client.request(method.upper(), path, **kwargs)


def test_only_apps_with_contacts_write_reach_the_writes(host, client):
    for app in ("mycalendar", "myassistant"):
        for method, path, body in WRITES:
            r = _send(client, method, path, body, bearer(host, app))
            assert r.status_code == 403, (app, path)
        assert client.get("/trash", headers=bearer(host, "mycalendar")).status_code == 403
    for app in ("mycontacts", "mydata", "cli"):
        for method, path, body in WRITES:
            assert _send(client, method, path, body, bearer(host, app)).status_code != 403, (app, path)


def test_agent_tokens_reach_no_write_route(host, client):
    _, token = AgentStore(host.home).create("Example agent")
    for method, path, body in [*WRITES, ("get", "/trash", None)]:
        r = _send(client, method, path, body, {"Authorization": f"Bearer {token}"})
        assert r.status_code in (401, 403), (path, r.status_code)
    assert client.get("/contacts", headers=host.auth).json() == []


def test_the_logs_hold_no_contact_data(host, client, caplog):
    caplog.set_level(logging.DEBUG)
    contact = create(client, host).json()["contact"]
    auth = bearer(host, "mycontacts")
    etag = client.patch(f"/contacts/{contact['id']}", headers={**auth, "If-Match": contact["etag"]},
                        json={"nickname": "Avi"}).json()["contact"]["etag"]
    client.patch(f"/contacts/{contact['id']}", headers={**auth, "If-Match": contact["etag"]}, json={"nickname": "Avi"})
    client.post("/contacts", headers=auth, json={"emails": [{"value": "Ava Fictional"}]})
    undo = client.delete(f"/contacts/{contact['id']}", headers={**auth, "If-Match": etag}).json()["undo_id"]
    client.post(f"/undo/{undo}", headers=auth)
    written = [r for r in caplog.records if r.getMessage() == "contact written"]
    assert [r.fields["op"] for r in written] == ["create", "update", "delete", "undo"]
    assert all(set(r.fields) == {"op", "actor", "contact_id"} for r in written)
    logged = " ".join(f"{r.getMessage()} {getattr(r, 'fields', '')} {r.args}" for r in caplog.records)
    for secret in SECRETS:
        assert secret not in logged, secret
    assert LAST_ERROR.last is None or not any(s in str(LAST_ERROR.last) for s in SECRETS)
