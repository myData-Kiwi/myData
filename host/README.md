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
- **App tokens**, one per app (`app-tokens/mydata`, `myassistant`, `mycontacts`, `mycalendar`, `cli`), each readable only by you. `mydata`, `myassistant` and `cli` can use every route, including approving held calls; only `mydata` and `cli` may stop the host (`/shutdown`). Each approval records which app decided. `mycontacts` and `mycalendar` only read: any request but GET from them gets 403, `/mcp` included.
- **Agent tokens**, for MCP agents (`uv run mydata agent create|list|revoke`, or from the myData app). They reach `/mcp` only, and only their hash is stored (`agents.json`).

**Accounts** (read-only mirrors). `uv run mydata account add icloud [--email EMAIL]` asks for an app-specific password (made at account.apple.com), checks it by running discovery, and only then stores it, in the macOS Keychain (service `mydata`, item `account:<id>`). `accounts.json` holds id, provider, email and date, never the password. `mydata account list`; `mydata account remove ID [--yes]` deletes the account's mirrored contacts and calendars and its Keychain item. The apps do the same through `/accounts`. While the host runs, it syncs every account at start, every 15 minutes and on "Sync now", one account at a time, backing off on errors (15 min, 30 min, 1 h, 2 h, then every 4 h). Only `PROPFIND`, `REPORT`, `OPTIONS` and `GET` are ever sent (`sources/dav/client.py`).

**Demo and real mode** (`service/modes.py`). With no account the host is in demo mode: the six fake tools over canned data, today pinned to 18 March 2026. With at least one account it is in real mode: the real date and the machine's time zone, and only `find_contact` and `list_events`, over the mirror. Mail, photos and adding events are not offered until they have a real source. `/status` reports the mode. Switching ends every conversation (their history holds the other mode's data), moves the conversation epoch on (kept in `state.json`, reported as `conversation_epoch` in `/status`) and re-warms the model. myAssistant sees the new epoch and says that a new conversation has started; a message to a conversation from an older epoch gets a `reset` event and starts a new one.

**What it serves.** Only `127.0.0.1`, port 47821 by default.
- `GET /status`: version, model state and download progress, and `backup`: the newest snapshot, the last restore drill and whether FileVault is on.
- `POST /assistant/messages`: one message, with the reply streamed as server-sent events. A `result` event says its `mode` ("real" or "demo"); a contact item carries its `id` and an event item its day (`date`), so myAssistant can open a real one in myContacts or myCalendar.
- `GET /approvals`, `GET /approvals/{id}`, `POST /approvals/{id}`: approvals.
- `GET /tools`: the tool registry.
- `/mcp`: MCP over Streamable HTTP, on the same tool registry and the same gate.
- `GET /agents`, `POST /agents`, `DELETE /agents/{id}`: agent tokens.
- `POST /model/retry`: try again to get the model ready.
- `GET /accounts`, `POST /accounts`, `DELETE /accounts/{id}`, `POST /accounts/{id}/sync`: linked accounts. The password is accepted when adding, verified first, and never returned.
- `GET /sync`: the mode and each account's sync status.
- `GET /sources`: This Mac (on a Mac host) and each followed iCloud account, with `counts` of what each holds (This Mac's while it is on; an iCloud account's as of its last sync).
- `GET /contacts?query=&limit=&offset=`, `GET /contacts/{id}` (`?raw=1` adds the vCard), `GET /calendars`, `GET /events?start=&end=&calendar=`: the mirror, with recurring events expanded. What the apps show is worked out here, once (`sources/views.py`, following `design/components`): each contact's `sort_letter` and `caption` for the list; on a contact, `source_label` ("this Mac", "the iCloud account …"), `job_title`, `urls` and `fields` grouped by kind (phone, email, address, birthday, url, note; notes never for This Mac) with labels in sentence case; each calendar's `source`, `source_label` ("This Mac", "iCloud account …") and, under This Mac, `account_caption` (the Mac's account name, or "Only on this Mac", "Birthdays from Contacts", "Subscribed").

`openapi.json` is generated from the app (`uv run mydata openapi --out openapi.json`). A test fails if it goes stale.

**Where its files live.** One per-user folder; `MYDATA_HOME` overrides it.
- macOS: `~/Library/Application Support/myData`
- Linux: `~/.local/share/mydata`
- Windows: `%APPDATA%\myData`

It holds `config.toml`, `app-tokens/`, `agents.json`, `accounts.json`, `contacts.sqlite`, `calendar.sqlite`, `backups/`, `mydatad.pid`, and `logs/`. With an account linked, the mirror and the logs hold real personal data: the host refuses a folder inside the source checkout, `.gitignore` keeps these files out of git anyway, and the feasibility harness refuses to write `results/` from anything but the demo registry. `logs/` holds:
- `mydatad.log`: structured JSON lines.
- `assistant.jsonl`: every assistant request.
- `ollama.log`: Ollama's output, if the host started Ollama.

**Backups** (`service/backup.py`). A snapshot is a consistent copy of every `*.sqlite` in the host folder, in `backups/<UTC time>/` with a `manifest.json` (sha256, size, schema version and row counts per file). Each copy must pass `integrity_check`. Files are copied one by one: a database that cannot be copied is listed in the manifest as left out (`failed`), the others are still kept, and `/status` shows the error until a snapshot holds it again.
- The host takes one every hour while it runs (skipped when nothing changed) and always before a migration. If the file to be migrated cannot be copied, the store is not migrated or opened, and `/status` shows the error. The host still starts: routes that need that store answer 503 with the message, and the assistant's tools that read it fail.
- Kept: the newest of each of the last 24 hours, 30 days and 12 months that have one, and every snapshot taken before a restore or by hand for at least 90 days; of those taken before a migration, the newest 3 for each file and version for 90 days. A migration that fails is rolled back, `/status` names the snapshot taken before it, and retrying it takes no new snapshot while the file is unchanged.
- `uv run mydata backup now|list`; `mydata backup verify [SNAPSHOT]` is the restore drill: it restores the snapshot into a temporary folder, opens it with this code (migrations included), runs the integrity, foreign key and search index checks and compares row counts. `mydata backup restore SNAPSHOT` needs the host stopped and snapshots the current state first; a database too damaged to copy is kept byte for byte in that snapshot's `damaged/` folder, so damage never blocks a restore.
- `uv run mydata export --out DIR` writes the stored vCards (one `.vcf` per address book) and iCalendar text (one `.ics` per calendar), to a new or empty folder outside the checkout. This Mac's events are not exported: the host holds only their expanded occurrences.

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
