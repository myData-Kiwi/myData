"""DavClient: the read-only lock, redirects, where credentials may go, and secrecy of the password."""

import base64
import logging
import pickle
import traceback

import httpx
import pytest

from fake_dav import PASSWORD, USERNAME, FakeDav
from mydata.sources.dav.client import ALLOWED_METHODS, DavClient, DavError, ReadOnlyViolation

SECRET = "fake-Secret-pw-Zq9!"


class Recorder(httpx.BaseTransport):
    """Records every request that reaches the transport and answers with `handler`."""

    def __init__(self, handler=None):
        self.seen: list[httpx.Request] = []
        self.handler = handler or (lambda r: httpx.Response(207, content=b'<D:multistatus xmlns:D="DAV:"/>'))

    def handle_request(self, request):
        self.seen.append(request)
        return self.handler(request)


def _secret_forms(username=USERNAME, password=SECRET):
    return [password, base64.b64encode(f"{username}:{password}".encode()).decode()]


# --- THE READ-ONLY TEST ------------------------------------------------------------------------------------

WRITE_METHODS = ["PUT", "DELETE", "POST", "PATCH", "PROPPATCH", "MKCOL", "MKCALENDAR", "MOVE", "COPY", "LOCK",
                 "UNLOCK", "ACL", "BIND", "UNBIND", "REBIND", "SEARCH", "HEAD", "TRACE", "CONNECT", "ORDERPATCH",
                 "MKWORKSPACE", "CHECKOUT", "CHECKIN", "VERSION-CONTROL", "UPDATE", "LABEL", "MERGE", "BASELINE-CONTROL",
                 "put", "Delete", "post", "GET ", " GET", "GE T", "GET\r\nX: y", "", "PROPFIND2", "REPORTS"]


def test_only_four_methods_are_allowed():
    assert ALLOWED_METHODS == frozenset({"PROPFIND", "REPORT", "OPTIONS", "GET"})
    assert DavClient.ALLOWED_METHODS == ALLOWED_METHODS


@pytest.mark.parametrize("method", WRITE_METHODS + [None, b"GET", 1])
def test_every_other_method_raises_before_any_request(method):
    rec = Recorder()
    client = DavClient(USERNAME, SECRET, transport=rec)
    with pytest.raises(ReadOnlyViolation):
        client.request(method, "https://p42-contacts.icloud.com/1234567/carddavhome/card/x.vcf",
                       body=b"BEGIN:VCARD", depth="0")
    assert rec.seen == []
    # The client is still usable for reads afterwards.
    client.request("PROPFIND", "https://p42-contacts.icloud.com/", depth="0")
    assert [r.method for r in rec.seen] == ["PROPFIND"]


@pytest.mark.parametrize("method", ["PUT", "DELETE", "POST", "PROPPATCH", "MKCALENDAR", "MOVE", "COPY"])
def test_transport_lock_refuses_writes_even_if_request_is_bypassed(method):
    rec = Recorder()
    client = DavClient(USERNAME, SECRET, transport=rec)
    with pytest.raises(ReadOnlyViolation):
        client._http.request(method, "https://p42-contacts.icloud.com/x")  # noqa: SLF001 (the point of the test)
    assert rec.seen == []


@pytest.mark.parametrize("status", [301, 302, 303, 307, 308])
def test_redirects_keep_the_read_method(status):
    def handler(r):
        if r.url.path == "/start":
            return httpx.Response(status, headers={"Location": "/next"})
        return httpx.Response(207, content=b'<D:multistatus xmlns:D="DAV:"/>')

    rec = Recorder(handler)
    resp = DavClient(USERNAME, SECRET, transport=rec).request("REPORT", "https://contacts.icloud.com/start",
                                                              body=b"<x/>")
    assert [r.method for r in rec.seen] == ["REPORT", "REPORT"]
    assert rec.seen[1].content == b"<x/>"
    assert resp.url == "https://contacts.icloud.com/next" and resp.status == 207


def test_whole_fake_session_sees_only_read_methods():
    fake = FakeDav()
    client = fake.client()
    client.request("OPTIONS", "https://p42-contacts.icloud.com/1234567/carddavhome/card/")
    client.request("GET", fake.url("card") + "ava-fictional.vcf")
    for m in WRITE_METHODS[:12]:
        with pytest.raises(ReadOnlyViolation):
            client.request(m, fake.url("card"))
    assert fake.methods <= ALLOWED_METHODS


# --- redirects and where credentials go ----------------------------------------------------------------------

def test_too_many_redirects():
    rec = Recorder(lambda r: httpx.Response(302, headers={"Location": "/again"}))
    with pytest.raises(DavError, match="too many redirects"):
        DavClient(USERNAME, SECRET, transport=rec).request("PROPFIND", "https://contacts.icloud.com/")
    assert len(rec.seen) == 6


def test_redirect_to_partition_host_keeps_credentials():
    def handler(r):
        if r.url.host == "contacts.icloud.com":
            return httpx.Response(301, headers={"Location": "https://p42-contacts.icloud.com/p/"})
        return httpx.Response(207, content=b'<D:multistatus xmlns:D="DAV:"/>')

    rec = Recorder(handler)
    DavClient(USERNAME, SECRET, transport=rec).request("PROPFIND", "https://contacts.icloud.com/")
    assert [r.url.host for r in rec.seen] == ["contacts.icloud.com", "p42-contacts.icloud.com"]
    assert all(r.headers["authorization"].startswith("Basic ") for r in rec.seen)


