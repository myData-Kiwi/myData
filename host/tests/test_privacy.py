"""Real personal data stays out of the repository.

- Test data (tests/fixtures, tests/fake_dav, tests/fake_mac) holds only reserved example addresses and fictional
  phone numbers.
- The host's data files (the mirror, accounts.json, logs) are ignored by git wherever they land in the checkout.
- The host refuses a folder or log folder inside the checkout; access log lines leave out query strings.
- The feasibility harness, whose results/ are committed, refuses to run on anything but demo data.
"""

from __future__ import annotations

import logging
import re
import shutil
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest

from mydata.feasibility.guard import RealDataRefused, demo_registry, ensure_demo
from mydata.service.config import ConfigError, inside_checkout, load_settings, source_checkout
from mydata.service.logs import NoQueryString, setup_logging
from mydata.tools import TOOLS, Registry, default_registry
from mydata.tools.mirror import mirror_registry

TESTS = Path(__file__).parent
SCANNED = [TESTS / "fixtures", TESTS / "fake_dav", TESTS / "fake_mac"]
# The myData app's fake host and fixtures (This Mac, iCloud accounts) and its screenshots' data, when the app
# is in this checkout.
APP_TESTS = TESTS.parent.parent / "app" / "apps" / "mydata" / "test"
if APP_TESTS.is_dir():
    SCANNED.append(APP_TESTS)

# ---------------------------------------------------------------- invented data only

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})")
EXAMPLE_DOMAINS = ("example.com", "example.net", "example.org")
RESERVED_TLDS = (".example", ".test", ".invalid", ".localhost")  # RFC 2606
PHONE = re.compile(r"(?:\+|tel:)\d[\d \t().\-]{5,}\d")
TEL_LINE = re.compile(r"^(?:item\d+\.)?TEL[^:\n]*:(.+)$", re.M | re.I)
# Ofcom's ranges for drama (national number without the leading 0).
UK_FICTIONAL = ("7700900", "2079460", "1632960", "1134960", "1144960", "1154960", "1164960", "1174960", "1184960",
                "1214960", "1314960", "1414960", "1514960", "1614960", "2896496", "2920180", "3069990", "8081570",
                "9098790")


def example_domain(domain: str) -> bool:
    d = domain.lower()
    return any(d == x or d.endswith("." + x) for x in EXAMPLE_DOMAINS) or d.endswith(RESERVED_TLDS)


def fictional_phone(text: str) -> bool:
    """+1 NXX 555 01xx (and 555 01xx, or the unassigned area code 555), or a UK drama range."""
    digits = re.sub(r"\D", "", text)
    if digits.startswith("1"):
        n = digits[1:]
        if len(n) == 10:
            return n[:3] == "555" or (n[3:6] == "555" and n[6:8] == "01")
        return len(n) == 7 and n[:3] == "555" and n[3:5] == "01"
    if digits.startswith("44"):
        return digits[2:].startswith(UK_FICTIONAL)
    return False


