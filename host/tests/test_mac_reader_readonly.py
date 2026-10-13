"""myData Reader, the macOS helper that reads This Mac's Contacts and Calendars, can only read.

The helper is Swift, in app/apps/mydata/macos/Reader. These tests hold it to the owner's rules:

- No write call of the Contacts or EventKit frameworks appears in its sources, and nothing that could reach
  one indirectly (selectors, KVC, dlsym). All framework access sits behind one protocol,
  `PersonalDataReader`, whose methods only read; only SystemReader.swift touches the frameworks.
- Contact notes are never asked for (CNContactNoteKey needs an entitlement Apple grants on request, and
  asking without it makes the fetch fail), and contacts are not read as vCards (their keys include notes).
- The sources type-check, and a self-test runs the helper's session against a fake reader with invented
  data, checking every message against the protocol the host speaks.
- The build puts the helper inside myData.app and signs it before Xcode signs the app; the usage strings
  are in both Info.plists; a developer's signing settings stay out of git.

The Swift tests are skipped where swiftc is missing (they need macOS and Xcode). None of them touches the
Mac's real Contacts or Calendars.
"""

from __future__ import annotations

import json
import os
import platform
import plistlib
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from test_privacy import real_looking

REPO = Path(__file__).resolve().parents[2]
MACOS = REPO / "app" / "apps" / "mydata" / "macos"
READER = MACOS / "Reader"
SOURCES = sorted((READER / "Sources").glob("*.swift"))
SYSTEM_READER = READER / "Sources" / "SystemReader.swift"

needs_swift = pytest.mark.skipif(
    sys.platform != "darwin" or shutil.which("swiftc") is None, reason="needs swiftc (macOS with Xcode)"
)


