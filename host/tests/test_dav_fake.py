"""The fake DAV server itself: it refuses writes, records every method, and runs as a Starlette app."""

import base64

import httpx
import pytest
from starlette.testclient import TestClient

from fake_dav import PASSWORD, USERNAME, FakeDav

AUTH = {"Authorization": "Basic " + base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()}


@pytest.mark.parametrize("method", ["PUT", "DELETE", "MKCALENDAR", "PROPPATCH", "MOVE", "COPY", "POST", "MKCOL"])
def test_fake_rejects_writes_with_405_and_records_them(method):
    fake = FakeDav(audit=False)  # this test sends writes on purpose, bypassing DavClient
    with httpx.Client(transport=fake.transport) as raw:
        resp = raw.request(method, fake.url("card") + "ava-fictional.vcf", headers=AUTH, content=b"x")
    assert resp.status_code == 405
    assert fake.methods == {method}
    assert "ava-fictional.vcf" in fake.collection("card").items  # nothing changed


def test_fake_requires_the_invented_credentials():
    fake = FakeDav()
    with httpx.Client(transport=fake.transport) as raw:
        assert raw.request("PROPFIND", fake.url("card"), headers={"Depth": "0"}).status_code == 401
        assert raw.request("PROPFIND", fake.url("card"), headers={"Depth": "0", **AUTH}).status_code == 207


def test_fake_unknown_host_is_a_connect_error():
    fake = FakeDav()
    with httpx.Client(transport=fake.transport) as raw, pytest.raises(httpx.ConnectError):
        raw.get("https://dav.example.net/", headers=AUTH)


def test_fake_as_a_starlette_app():
    fake = FakeDav()
    with TestClient(fake.app, base_url="https://p42-contacts.icloud.com") as tc:
        resp = tc.request("PROPFIND", "/1234567/carddavhome/card/", headers={"Depth": "1", **AUTH})
        assert resp.status_code == 207 and b"ava-fictional.vcf" in resp.content
        resp = tc.get("/1234567/carddavhome/card/ava-fictional.vcf", headers=AUTH)
        assert resp.status_code == 200 and b"Ava Fictional" in resp.content
    assert fake.methods == {"PROPFIND", "GET"}


def test_fake_data_is_invented():
    fake = FakeDav()
    text = "".join(i.data for c in fake.collections.values() for i in c.items.values())
    import re
    emails = re.findall(r"[\w.+-]+@([\w.-]+)", text)
    assert emails and all(d.startswith(("example.", "work.example.")) for d in emails)
