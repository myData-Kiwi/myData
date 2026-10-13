"""This Mac, piece by piece: the helper protocol, the generated vCard, finding and starting the helper, and the
socket (private, one connection at a time, line limits). Invented data only (tests/fake_mac)."""

from __future__ import annotations

import base64
import json
import os
import plistlib
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import time
from datetime import date
from pathlib import Path

import pytest

from fake_mac import data
from mydata.sources.mac import cards, protocol
from mydata.sources.mac.launcher import (APP_BUNDLE_ID, BUNDLE_ID, LaunchError, MacReaderLauncher, check_signature,
                                         signing_identity, validate_helper_path)
from mydata.sources.mac.socket import ReaderSocket, ReaderSocketError, socket_path
from mydata.sources.mac.source import add_years, window_for
from mydata.sources.vcard import parse_vcard, photo

needs_unix = pytest.mark.skipif(not hasattr(socket, "AF_UNIX"), reason="needs Unix sockets")


def wait(predicate, timeout: float = 5.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.01)
    return False


@pytest.fixture
def home():
    # Unix socket paths are limited to 104 bytes on macOS; pytest's tmp_path is often longer.
    path = Path(tempfile.mkdtemp(prefix="md-", dir="/tmp"))
    yield path
    shutil.rmtree(path, ignore_errors=True)


# ---------------------------------------------------------------- protocol


def line(obj) -> bytes:
    return json.dumps(obj).encode()


def test_unknown_message_types_are_ignored_and_bad_ones_refused():
    assert protocol.parse(line({"type": "something_new", "x": 1})) is None
    with pytest.raises(protocol.ProtocolError):
        protocol.parse(b"not json")
    with pytest.raises(protocol.ProtocolError, match="window_end is before window_start"):
        protocol.parse(line({"type": "events_snapshot", "window_start": "2026-01-02", "window_end": "2026-01-01",
                             "items": []}))
    hello = protocol.parse(line({"type": "hello", "version": 1, "contacts": "denied", "calendars": "writeOnly"}))
    assert hello == protocol.Hello(1, "denied", "writeOnly")


def test_a_status_the_host_does_not_know_is_unknown_and_the_message_is_still_used():
    # The helper sends "unknown" for a value a later macOS adds; the hello must still be taken.
    hello = protocol.parse(line({"type": "hello", "version": 1, "contacts": "unknown", "calendars": "fullAccess"}))
    assert hello == protocol.Hello(1, "unknown", "fullAccess")
    status = protocol.parse(line({"type": "status", "contacts": "authorized", "calendars": "someNewState"}))
    assert status == protocol.Status("authorized", "unknown")
    odd = protocol.parse(line({"type": "status", "contacts": 3, "calendars": None}))
    assert odd == protocol.Status("unknown", "unknown")
    # "limited" (iOS) is not readable on either side: the helper reads only with "authorized".
    assert protocol.parse(line({"type": "status", "contacts": "limited", "calendars": "denied"})).contacts == "unknown"
    assert protocol.CONTACTS_READABLE == ("authorized",) and protocol.CALENDARS_READABLE == ("fullAccess",)


def test_snapshot_parts_are_read_and_a_bad_part_number_refused():
    whole = protocol.parse(line({"type": "contacts_snapshot", "container_id": "c", "items": []}))
    assert (whole.part, whole.last) == (0, True)  # no part fields: the whole snapshot
    part = protocol.parse(line({"type": "events_snapshot", "window_start": "2025-03-18", "window_end": "2028-03-18",
                                "part": 2, "last": False, "items": []}))
    assert (part.part, part.last) == (2, False)
    for bad in ({"part": -1}, {"part": "1"}, {"part": True}, {"part": protocol.MAX_PARTS}, {"last": "yes"}):
        with pytest.raises(protocol.ProtocolError):
            protocol.parse(line({"type": "contacts_snapshot", "container_id": "c", "items": [], **bad}))


def test_a_bad_item_is_skipped_not_the_snapshot():
    good = data.OCCURRENCES[0]
    snap = protocol.parse(line({"type": "events_snapshot", "window_start": "2025-03-18", "window_end": "2028-03-18",
                                "items": [good, {**good, "external_id": ""}, {**good, "start": "tomorrow"},
                                          {**good, "start": "2026-03-20T19:00:00"}]}))
    assert len(snap.items) == 1 and snap.skipped == 3  # empty id, not a date, no UTC offset
    assert snap.items[0].calendar_id == data.HOME and snap.items[0].notes  # event notes are kept
    contacts = protocol.parse(line({"type": "contacts_snapshot", "container_id": data.ICLOUD_CONTAINER,
                                    "items": [*data.CONTACTS[data.ICLOUD_CONTAINER], {"id": ""}, "x"]}))
    assert [c.id for c in contacts.items] == ["contact-ava-0001", "contact-sam-0002"] and contacts.skipped == 2


