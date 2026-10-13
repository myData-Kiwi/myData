"""Discovery against the fake iCloud-shaped server: well-known -> partition host -> principal -> homes."""

import httpx
import pytest

from fake_dav import FakeDav
from mydata.sources.dav.client import DavClient, DavError
from mydata.sources.dav.discovery import Collection, discover

CONTACTS = "https://contacts.icloud.com"
CALENDAR = "https://caldav.icloud.com"


def test_contacts_discovery_follows_the_redirect_to_the_partition_host():
    fake = FakeDav()
    d = discover(fake.client(), CONTACTS, "contacts")
    assert d.principal_url == "https://p42-contacts.icloud.com/1234567/principal/"
    assert d.home_urls == ["https://p42-contacts.icloud.com/1234567/carddavhome/"]  # explicit :443 dropped
    assert d.collections == [Collection(
        url="https://p42-contacts.icloud.com/1234567/carddavhome/card/", kind="contacts", display_name="Contacts",
        color=None, ctag=fake.collection("card").ctag, sync_token=fake.token("card"), components=())]
    hosts = [(m, h, p) for m, h, p in fake.requests]
    assert hosts[0] == ("PROPFIND", "contacts.icloud.com", "/.well-known/carddav")
    assert hosts[1][1] == "p42-contacts.icloud.com"  # the redirect was followed with the same method
    assert {h for _, h, _ in hosts} == {"contacts.icloud.com", "p42-contacts.icloud.com"}


def test_calendar_discovery_keeps_event_calendars_only():
    fake = FakeDav()
    d = discover(fake.client(), CALENDAR, "calendar")
    assert d.principal_url == "https://p42-caldav.icloud.com/1234567/principal/"
    assert d.home_urls == ["https://p42-caldav.icloud.com/1234567/calendars/"]
    by_name = {c.display_name: c for c in d.collections}
    # Reminders (VTODO only) and the scheduling inbox are left out.
    assert set(by_name) == {"Home", "Work", "Holidays (example)"}
    assert by_name["Home"].components == ("VEVENT",)
    assert by_name["Work"].components == ("VEVENT", "VTODO")
    assert by_name["Holidays (example)"].components == ()  # not stated by the server: allowed
    assert by_name["Home"].color == "#34AADC"  # iCloud's #RRGGBBAA trimmed to #RRGGBB
    assert by_name["Holidays (example)"].color is None
    assert all(c.kind == "calendar" and c.url.startswith("https://p42-caldav.icloud.com/1234567/calendars/")
               for c in d.collections)
    assert by_name["Work"].sync_token == fake.token("work")


def test_without_sync_support_collections_have_no_token():
    d = discover(FakeDav(supports_sync=False).client(), CONTACTS, "contacts")
    assert d.collections[0].sync_token is None and d.collections[0].ctag


def test_falls_back_to_the_start_url_when_well_known_is_missing():
    fake = FakeDav(well_known=False)
    d = discover(fake.client(), CALENDAR, "calendar")
    assert d.principal_url == "https://p42-caldav.icloud.com/1234567/principal/"
    assert ("PROPFIND", "caldav.icloud.com", "/") in fake.requests


def test_wrong_password_is_a_401_dav_error():
    fake = FakeDav()
    with pytest.raises(DavError) as info:
        discover(fake.client(password="wrong-fake-password"), CONTACTS, "contacts")
    assert info.value.status == 401
    assert "wrong-fake-password" not in str(info.value)
    assert len(fake.requests) == 1  # stops at the first 401; no fallback retries with a bad password


def test_one_client_discovers_both_kinds():
    fake = FakeDav()
    client = fake.client()
    assert discover(client, CONTACTS, "contacts").collections
    assert discover(client, CALENDAR, "calendar").collections


def test_home_set_on_a_foreign_host_is_refused():
    """A server answer cannot steer the credentials to another domain."""
    fake = FakeDav()

    def handler(request: httpx.Request) -> httpx.Response:
        resp = fake.transport.handle_request(request)
        body = resp.read().replace(b"https://p42-contacts.icloud.com:443", b"https://dav.example.net")
        return httpx.Response(resp.status_code, headers=resp.headers, content=body)

    seen = []

    def outer(request):
        seen.append(request.url.host)
        if request.url.host == "dav.example.net":
            raise AssertionError("credentials sent to a foreign host")
        return handler(request)

    client = DavClient(fake.username, fake.password, transport=httpx.MockTransport(outer))
    with pytest.raises(DavError, match="refusing to send credentials to dav.example.net"):
        discover(client, CONTACTS, "contacts")
    assert "dav.example.net" not in seen


def test_server_without_a_principal_is_an_error():
    def handler(request):
        return httpx.Response(207, content=b'<?xml version="1.0"?><D:multistatus xmlns:D="DAV:"/>')

    with pytest.raises(DavError, match="principal"):
        discover(DavClient("u@example.com", "fake-pw", transport=httpx.MockTransport(handler)), CONTACTS, "contacts")


def test_malformed_and_hostile_xml_is_a_dav_error():
    bomb = (b'<?xml version="1.0"?><!DOCTYPE x [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;">]>'
            b'<D:multistatus xmlns:D="DAV:">&b;</D:multistatus>')
    for body in (b"not xml at all", bomb):
        transport = httpx.MockTransport(lambda r, body=body: httpx.Response(207, content=body))
        with pytest.raises(DavError):
            discover(DavClient("u@example.com", "fake-pw", transport=transport), CONTACTS, "contacts")
