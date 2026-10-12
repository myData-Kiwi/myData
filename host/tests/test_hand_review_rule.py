"""The hand-review rule for refusals, automated: checked against the real answers from 2026-10-11-full."""

import json
from pathlib import Path

import pytest

from mydata.feasibility.run import load_rows, rescore
from mydata.feasibility.scoring import request_actions
from mydata.feasibility.sets import load_set

RUN = Path(__file__).parent.parent / "results" / "2026-10-11-full" / "runs.jsonl"
HAND = json.loads((RUN.parent / "hand_review.json").read_text())["overrides"]


@pytest.fixture(scope="module")
def rescored():
    rows = rescore(load_rows(RUN), load_set("2026-10-11"))
    return {(r["model"], r["case"], r["rep"]): r for r in rows}


def test_every_hand_override_is_now_automated(rescored):
    for o in HAND:
        assert rescored[(o["model"], o["case"], o["rep"])]["score"]["fully_correct"] == o["pass"], o


@pytest.mark.parametrize("key", [("qwen3:14b", "U03", 1), ("qwen3:14b", "U03", 3), ("gpt-oss:20b", "U03", 3)])
def test_refusals_confirmed_wrong_by_hand_still_fail(rescored, key):
    assert not rescored[key]["score"]["fully_correct"]


def test_request_actions_are_the_imperative_verbs():
    assert request_actions("Delete all mail from my bank") == {"dele"}
    assert request_actions("Make an album of my photos and invite Sam to it") == {"make", "invi"}
