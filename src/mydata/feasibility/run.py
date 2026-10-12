"""Run the feasibility test and report.

    python -m mydata.feasibility run --set 2026-10-11-b --models qwen3:14b
    python -m mydata.feasibility report results/<stamp>/runs.jsonl [--rescore]
    python -m mydata.feasibility compare baseline=results/a/runs.jsonl +a=results/b/runs.jsonl ...
"""

from __future__ import annotations

import argparse
import hashlib
import inspect
import json
import math
import platform
import statistics
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from ..orchestrator import dates as dates_module
from ..orchestrator import engine as engine_module
from ..orchestrator import fixtures
from ..orchestrator import ollama as ollama_module
from ..orchestrator import tools as tools_module
from ..orchestrator.engine import SYSTEM_PROMPT, Engine
from ..orchestrator.ollama import OllamaChat
from ..orchestrator.tools import TOOLS
from . import scoring as scoring_module
from .scoring import outcome_score, score
from .sets import DEFAULT_SET, CaseSet, load_set, use_data

HAND_REVIEW_RULE = (
    "Hand review touches only what the scorer judges by pattern-matching free text: the answer to a "
    "no-suitable-tool request and the answer to a no-tool question. Tool choice, arguments and how the run "
    "ended are never hand-reviewed. A refusal passes if a person reading it would say it tells the user the "
    "assistant cannot do the action, and it neither claims the action was done nor offers to do that action "
    "itself; suggesting something the tools can do instead, or telling the user how to do it themselves, is "
    "fine. A no-tool answer passes if it gives the right answer. The refusal part of this rule is automated "
    "in scoring.py (says_cannot, _claims_done and _offers_action in score()), so the raw score already applies it; the hand pass only records cases "
    "where a person disagrees with the automated judgement, each with a reason, in hand_review.json."
)


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:16]


def digests(case_set: CaseSet) -> dict:
    """Fingerprints of everything that decides a result, so runs from different versions are never mixed."""
    return {
        "cases_sha": _sha(case_set.source),
        "tools_sha": _sha(json.dumps([t.definition() for t in TOOLS.values()], sort_keys=True)),
        "tools_code_sha": _sha(inspect.getsource(tools_module) + inspect.getsource(fixtures)),
        "prompt_sha": _sha(SYSTEM_PROMPT),
        "dates_sha": _sha(inspect.getsource(dates_module)),
        "scoring_sha": _sha(inspect.getsource(scoring_module)),
        "engine_sha": _sha(inspect.getsource(engine_module) + inspect.getsource(think_setting)),
        "client_sha": _sha(inspect.getsource(ollama_module)),
    }


def think_setting(model: str, on: bool = False) -> bool | str:
    # gpt-oss has no "off"; "low" is its least-thinking level.
    if on:
        return "medium" if model.startswith("gpt-oss") else True
    return "low" if model.startswith("gpt-oss") else False


