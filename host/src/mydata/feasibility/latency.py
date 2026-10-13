"""Part A measurements: answer latency by follow-up mode, how the two decision methods do, and raw speed.

    python -m mydata.feasibility latency  --stamp NAME [--reps 3]      time to result on screen / end of reply
    python -m mydata.feasibility decide   --stamp NAME [--reps 3]      rule vs field on the labelled probes
    python -m mydata.feasibility speed    --stamp NAME [--minutes 10]  prompt-read and generation speed over time
"""

from __future__ import annotations

import json
import re
import secrets
import statistics
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

from ..orchestrator import followup as fu
from ..orchestrator.engine import SYSTEM_PROMPT, Engine, request_prefix
from ..orchestrator.ollama import OllamaChat
from ..tools import Registry
from .guard import demo_registry, ensure_demo
from .followup_probe import PROBES
from .sets import load_set, use_data

NS = 1e9


def _model(name: str) -> OllamaChat:
    return OllamaChat(name, think=False, options={"num_ctx": 8192}, keep_alive=-1)


# ---------------------------------------------------------------- latency by mode


def run_latency(set_name: str, model_name: str, reps: int, modes: list[str], out: Path,
                registry: Registry | None = None) -> str:
    if registry is not None:
        ensure_demo(registry)  # results/ never holds real data
    case_set = load_set(set_name)
    cases = [c for c in case_set.cases if c["type"] == "single"]
    model = _model(model_name)
    rows = []
    with use_data(case_set.data):
        for mode in modes:
            registry = registry or demo_registry(lambda: case_set.today)
            model.warm(*request_prefix(registry, followup=mode))  # same prefix as the runs, cached
            for case in cases:
                for rep in range(1, reps + 1):
                    run = Engine(model, case_set.today, registry=registry, followup=mode).run(case["text"]).to_json()
                    rows.append({"mode": mode, "case": case["id"], "rep": rep, "run": run})
                    print(f"{mode:5} {case['id']} #{rep} result {run['seconds_to_result']} end {run['seconds_total']:.1f}s "
                          f"by {run['reply_by']} calls {run['model_calls']}", file=sys.stderr)
    out.mkdir(parents=True, exist_ok=True)
    with (out / "latency.jsonl").open("w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
    report = render_latency(rows, model_name, set_name, reps)
    (out / "latency.md").write_text(report)
    return report


def _ms(xs: list[float]) -> str:
    return f"{statistics.median(xs):.1f} / {max(xs):.1f}" if xs else "-"


def render_latency(rows: list[dict], model: str, set_name: str, reps: int) -> str:
    lines = [f"`{model}`, set {set_name}, the 10 single-tool requests × {reps}. Seconds, median / worst.", "",
             "| Configuration | Time to result on screen | Time to end of reply | Model calls (median) "
             "| Reply written by code |", "|---|---|---|---|---|"]
    full = [r["run"] for r in rows if r["mode"] == "full"]
    if full:
        # Before: the app showed nothing until the model's reply was complete.
        lines.append(f"| Before: model writes every reply, nothing shown until it ends | "
                     f"{_ms([r['seconds_total'] for r in full])} | {_ms([r['seconds_total'] for r in full])} | "
                     f"{statistics.median(r['model_calls'] for r in full):.0f} | 0/{len(full)} |")
        lines.append(f"| Result shown at once, model still writes the reply (\"full\") | "
                     f"{_ms([r['seconds_to_result'] or r['seconds_total'] for r in full])} | "
                     f"{_ms([r['seconds_total'] for r in full])} | "
                     f"{statistics.median(r['model_calls'] for r in full):.0f} | "
                     f"{sum(r['reply_by'] == 'code' for r in full)}/{len(full)} |")
    for mode, label in (("rule", "After, code rule decides (\"rule\")"), ("field", "After, tool-choice field decides (\"field\")")):
        rs = [r["run"] for r in rows if r["mode"] == mode]
        if rs:
            lines.append(f"| {label} | {_ms([r['seconds_to_result'] or r['seconds_total'] for r in rs])} | "
                         f"{_ms([r['seconds_total'] for r in rs])} | "
                         f"{statistics.median(r['model_calls'] for r in rs):.0f} | "
                         f"{sum(r['reply_by'] == 'code' for r in rs)}/{len(rs)} |")
    lines += ["", "Runs where no result was shown (no read tool succeeded) count their end of reply as the time to "
                  "result."]
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- decision accuracy


def run_decide(set_name: str, model_name: str, reps: int, out: Path, registry: Registry | None = None) -> str:
    """Score the code rule (no model) and the field (the tool-choice call only) on the labelled probes."""
    if registry is not None:
        ensure_demo(registry)
    case_set = load_set(set_name)
    model = _model(model_name)
    registry = registry or demo_registry(lambda: case_set.today)
    system, tools = request_prefix(registry, followup="field")
    rows = []
    with use_data(case_set.data):
        model.warm(system, tools)
        for text, needs in PROBES:
            rule = fu.sentence_needed(text)
            for rep in range(1, reps + 1):
                reply = model.chat([system, {"role": "user", "content": text}], tools)
                thens = [((c.get("function") or {}).get("arguments") or {}).get(fu.THEN) for c in reply["tool_calls"]]
                then = thens[0] if thens else None
                rows.append({"text": text, "needs": needs, "rule": rule, "rep": rep, "then": then,
                             "tools": [(c.get("function") or {}).get("name") for c in reply["tool_calls"]]})
                print(f"{needs!s:5} rule={rule!s:5} then={then} {text}", file=sys.stderr)
    out.mkdir(parents=True, exist_ok=True)
    (out / "decide.json").write_text(json.dumps(rows, indent=1))
    report = render_decide(rows)
    (out / "decide.md").write_text(report)
    return report


def render_decide(rows: list[dict]) -> str:
    per_text = {r["text"]: r for r in rows}
    rule_ok = sum(r["rule"] == r["needs"] for r in per_text.values())
    field = [r for r in rows]
    decided = [r for r in field if r["then"] in ("show", "answer")]
    field_ok = sum((r["then"] == "answer") == r["needs"] for r in decided)
    needs = sum(r["needs"] for r in per_text.values())
    lines = [f"{len(per_text)} labelled requests ({len(per_text) - needs} answered by the list, {needs} needing a "
             f"sentence), written blind to both methods.", "",
             "| Method | Correct | Wrong | Undecided |", "|---|---|---|---|",
             f"| Code rule | {rule_ok}/{len(per_text)} | {len(per_text) - rule_ok} | 0 |",
             f"| `then` field (all reps) | {field_ok}/{len(field)} | {len(decided) - field_ok} | "
             f"{len(field) - len(decided)} (said continue, left it out, or called no tool) |", "",
             "| Request | Needs a sentence | Rule | `then` per rep |", "|---|---|---|---|"]
    for text in per_text:
        reps = [r["then"] or "—" for r in rows if r["text"] == text]
        r = per_text[text]
        lines.append(f"| {text} | {'yes' if r['needs'] else 'no'} | {'answer' if r['rule'] else 'show'} | "
                     f"{', '.join(reps)} |")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- raw speed


def _sh(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception as e:  # tool missing on this OS
        return f"({cmd[0]}: {e})"


def _vm() -> dict:
    out = {}
    for line in _sh(["vm_stat"]).splitlines():
        m = re.match(r"(Pageins|Pageouts|Swapins|Swapouts):\s+(\d+)", line)
        if m:
            out[m.group(1).lower()] = int(m.group(2))
    return out


def _temps() -> dict:
    """Battery and system temperatures in °C (macOS AppleSmartBattery): a heat proxy without admin rights."""
    out = {}
    for key in ("Temperature", "VirtualTemperature"):
        m = re.search(rf'"{key}" = (\d+)', _sh(["ioreg", "-rn", "AppleSmartBattery"]))
        if m:
            out["battery_c" if key == "Temperature" else "system_c"] = int(m.group(1)) / 100
    return out


def environment() -> dict:
    mp = _sh(["memory_pressure", "-Q"])
    free = re.search(r"free percentage: (\d+)%", mp)
    return {
        "vm": _vm(),
        "temps": _temps(),
        "memorystatus_level": _sh(["sysctl", "-n", "kern.memorystatus_level"]),
        "at": time.strftime("%H:%M:%S"),
        "power": _sh(["pmset", "-g", "batt"]).splitlines()[0:2],
        "thermal": _sh(["pmset", "-g", "therm"]),
        "memory_free_percent": int(free.group(1)) if free else None,
        "swap": _sh(["sysctl", "-n", "vm.swapusage"]),
        "load": _sh(["sysctl", "-n", "vm.loadavg"]),
        "ollama_ps": _sh(["ollama", "ps"]),
        "top": _sh(["ps", "-Ao", "pcpu,comm", "-r"]).splitlines()[1:6],
    }


def _post(model: OllamaChat, payload: dict) -> dict:
    req = urllib.request.Request(model.host + "/api/chat", data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as resp:
        return json.loads(resp.read())


def _probe(model: OllamaChat, system: dict, tools: list[dict], cached: bool, generate: int, tag: str) -> dict:
    """One request with `tag` at the start of the system prompt, then `generate` tokens. The first request
    with a new tag reads the whole prompt (cold); repeating it reads it from the cache (warm)."""
    sys_msg = {**system, "content": tag + system["content"]}
    body = _post(model, {"model": model.name, "think": False, "stream": False, "keep_alive": -1, "tools": tools,
                         "options": {**model.options, "num_predict": generate, "temperature": 0},
                         "messages": [sys_msg, {"role": "user", "content":
                                                "Without using any tool, write the numbers from one to two hundred "
                                                "in words, separated by commas."}]})
    pc, pd = body.get("prompt_eval_count") or 0, (body.get("prompt_eval_duration") or 0) / NS
    ec, ed = body.get("eval_count") or 0, (body.get("eval_duration") or 0) / NS
    return {"cached": cached, "prompt_tokens": pc, "prompt_s": round(pd, 2),
            "prompt_tok_s": round(pc / pd, 1) if pd else None, "gen_tokens": ec, "gen_s": round(ed, 2),
            "gen_tok_s": round(ec / ed, 1) if ed else None, "load_s": round((body.get("load_duration") or 0) / NS, 2)}


def run_speed(set_name: str, model_name: str, minutes: float, out: Path, registry: Registry | None = None) -> str:
    if registry is not None:
        ensure_demo(registry)
    case_set = load_set(set_name)
    model = _model(model_name)
    registry = registry or demo_registry(lambda: case_set.today)
    system, tools = request_prefix(registry, followup="rule")
    singles = [c["text"] for c in case_set.cases if c["type"] == "single"]
    log: dict = {"model": model_name, "minutes": minutes, "phases": []}

    def phase(name: str) -> None:
        env = environment()
        _post(model, {"model": model.name, "messages": [], "keep_alive": 0})  # unload: the next read is cold
        time.sleep(2)
        tag = f"[{secrets.token_hex(4)}] "
        cold = _probe(model, system, tools, cached=False, generate=128, tag=tag)
        warm = _probe(model, system, tools, cached=True, generate=128, tag=tag)
        log["phases"].append({"name": name, "env": env, "cold_load": cold, "warm": warm,
                              "env_after": environment()})
        print(f"{name}: cold prompt {cold['prompt_tok_s']} tok/s (load {cold['load_s']} s), "
              f"warm gen {warm['gen_tok_s']} tok/s", file=sys.stderr)

    with use_data(case_set.data):
        phase("start")
        samples, deadline, i = [], time.time() + minutes * 60, 0
        next_env = time.time()
        while time.time() < deadline:
            run = Engine(model, case_set.today, registry=registry, followup="full").run(singles[i % len(singles)])
            i += 1
            for c in run.model_replies:
                st = c["stats"] or {}
                if st.get("eval_duration"):
                    samples.append({"t": round(time.time() - (deadline - minutes * 60), 1),
                                    "gen_tok_s": round(st["eval_count"] / (st["eval_duration"] / NS), 1),
                                    "prompt_s": round((st.get("prompt_eval_duration") or 0) / NS, 2)})
            if time.time() >= next_env:
                samples.append({"t": round(time.time() - (deadline - minutes * 60), 1), "env": environment()})
                next_env += 60
        log["continuous"] = samples
        phase(f"after {minutes:g} minutes")
    out.mkdir(parents=True, exist_ok=True)
    (out / "speed.json").write_text(json.dumps(log, indent=1))
    report = render_speed(log)
    (out / "speed.md").write_text(report)
    return report


def _power(env: dict) -> str:
    """"AC" or "battery 28%" from `pmset -g batt`; "-" when the run did not record it."""
    lines = env.get("power") or []
    if not lines:
        return "-"
    if "AC Power" in lines[0]:
        return "AC"
    pct = re.search(r"(\d+)%", " ".join(lines))
    return f"battery {pct.group(1)}%" if pct else "battery"


def render_speed(log: dict) -> str:
    lines = [f"`{log['model']}`. Cold = model just loaded and prompt not cached; warm = loaded, prefix cached. "
             f"Generation speed from a 128-token answer.", "",
             "| When | Load s | Cold prompt read tok/s | Warm prompt read s | Generation tok/s (warm) | "
             "Memory free | Swap used | Pages out / swapped out during the phase | Battery / system °C | Load avg | Power |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for p in log["phases"]:
        e, c, w, a = p["env"], p["cold_load"], p["warm"], p.get("env_after", p["env"])
        dv = {k: a.get("vm", {}).get(k, 0) - e.get("vm", {}).get(k, 0) for k in ("pageouts", "swapouts")}
        t = e.get("temps", {})
        swap = re.search(r"used = ([\d.]+)M", e["swap"])
        lines.append(f"| {p['name']} | {c['load_s']} | {c['prompt_tok_s']} ({c['prompt_tokens']} tokens in "
                     f"{c['prompt_s']} s) | {w['prompt_s']} | {w['gen_tok_s']} | {e['memory_free_percent']}% | "
                     f"{float(swap.group(1)) / 1024:.1f} GB | {dv['pageouts']} / {dv['swapouts']} | "
                     f"{t.get('battery_c', '-')} / {t.get('system_c', '-')} | {e['load']} | {_power(e)} |" if swap else
                     f"| {p['name']} | {c['load_s']} | {c['prompt_tok_s']} | {w['prompt_s']} | {w['gen_tok_s']} | "
                     f"{e['memory_free_percent']}% | {e['swap']} | | | {e['load']} | {_power(e)} |")
    gen = [s for s in log.get("continuous", []) if "gen_tok_s" in s]
    if gen:
        n = len(gen)
        first, last = gen[: max(1, n // 5)], gen[-max(1, n // 5):]
        lines += ["", f"During {log['minutes']:g} minutes of continuous requests ({n} model calls): generation "
                      f"{statistics.median(s['gen_tok_s'] for s in first):.1f} tok/s (first fifth) → "
                      f"{statistics.median(s['gen_tok_s'] for s in last):.1f} tok/s (last fifth); "
                      f"all calls {min(s['gen_tok_s'] for s in gen):.1f}–{max(s['gen_tok_s'] for s in gen):.1f}."]
    envs = [s["env"] for s in log.get("continuous", []) if "env" in s]
    if envs:
        lines += ["", "| Minute | Memory free | Pages out / swapped out since the last minute | Battery / system °C "
                      "| Busiest processes |", "|---|---|---|---|---|"]
        prev = None
        for k, e in enumerate(envs):
            vm, t = e.get("vm", {}), e.get("temps", {})
            delta = (f"{vm.get('pageouts', 0) - prev.get('pageouts', 0)} / {vm.get('swapouts', 0) - prev.get('swapouts', 0)}"
                     if prev else "-")
            prev = vm
            lines.append(f"| {k} | {e['memory_free_percent']}% | {delta} | {t.get('battery_c', '-')} / "
                         f"{t.get('system_c', '-')} | {'; '.join(x.strip() for x in e['top'][:3])} |")
    return "\n".join(lines) + "\n"
