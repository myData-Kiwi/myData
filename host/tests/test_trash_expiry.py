"""The daily trash expiry (service/trash.py): what has been in Recently deleted for 30 days is deleted for good
through purge permits, and a host with no contacts file gets none made. Invented data only."""

from __future__ import annotations

import time
from datetime import datetime, timedelta, timezone

from starlette.testclient import TestClient

from fake_dav import FakeDav
from mydata.service.trash import TrashExpiry

from service_helpers import Host
from test_contacts_api import bearer, create


def test_the_daily_expiry_purges_the_trash_after_30_days(tmp_path):
    host = Host(tmp_path, FakeDav())
    with TestClient(host.app, base_url="http://127.0.0.1") as client:
        _expire(host, client)


def _expire(host, client):
    contact = create(client, host).json()["contact"]
    client.delete(f"/contacts/{contact['id']}", headers={**bearer(host, "mycontacts"), "If-Match": contact["etag"]})
    purge_after = datetime.fromisoformat(client.get("/trash", headers=host.auth).json()[0]["purge_after"])
    early = TrashExpiry(host.sources, clock=lambda: purge_after - timedelta(minutes=1))
    assert early.run_once() == 0 and len(client.get("/trash", headers=host.auth).json()) == 1
    assert TrashExpiry(host.sources, clock=lambda: purge_after).run_once() == 1
    assert client.get("/trash", headers=host.auth).json() == []
    assert client.post(f"/trash/{contact['id']}/restore", headers=host.auth).status_code == 404
    assert client.get("/status", headers=host.auth).json()["mode"] == "real"  # the address book stays


def test_the_expiry_never_creates_a_file(tmp_path):
    host = Host(tmp_path, FakeDav())
    assert TrashExpiry(host.sources, clock=lambda: datetime.now(timezone.utc)).run_once() == 0
    assert not (tmp_path / "contacts.sqlite").exists()


def test_the_job_runs_when_the_host_starts_and_stops_with_it(tmp_path):
    host = Host(tmp_path, FakeDav())
    with TestClient(host.app, base_url="http://127.0.0.1") as client:
        contact = create(client, host).json()["contact"]
        client.delete(f"/contacts/{contact['id']}", headers={**bearer(host, "mycontacts"), "If-Match": contact["etag"]})
        job = TrashExpiry(host.sources, interval=3600, clock=lambda: datetime.now(timezone.utc) + timedelta(days=31))
        job.start()
        deadline = time.time() + 5
        while client.get("/trash", headers=host.auth).json() and time.time() < deadline:
            time.sleep(0.02)
        job.stop(timeout=5)
        assert client.get("/trash", headers=host.auth).json() == [] and job._thread is None
