"""Where the time goes in a single-step request.

    python -m mydata.feasibility timing --set 2026-10-11-b --out results --stamp <name>

Runs the set's single-tool requests with the kept configuration and records, per model call, Ollama's
own counters: prompt tokens evaluated, seconds reading the prompt, output tokens, seconds generating.

Cache reuse is not reported by Ollama, so it is measured afterwards: every logged call is sent again
with a short tag at the very start of the system prompt, which defeats the prompt cache, and the
number of prompt tokens Ollama evaluates then is the call's full prompt length (minus the tag, whose
own cost is measured too). A timed call that evaluated fewer tokens than its full length reused a
cached prefix of the difference. These probe calls run after all timed runs, so they never disturb the
cache the timed runs saw.

Then the time to the final answer is split into the tool-choice call, tool execution (everything
between the two model calls: validation, grounding, the tool itself, engine overhead) and the phrasing
call.
"""

from __future__ import annotations

import json
import secrets
import statistics
import sys
import urllib.request
from pathlib import Path

from ..orchestrator.engine import SYSTEM_PROMPT, Engine
from ..orchestrator.ollama import OllamaChat
from ..tools import default_registry
from .sets import load_set, use_data

NS = 1e9


def _probe(model: OllamaChat, messages: list[dict], tools: list[dict], tag: str) -> int:
    """Prompt tokens Ollama evaluates for these messages with `tag` prepended to the system prompt."""
    msgs = [dict(m) for m in messages]
    msgs[0] = {**msgs[0], "content": tag + msgs[0]["content"]}
    payload = {"model": model.name, "messages": msgs, "tools": tools, "stream": False, "think": model.think,
               "options": {**model.options, "num_predict": 1}, "keep_alive": model.keep_alive}
    req = urllib.request.Request(model.host + "/api/chat", data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as resp:
        return int(json.loads(resp.read()).get("prompt_eval_count") or 0)


def _inputs(run: dict) -> list[list[dict]]:
    """The messages each model call of a run was sent: everything before its own reply."""
    msgs = run["messages"]
    return [msgs[:i] for i, m in enumerate(msgs) if m["role"] == "assistant"]


def run_timing(set_name: str, model_name: str, reps: int, out_dir: Path) -> dict:
    case_set = load_set(set_name)
    cases = [c for c in case_set.cases if c["type"] == "single"]
    model = OllamaChat(model_name, think=False, options={"num_ctx": 8192})
    registry = default_registry(today=lambda: case_set.today)
    tools = registry.definitions()
    rows = []
    with use_data(case_set.data):
        model.load()
        Engine(model, case_set.today, registry=registry).run("Hello")  # warm the shared prefix, untimed
        for case in cases:
            for rep in range(1, reps + 1):
                run = Engine(model, case_set.today, registry=registry).run(case["text"]).to_json()
                rows.append({"case": case["id"], "rep": rep, "run": run})
                print(f"{case['id']} #{rep} {run['seconds_total']:.1f}s, {run['model_calls']} model calls",
                      file=sys.stderr)

        # Cache probes, after every timed run. The tag's own cost: two tags of known length differ by one.
        tag_a, tag_b = f"[{secrets.token_hex(4)}] ", f"[{secrets.token_hex(4)}] [{secrets.token_hex(4)}] "
        base = [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": "Hello"}]
        tag_cost = _probe(model, base, tools, tag_b) - _probe(model, base, tools, tag_a)
        for row in rows:
            for call, msgs in zip(row["run"]["model_replies"], _inputs(row["run"])):
                full = _probe(model, msgs, tools, f"[{secrets.token_hex(4)}] ") - tag_cost
                st = call["stats"] or {}
                evaluated = int(st.get("prompt_eval_count") or 0)
                call["probe"] = {"full_prompt_tokens": full, "cached_tokens": max(0, full - evaluated),
                                 "cache_reused": evaluated < full - 2}

    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / "timing.jsonl").open("w") as fh:
        for row in rows:
            fh.write(json.dumps(row) + "\n")
    meta = {"set": set_name, "model": model_name, "reps": reps, "tag_cost_tokens": tag_cost,
            "ollama_version": model.version(), "cases": [c["id"] for c in cases]}
    (out_dir / "meta.json").write_text(json.dumps(meta, indent=2))
    report = render_timing(rows, meta)
    (out_dir / "timing.md").write_text(report)
    return {"rows": rows, "meta": meta, "report": report}


def _med(xs: list[float]) -> str:
    return f"{statistics.median(xs):.2f}" if xs else "-"


def render_timing(rows: list[dict], meta: dict) -> str:
    lines = [f"Model `{meta['model']}`, thinking off, kept configuration (tool descriptions + grounding, no routing), "
             f"set {meta['set']}, the {len(meta['cases'])} single-tool requests × {meta['reps']} reps, "
             f"Ollama {meta['ollama_version']}. Nothing else ran on the machine.", ""]

    lines += ["**Per model call** (median over runs; s = seconds)", "",
              "| Call | Runs | Prompt tokens (full) | Prompt tokens evaluated | Reused cached prefix | s reading prompt "
              "| Output tokens | s generating | s total (wall) |",
              "|---|---|---|---|---|---|---|---|---|"]
    for pos, name in ((0, "1: tool choice"), (1, "2: phrasing")):
        calls = [r["run"]["model_replies"][pos] for r in rows
                 if len(r["run"]["model_replies"]) == 2 and len(r["run"]["calls"]) == 1]
        if not calls:
            continue
        st = [c["stats"] or {} for c in calls]
        reused = sum(c["probe"]["cache_reused"] for c in calls)
        lines.append(
            f"| {name} | {len(calls)} | {_med([c['probe']['full_prompt_tokens'] for c in calls])} | "
            f"{_med([s.get('prompt_eval_count') or 0 for s in st])} | {reused}/{len(calls)} "
            f"(median {_med([c['probe']['cached_tokens'] for c in calls])} tokens) | "
            f"{_med([(s.get('prompt_eval_duration') or 0) / NS for s in st])} | "
            f"{_med([s.get('eval_count') or 0 for s in st])} | "
            f"{_med([(s.get('eval_duration') or 0) / NS for s in st])} | {_med([c['seconds'] for c in calls])} |")
    lines.append("")

    split = []
    for r in rows:
        run = r["run"]
        if len(run["model_replies"]) != 2 or len(run["calls"]) != 1:
            continue
        a, b = (c["seconds"] for c in run["model_replies"])
        total = run["seconds_total"]
        split.append((a, total - a - b, b, total))
    if split:
        tot = statistics.median(s[3] for s in split)
        lines += ["**Time to the final answer**, split (median over runs with one tool call and two model calls)", "",
                  "| Part | Median s | Share of the median total |", "|---|---|---|"]
        for i, name in enumerate(("Tool-choice call", "Tool execution (incl. validation, grounding)",
                                  "Phrasing call")):
            m = statistics.median(s[i] for s in split)
            lines.append(f"| {name} | {m:.2f} | {100 * m / tot:.0f}% |")
        lines += [f"| **Total to final answer** | **{tot:.2f}** | |", ""]
    other = [r for r in rows if len(r["run"]["model_replies"]) != 2 or len(r["run"]["calls"]) != 1]
    if other:
        lines.append("Runs left out of the split (not one tool call and two model calls): "
                     + ", ".join(f"{r['case']} #{r['rep']} ({r['run']['model_calls']} calls)" for r in other) + ".")
        lines.append("")

    lines += ["**Every run**", "", "| Run | Call | Prompt tokens evaluated / full | Cached | s reading | "
              "Output tokens | s generating | s wall |", "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        for i, c in enumerate(r["run"]["model_replies"], 1):
            s = c["stats"] or {}
            lines.append(f"| {r['case']} #{r['rep']} | {i} | {s.get('prompt_eval_count')} / "
                         f"{c['probe']['full_prompt_tokens']} | {'yes' if c['probe']['cache_reused'] else 'no'} | "
                         f"{(s.get('prompt_eval_duration') or 0) / NS:.2f} | {s.get('eval_count')} | "
                         f"{(s.get('eval_duration') or 0) / NS:.2f} | {c['seconds']:.2f} |")
    return "\n".join(lines) + "\n"
