"""Report rendering on synthetic runs from the scripted ideal model."""

from mydata.feasibility.cases import CASES
from mydata.feasibility.run import render_report
from mydata.feasibility.scoring import score
from mydata.orchestrator.engine import Engine
from mydata.orchestrator.fixtures import TODAY

from test_oracle import IDEAL, Scripted


def _rows(case_ids, reps=3, model="m"):
    rows = []
    for c in CASES:
        if c["id"] not in case_ids:
            continue
        for rep in range(1, reps + 1):
            run = Engine(Scripted(IDEAL[c["id"]]), TODAY).run(c["text"]).to_json()
            rows.append({"model": model, "case": c["id"], "type": c["type"], "rep": rep, "run": run,
                         "score": score(c, run, TODAY).to_json()})
    return rows


def test_full_ideal_run_gets_works_verdict():
    out = render_report(_rows({c["id"] for c in CASES}))
    assert "works (>=90%)" in out and "**100%**" in out


def test_partial_run_gets_no_verdict():
    out = render_report(_rows({"S01", "S02"}))
    assert "works (>=90%)" not in out
    assert "partial: 2/30 requests" in out


def test_refusals_listed_for_hand_check():
    out = render_report(_rows({c["id"] for c in CASES}, reps=1))
    assert "Free-text answers, for checking by hand" in out
    assert out.count("`m` U0") == 3