def test_a_photo_that_is_not_a_jpeg_or_png_is_dropped():
    ava = dict(data.CONTACTS[data.ICLOUD_CONTAINER][0])
    parse = lambda c: protocol.parse(line({"type": "contacts_snapshot", "container_id": "c", "items": [c]})).items[0]  # noqa: E731
    assert parse(ava).photo == data.PHOTO_BYTES
    assert parse({**ava, "photo_jpeg_base64": base64.b64encode(b"GIF89a-invented").decode()}).photo is None
    assert parse({**ava, "photo_jpeg_base64": "%%% not base64"}).photo is None


def test_host_commands():
    assert protocol.cmd_read("all", None, ["a"], (date(2025, 3, 18), date(2028, 3, 18))) == {
        "cmd": "read", "what": "all", "containers": None, "calendars": ["a"], "window_start": "2025-03-18",
        "window_end": "2028-03-18"}
    assert protocol.cmd_request_access("calendars") == {"cmd": "request_access", "what": "calendars"}
    with pytest.raises(ValueError):
        protocol.cmd_request_access("photos")
    assert protocol.encode(protocol.cmd_quit()) == b'{"cmd":"quit"}\n'


def test_window_is_one_year_back_and_two_ahead():
    assert window_for(date(2026, 3, 18)) == (date(2025, 3, 18), date(2028, 3, 18))
    assert window_for(date(2028, 2, 29)) == (date(2027, 2, 28), date(2030, 2, 28))
    assert add_years(date(2024, 2, 29), 4) == date(2028, 2, 29)


# ---------------------------------------------------------------- the generated vCard


def contact(raw: dict) -> protocol.MacContact:
    return protocol.parse(line({"type": "contacts_snapshot", "container_id": "c", "items": [raw]})).items[0]


def test_generated_vcard_reads_back_with_labels_and_no_note():
    ava = contact(data.CONTACTS[data.ICLOUD_CONTAINER][0])
    text = cards.to_vcard(ava)
    assert text.startswith("BEGIN:VCARD\r\nVERSION:3.0\r\n") and "NOTE" not in text
    assert all(len(l.encode()) <= 75 for l in text.split("\r\n"))  # folded
    parsed = parse_vcard(text)
    assert parsed.full_name == "Ava Q Fictional" and parsed.given_name == "Ava" and parsed.family_name == "Fictional"
    assert parsed.nickname == "Avi" and parsed.organisation == "Example Labs" and parsed.birthday == "1990-04-12"
    assert parsed.emails == [{"value": "ava.fictional@example.com", "label": "home"},
                             {"value": "ava@work.example.net", "label": "work"}]
    assert parsed.phones == [{"value": "+1 202 555 0101", "label": "mobile"}]
    assert parsed.addresses == [{"label": "home", "street": "1 Example Street", "locality": "Testville",
                                 "region": "", "postal_code": "00000", "country": "Exampleland"}]
    assert parsed.note == "" and parsed.has_photo
    assert photo(text) == (data.PHOTO_BYTES, "image/jpeg")
    assert cards.etag(text) == cards.etag(cards.to_vcard(ava))  # stable: unchanged contacts are not rewritten


def test_generated_vcard_escapes_text_and_handles_organisations_and_yearless_birthdays():
    acme = contact(data.CONTACTS[data.LOCAL_CONTAINER][0])
    parsed = parse_vcard(cards.to_vcard(acme))
    assert parsed.display_name == "Acme Plumbing (Example)" and parsed.phones[0]["label"] == "work"
    sam = contact(data.CONTACTS[data.ICLOUD_CONTAINER][1])
    assert parse_vcard(cards.to_vcard(sam)).birthday == "--07-04"
    odd = contact({"id": "x", "given_name": "Ann; Lee, Jr.", "family_name": "O\\Example", "nickname": "A\nB",
                   "emails": [{"value": "ann@example.org", "label": "_$!<Other>!$_"}]})
    parsed = parse_vcard(cards.to_vcard(odd))
    assert parsed.given_name == "Ann; Lee, Jr." and parsed.family_name == "O\\Example"
    assert parsed.full_name == "Ann; Lee, Jr. O\\Example" and parsed.emails[0]["label"] == "other"


