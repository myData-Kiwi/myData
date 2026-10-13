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

**Tokens.** Every request needs `Authorization: Bearer <token>`.
- **App tokens**, one per app (`app-tokens/mydata`, `myassistant`, `cli`), each readable only by you. They can use every route, including approving held calls. Each approval records which app decided.
- **Agent tokens**, for MCP agents (`uv run mydata agent create|list|revoke`, or from the myData app). They reach `/mcp` only, and only their hash is stored (`agents.json`).

**Accounts** (read-only mirrors). `uv run mydata account add icloud [--email EMAIL]` asks for an app-specific password (made at account.apple.com), checks it by running discovery, and only then stores it, in the macOS Keychain (service `mydata`, item `account:<id>`). `accounts.json` holds id, provider, email and date, never the password. `mydata account list`; `mydata account remove ID [--yes]` deletes the account's mirrored contacts and calendars and its Keychain item. The apps do the same through `/accounts`. While the host runs, it syncs every account at start, every 15 minutes and on "Sync now", one account at a time, backing off on errors (15 min, 30 min, 1 h, 2 h, then every 4 h). Only `PROPFIND`, `REPORT`, `OPTIONS` and `GET` are ever sent (`sources/dav/client.py`).

**Demo and real mode** (`service/modes.py`). With no account the host is in demo mode: the six fake tools over canned data, today pinned to 18 March 2026. With at least one account it is in real mode: the real date and the machine's time zone, and only `find_contact` and `list_events`, over the mirror. Mail, photos and adding events are not offered until they have a real source. `/status` reports the mode. Switching ends every conversation (their history holds the other mode's data), moves the conversation epoch on (kept in `state.json`, reported as `conversation_epoch` in `/status`) and re-warms the model. myAssistant sees the new epoch and says that a new conversation has started; a message to a conversation from an older epoch gets a `reset` event and starts a new one.

**What it serves.** Only `127.0.0.1`, port 47821 by default.
- `GET /status`: version, model state and download progress.
- `POST /assistant/messages`: one message, with the reply streamed as server-sent events.
- `GET /approvals`, `GET /approvals/{id}`, `POST /approvals/{id}`: approvals.
- `GET /tools`: the tool registry.
- `/mcp`: MCP over Streamable HTTP, on the same tool registry and the same gate.
- `GET /agents`, `POST /agents`, `DELETE /agents/{id}`: agent tokens.
- `POST /model/retry`: try again to get the model ready.
- `GET /accounts`, `POST /accounts`, `DELETE /accounts/{id}`, `POST /accounts/{id}/sync`: linked accounts. The password is accepted when adding, verified first, and never returned.
- `GET /sync`: the mode and each account's sync status.
- `GET /contacts?query=&limit=&offset=`, `GET /contacts/{id}` (`?raw=1` adds the vCard), `GET /calendars`, `GET /events?start=&end=&calendar=`: the mirror, with recurring events expanded.

`openapi.json` is generated from the app (`uv run mydata openapi --out openapi.json`). A test fails if it goes stale.

**Where its files live.** One per-user folder; `MYDATA_HOME` overrides it.
- macOS: `~/Library/Application Support/myData`
- Linux: `~/.local/share/mydata`
- Windows: `%APPDATA%\myData`

It holds `config.toml`, `app-tokens/`, `agents.json`, `accounts.json`, `contacts.sqlite`, `calendar.sqlite`, `mydatad.pid`, and `logs/`. With an account linked, the mirror and the logs hold real personal data: the host refuses a folder inside the source checkout, `.gitignore` keeps these files out of git anyway, and the feasibility harness refuses to write `results/` from anything but the demo registry. `logs/` holds:
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
