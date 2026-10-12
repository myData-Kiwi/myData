"""The outcome score ignores rejected calls the model corrected, and nothing else."""

from mydata.feasibility.cases import CASES
from mydata.feasibility.scoring import outcome_score, score
from mydata.orchestrator.engine import Engine
from mydata.orchestrator.fixtures import TODAY

from test_oracle import IDEAL, Scripted, call


def _case(cid):
    return next(c for c in CASES if c["id"] == cid)


def _run(cid, script):
    return Engine(Scripted(script), TODAY, route=False, ground=False).run(_case(cid)["text"]).to_json()


def test_corrected_rejection_passes_outcome_but_not_strict():
    run = _run("S05", [[call("list_events", date="whenever tomorrow-ish")], [call("list_events", date="tomorrow")],
                       {"content": "Two things."}])
    assert run["calls"][0]["status"] == "bad_date"
    assert not score(_case("S05"), run, TODAY).fully_correct
    assert outcome_score(_case("S05"), run, TODAY).fully_correct


def test_uncorrected_rejection_still_fails():
    run = _run("S05", [[call("list_events", date="whenever tomorrow-ish")], {"content": "Sorry."}])
    assert not outcome_score(_case("S05"), run, TODAY).fully_correct


def test_run_ending_in_rejection_fails():
    run = _run("C05", [[call("find_contact", name="Nisha Patel")],
                       [call("send_mail", to="nisha.patel@example.com", subject="Late")]])
    assert run["calls"][-1]["status"] == "invalid_args"
    assert not outcome_score(_case("C05"), run, TODAY).fully_correct


def test_invented_tool_is_never_ignored():
    run = _run("S05", [[call("calendar_lookup", day="tomorrow")], [call("list_events", date="tomorrow")],
                       {"content": "."}])
    assert not outcome_score(_case("S05"), run, TODAY).fully_correct


def test_ideal_runs_pass_both():
    for c in CASES:
        run = _run(c["id"], IDEAL[c["id"]])
        assert outcome_score(c, run, TODAY).fully_correct == score(c, run, TODAY).fully_correct is True