def test_photo_is_read_from_vcard_3_and_4_and_never_from_a_link():
    jpeg = base64.b64encode(data.PHOTO_BYTES).decode()
    png = base64.b64encode(b"\x89PNG\r\n\x1a\ninvented").decode()
    v3 = f"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:X\r\nPHOTO;ENCODING=b;TYPE=JPEG:{jpeg}\r\nEND:VCARD\r\n"
    v4 = f"BEGIN:VCARD\r\nVERSION:4.0\r\nFN:X\r\nPHOTO:data:image/png;base64,{png}\r\nEND:VCARD\r\n"
    link = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:X\r\nPHOTO;VALUE=uri:https://www.example.com/x.jpg\r\nEND:VCARD\r\n"
    assert photo(v3) == (data.PHOTO_BYTES, "image/jpeg")
    assert photo(v4)[1] == "image/png"
    assert photo(link) is None and photo("BEGIN:VCARD\r\nFN:X\r\nEND:VCARD\r\n") is None


# ---------------------------------------------------------------- finding and starting the helper


def make_helper(root: Path, bundle_id: str = BUNDLE_ID, app_id: str | None = APP_BUNDLE_ID,
                app_name: str = "myData.app") -> Path:
    """A made-up myData.app (unsigned) holding a made-up reader; app_id None leaves out the app's Info.plist."""
    app = root / app_name
    helper = app / "Contents" / "Helpers" / "myDataReader.app"
    (helper / "Contents").mkdir(parents=True)
    with (helper / "Contents" / "Info.plist").open("wb") as fh:
        plistlib.dump({"CFBundleIdentifier": bundle_id, "LSUIElement": True, "CFBundleExecutable": "anything"}, fh)
    if app_id is not None:
        with (app / "Contents" / "Info.plist").open("wb") as fh:
            plistlib.dump({"CFBundleIdentifier": app_id}, fh)
    return helper


def real(path: Path) -> Path:
    return Path(os.path.realpath(path))


def test_helper_path_is_checked(home):
    good = make_helper(home / "a")
    assert validate_helper_path(str(good), signature=None) == real(good)
    for bad, message in ((make_helper(home / "b", "kiwi.example.other"), "not the reader"),
                         (home / "nowhere" / "myData.app" / "Contents" / "Helpers" / "myDataReader.app", "no reader"),
                         (home / "x.app", "must end in"), ("relative/Contents/Helpers/myDataReader.app", "absolute"),
                         # a reader in a bundle that is not the myData app
                         (make_helper(home / "c", app_id="kiwi.example.notmydata", app_name="NotMyData.app"),
                          "not inside the myData app"),
                         (make_helper(home / "d", app_id=None, app_name="NotMyData.app"), "not inside the myData app"),
                         (home / "Contents" / "Helpers" / "myDataReader.app", "must end in")):
        with pytest.raises(ValueError, match=message):
            validate_helper_path(bad, signature=None)


def test_a_symlink_is_judged_by_where_it_leads(home):
    crafted = make_helper(home / "elsewhere", app_id="kiwi.example.notmydata", app_name="NotMyData.app")
    (home / "fake" / "myData.app" / "Contents" / "Helpers").mkdir(parents=True)
    with (home / "fake" / "myData.app" / "Contents" / "Info.plist").open("wb") as fh:
        plistlib.dump({"CFBundleIdentifier": APP_BUNDLE_ID}, fh)
    link = home / "fake" / "myData.app" / "Contents" / "Helpers" / "myDataReader.app"
    link.symlink_to(crafted)
    with pytest.raises(ValueError, match="not inside the myData app"):
        validate_helper_path(link, signature=None)


