"""The orchestrator now goes through the tool layer. Replaying every logged model reply from every saved
feasibility run must give the same calls, statuses, tool results, outcomes and scores as when it ran."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from mydata.feasibility.run import load_rows
from mydata.feasibility.scoring import outcome_score, score
from mydata.feasibility.sets import load_set, use_data
from mydata.orchestrator.engine import Engine

RESULTS = Path(__file__).parent.parent / "results"

# How each saved run's engine was configured (see the commit that produced it).
CONFIG = {
    "2026-10-11-full": dict(route=False, ground=False),
    "2026-10-11-b-baseline": dict(route=False, ground=False),
    "2026-10-11-b-fix-a": dict(route=False, ground=False),
    "2026-10-11-b-fix-b": dict(route=True, ground=False),
    "2026-10-11-b-fix-c": dict(route=True, ground=True),
    "2026-10-11-b-kept-ac": dict(route=False, ground=True),
    "2026-10-11-b-kept-ac-think-chains": dict(route=False, ground=True),
}


class Replay:
    """Returns the assistant messages a model produced in a logged run, in order."""

    def __init__(self, name: str, messages: list[dict]):
        self.name = name
        self.replies = [m for m in messages if m["role"] == "assistant"]

    def chat(self, messages, tools):
        m = self.replies.pop(0)
        return {"content": m.get("content", ""), "tool_calls": m.get("tool_calls") or [],
                "thinking": m.get("thinking", "")}


def _strip(call: dict) -> dict:
    out = {k: call.get(k) for k in ("step", "tool", "args", "status", "error", "invented_args", "dropped_args",
                                     "resolved", "result")}
    # Runs logged before the field existed have no dropped_args.
    out["dropped_args"] = out["dropped_args"] or {}
    # Known logging improvement: the old engine did not record arguments grounding dropped when the call
    # then failed on its date (the arguments sent were the same; only the record of the drop is new).
    if out["status"] == "bad_date":
        out["dropped_args"] = None
    return out


@pytest.mark.parametrize("run_dir", sorted(CONFIG))
def test_replay_matches_logged_run(run_dir):
    path = RESULTS / run_dir / "runs.jsonl"
    meta = json.loads((path.parent / "meta.json").read_text())
    case_set = load_set(meta.get("set", "2026-10-11"))
    by_id = {c["id"]: c for c in case_set.cases}
    mismatches = []
    with use_data(case_set.data):
        for row in load_rows(path):
            logged = row["run"]
            engine = Engine(Replay(row["model"], logged["messages"]), case_set.today, **CONFIG[run_dir])
            new = engine.run(logged["request"]).to_json()
            case = by_id[row["case"]]
            same = (
                [_strip(c) for c in new["calls"]] == [_strip(c) for c in logged["calls"]]
                and new["outcome"] == logged["outcome"]
                and new["final_text"] == logged["final_text"]
                and score(case, new, case_set.today) == score(case, logged, case_set.today)
                and outcome_score(case, new, case_set.today) == outcome_score(case, logged, case_set.today)
            )
            if not same:
                mismatches.append(f"{row['model']} {row['case']} #{row['rep']}")
    assert not mismatches, f"{len(mismatches)} runs differ: {mismatches[:10]}"