def cmd_run(ns: argparse.Namespace) -> int:
    case_set = load_set(ns.set)
    selected = [c for c in case_set.cases if not ns.only or c["id"] in ns.only]
    stamp = ns.stamp or datetime.now().strftime("%Y%m%d-%H%M%S")
    out_dir = Path(ns.out) / stamp
    runs_path = out_dir / "runs.jsonl"
    if runs_path.exists():
        print(f"{runs_path} already exists; choose another --stamp", file=sys.stderr)
        return 2
    out_dir.mkdir(parents=True, exist_ok=True)
    probe = OllamaChat(ns.models[0])
    models_meta = {}
    for m in ns.models:
        info = OllamaChat(m).show()
        models_meta[m] = {
            "think": think_setting(m, ns.think), "options": {"num_ctx": ns.num_ctx},
            "digest": OllamaChat(m).digest(),
            "modified_at": info.get("modified_at"), "parameters": info.get("parameters"),
            "details": info.get("details"),
        }
    meta = {
        "stamp": stamp, "set": case_set.name, "label": ns.label, "today": case_set.today.isoformat(),
        **digests(case_set), "reps": ns.reps,
        "models": models_meta, "ollama_version": probe.version(),
        "sampling": "model defaults, no seed (variance across reps is part of the measurement)",
        "system_prompt": SYSTEM_PROMPT, "tools": [t.definition() for t in TOOLS.values()],
        "host": platform.platform(), "cases": [c["id"] for c in selected],
    }
    (out_dir / "meta.json").write_text(json.dumps(meta, indent=2))
    (out_dir / "cases.frozen.py").write_text(case_set.source)
    print(f"writing {runs_path}  (set {case_set.name}, cases sha {meta['cases_sha']})", file=sys.stderr)

    with runs_path.open("a") as fh, use_data(case_set.data):
        for model_name in ns.models:
            model = OllamaChat(model_name, think=think_setting(model_name, ns.think), options={"num_ctx": ns.num_ctx})
            print(f"loading {model_name}...", file=sys.stderr)
            model.load()
            # One untimed request (not one of the cases) to warm the shared prompt prefix.
            Engine(model, case_set.today).run("Hello")
            engine = Engine(model, case_set.today)
            for case in selected:
                for rep in range(1, ns.reps + 1):
                    run = engine.run(case["text"]).to_json()
                    s = score(case, run, case_set.today)
                    row = {"model": model_name, "case": case["id"], "type": case["type"], "rep": rep,
                           "run": run, "score": s.to_json(),
                           "outcome_score": outcome_score(case, run, case_set.today).to_json()}
                    fh.write(json.dumps(row) + "\n")
                    fh.flush()
                    mark = "PASS" if s.fully_correct else "fail"
                    print(f"{model_name:14} {case['id']} #{rep} {mark} {run['seconds_total']:6.1f}s  "
                          f"{'; '.join(s.notes)[:160]}", file=sys.stderr)
            if not ns.keep_loaded:
                model.unload()

    report = render_report(load_rows(runs_path), meta, case_set)
    (out_dir / "report.md").write_text(report)
    print(report)
    return 0


def load_rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def load_hand_review(runs_path: Path) -> dict[tuple[str, str, int], dict]:
    """Per-run overrides recorded by a person: {(model, case, rep): {"pass": bool, "reason": str}}."""
    path = runs_path.parent / "hand_review.json"
    if not path.exists():
        return {}
    entries = json.loads(path.read_text()).get("overrides", [])
    return {(e["model"], e["case"], int(e["rep"])): e for e in entries}


def add_outcome(rows: list[dict], case_set: CaseSet) -> list[dict]:
    """Outcome score for every row, worked out from the logged run (so old runs get it too)."""
    by_id = {c["id"]: c for c in case_set.cases}
    with use_data(case_set.data):
        for r in rows:
            r["outcome_score"] = outcome_score(by_id[r["case"]], r["run"], case_set.today).to_json()
    return rows


def apply_hand_review(rows: list[dict], overrides: dict) -> list[dict]:
    for r in rows:
        o = overrides.get((r["model"], r["case"], r["rep"]))
        r["hand_pass"] = o["pass"] if o else r["score"]["fully_correct"]
        r["hand_reason"] = o["reason"] if o else None
        if o and "outcome_score" in r:
            # An override judges the reply itself, which both scores depend on.
            r["outcome_score"] = {**r["outcome_score"], "fully_correct": o["pass"]}
    return rows


def rescore(rows: list[dict], case_set: CaseSet) -> list[dict]:
    """Score again from the raw runs, so a scoring fix never needs a re-run."""
    by_id = {c["id"]: c for c in case_set.cases}
    with use_data(case_set.data):
        for r in rows:
            r["score"] = score(by_id[r["case"]], r["run"], case_set.today).to_json()
    return rows


def _pct(n: int, d: int) -> str:
    # Floor, so 89.7% never shows as 90% beside a "70-90%" verdict.
    return f"{math.floor(100 * n / d)}%" if d else "-"


def _median(xs: list[float]) -> str:
    return f"{statistics.median(xs):.1f}" if xs else "-"


def _first_tool_median(rows: list[dict]) -> str:
    return _median([r["run"]["seconds_to_first_tool_call"] for r in rows
                    if r["run"]["seconds_to_first_tool_call"] is not None])


def _by_request(rows: list[dict], key: str) -> tuple[int, int]:
    """Requests passed (all reps pass) and requests seen."""
    reps: dict[str, list[bool]] = defaultdict(list)
    for r in rows:
        reps[r["case"]].append(bool(r["score"]["fully_correct"] if key == "raw" else r["hand_pass"]))
    return sum(all(v) for v in reps.values()), len(reps)