def test_redirect_to_another_domain_is_refused_without_sending_credentials():
    rec = Recorder(lambda r: httpx.Response(301, headers={"Location": "https://dav.example.net/steal/"}))
    with pytest.raises(DavError, match="refusing to send credentials to dav.example.net"):
        DavClient(USERNAME, SECRET, transport=rec).request("PROPFIND", "https://contacts.icloud.com/")
    assert [r.url.host for r in rec.seen] == ["contacts.icloud.com"]


def test_lookalike_host_is_not_in_the_icloud_family():
    rec = Recorder()
    client = DavClient(USERNAME, SECRET, transport=rec)
    client.request("PROPFIND", "https://contacts.icloud.com/")
    for host in ("evilicloud.com", "icloud.com.example.net", "p42-contacts.icloud.co"):
        with pytest.raises(DavError, match="refusing"):
            client.request("PROPFIND", f"https://{host}/")
    assert len(rec.seen) == 1


def test_non_icloud_origin_allows_only_that_exact_host():
    rec = Recorder()
    client = DavClient(USERNAME, SECRET, transport=rec)
    client.request("PROPFIND", "https://dav.example.com/")
    client.request("PROPFIND", "https://dav.example.com/other/")
    with pytest.raises(DavError, match="refusing"):
        client.request("PROPFIND", "https://p1-dav.example.com/")
    assert len(rec.seen) == 2


def test_plain_http_and_https_downgrade_are_refused():
    rec = Recorder(lambda r: httpx.Response(301, headers={"Location": "http://contacts.icloud.com/"}))
    with pytest.raises(DavError, match="plain HTTP"):
        DavClient(USERNAME, SECRET, transport=rec).request("PROPFIND", "https://contacts.icloud.com/")
    assert len(rec.seen) == 1
    with pytest.raises(DavError, match="plain HTTP"):
        DavClient(USERNAME, SECRET, transport=Recorder()).request("GET", "http://dav.example.com/")


def test_loopback_http_is_allowed():
    rec = Recorder()
    DavClient(USERNAME, SECRET, transport=rec).request("GET", "http://127.0.0.1:8080/x")
    assert len(rec.seen) == 1


def test_urls_with_credentials_and_caller_authorization_are_refused():
    rec = Recorder()
    client = DavClient(USERNAME, SECRET, transport=rec)
    with pytest.raises(DavError, match="must not carry credentials"):
        client.request("GET", "https://someone:pw@contacts.icloud.com/")
    with pytest.raises(ValueError):
        client.request("GET", "https://contacts.icloud.com/", headers={"Authorization": "Basic x"})
    with pytest.raises(DavError):
        client.request("GET", "/relative/path")
    assert rec.seen == []


def test_headers_depth_and_user_agent():
    rec = Recorder()
    DavClient(USERNAME, SECRET, transport=rec).request("PROPFIND", "https://contacts.icloud.com/", depth="1",
                                                       body=b"<x/>")
    h = rec.seen[0].headers
    assert h["depth"] == "1" and h["user-agent"].startswith("myData/")
    assert h["content-type"].startswith("application/xml")


# --- secrecy ---------------------------------------------------------------------------------------------

def _assert_no_secret(*texts):
    for text in texts:
        for form in _secret_forms():
            assert form not in text


def test_401_raises_dav_error_without_the_password(caplog, capsys):
    caplog.set_level(logging.DEBUG)
    fake = FakeDav()
    client = DavClient(USERNAME, SECRET, transport=fake.transport)
    with pytest.raises(DavError) as info:
        client.request("PROPFIND", "https://contacts.icloud.com/.well-known/carddav", depth="0")
    e = info.value
    assert e.status == 401
    out = capsys.readouterr()
    _assert_no_secret(str(e), repr(e), repr(e.args), "".join(traceback.format_exception(e)), caplog.text,
                      out.out, out.err, repr(client), str(client), repr(vars(client)))


def test_client_repr_and_pickle_hide_the_password():
    client = DavClient(USERNAME, SECRET, transport=Recorder())
    _assert_no_secret(repr(client), str(client), repr(vars(client)), repr(client._password))  # noqa: SLF001
    with pytest.raises(TypeError):
        pickle.dumps(client)
    with pytest.raises(TypeError):
        pickle.dumps(client._password)  # noqa: SLF001


def test_network_error_text_is_scrubbed(caplog):
    caplog.set_level(logging.DEBUG)

    def boom(request):
        raise httpx.ConnectError(f"failed with {request.headers['authorization']} and {SECRET}", request=request)

    with pytest.raises(DavError) as info:
        DavClient(USERNAME, SECRET, transport=httpx.MockTransport(boom)).request("GET", "https://contacts.icloud.com/")
    e = info.value
    assert e.status is None and "ConnectError" in str(e)
    assert e.__cause__ is None and e.__suppress_context__
    _assert_no_secret(str(e), repr(e), "".join(traceback.format_exception(e)), caplog.text)


def test_successful_requests_log_nothing_secret(caplog):
    caplog.set_level(logging.DEBUG)
    fake = FakeDav(password=SECRET)
    from mydata.sources.dav.discovery import discover
    from mydata.sources.dav.sync import CollectionState, sync_collection
    client = DavClient(USERNAME, SECRET, transport=fake.transport)
    d = discover(client, "https://contacts.icloud.com", "contacts")
    sync_collection(client, d.collections[0], CollectionState())
    assert caplog.text  # something was logged at debug level ...
    _assert_no_secret(caplog.text)  # ... and none of it is the password


def test_fake_credentials_are_invented():
    assert USERNAME.endswith("@example.com") and "fake" in PASSWORD
