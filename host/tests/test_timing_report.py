"""The timing report's arithmetic, on synthetic runs (no model)."""

from mydata.feasibility.timing import _inputs, render_timing


def _run(a, b, total):
    msgs = [{"role": "system"}, {"role": "user"}, {"role": "assistant", "tool_calls": [{}]},
            {"role": "tool"}, {"role": "assistant"}]
    stats = {"prompt_eval_count": 40, "prompt_eval_duration": 2e8, "eval_count": 20, "eval_duration": 1e9}
    return {"case": "BS01", "rep": 1, "run": {
        "messages": msgs, "calls": [{"tool": "list_events"}], "seconds_total": total, "model_calls": 2,
        "model_replies": [
            {"stats": stats, "seconds": a, "probe": {"full_prompt_tokens": 1500, "cold_read_s": 2.5, "cache_reused": True, "skipped_share": 0.92}},
            {"stats": stats, "seconds": b, "probe": {"full_prompt_tokens": 1600, "cold_read_s": 2.6, "cache_reused": True, "skipped_share": 0.92}},
        ]}}


def test_split_adds_up():
    report = render_timing([_run(2.0, 3.0, 5.5)], {"model": "m", "set": "s", "cases": ["BS01"], "reps": 1,
                                                    "ollama_version": "x"})
    assert "| Tool-choice call | 2.00 | 2.00 | 36% |" in report
    assert "| Tool execution (validation, grounding, the tool, engine) | 0.50 | 0.50 | 9% |" in report
    assert "| Phrasing call | 3.00 | 3.00 | 55% |" in report
    assert "1/1 (median 92% of the prompt skipped)" in report


def test_each_call_sees_the_messages_before_its_reply():
    run = _run(1, 1, 2)["run"]
    inputs = _inputs(run)
    assert [len(m) for m in inputs] == [2, 4]
