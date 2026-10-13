"""Scorer-agreement tests replay ideal and known-bad behaviour to check that the scorer and the case
expectations agree. They test the scoring, not the orchestrator fixes, so they run the engine with
every tool visible and no grounding. The fixes have their own tests (test_routing, test_grounding)."""

import functools

import pytest

from mydata.orchestrator.engine import Engine

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
def _plain_engine(request, monkeypatch):
    if request.module.__name__.rsplit(".", 1)[-1] in SCORER_AGREEMENT_MODULES and hasattr(request.module, "Engine"):
        monkeypatch.setattr(request.module, "Engine", functools.partial(Engine, route=False, ground=False))
    yield