def test_signature_check_needs_a_valid_seal_and_one_identity(home):
    app, helper = home / "myData.app", home / "myData.app" / "Contents" / "Helpers" / "myDataReader.app"
    adhoc = "Executable=/x\nIdentifier=kiwi.mydata.mydata\nSignature=adhoc\nTeamIdentifier=not set\n"
    dev = ("Identifier=kiwi.mydata.reader\nAuthority=Apple Development: Example Person (EXAMPLE123)\n"
           "Authority=Apple Worldwide Developer Relations Certification Authority\nTeamIdentifier=EXAMPLE123\n")
    assert signing_identity(adhoc) == ("not set", "adhoc")
    assert signing_identity(dev) == ("EXAMPLE123", "Apple Development: Example Person (EXAMPLE123)")

    def runner(verify: int, app_details: str, helper_details: str):
        def run(args):
            if args[0] == "--verify":
                return subprocess.CompletedProcess(args, verify, "", "")
            return subprocess.CompletedProcess(args, 0, "", app_details if args[-1] == str(app) else helper_details)
        return run

    check_signature(app, helper, run=runner(0, adhoc, adhoc))
    check_signature(app, helper, run=runner(0, dev, dev))
    with pytest.raises(ValueError, match="not validly signed"):
        check_signature(app, helper, run=runner(1, adhoc, adhoc))
    with pytest.raises(ValueError, match="same identity"):
        check_signature(app, helper, run=runner(0, dev, adhoc))


needs_codesign = pytest.mark.skipif(sys.platform != "darwin" or not Path("/usr/bin/codesign").exists(),
                                    reason="needs macOS codesign")


@needs_codesign
def test_an_unsigned_bundle_shaped_like_the_reader_is_refused_by_codesign(home):
    crafted = make_helper(home / "a")  # the right names and ids, but nothing signed it
    with pytest.raises(ValueError, match="not validly signed"):
        validate_helper_path(crafted)


@needs_codesign
def test_a_signed_myData_app_with_its_reader_is_accepted(home):
    """A made-up myData.app with a made-up reader, both signed ad hoc as a development build is: accepted.
    Then a change inside the reader breaks the app's seal: refused."""
    helper = make_helper(home / "a")
    app = helper.parents[2]
    for bundle, name in ((helper, "myDataReader"), (app, "myData")):
        (bundle / "Contents" / "MacOS").mkdir(parents=True)
        shutil.copy("/usr/bin/true", bundle / "Contents" / "MacOS" / name)
        info = plistlib.loads((bundle / "Contents" / "Info.plist").read_bytes())
        (bundle / "Contents" / "Info.plist").write_bytes(plistlib.dumps({**info, "CFBundleExecutable": name}))
    for bundle in (helper, app):  # the helper first: the app's seal covers it
        r = subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(bundle)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
    assert validate_helper_path(helper) == real(helper)
    (helper / "Contents" / "Resources").mkdir()
    (helper / "Contents" / "Resources" / "extra.txt").write_text("added after signing")
    with pytest.raises(ValueError, match="not validly signed"):
        validate_helper_path(helper)


def test_the_helper_is_started_through_launchservices_never_executed(home):
    calls = []

    def run(cmd, **kw):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0)

    helper = make_helper(home)
    sock = home / "run" / "reader.sock"
    MacReaderLauncher(run=run, signature=None).launch(sock, helper)
    MacReaderLauncher(run=run, signature=None).launch(sock, home / "moved" / "Contents" / "Helpers" /
                                                      "myDataReader.app")
    assert calls == [["/usr/bin/open", "-g", "-j", "-n", "-a", str(real(helper)), "--args", "--socket", str(sock)],
                     ["/usr/bin/open", "-g", "-j", "-n", "-b", BUNDLE_ID, "--args", "--socket", str(sock)]]
    # Unsigned, so the real check refuses it, and the launcher falls back to the bundle id.
    if sys.platform == "darwin":
        MacReaderLauncher(run=run).launch(sock, helper)
        assert calls[-1][4:6] == ["-b", BUNDLE_ID]
    with pytest.raises(LaunchError, match="was not found"):
        MacReaderLauncher(run=lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1)).launch(sock, None)


# ---------------------------------------------------------------- the socket


def connect(path: Path) -> socket.socket:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(str(path))
    return s


def closed_by_peer(s: socket.socket) -> bool:
    s.settimeout(3)
    try:
        return s.recv(1) == b""
    except ConnectionResetError:
        return True