def _cell(rows: list[dict]) -> str:
    """Runs fully correct (raw / hand-reviewed) and requests passed on every rep (raw / hand-reviewed)."""
    if not rows:
        return "-"
    raw = sum(r["score"]["fully_correct"] for r in rows)
    hand = sum(r["hand_pass"] for r in rows)
    rq_raw, n = _by_request(rows, "raw")
    rq_hand, _ = _by_request(rows, "hand")
    runs = f"{_pct(raw, len(rows))}" if raw == hand else f"{_pct(raw, len(rows))} / {_pct(hand, len(rows))}"
    reqs = f"{rq_raw}/{n}" if rq_raw == rq_hand else f"{rq_raw}/{n} / {rq_hand}/{n}"
    return f"{runs} · {reqs}"


def _outcome(rows: list[dict]) -> int:
    return sum(r["outcome_score"]["fully_correct"] for r in rows)


def _worst(rows: list[dict]) -> str:
    return f"{max(r['run']['seconds_total'] for r in rows):.1f}" if rows else "-"


def _outcome_cell(rows: list[dict]) -> str:
    if not rows:
        return "-"
    reqs: dict[str, list[bool]] = defaultdict(list)
    for r in rows:
        reqs[r["case"]].append(r["outcome_score"]["fully_correct"])
    return f"{_pct(_outcome(rows), len(rows))} · {sum(all(v) for v in reqs.values())}/{len(reqs)}"


def _verdict(pct: float) -> str:
    return ("works (>=90%)" if pct >= 90 else "look at failures (70-90%)" if pct >= 70
            else "not viable as planned (<70%)")


