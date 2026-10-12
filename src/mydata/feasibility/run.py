"""Run the feasibility test and report.

    python -m mydata.feasibility run --models qwen3:14b gpt-oss:20b
    python -m mydata.feasibility report results/<stamp>/runs.jsonl
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
from datetime import date, datetime
from pathlib import Path

from ..orchestrator import dates as dates_module
from ..orchestrator import engine as engine_module
from ..orchestrator import fixtures
from ..orchestrator import ollama as ollama_module
from ..orchestrator import tools as tools_module
from ..orchestrator.engine import SYSTEM_PROMPT, Engine
from ..orchestrator.ollama import OllamaChat
from ..orchestrator.tools import TOOLS
from . import cases as cases_module
from . import scoring as scoring_module
from .cases import CASES, TYPES
from .scoring import score

TODAY = fixtures.TODAY


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:16]


def cases_digest() -> str:
    return _sha(inspect.getsource(cases_module))


def digests() -> dict:
    """Fingerprints of everything that decides a result, so runs from different versions are never mixed."""
    return {
        "cases_sha": cases_digest(),
        "tools_sha": _sha(json.dumps([t.definition() for t in TOOLS.values()], sort_keys=True)
                          + inspect.getsource(tools_module) + inspect.getsource(fixtures)),
        "prompt_sha": _sha(SYSTEM_PROMPT),
        "dates_sha": _sha(inspect.getsource(dates_module)),
        "scoring_sha": _sha(inspect.getsource(scoring_module)),
        "engine_sha": _sha(inspect.getsource(engine_module) + inspect.getsource(think_setting)),
        "client_sha": _sha(inspect.getsource(ollama_module)),
    }


def think_setting(model: str) -> bool | str:
    # gpt-oss has no "off"; "low" is its least-thinking level.
    return "low" if model.startswith("gpt-oss") else False


def cmd_run(ns: argparse.Namespace) -> int:
    selected = [c for c in CASES if not ns.only or c["id"] in ns.only]
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
            "think": think_setting(m), "options": {"num_ctx": ns.num_ctx},
            "digest": OllamaChat(m).digest(),
            "modified_at": info.get("modified_at"), "parameters": info.get("parameters"),
            "details": info.get("details"),
        }
    meta = {
        "stamp": stamp, "today": TODAY.isoformat(), **digests(), "reps": ns.reps,
        "models": models_meta, "ollama_version": probe.version(),
        "sampling": "model defaults, no seed (variance across reps is part of the measurement)",
        "system_prompt": SYSTEM_PROMPT, "host": platform.platform(), "cases": [c["id"] for c in selected],
    }
    (out_dir / "meta.json").write_text(json.dumps(meta, indent=2))
    (out_dir / "cases.frozen.py").write_text(inspect.getsource(cases_module))
    print(f"writing {runs_path}  (cases sha {meta['cases_sha']})", file=sys.stderr)

    with runs_path.open("a") as fh:
        for model_name in ns.models:
            model = OllamaChat(model_name, think=think_setting(model_name), options={"num_ctx": ns.num_ctx})
            print(f"loading {model_name}...", file=sys.stderr)
            model.load()
            # One untimed request (not one of the cases) to warm the shared prompt prefix.
            Engine(model, TODAY).run("Hello")
            engine = Engine(model, TODAY)
            for case in selected:
                for rep in range(1, ns.reps + 1):
                    run = engine.run(case["text"]).to_json()
                    s = score(case, run, TODAY)
                    row = {"model": model_name, "case": case["id"], "type": case["type"], "rep": rep,
                           "run": run, "score": s.to_json()}
                    fh.write(json.dumps(row) + "\n")
                    fh.flush()
                    mark = "PASS" if s.fully_correct else "fail"
                    print(f"{model_name:14} {case['id']} #{rep} {mark} {run['seconds_total']:6.1f}s  "
                          f"{'; '.join(s.notes)[:160]}", file=sys.stderr)
            if not ns.keep_loaded:
                model.unload()

    report = render_report(load_rows(runs_path), meta)
    (out_dir / "report.md").write_text(report)
    print(report)
    return 0


def load_rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def rescore(rows: list[dict]) -> list[dict]:
    """Score again from the raw runs, so a scoring fix never needs a re-run."""
    by_id = {c["id"]: c for c in CASES}
    for r in rows:
        r["score"] = score(by_id[r["case"]], r["run"], TODAY).to_json()
    return rows


def _pct(n: int, d: int) -> str:
    # Floor, so 89.7% never shows as 90% beside a "70-90%" verdict.
    return f"{math.floor(100 * n / d)}%" if d else "-"


def _median(xs: list[float]) -> str:
    return f"{statistics.median(xs):.1f}" if xs else "-"


def render_report(rows: list[dict], meta: dict | None = None) -> str:
    lines: list[str] = ["# Feasibility test results", ""]
    if meta:
        lines += [f"- Run {meta['stamp']}, fixed today {meta['today']}, {meta['reps']} reps per request, "
                  f"Ollama {meta.get('ollama_version', '?')}.",
                  "- Fingerprints: " + ", ".join(f"{k} `{meta[k]}`" for k in
                                                 ("cases_sha", "tools_sha", "prompt_sha", "dates_sha", "scoring_sha",
                                                  "engine_sha", "client_sha")
                                                 if k in meta),
                  "- Models: " + ", ".join(f"`{m}` (think={c['think']}, num_ctx={c['options']['num_ctx']})"
                                           for m, c in meta["models"].items())]
        if any(c["think"] is not False for c in meta["models"].values()):
            lines.append("- Caveat: thinking could not be turned off for "
                         + ", ".join(f"`{m}` (used think={c['think']!r})" for m, c in meta["models"].items()
                                     if c["think"] is not False) + ".")
        if set(meta.get("cases", [])) != {c["id"] for c in CASES}:
            lines.append(f"- Cases: subset ({len(meta.get('cases', []))} of {len(CASES)}): {', '.join(meta.get('cases', []))}")
        if meta.get("rescored_note"):
            lines.append(f"- {meta['rescored_note']}")
        lines.append("")
    models = list(dict.fromkeys(r["model"] for r in rows))
    reps = meta["reps"] if meta else max((r["rep"] for r in rows), default=0)
    expected = {(c["id"], k) for c in CASES for k in range(1, reps + 1)}
    gaps: dict[str, str] = {}
    for m in models:
        present = [(r["case"], r["rep"]) for r in rows if r["model"] == m]
        missing = expected - set(present)
        if missing or len(present) != len(set(present)):
            gaps[m] = (f"partial: {len({c for c, _ in present})}/{len(CASES)} requests, "
                       f"{len(set(present))}/{len(expected)} runs" + (", duplicate rows" if len(present) != len(set(present)) else "")
                       + ", no verdict")

    lines += ["## Overall", "",
              "| Model | Runs | Right tool | Args strict | Invented | Fully correct | Verdict | Median s to 1st tool call | Median s total | Model errors | Retried after rejection |",
              "|---|---|---|---|---|---|---|---|---|---|---|"]
    for m in models:
        rs = [r for r in rows if r["model"] == m]
        full = sum(r["score"]["fully_correct"] for r in rs)
        pct = 100 * full / len(rs)
        verdict = gaps.get(m) or ("works (>=90%)" if pct >= 90 else "look at failures (70-90%)" if pct >= 70
                                  else "not viable as planned (<70%)")
        lines.append(
            f"| `{m}` | {len(rs)} | {_pct(sum(r['score']['right_tool'] for r in rs), len(rs))} | "
            f"{_pct(sum(r['score']['args_ok'] for r in rs), len(rs))} | {sum(r['score']['invented'] for r in rs)} | "
            f"**{_pct(full, len(rs))}** | {verdict} | "
            f"{_median([r['run']['seconds_to_first_tool_call'] for r in rs if r['run']['seconds_to_first_tool_call'] is not None])} | "
            f"{_median([r['run']['seconds_total'] for r in rs])} | "
            f"{sum(r['run']['outcome'] == 'model_error' for r in rs)} | {sum(_retried(r) for r in rs)} |")
    lines += ["", "Fully correct = right tools, every argument strictly right, nothing invented, and the run "
              "ended the right way (answered / held for approval / stopped to ask). Model errors count as failures. "
              "\"Retried after rejection\" counts runs where the code rejected a call and the model then fixed it; "
              "information only, never credit.", ""]

    for m in models:
        rs = [r for r in rows if r["model"] == m]
        lines += [f"## `{m}` by request type", "",
                  "| Type | Runs | Right tool | Args strict | Invented | Outcome right | Fully correct | Median s to 1st tool call |",
                  "|---|---|---|---|---|---|---|---|"]
        for t, label in TYPES.items():
            ts = [r for r in rs if r["type"] == t]
            if not ts:
                continue
            lines.append(
                f"| {label} | {len(ts)} | {_pct(sum(r['score']['right_tool'] for r in ts), len(ts))} | "
                f"{_pct(sum(r['score']['args_ok'] for r in ts), len(ts))} | {sum(r['score']['invented'] for r in ts)} | "
                f"{_pct(sum(r['score']['outcome_ok'] for r in ts), len(ts))} | "
                f"**{_pct(sum(r['score']['fully_correct'] for r in ts), len(ts))}** | "
                f"{_median([r['run']['seconds_to_first_tool_call'] for r in ts if r['run']['seconds_to_first_tool_call'] is not None])} |")
        lines.append("")

    by_id = {c["id"]: c for c in CASES}
    lines += ["## Per request", "", "| Request | " + " | ".join(f"`{m}`" for m in models) + " |",
              "|---|" + "---|" * len(models)]
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        grouped[(r["case"], r["model"])].append(r)
    for cid in dict.fromkeys(r["case"] for r in rows):
        cells = []
        for m in models:
            rs = grouped.get((cid, m), [])
            cells.append(f"{sum(r['score']['fully_correct'] for r in rs)}/{len(rs)}" if rs else "-")
        lines.append(f"| {cid} {by_id[cid]['text']} | " + " | ".join(cells) + " |")
    lines.append("")

    lines += ["## Limits of this test", "",
              "- Tool arguments are not grammar-constrained: Ollama's tools API parses the model's output; "
              "the engine validates it afterwards.",
              "- All six tools are shown on every request (the brief's \"small tool set\" is six here).",
              "- Prompt injection from mail bodies is not tested; the permission gate is.",
              "- For read requests, the final answer text is not checked, only the calls and how the run ended.",
              "- Requests are in English with one fixed \"today\" (Wednesday 18 March 2026).", ""]

    refusals = [r for r in rows if r["type"] == "no_suitable" and not r["run"]["calls"]]
    if refusals:
        lines += ["## Refusal answers, for checking by hand", "",
                  "The refusal check is a pattern match on free text. Every no-call answer to a no-suitable-tool "
                  "request is listed so a human can overrule it.", ""]
        for r in refusals:
            mark = "pass" if r["score"]["fully_correct"] else "FAIL"
            text = " ".join((r["run"].get("final_text") or "").split())
            lines.append(f"- {mark} `{r['model']}` {r['case']} #{r['rep']}: {text[:300]!r}")
        lines.append("")

    lines += ["## Failures", ""]
    for r in rows:
        if r["score"]["fully_correct"]:
            continue
        calls = "; ".join(f"{c['tool']}({json.dumps(c['args'], ensure_ascii=False)})" for c in r["run"]["calls"]) or "no calls"
        lines.append(f"- `{r['model']}` {r['case']} #{r['rep']}: {'; '.join(r['score']['notes'])}")
        lines.append(f"  - calls: {calls}")
        if r["run"].get("final_text"):
            lines.append(f"  - said: {r['run']['final_text'][:200]!r}")
    return "\n".join(lines) + "\n"


def _retried(row: dict) -> bool:
    calls = row["run"]["calls"]
    bad = ("invalid_args", "bad_date", "error", "unknown_tool")
    return any(c["status"] in bad and any(d["tool"] == c["tool"] and d["status"] not in bad and d["step"] > c["step"]
                                         for d in calls) for c in calls)


def cmd_report(ns: argparse.Namespace) -> int:
    path = Path(ns.runs)
    meta_path = path.parent / "meta.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else None
    rows = load_rows(path)
    if ns.rescore:
        now = digests()
        if meta is None or meta.get("cases_sha") != now["cases_sha"]:
            msg = (f"cases.py changed since the run (run {meta and meta.get('cases_sha')}, now {now['cases_sha']}): "
                   "rescoring would judge old answers against new expectations")
            if not ns.allow_changed_cases:
                print(msg + "; pass --allow-changed-cases to do it anyway", file=sys.stderr)
                return 2
        known = {c["id"] for c in CASES}
        dropped = [r for r in rows if r["case"] not in known]
        rows = rescore([r for r in rows if r["case"] in known])
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
    print(render_report(rows, meta))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m mydata.feasibility")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="run the requests against models")
    r.add_argument("--models", nargs="+", default=["qwen3:14b", "gpt-oss:20b"])
    r.add_argument("--reps", type=int, default=3)
    r.add_argument("--only", nargs="*", help="case ids to run")
    r.add_argument("--out", default="results")
    r.add_argument("--stamp", help="results subdirectory name (default: current time)")
    r.add_argument("--num-ctx", type=int, default=8192)
    r.add_argument("--keep-loaded", action="store_true")
    r.set_defaults(fn=cmd_run)
    p = sub.add_parser("report", help="print the report for a runs.jsonl")
    p.add_argument("runs")
    p.add_argument("--rescore", action="store_true", help="re-score from raw runs with the current scorer")
    p.add_argument("--allow-changed-cases", action="store_true")
    p.set_defaults(fn=cmd_report)
    ns = ap.parse_args(argv)
    return ns.fn(ns)
