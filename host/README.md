# myData host

The host stores, syncs, indexes and runs the models. It is the background service `mydatad`, and the `mydata` command controls it. Apps and agents talk to it only through its HTTP API, or through MCP for agents.

```sh
uv sync
uv run mydata start      # start mydatad in the background; it starts Ollama and pulls the model if needed
uv run mydata status     # host version and model state
uv run mydata stop
uv run mydata run        # foreground, for development
uv run pytest -q         # all tests; no model needed
```

**What it serves.** Only `127.0.0.1`, port 47821 by default. Every request needs `Authorization: Bearer <token>`.
- `GET /status`: version, model state and download progress.
- `POST /assistant/messages`: one message, with the reply streamed as server-sent events.
- `GET /approvals`, `GET /approvals/{id}`, `POST /approvals/{id}`: approvals.
- `GET /tools`: the tool registry.
- `/mcp`: MCP over Streamable HTTP, on the same tool registry and the same gate.

`openapi.json` is generated from the app (`uv run mydata openapi --out openapi.json`). A test fails if it goes stale.

**Where its files live.** One per-user folder; `MYDATA_HOME` overrides it.
- macOS: `~/Library/Application Support/myData`
- Linux: `~/.local/share/mydata`
- Windows: `%APPDATA%\myData`

It holds `config.toml`, `token` (readable only by you), `mydatad.pid`, and `logs/`:
- `mydatad.log`: structured JSON lines.
- `assistant.jsonl`: every assistant request.
- `ollama.log`: Ollama's output, if the host started Ollama.

**The permission gate** (`src/mydata/tools/registry.py`). Every agent reaches tools only through the registry: our assistant, MCP clients, anything else.
- Read tools run.
- Reversible tools run and record their undo.
- Irreversible tools (`send_mail`) are held under an approval id. They run only when the user approves that exact held call, through `POST /approvals/{id}`, and only once.

## Feasibility test

Can a local model pick the right tool and pass plain arguments, with dates, permissions and ambiguity handled in code?

```sh
uv run python -m mydata.feasibility run               # qwen3:14b and gpt-oss:20b, 3 reps each
uv run python -m mydata.feasibility run --models qwen3:8b --only S01 A01
uv run python -m mydata.feasibility report results/<stamp>/runs.jsonl [--rescore]
uv run python -m mydata.feasibility run --set 2026-10-11-b --models qwen3:14b --label baseline
uv run python -m mydata.feasibility compare baseline=results/a/runs.jsonl +a=results/b/runs.jsonl
```

Needs Ollama running locally with the models pulled.

- `src/mydata/tools/`: the tool layer.
  - `registry.py`: the registry and the permission gate.
  - `builtin.py`: the six tools, fakes over canned data in `orchestrator/fixtures.py`. The harness's fixed today is Wednesday 18 March 2026.
  - `dates.py`: the date-phrase resolver. Its conventions are listed at the top of the file.
- `src/mydata/orchestrator/`: our own agent, a client of the tool layer.
  - `engine.py`: the loop. The model picks tools; the tool layer validates them, resolves dates and gates `send_mail`; the engine adds the grounding check and stops to ask when a lookup is ambiguous.
  - `ollama.py`: a standard-library client for `/api/chat`, with streaming.
- `src/mydata/feasibility/cases.py`: the 30 requests and the strict definition of correct for each. These are frozen; add a new set rather than editing them.
- `src/mydata/feasibility/scoring.py`: the scoring. `report --rescore` re-judges the logged runs without calling a model again.
- `results/<stamp>/`: each run writes the following.
  - `runs.jsonl`: every request, with the calls made, their arguments, the outcome, timings and the full message log.
  - `meta.json`: fingerprints of the cases, tools, prompt, resolver, scorer and engine, plus the model digests.
  - `cases.frozen.py` and `report.md`.

Thinking is off for qwen3. gpt-oss cannot turn it off, so it runs at `think="low"`.
