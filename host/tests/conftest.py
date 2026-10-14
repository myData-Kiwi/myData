"""Scorer-agreement tests replay ideal and known-bad behaviour to check that the scorer and the case
expectations agree. They test the scoring, not the orchestrator fixes, so they run the engine with
every tool visible and no grounding. The fixes have their own tests (test_routing, test_grounding)."""

import functools

import pytest

from mydata.orchestrator.engine import Engine

# No test leaves an Ollama server running (the stand-in or the real one); see tests/ollama_guard.py.
from ollama_guard import (_ollama_guard, fake_ollama, pytest_configure, pytest_sessionfinish,  # noqa: F401
                          pytest_sessionstart, pytest_unconfigure)

SCORER_AGREEMENT_MODULES = {"test_oracle", "test_outcome_score", "test_oracle_b", "test_review_regressions", "test_report",
                            "test_hand_review_rule"}


@pytest.fixture(scope="session", autouse=True)
def _dav_read_only_audit():
    """Whole-run check: across every test, the fake DAV server saw only PROPFIND, REPORT, OPTIONS and GET
    (tests that probe the fake's own 405 answers use audit=False)."""
    yield
    import fake_dav

    assert fake_dav.audit_violations() == [], f"write methods reached the fake DAV server: {fake_dav.audit_violations()}"


@pytest.fixture(autouse=True)
def _never_start_the_real_reader(monkeypatch):
    """No test may start the real myDataReader (it could show a permission prompt or read real data): the
    launcher's /usr/bin/open is replaced by a refusal. Tests use the fake helper in tests/fake_mac."""
    import mydata.sources.mac.launcher as launcher

    def refuse(cmd, **_kw):
        raise AssertionError(f"a test tried to start the real reader: {cmd[:2]}")

    monkeypatch.setattr(launcher, "_open_run", refuse)


@pytest.fixture(autouse=True)
def _filevault_not_asked(monkeypatch):
    """/status reports FileVault; tests never run fdesetup (test_backup checks the call with a stand-in)."""
    import mydata.service.backup as backup

    monkeypatch.setattr(backup, "_filevault", "unknown")


@pytest.fixture(autouse=True)
def _plain_engine(request, monkeypatch):
    if request.module.__name__.rsplit(".", 1)[-1] in SCORER_AGREEMENT_MODULES and hasattr(request.module, "Engine"):
        monkeypatch.setattr(request.module, "Engine", functools.partial(Engine, route=False, ground=False))
    yield
