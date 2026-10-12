# myData

The host for myData: stores, syncs, indexes, and runs the models. See `CLAUDE.md` for the plan.

## Feasibility test

Can a local model pick the right tool and pass plain arguments, with dates, permissions and ambiguity handled in code?

```sh
uv sync
uv run pytest -q                                      # harness tests; no model needed
uv run python -m mydata.feasibility run               # qwen3:14b and gpt-oss:20b, 3 reps each
uv run python -m mydata.feasibility run --models qwen3:8b --only S01 A01
uv run python -m mydata.feasibility report results/<stamp>/runs.jsonl [--rescore]
uv run python -m mydata.feasibility run --set 2026-10-11-b --models qwen3:14b --label baseline
uv run python -m mydata.feasibility compare baseline=results/a/runs.jsonl +a=results/b/runs.jsonl
```

Needs Ollama running locally with the models pulled.

- `src/mydata/orchestrator/`: the first version of the orchestrator.
  - `engine.py`: the loop. The model picks tools; code validates arguments, resolves dates, gates `send_mail`, and stops to ask when a lookup is ambiguous.
  - `dates.py`: the date-phrase resolver. Its conventions are listed at the top of the file.
  - `tools.py`, `fixtures.py`: six fake tools over canned data. The fixed today is Wednesday 18 March 2026.
  - `ollama.py`: a standard-library client for `/api/chat`.
- `src/mydata/feasibility/cases.py`: the 30 requests and the strict definition of correct for each. These are frozen; add a new set rather than editing them.
- `src/mydata/feasibility/scoring.py`: the scoring. `report --rescore` re-judges the logged runs without calling a model again.
- `results/<stamp>/`: each run writes the following.
  - `runs.jsonl`: every request, with the calls made, their arguments, the outcome, timings and the full message log.
  - `meta.json`: fingerprints of the cases, tools, prompt, resolver, scorer and engine, plus the model digests.
  - `cases.frozen.py` and `report.md`.

Thinking is off for qwen3. gpt-oss cannot turn it off, so it runs at `think="low"`.