@needs_unix
def test_socket_is_private_whatever_the_umask_and_takes_one_connection(home):
    lines: list[bytes] = []
    old = os.umask(0)
    try:
        sock = ReaderSocket(home, on_line=lines.append)
        path = sock.start()
    finally:
        os.umask(old)
    try:
        assert path == socket_path(home) == home / "run" / "reader.sock"
        assert stat.S_IMODE(os.stat(home / "run").st_mode) == 0o700
        info = os.lstat(path)
        assert stat.S_ISSOCK(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o600
        assert [p.name for p in (home / "run").iterdir()] == ["reader.sock"]  # no temporary name left behind

        first = connect(path)
        assert wait(lambda: sock.connected)
        second = connect(path)
        assert closed_by_peer(second)  # refused at once while the first is open
        assert sock.rejected == 1 and sock.connected
        first.sendall(b'{"type":"status"}\n')
        assert wait(lambda: lines == [b'{"type":"status"}'])
        assert sock.send(b'{"cmd":"status"}\n')
        first.settimeout(3)
        assert first.recv(100) == b'{"cmd":"status"}\n'

        first.close()
        assert wait(lambda: not sock.connected)
        third = connect(path)  # once the first has gone, a new one is taken
        assert wait(lambda: sock.connected)
        third.close()
    finally:
        sock.close()
    assert not path.exists()


@needs_unix
def test_stale_socket_is_replaced_and_anything_else_refused(home):
    run = home / "run"
    run.mkdir(mode=0o700)
    stale = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    stale.bind(str(run / "reader.sock"))
    stale.close()  # a crashed host leaves the file behind
    sock = ReaderSocket(home, on_line=lambda _l: None)
    sock.start()
    c = connect(sock.path)
    assert wait(lambda: sock.connected)
    c.close()
    sock.close()

    (run / "reader.sock").write_text("not a socket")
    with pytest.raises(ReaderSocketError, match="not a socket"):
        ReaderSocket(home, on_line=lambda _l: None).start()


@needs_unix
def test_a_file_or_a_link_in_place_of_the_run_folder_is_refused_and_left_alone(home):
    (home / "run").write_text("not a folder")
    with pytest.raises(ReaderSocketError, match="not a folder owned by this user"):
        ReaderSocket(home, on_line=lambda _l: None).start()
    (home / "run").unlink()

    target = home / "someone-elses-idea"
    target.mkdir(mode=0o755)
    os.chmod(target, 0o755)
    (home / "run").symlink_to(target)
    with pytest.raises(ReaderSocketError, match="not a folder owned by this user"):
        ReaderSocket(home, on_line=lambda _l: None).start()
    assert stat.S_IMODE(os.stat(target).st_mode) == 0o755  # not changed through the link
    assert list(target.iterdir()) == []


@needs_unix
def test_an_open_run_folder_is_made_private_again(home):
    (home / "run").mkdir()
    os.chmod(home / "run", 0o777)
    sock = ReaderSocket(home, on_line=lambda _l: None)
    try:
        sock.start()
        assert stat.S_IMODE(os.stat(home / "run").st_mode) == 0o700
        assert stat.S_IMODE(os.lstat(sock.path).st_mode) == 0o600
    finally:
        sock.close()


@needs_unix
def test_a_line_over_the_limit_closes_the_connection(home):
    whys: list[str] = []
    sock = ReaderSocket(home, on_line=lambda _l: None, on_disconnect=whys.append, max_line=64)
    sock.start()
    try:
        c = connect(sock.path)
        c.sendall(b"x" * 200)
        assert closed_by_peer(c)
        assert wait(lambda: whys == ["too_long"])
    finally:
        sock.close()


@needs_unix
def test_a_line_that_stalls_half_way_closes_the_connection(home):
    whys: list[str] = []
    sock = ReaderSocket(home, on_line=lambda _l: None, on_disconnect=whys.append, stall_timeout=0.3)
    sock.start()
    try:
        c = connect(sock.path)
        c.sendall(b'{"type":"sta')
        assert wait(lambda: whys == ["stalled"])
    finally:
        sock.close()


@needs_unix
def test_a_host_folder_path_too_long_for_a_socket_is_refused_plainly(home):
    deep = home / ("d" * 120)
    with pytest.raises(ReaderSocketError, match="too long"):
        ReaderSocket(deep, on_line=lambda _l: None).start()


# ---------------------------------------------------------------- the real helper's messages, read by the host

from test_mac_reader_readonly import _all_messages, selftest  # noqa: E402,F401 - the helper's self-test output


def test_every_message_the_helper_sends_is_read_by_the_host_without_loss(selftest):  # noqa: F811
    seen = set()
    for m in _all_messages(selftest):
        parsed = protocol.parse(json.dumps(m))
        assert parsed is not None, m["type"]
        seen.add(m["type"])
        if isinstance(parsed, (protocol.ContactsSnapshot, protocol.EventsSnapshot)):
            assert parsed.skipped == 0 and len(parsed.items) == len(m["items"]), m["type"]
    assert seen == {"hello", "status", "contact_containers", "calendars", "contacts_snapshot", "events_snapshot",
                    "changed", "error"}