def render_report(rows: list[dict], meta: dict | None = None, case_set: CaseSet | None = None) -> str:
    case_set = case_set or load_set((meta or {}).get("set", DEFAULT_SET))
    cases = case_set.cases
    for r in rows:
        r.setdefault("hand_pass", r["score"]["fully_correct"])
        r.setdefault("hand_reason", None)
        r.setdefault("outcome_score", r["score"])
    lines: list[str] = ["# Feasibility test results", ""]
    if meta:
        lines += [f"- Run {meta['stamp']}, request set {meta.get('set', DEFAULT_SET)}"
                  + (f" ({meta['label']})" if meta.get("label") else "")
                  + f", fixed today {meta['today']}, {meta['reps']} reps per request, "
                  f"Ollama {meta.get('ollama_version', '?')}.",
                  "- Fingerprints: " + ", ".join(f"{k} `{v}`" for k, v in meta.items() if k.endswith("_sha")),
                  "- Models: " + ", ".join(f"`{m}` (think={c['think']}, num_ctx={c['options']['num_ctx']})"
                                           for m, c in meta["models"].items())]
        if any(c["think"] is not False for c in meta["models"].values()):
            lines.append("- Caveat: thinking could not be turned off for "
                         + ", ".join(f"`{m}` (used think={c['think']!r})" for m, c in meta["models"].items()
                                     if c["think"] is not False) + ".")
        if set(meta.get("cases", [])) != {c["id"] for c in cases}:
            lines.append(f"- Cases: subset ({len(meta.get('cases', []))} of {len(cases)}): {', '.join(meta.get('cases', []))}")
        if meta.get("rescored_note"):
            lines.append(f"- {meta['rescored_note']}")
        lines.append("")
    models = list(dict.fromkeys(r["model"] for r in rows))
    reps = meta["reps"] if meta else max((r["rep"] for r in rows), default=0)
    expected = {(c["id"], k) for c in cases for k in range(1, reps + 1)}
    gaps: dict[str, str] = {}
    for m in models:
        present = [(r["case"], r["rep"]) for r in rows if r["model"] == m]
        missing = expected - set(present)
        if missing or len(present) != len(set(present)):
            gaps[m] = (f"partial: {len({c for c, _ in present})}/{len(cases)} requests, "
                       f"{len(set(present))}/{len(expected)} runs" + (", duplicate rows" if len(present) != len(set(present)) else "")
                       + ", no verdict")

    lines += ["## Overall", "",
              "| Model | Runs | Right tool | Args strict | Invented | Fully correct (raw) | Fully correct (hand-reviewed) "
              "| Outcome correct | Requests passed, all reps (raw) | Requests passed, all reps (hand-reviewed) "
              "| Verdict (hand-reviewed) | Median s to 1st tool call | Median s to final answer | Worst s to final answer "
              "| Model errors | Retried after rejection |",
              "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for m in models:
        rs = [r for r in rows if r["model"] == m]
        raw = sum(r["score"]["fully_correct"] for r in rs)
        hand = sum(r["hand_pass"] for r in rs)
        rq_raw, n = _by_request(rs, "raw")
        rq_hand, _ = _by_request(rs, "hand")
        lines.append(
            f"| `{m}` | {len(rs)} | {_pct(sum(r['score']['right_tool'] for r in rs), len(rs))} | "
            f"{_pct(sum(r['score']['args_ok'] for r in rs), len(rs))} | {sum(r['score']['invented'] for r in rs)} | "
            f"{raw}/{len(rs)} ({_pct(raw, len(rs))}) | **{hand}/{len(rs)} ({_pct(hand, len(rs))})** | "
            f"{_outcome(rs)} ({_pct(_outcome(rs), len(rs))}) | "
            f"{rq_raw}/{n} ({_pct(rq_raw, n)}) | {rq_hand}/{n} ({_pct(rq_hand, n)}) | "
            f"{gaps.get(m) or _verdict(100 * hand / len(rs))} | {_first_tool_median(rs)} | "
            f"{_median([r['run']['seconds_total'] for r in rs])} | {_worst(rs)} | "
            f"{sum(r['run']['outcome'] == 'model_error' for r in rs)} | {sum(_retried(r) for r in rs)} |")
    lines += ["", "Fully correct = right tools, every argument strictly right, nothing invented, and the run "
              "ended the right way (answered / held for approval / stopped to ask). Model errors count as failures. "
              "A request passes only if every rep is fully correct. \"Retried after rejection\" counts runs where "
              "the code rejected a call and the model then fixed it; information only, never credit in the strict "
              "score. \"Outcome correct\" is the same strict test applied to the calls that stood: a rejected call "
              "is ignored if the model later made an accepted call to the same tool; a run whose last call was "
              "rejected, or that never corrected a rejection, still fails. \"Final answer\" is the end of the "
              "run: the reply, or the point where the code held a send for approval or stopped to ask.", "",
              "**Hand-review rule.** " + HAND_REVIEW_RULE, ""]

    for m in models:
        rs = [r for r in rows if r["model"] == m]
        lines += [f"## `{m}` by request type", "",
                  "| Type | Runs | Right tool | Args strict | Invented | Outcome right | Fully correct (raw) "
                  "| Fully correct (hand-reviewed) | Outcome correct | Requests passed, all reps (raw / hand) "
                  "| Median s to 1st tool call |",
                  "|---|---|---|---|---|---|---|---|---|---|---|"]
        for t, label in case_set.types.items():
            ts = [r for r in rs if r["type"] == t]
            if not ts:
                continue
            rq_raw, n = _by_request(ts, "raw")
            rq_hand, _ = _by_request(ts, "hand")
            lines.append(
                f"| {label} | {len(ts)} | {_pct(sum(r['score']['right_tool'] for r in ts), len(ts))} | "
                f"{_pct(sum(r['score']['args_ok'] for r in ts), len(ts))} | {sum(r['score']['invented'] for r in ts)} | "
                f"{_pct(sum(r['score']['outcome_ok'] for r in ts), len(ts))} | "
                f"{_pct(sum(r['score']['fully_correct'] for r in ts), len(ts))} | "
                f"**{_pct(sum(r['hand_pass'] for r in ts), len(ts))}** | {_pct(_outcome(ts), len(ts))} | "
                f"{rq_raw}/{n} / {rq_hand}/{n} | "
                f"{_first_tool_median(ts)} |")
        lines.append("")

    by_id = {c["id"]: c for c in cases}
    lines += ["## Per request", "", "| Request | " + " | ".join(f"`{m}`" for m in models) + " |",
              "|---|" + "---|" * len(models)]
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        grouped[(r["case"], r["model"])].append(r)
    for cid in dict.fromkeys(r["case"] for r in rows):
        cells = []
        for m in models:
            rs = grouped.get((cid, m), [])
            raw = sum(r["score"]["fully_correct"] for r in rs)
            hand = sum(r["hand_pass"] for r in rs)
            cells.append((f"{raw}/{len(rs)}" if raw == hand else f"{raw}/{len(rs)} (hand {hand}/{len(rs)})") if rs else "-")
        lines.append(f"| {cid} {by_id[cid]['text']} | " + " | ".join(cells) + " |")
    lines.append("")

    lines += ["## Limits of this test", "",
              "- Tool arguments are not grammar-constrained: Ollama's tools API parses the model's output; "
              "the engine validates it afterwards.",
              "- Prompt injection from mail bodies is not tested; the permission gate is.",
              "- For read requests, the final answer text is not checked, only the calls and how the run ended.",
              f"- Requests are in English with one fixed \"today\" ({case_set.today:%A %d %B %Y}).", ""]

    overrides = [r for r in rows if r.get("hand_reason")]
    if overrides:
        lines += ["## Hand-review overrides", ""]
        for r in overrides:
            lines.append(f"- `{r['model']}` {r['case']} #{r['rep']}: raw {'pass' if r['score']['fully_correct'] else 'fail'}"
                         f" → hand {'pass' if r['hand_pass'] else 'fail'}. {r['hand_reason']}")
        lines.append("")

    refusals = [r for r in rows if r["type"] in ("no_suitable", "no_tool") and not r["run"]["calls"]]
    if refusals:
        lines += ["## Free-text answers, for checking by hand", "",
                  "Every no-call answer to a no-suitable-tool or no-tool request, so a person can check the "
                  "automated judgement against the hand-review rule above.", ""]
        for r in refusals:
            mark = "pass" if r["hand_pass"] else "FAIL"
            text = " ".join((r["run"].get("final_text") or "").split())
            lines.append(f"- {mark} `{r['model']}` {r['case']} #{r['rep']}: {text[:300]!r}")
        lines.append("")

    lines += ["## Failures", ""]
    for r in rows:
        if r["hand_pass"]:
            continue
        lines.append(f"- `{r['model']}` {r['case']} #{r['rep']}: {'; '.join(r['score']['notes'])}")
        lines.append(f"  - calls: {_calls(r)}")
        if r["run"].get("final_text"):
            lines.append(f"  - said: {r['run']['final_text'][:200]!r}")
    return "\n".join(lines) + "\n"


def _calls(row: dict) -> str:
    return "; ".join(f"{c['tool']}({json.dumps(c['args'], ensure_ascii=False)})"
                     + (f" [{c['status']}]" if c["status"] not in ("ok",) else "")
                     for c in row["run"]["calls"]) or "no calls"


def _retried(row: dict) -> bool:
    calls = row["run"]["calls"]
    bad = ("invalid_args", "bad_date", "error", "unknown_tool")
    return any(c["status"] in bad and any(d["tool"] == c["tool"] and d["status"] not in bad and d["step"] > c["step"]
                                         for d in calls) for c in calls)


def _load_scored(path: Path, rescore_rows: bool = False) -> tuple[list[dict], dict | None, CaseSet]:
    meta_path = path.parent / "meta.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else None
    case_set = load_set((meta or {}).get("set", DEFAULT_SET))
    rows = load_rows(path)
    if rescore_rows:
        rows = rescore(rows, case_set)
    return apply_hand_review(add_outcome(rows, case_set), load_hand_review(path)), meta, case_set


def cmd_report(ns: argparse.Namespace) -> int:
    path = Path(ns.runs)
    rows, meta, case_set = _load_scored(path)
    if ns.rescore:
        now = digests(case_set)
        if meta is None or meta.get("cases_sha") != now["cases_sha"]:
            msg = (f"the request set changed since the run (run {meta and meta.get('cases_sha')}, now {now['cases_sha']}): "
                   "rescoring would judge old answers against new expectations")
            if not ns.allow_changed_cases:
                print(msg + "; pass --allow-changed-cases to do it anyway", file=sys.stderr)
                return 2
        known = {c["id"] for c in case_set.cases}
        dropped = [r for r in rows if r["case"] not in known]
        rows = apply_hand_review(rescore([r for r in rows if r["case"] in known], case_set), load_hand_review(path))
        if meta is not None:
            keys = ("scoring_sha", "cases_sha", "dates_sha", "tools_sha")
            changed = [k for k in keys if meta.get(k) != now[k]]
            note = "Rescored with " + ", ".join(f"{k} `{now[k]}`" for k in keys)
            if changed:
                note += (f". Changed since the run: {', '.join(changed)}. Arguments are re-judged with the current "
                         "code; call statuses (bad_date, invalid_args...) are still those from the run")
            if dropped:
                note += f"; {len(dropped)} rows for removed cases left out"
            meta = {**meta, "rescored_note": note}
    print(render_report(rows, meta, case_set))
    return 0


def render_compare(labelled: list[tuple[str, list[dict], dict | None]], case_set: CaseSet) -> str:
    """One row per run (baseline, +a, +b, ...): overall, chains, each other type, median s to first tool call."""
    types = [t for t in case_set.types if t != "chain"]
    head = (["Run", "Overall (strict)", "Overall (outcome)", "Chains (strict)", "Chains (outcome)"]
            + [case_set.types[t] for t in types]
            + ["Median s to 1st tool call", "Median s to final answer", "Worst s to final answer"])
    lines = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for label, rows, _ in labelled:
        chains = [r for r in rows if r["type"] == "chain"]
        cells = [label, _cell(rows), _outcome_cell(rows), _cell(chains), _outcome_cell(chains)]
        cells += [_cell([r for r in rows if r["type"] == t]) for t in types]
        cells += [_first_tool_median(rows), _median([r["run"]["seconds_total"] for r in rows]), _worst(rows)]
        lines.append("| " + " | ".join(cells) + " |")
    lines += ["",
              "Each cell: share of runs fully correct · requests passed on all reps. Where the hand-reviewed "
              "number differs from the raw automated one, both are shown as raw / hand-reviewed. Strict counts "
              "every call; outcome ignores rejected calls the model then corrected (see a run's report.md).", ""]
    label, rows, _ = labelled[-1]
    by_id = {c["id"]: c for c in case_set.cases}
    failing = defaultdict(list)
    for r in rows:
        if r["type"] == "chain" and not r["hand_pass"]:
            failing[r["case"]].append(r)
    lines += [f"### Chain requests still failing after {label}", ""]
    if not failing:
        lines.append("None.")
    for cid, rs in failing.items():
        lines.append(f"- **{cid}** {by_id[cid]['text']!r} ({len(rs)} of "
                     f"{sum(1 for r in rows if r['case'] == cid)} reps fail)")
        for r in rs:
            lines.append(f"  - #{r['rep']}: {_calls(r)}")
            lines.append(f"    - why: {'; '.join(r['score']['notes'])}")
    return "\n".join(lines) + "\n"


def cmd_compare(ns: argparse.Namespace) -> int:
    labelled = []
    sets = set()
    for spec in ns.runs:
        label, _, path = spec.partition("=")
        rows, meta, case_set = _load_scored(Path(path), ns.rescore)
        labelled.append((label, rows, meta))
        sets.add(case_set.name)
    if len(sets) != 1:
        print(f"runs are from different request sets: {sorted(sets)}", file=sys.stderr)
        return 2
    print(render_compare(labelled, load_set(sets.pop())))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m mydata.feasibility")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="run the requests against models")
    r.add_argument("--set", default=DEFAULT_SET, help="request set name (see sets.py)")
    r.add_argument("--label", help="what this run measures, e.g. baseline or +a")
    r.add_argument("--models", nargs="+", default=["qwen3:14b", "gpt-oss:20b"])
    r.add_argument("--reps", type=int, default=3)
    r.add_argument("--only", nargs="*", help="case ids to run")
    r.add_argument("--out", default="results")
    r.add_argument("--stamp", help="results subdirectory name (default: current time)")
    r.add_argument("--num-ctx", type=int, default=8192)
    r.add_argument("--keep-loaded", action="store_true")
    r.add_argument("--think", action="store_true", help="turn thinking on (default off)")
    r.set_defaults(fn=cmd_run)
    p = sub.add_parser("report", help="print the report for a runs.jsonl")
    p.add_argument("runs")
    p.add_argument("--rescore", action="store_true", help="re-score from raw runs with the current scorer")
    p.add_argument("--allow-changed-cases", action="store_true")
    p.set_defaults(fn=cmd_report)
    c = sub.add_parser("compare", help="one table across runs: label=path/runs.jsonl ...")
    c.add_argument("runs", nargs="+")
    c.add_argument("--rescore", action="store_true")
    c.set_defaults(fn=cmd_compare)
    ns = ap.parse_args(argv)
    return ns.fn(ns)