def _scanned_files():
    for root in SCANNED:
        for path in sorted(root.rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts:
                yield path


def real_looking(text: str) -> list[str]:
    found = [f"email {m.group(0)}" for m in EMAIL.finditer(text) if not example_domain(m.group(1))]
    phones = {m.group(0) for m in PHONE.finditer(text)} | {m.group(1).strip() for m in TEL_LINE.finditer(text)}
    found += [f"phone {p}" for p in sorted(phones) if not fictional_phone(p)]
    return found


def test_the_scanner_catches_real_looking_data():
    assert real_looking("mail ava@gmail.com or ava@example.com") == ["email ava@gmail.com"]
    assert real_looking("TEL;TYPE=CELL:+64 21 555 0101\r\n") == ["phone +64 21 555 0101"]
    assert real_looking("TEL:021 123 4567\n") == ["phone 021 123 4567"]
    assert real_looking('phones=[("CELL", "+91 98200 11111")]') == ["phone +91 98200 11111"]
    assert real_looking("+1 202 555 0101 +44 7700 900123 +44 20 7946 0000 +1 (555) 010-0100 x@work.example.net") == []
    assert real_looking("+1 202 555 0199 TZOFFSETFROM:+1300 ORGANIZER:mailto:x@host.test") == []
    assert real_looking("+1 202 555 0200") == ["phone +1 202 555 0200"]


def test_test_data_holds_no_real_looking_address_or_phone():
    problems = []
    files = list(_scanned_files())
    assert len(files) > 20  # the fixtures are really being read
    assert {TESTS / "fake_mac" / "data.py", TESTS / "fake_mac" / "__init__.py"} <= set(files)
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        problems += [f"{path.relative_to(TESTS)}: {p}" for p in real_looking(text)]
    assert not problems, "test data must be invented (example.com/.net/.org, fictional numbers):\n" + "\n".join(problems)


# ---------------------------------------------------------------- git never takes the host's data

CHECKOUT = source_checkout()
needs_git = pytest.mark.skipif(CHECKOUT is None or shutil.which("git") is None, reason="not a git checkout")

IGNORED = ["host/contacts.sqlite", "host/calendar.sqlite", "host/tests/contacts.sqlite", "contacts.sqlite-wal",
           "host/calendar.sqlite-shm", "host/accounts.json", "host/tests/some-home/accounts.json", "logs/mydatad.log",
           "host/logs/assistant.jsonl", "host/some-home/logs/mydatad.log.1", "host/mydatad.log",
           "host/app-tokens/mydata", "host/state.json", "host/agents.json", "host/mydatad.pid"]
KEPT = ["host/results/2026-10-11-full/runs.jsonl", "host/results/2026-10-11-full/console.log", "host/openapi.json",
        "host/tests/fixtures/dav/contacts/ava-fictional.vcf", "host/tests/fake_dav/data.py", "app/pubspec.yaml"]


def _ignored(rel: str) -> bool:
    r = subprocess.run(["git", "-C", str(CHECKOUT), "check-ignore", "-q", "--no-index", rel], capture_output=True)
    assert r.returncode in (0, 1), r.stderr
    return r.returncode == 0


@needs_git
def test_host_data_files_are_ignored_by_git_wherever_they_land():
    assert [p for p in IGNORED if not _ignored(p)] == []


@needs_git
def test_committed_kinds_of_file_are_not_ignored():
    assert [p for p in KEPT if _ignored(p)] == []


# ---------------------------------------------------------------- logs live in the host folder only


@pytest.mark.skipif(CHECKOUT is None, reason="not a git checkout")
def test_a_host_folder_or_log_folder_inside_the_checkout_is_refused():
    inside = CHECKOUT / "host" / "not-a-home"
    with pytest.raises(ConfigError, match="inside the source checkout"):
        load_settings(inside)
    assert not inside.exists()  # refused before anything was written
    with pytest.raises(ConfigError, match="inside the source checkout"):
        setup_logging(inside / "logs")
    assert not inside.exists()
    assert inside_checkout(TESTS) and not inside_checkout(Path("/tmp"))


def test_the_default_host_folder_and_logs_are_outside_the_checkout(tmp_path):
    settings = load_settings(tmp_path)
    assert settings.log_dir == tmp_path / "logs"
    assert not inside_checkout(settings.home) and not inside_checkout(settings.log_dir)


def test_setup_logging_quiets_http_clients_and_strips_query_strings(tmp_path):
    root = logging.getLogger()
    saved = (list(root.handlers), root.level)
    access = logging.getLogger("uvicorn.access")
    saved_access = (list(access.handlers), access.propagate)
    try:
        setup_logging(tmp_path / "logs", to_stderr=False)
        assert logging.getLogger("httpx").getEffectiveLevel() >= logging.WARNING
        assert any(isinstance(f, NoQueryString) for f in access.filters)
    finally:
        root.handlers[:] = saved[0]
        root.setLevel(saved[1])
        access.handlers[:], access.propagate = saved_access
    record = logging.LogRecord("uvicorn.access", logging.INFO, __file__, 1, '%s - "%s %s HTTP/%s" %d',
                               ("127.0.0.1:5000", "GET", "/contacts?query=Ava+Fictional", "1.1", 200), None)
    assert NoQueryString().filter(record)
    assert record.getMessage() == '127.0.0.1:5000 - "GET /contacts HTTP/1.1" 200'


# ---------------------------------------------------------------- the feasibility harness: demo data only


class _Empty:
    def find_by_name(self, name):
        return []

    def events_between(self, *a, **kw):
        return []


def test_guard_accepts_the_demo_registry_and_a_demo_host():
    ensure_demo(default_registry())
    ensure_demo(demo_registry(lambda: None))
    ensure_demo({"mode": "demo"})


def test_guard_refuses_a_real_mode_registry():
    with pytest.raises(RealDataRefused, match="only runs on demo data"):
        ensure_demo(mirror_registry(_Empty(), _Empty()))


def test_guard_refuses_real_handlers_even_under_a_demo_label():
    mirror = mirror_registry(_Empty(), _Empty())
    tools = [mirror.get(n) if n in mirror else TOOLS[n] for n in TOOLS]
    with pytest.raises(RealDataRefused, match="find_contact, list_events do not use the fake demo data"):
        ensure_demo(Registry(tools, mode="demo"))
    with pytest.raises(RealDataRefused, match="not the built-in demo tools"):
        ensure_demo(Registry([TOOLS["find_contact"]], mode="demo"))


def test_guard_refuses_a_real_mode_host():
    with pytest.raises(RealDataRefused, match="real mode"):
        ensure_demo({"mode": "real"})
    with pytest.raises(RealDataRefused):
        ensure_demo({"version": "0.0.1"})  # a host too old to say: not known to be demo


def test_harness_commands_refuse_before_writing_results(tmp_path):
    from mydata.feasibility.latency import run_decide, run_latency, run_speed
    from mydata.feasibility.run import cmd_run
    from mydata.feasibility.timing import run_timing

    real = mirror_registry(_Empty(), _Empty())
    out = tmp_path / "results"
    calls = [
        lambda: run_timing("2026-10-11-b", "qwen3:14b", 1, out / "t", registry=real),
        lambda: run_latency("2026-10-11-b", "qwen3:14b", 1, ["rule"], out / "l", registry=real),
        lambda: run_decide("2026-10-11-b", "qwen3:14b", 1, out / "d", registry=real),
        lambda: run_speed("2026-10-11-b", "qwen3:14b", 0.1, out / "s", registry=real),
        lambda: cmd_run(SimpleNamespace(set="2026-10-11-b", only=None, stamp="x", out=str(out)), registry=real),
    ]
    for run in calls:
        with pytest.raises(RealDataRefused):
            run()
    assert not out.exists()