def strip_comments(src: str) -> str:
    """Swift source without its comments; string literals are kept (a write call hidden in one still fails)."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith('"""', i):
            j = src.find('"""', i + 3)
            j = n if j < 0 else j + 3
            out.append(src[i:j])
            i = j
        elif src[i] == '"':
            j = i + 1
            while j < n and src[j] not in '"\n':
                j += 2 if src[j] == "\\" else 1
            out.append(src[i : j + 1])
            i = j + 1
        elif src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            out.append(" ")
        elif src.startswith("/*", i):  # Swift block comments nest
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif src.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            out.append(" ")
            i = j
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def code(path: Path) -> str:
    return strip_comments(path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------- the helper has no write call

# Write APIs of Contacts (CNSaveRequest and CNContactStore.execute) and EventKit (save/remove of events,
# reminders and calendars, commit), anything shaped like them, mutable framework objects, and the ways of
# calling a method without naming it in the source.
FORBIDDEN = {
    "CNSaveRequest": r"\bCNSaveRequest\b",
    "execute(": r"\bexecute\s*\(",
    "save...(": r"\bsave\w*\s*\(",
    "remove...(": r"\bremove\w*\s*\(",
    "delete...(": r"\bdelete\w*\s*\(",
    "commit...(": r"\bcommit\w*\s*\(",
    "update...(": r"\bupdate\w*\s*\(",
    ".add(": r"\.add\s*\(",
    "addMember/addContact/...": r"\badd(?:Member|Contact|Group|Calendar|Event|Reminder|Source|Alarm)\w*",
    "toContainerWithIdentifier": r"toContainerWithIdentifier",
    "mutable or new framework objects": r"\bCNMutable\w+|\bEK(?:Event|Calendar|Reminder|Source|Alarm|RecurrenceRule)\s*\(",
    "dynamic dispatch": r"\b(?:NSSelectorFromString|NSClassFromString|objc_msgSend|dlsym|dlopen|"
    r"class_getInstanceMethod|method_exchangeImplementations|setValue)\b|#selector|\.perform\s*\(",
}


def write_calls(text: str) -> list[str]:
    return [name for name, pattern in FORBIDDEN.items() if re.search(pattern, text)]


def test_the_scanner_catches_write_calls():
    bad = [
        "try store.execute(request)",
        "try eventStore.save(event, span: .thisEvent)",
        "try eventStore.saveCalendar(calendar, commit: true)",
        "try eventStore.remove(event, span: .futureEvents)",
        "request.add(contact, toContainerWithIdentifier: nil)",
        "request.update(contact)",
        "request.delete(contact)",
        "try eventStore.commit()",
        "let c = CNMutableContact()",
        "let e = EKEvent(eventStore: store)",
        'store.perform(NSSelectorFromString("saveEvent:span:error:"))',
        "request.addMember(contact, to: group)",
        'let s = CNSaveRequest()',
    ]
    for line in bad:
        assert write_calls(line), line
    good = [
        "eventStore.events(matching: predicate)",
        "center.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: nil) { _ in }",
        "try contactStore.enumerateContacts(with: request) { contact, _ in records.append(x) }",
        "seen.insert(key)",
        "let calendars: [EKCalendar]? = nil",
    ]
    for line in good:
        assert not write_calls(line), line
    assert write_calls(strip_comments("let a = 1 // try store.execute(r)\n")) == []
    assert write_calls(strip_comments('let a = "store.execute(r)"')) == ["execute("]


def test_the_helper_sources_contain_no_write_call():
    assert {p.name for p in SOURCES} >= {"main.swift", "Protocol.swift", "SystemReader.swift"}
    found = {p.name: write_calls(code(p)) for p in SOURCES}
    assert {k: v for k, v in found.items() if v} == {}


def _protocol_methods() -> list[str]:
    text = code(SYSTEM_READER)
    match = re.search(r"\bprotocol\s+PersonalDataReader\b[^{]*\{(.*?)\n\}", text, re.S)
    assert match, "SystemReader.swift must declare `protocol PersonalDataReader`"
    return re.findall(r"\bfunc\s+(\w+)", match.group(1))


def test_the_one_protocol_declares_only_reads():
    methods = _protocol_methods()
    assert sorted(methods) == sorted([
        "contactsStatus", "calendarsStatus", "requestContactsAccess", "requestCalendarsAccess",
        "contactContainers", "contacts", "calendars", "occurrences", "observeChanges",
    ])  # a new method is a decision: review it, then add it here
    verbs = ("save", "remove", "delete", "add", "update", "commit", "write", "set", "create", "insert", "modify")
    assert [m for m in methods if m.lower().startswith(verbs)] == []


def test_only_system_reader_touches_the_frameworks():
    framework = re.compile(r"\bimport\s+(?:Contacts|EventKit)\b|\b(?:CN|EK)[A-Z]\w*")
    others = {p.name: sorted(set(framework.findall(code(p)))) for p in SOURCES if p != SYSTEM_READER}
    assert {k: v for k, v in others.items() if v} == {}
    conforms = re.compile(r"\b(?:class|struct|enum|actor|extension)\s+\w+\s*:[\w\s,]*\bPersonalDataReader\b")
    implementations = {p.name: len(conforms.findall(code(p))) for p in SOURCES}
    assert {k: v for k, v in implementations.items() if v} == {"SystemReader.swift": 1}


# ---------------------------------------------------------------- contact notes are never asked for

NOTES = {
    "CNContactNoteKey": r"CNContactNoteKey",
    "a note key": r"[Nn]oteKey",
    "CNContact.note": r"\.note\b",
    "vCard serialisation (its keys include the note)": r"VCardSerialization|vCardSerialization",
    "the notes entitlement": r"contacts\.notes",
}


def test_the_helper_never_asks_for_contact_notes():
    for path in [*SOURCES, READER / "Info.plist", READER / "Reader.entitlements"]:
        text = code(path) if path.suffix == ".swift" else path.read_text(encoding="utf-8")
        assert [name for name, p in NOTES.items() if re.search(p, text)] == [], path.name
    assert re.search(r"\.note\b", "contact.note") and not re.search(r"\.note\b", "event.notes")


def test_a_contact_record_has_no_notes_field():
    text = code(READER / "Sources" / "Protocol.swift")
    body = re.search(r"struct\s+ContactRecord\b[^{]*\{(.*?)\n\}", text, re.S).group(1)
    assert "note" not in body.lower()


# ---------------------------------------------------------------- Info.plists, entitlements, build wiring

CONTACTS_USAGE = "myData shows your contacts in myContacts and uses them to answer your questions. They stay on this Mac."
CALENDARS_USAGE = "myData shows your events in myCalendar and uses them to answer your questions. They stay on this Mac."
USAGE = {
    "NSContactsUsageDescription": CONTACTS_USAGE,
    "NSCalendarsFullAccessUsageDescription": CALENDARS_USAGE,
    "NSCalendarsUsageDescription": CALENDARS_USAGE,
}


def _plist(path: Path) -> dict:
    with path.open("rb") as f:
        return plistlib.load(f)


def test_the_myData_app_carries_the_usage_strings():
    # macOS shows the containing app's strings: the prompt names myData and the grant belongs to myData.app.
    info = _plist(MACOS / "Runner" / "Info.plist")
    assert {k: info.get(k) for k in USAGE} == USAGE


def test_the_helper_bundle_is_a_background_app_with_the_same_strings():
    info = _plist(READER / "Info.plist")
    assert info["CFBundleIdentifier"] == "kiwi.mydata.reader"
    assert info["CFBundleName"] == "myData Reader"
    assert info["CFBundleExecutable"] == "myDataReader"
    assert info["LSUIElement"] is True
    assert info["LSMinimumSystemVersion"] == "14.0"
    assert {k: info.get(k) for k in USAGE} == USAGE


def test_the_hardened_runtime_entitlements_are_the_two_personal_information_keys():
    assert _plist(READER / "Reader.entitlements") == {
        "com.apple.security.personal-information.addressbook": True,
        "com.apple.security.personal-information.calendars": True,
    }


def test_the_input_file_list_names_every_source():
    listed = [line.strip() for line in (READER / "ReaderInputs.xcfilelist").read_text().splitlines() if line.strip()]
    sources = {f"$(SRCROOT)/Reader/Sources/{p.name}" for p in SOURCES}
    assert sources <= set(listed), "add new helper sources to Reader/ReaderInputs.xcfilelist"
    for entry in listed:
        assert (MACOS / entry.replace("$(SRCROOT)/", "")).is_file(), entry


def test_the_build_phase_embeds_the_helper_after_flutter_and_before_signing():
    pbx = (MACOS / "Runner.xcodeproj" / "project.pbxproj").read_text()
    runner = re.search(r"/\* Runner \*/ = \{\s*isa = PBXNativeTarget;.*?buildPhases = \((.*?)\);", pbx, re.S)
    phases = re.findall(r"/\* (.*?) \*/", runner.group(1))
    # Xcode signs the app after the last phase, so the helper (signed by the script) is sealed into it.
    assert phases[-2:] == ["ShellScript", "Embed myData Reader"]
    phase = re.search(r"/\* Embed myData Reader \*/ = \{(.*?)\n\t\t\};", pbx, re.S).group(1)
    assert "Reader/build_reader.sh" in phase
    assert "ReaderInputs.xcfilelist" in phase and "ReaderOutputs.xcfilelist" in phase
    outputs = (READER / "ReaderOutputs.xcfilelist").read_text()
    assert "$(TARGET_BUILD_DIR)/$(WRAPPER_NAME)/Contents/Helpers/myDataReader.app/" in outputs


def test_a_local_signing_file_can_set_the_identity():
    pbx = (MACOS / "Runner.xcodeproj" / "project.pbxproj").read_text()
    # A CODE_SIGN_IDENTITY in the project file would win over the xcconfig and its optional include.
    assert "CODE_SIGN_IDENTITY" not in pbx
    for name in ("Debug.xcconfig", "Release.xcconfig"):
        lines = [l.strip() for l in (MACOS / "Runner" / "Configs" / name).read_text().splitlines()]
        assert "CODE_SIGN_IDENTITY = -" in lines
        assert '#include? "Signing.local.xcconfig"' in lines
        assert lines.index('#include? "Signing.local.xcconfig"') > lines.index("CODE_SIGN_IDENTITY = -")
    assert (MACOS / "Runner" / "Configs" / "Signing.local.xcconfig.example").is_file()


@pytest.mark.skipif(shutil.which("git") is None or not (REPO / ".git").exists(), reason="not a git checkout")
def test_the_local_signing_file_is_ignored_by_git():
    def ignored(rel: str) -> bool:
        r = subprocess.run(["git", "-C", str(REPO), "check-ignore", "-q", "--no-index", rel], capture_output=True)
        return r.returncode == 0

    assert ignored("app/apps/mydata/macos/Runner/Configs/Signing.local.xcconfig")
    assert not ignored("app/apps/mydata/macos/Runner/Configs/Signing.local.xcconfig.example")


def test_the_helper_holds_no_real_looking_address_or_phone():
    files = [p for p in READER.rglob("*") if p.is_file() and p.suffix in {".swift", ".plist", ".sh", ".entitlements"}]
    assert len(files) >= 8
    problems = [f"{p.relative_to(READER)}: {x}" for p in files for x in real_looking(p.read_text(encoding="utf-8"))]
    assert problems == []


# ---------------------------------------------------------------- Swift: type-check, self-test, build


def _target() -> str:
    arch = "arm64" if platform.machine() == "arm64" else "x86_64"
    return f"{arch}-apple-macos14.0"


@needs_swift
def test_the_helper_sources_type_check():
    r = subprocess.run(
        ["swiftc", "-typecheck", "-swift-version", "5", "-target", _target(), *map(str, SOURCES)],
        capture_output=True, text=True, timeout=300,
    )
    assert r.returncode == 0, r.stderr


@pytest.fixture(scope="module")
def selftest(tmp_path_factory) -> dict[str, dict]:
    if sys.platform != "darwin" or shutil.which("swiftc") is None:
        pytest.skip("needs swiftc (macOS with Xcode)")
    out = tmp_path_factory.mktemp("reader") / "selftest"
    files = [p for p in SOURCES if p.name != "main.swift"] + sorted((READER / "Tests").glob("*.swift"))
    r = subprocess.run(
        ["swiftc", "-swift-version", "5", "-target", _target(), "-framework", "Contacts", "-framework", "EventKit",
         "-o", str(out), *map(str, files)],
        capture_output=True, text=True, timeout=600,
    )
    assert r.returncode == 0, r.stderr
    # The harness fixes its own time zone (Pacific/Auckland); the machine's must not matter.
    run = subprocess.run([str(out)], capture_output=True, text=True, timeout=60, env={**os.environ, "TZ": "America/Denver"})
    assert run.returncode == 0, run.stderr
    cases = [json.loads(line) for line in run.stdout.splitlines()]
    return {c.pop("case"): c for c in cases}


MESSAGE_KEYS = {
    "hello": {"type", "version", "contacts", "calendars"},
    "status": {"type", "contacts", "calendars"},
    "contact_containers": {"type", "items"},
    "calendars": {"type", "items"},
    "contacts_snapshot": {"type", "container_id", "part", "last", "items"},
    "events_snapshot": {"type", "window_start", "window_end", "part", "last", "items"},
    "changed": {"type", "what"},
    "error": {"type", "message"},
}
ITEM_KEYS = {
    "contact_containers": {"id", "name", "kind"},
    "calendars": {"id", "name", "source_id", "source_name", "source_kind", "color"},
    "contacts_snapshot": {"id", "given_name", "family_name", "middle_name", "nickname", "organisation", "job_title",
                          "kind", "emails", "phones", "addresses", "birthday", "urls", "photo_jpeg_base64"},
    "events_snapshot": {"calendar_id", "external_id", "occurrence_date", "start", "end", "all_day", "time_zone",
                        "title", "location", "notes", "detached", "recurring"},
}


def _types(messages):
    return [m["type"] for m in messages]


def _all_messages(selftest):
    for case in selftest.values():
        for key in ("messages", "revoked", "again", "status"):
            yield from case.get(key, [])
        for errors in case.get("errors", []):
            yield from errors


def test_every_message_has_exactly_the_protocol_keys(selftest):
    seen = set()
    for m in _all_messages(selftest):
        seen.add(m["type"])
        assert set(m) == MESSAGE_KEYS[m["type"]], m["type"]
        for item in m.get("items", []):
            assert set(item) == ITEM_KEYS[m["type"]], m["type"]
            for labeled in item.get("emails", []) + item.get("phones", []) + item.get("urls", []):
                assert set(labeled) == {"value", "label"}
            for address in item.get("addresses", []):
                assert set(address) == {"label", "street", "city", "region", "postcode", "country"}
    assert seen == set(MESSAGE_KEYS)


def test_hello_reports_both_statuses_without_reading(selftest):
    case = selftest["hello"]
    assert case["messages"] == [{"type": "hello", "version": 1, "contacts": "authorized", "calendars": "fullAccess"}]
    assert case["calls"] == []


def test_read_all_sends_accounts_contacts_calendars_and_the_window(selftest):
    case = selftest["read_all"]
    assert _types(case["messages"]) == [
        "contact_containers", "contacts_snapshot", "contacts_snapshot", "calendars", "events_snapshot"]
    snapshot = case["messages"][-1]
    # One year back and two years ahead of 18 March 2026 (Auckland), both ends covered.
    assert (snapshot["window_start"], snapshot["window_end"]) == ("2025-03-18", "2028-03-18")
    assert case["queries"] == [{"start": "2025-03-17T11:00:00Z", "end": "2028-03-18T11:00:00Z", "ids": None}]
    timed, all_day = snapshot["items"]
    assert timed["start"] == "2026-03-20T10:00:00+13:00" and timed["occurrence_date"].endswith("Z")
    assert all_day["all_day"] and all_day["time_zone"] is None and all_day["end"] == "2026-04-10"
    contact = case["messages"][1]["items"][0]
    assert contact["birthday"] == "--04-09" and contact["photo_jpeg_base64"] is None
    assert contact["urls"] == [{"value": "https://example.org/ava", "label": None}]


def test_a_snapshot_is_one_part_when_small(selftest):
    for m in selftest["read_all"]["messages"]:
        if m["type"].endswith("_snapshot"):
            assert (m["part"], m["last"]) == (0, True)


def test_a_large_snapshot_is_sent_in_parts_the_host_puts_back_together(selftest):
    case = selftest["read_in_parts"]
    events = [m for m in case["messages"] if m["type"] == "events_snapshot"]
    assert [(m["part"], m["last"], len(m["items"])) for m in events] == [(0, False, 1), (1, True, 1)]
    assert len({(m["window_start"], m["window_end"]) for m in events}) == 1
    assert [e["external_id"] for m in events for e in m["items"]] == [
        e["external_id"] for e in selftest["read_all"]["messages"][-1]["items"]]  # nothing lost, order kept
    contacts = [m for m in case["messages"] if m["type"] == "contacts_snapshot"]
    assert [(m["part"], m["last"]) for m in contacts] == [(0, True), (0, True)]
    # Each part stays under the budget (after 4 KB for the message's other fields); both events fit in 2 KB.
    assert case["part_counts"] == [2, 2, 1, 1]
    assert case["empty_parts"] == 1  # an empty snapshot is still sent, so the host removes what it held


def test_only_the_chosen_accounts_and_calendars_are_read(selftest):
    case = selftest["read_selected"]
    assert "contacts:container-icloud" not in case["calls"]
    snapshots = [m for m in case["messages"] if m["type"] == "contacts_snapshot"]
    assert [m["container_id"] for m in snapshots] == ["container-local"]
    # The account list is always complete, so the user can choose.
    assert len(case["messages"][0]["items"]) == 2
    assert case["queries"][0]["ids"] == ["cal-home"]  # cal-gone no longer exists
    assert {e["calendar_id"] for e in case["messages"][-1]["items"]} == {"cal-home"}


def test_choosing_nothing_reads_nothing(selftest):
    case = selftest["read_none_chosen"]
    assert not any(c.startswith("contacts:") for c in case["calls"])
    assert case["queries"][0]["ids"] == [] and case["messages"][-1]["items"] == []


def test_nothing_is_read_or_requested_before_the_user_allows_it(selftest):
    case = selftest["not_allowed"]
    assert case["calls"] == []  # no read, no request, not even watching for changes
    assert _types(case["messages"]) == ["hello", "error", "error"]


def test_access_is_requested_only_by_the_request_access_command(selftest):
    requesting = {k for k, v in selftest.items() if any(c.startswith("request") for c in v.get("calls", []))}
    assert requesting == {"request_access", "request_after_read", "request_denied"}
    assert selftest["request_access"]["calls"] == ["requestContactsAccess"]
    assert selftest["request_access"]["messages"] == [
        {"type": "status", "contacts": "authorized", "calendars": "fullAccess"}]
    assert selftest["request_denied"]["messages"] == [
        {"type": "status", "contacts": "authorized", "calendars": "denied"}]


def test_a_grant_after_a_read_request_reads_straight_away(selftest):
    assert _types(selftest["request_after_read"]["messages"]) == [
        "status", "contact_containers", "contacts_snapshot", "contacts_snapshot"]


def test_changes_are_ignored_at_start_then_debounced_and_reread(selftest):
    case = selftest["changes"]
    assert case["during_grace"] == []
    assert case["after_grace"] == ["calendars", "contacts"]  # three notices, two re-reads
    assert _types(case["messages"]) == [
        "changed", "calendars", "events_snapshot", "changed", "contact_containers", "contacts_snapshot",
        "contacts_snapshot"]
    assert selftest["change_not_followed"]["debounced"] == []


def test_the_timer_rereads_every_15_minutes_and_moves_the_window_daily(selftest):
    assert selftest["tick_quiet"] == {"messages": [], "calls": []}
    assert _types(selftest["tick_safety"]["messages"]) == [
        "contact_containers", "contacts_snapshot", "contacts_snapshot", "calendars", "events_snapshot"]
    new_day = selftest["tick_new_day"]
    assert _types(new_day["messages"]) == ["calendars", "events_snapshot"]
    assert (new_day["messages"][-1]["window_start"], new_day["messages"][-1]["window_end"]) == (
        "2025-03-19", "2028-03-19")
    assert _types(selftest["tick_before_start"]["messages"]) == ["status"]
    assert selftest["tick_before_start"]["calls"] == []


def test_a_revoked_permission_is_reported_once(selftest):
    assert selftest["tick_status"]["revoked"] == [{"type": "status", "contacts": "authorized", "calendars": "denied"}]
    assert selftest["tick_status"]["again"] == []


def test_bad_commands_get_an_error_that_does_not_repeat_them(selftest):
    case = selftest["commands"]
    assert all(_types(e) == ["error"] for e in case["errors"])
    assert not any("Ava" in e[0]["message"] or "drop" in e[0]["message"] for e in case["errors"])
    assert case["blank"] == [] and case["calls"] == [] and case["quit"] is True
    assert _types(case["status"]) == ["status"]


def test_long_ranges_are_read_in_pieces_of_at_most_four_years(selftest):
    c = selftest["conversions"]
    assert c["max_span"] == 4 * 365 * 86400
    spans = c["spans"]
    assert spans[0][0] == "2019-01-01T00:00:00Z" and spans[-1][1] == "2031-01-01T00:00:00Z"
    assert all(a[1] == b[0] for a, b in zip(spans, spans[1:]))  # no gap, no overlap
    assert all(0 < s[2] <= c["max_span"] for s in spans) and len(spans) == 4
    parse = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
    for start, end, _ in spans:  # never more than four calendar years, leap days included
        assert parse(end) - parse(start) <= timedelta(days=4 * 365)
    assert c["window_spans"] == 1


def test_conversions(selftest):
    c = selftest["conversions"]
    assert c["window"] == ["2025-03-17T11:00:00Z", "2028-03-18T11:00:00Z", "2025-03-18", "2028-03-18"]
    assert c["leap_window"] == ["2027-02-28", "2030-02-28"]
    assert c["all_day_one"] == ["2026-04-09", "2026-04-10"]
    assert c["all_day_midnight_end"] == ["2026-04-09", "2026-04-11"]
    assert c["all_day_zero"] == ["2026-04-09", "2026-04-10"]
    assert c["timestamp"] == "2026-03-20T10:00:00+13:00"
    assert c["timestamp_utc"] == c["timestamp_in_utc_zone"] == "2026-03-19T21:00:00Z"
    assert c["birthday"] == ["1990-04-09", "--04-09", None]
    assert c["labels"] == ["mobile", "homepage", "Gym", None, None]
    assert c["colors"] == ["#A9CC4E", "#000000", "#FFFFFF"]
    assert c["jpeg_from_png"] == [0xFF, 0xD8, 0xFF]
    assert c["jpeg_kept"] and c["jpeg_garbage"] and c["jpeg_empty"]
    assert c["text"] == ["x", None, None]
    assert c["selection"] == [True, True, False]


@needs_swift
@pytest.mark.skipif(shutil.which("codesign") is None, reason="needs codesign")
def test_the_build_script_signs_with_the_hardened_runtime_and_entitlements_when_asked(tmp_path):
    app = tmp_path / "out" / "myDataReader.app"
    env = {k: v for k, v in os.environ.items() if k not in {"EXPANDED_CODE_SIGN_IDENTITY", "TARGET_TEMP_DIR", "ARCHS"}}
    env.update(TMPDIR=str(tmp_path), ENABLE_HARDENED_RUNTIME="YES")
    r = subprocess.run(["/bin/bash", str(READER / "build_reader.sh"), str(app)], capture_output=True, text=True,
                       env=env, timeout=600)
    assert r.returncode == 0, r.stderr
    assert (app / "Contents" / "MacOS" / "myDataReader").is_file()
    assert _plist(app / "Contents" / "Info.plist")["CFBundleIdentifier"] == "kiwi.mydata.reader"
    details = subprocess.run(["codesign", "-dvv", str(app)], capture_output=True, text=True).stderr
    assert "Identifier=kiwi.mydata.reader" in details and "runtime" in details
    ents = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(app)], capture_output=True)
    xml = ents.stdout[ents.stdout.find(b"<?xml"):]
    assert plistlib.loads(xml) == _plist(READER / "Reader.entitlements")
    # A second run with nothing changed reuses the signed build.
    again = subprocess.run(["/bin/bash", str(READER / "build_reader.sh"), str(app)], capture_output=True, text=True,
                           env=env, timeout=600)
    assert again.returncode == 0 and "unchanged" in again.stdout
