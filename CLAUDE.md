# myData

Open-source, self-hosted personal cloud with a local assistant. All user data stays on hardware the user owns. A family of "my"-prefixed apps connects to one host that stores, syncs, indexes, and runs the models.

This file is the project's working memory. Read it before doing anything. Update it when a decision changes.

## Status

Early build. Done:
- the marketing site;
- two rounds of feasibility testing (see "Feasibility test result" and "Round 2 result");
- **the host** (phase 1): `mydatad` with the tool layer and permission gate, HTTP API, MCP, app and agent tokens;
- **the first two apps** (phase 2): myData (setup, status, settings) and myAssistant (chat), in Flutter, macOS first.

The tools still serve fake demo data, and the host's today is pinned to its date (18 March 2026). **Next:** myContacts and myCalendar with real data (CardDAV, CalDAV), replacing the fake tools; see "Build order". Chained requests are an open problem, not a blocker: the planner write-up in `host/results/2026-10-11-b-REPORT.md` is the starting point. Answer latency is in "Answer latency" below.

## Ground rules

- Non-commercial hobby project. No payments, donations, sponsorship links, or company entity. Do not add any of these to code, docs, or the website.
- Work happens on the owner's personal computer and personal GitHub account only.
- Not affiliated with MyData Global; the site footer says so. Keep that line.
- No trademark filing planned. "myData" is descriptive and crowded.
- Owner's working style: direct, concise answers. Stress-test ideas and lead with what is wrong or missing. No flattery.

## Names

| Name | What it is | Runs on |
|---|---|---|
| myData | The host (`mydatad`): stores, syncs, indexes, runs models. Also the myData app: setup, status, settings; later the dashboard and file browser | Host on macOS, Windows, Linux. App everywhere |
| myAssistant | Chat (later voice) app | Everywhere |
| myContacts, myCalendar, myMail, myPhotos | First apps | Everywhere, as clients |
| myNotes, myReminders, myFiles, myDocs, myHealth, myHome and others | Later apps | Everywhere, as clients |

Technical names: repo `mydata-kiwi/mydata`, command `mydata`, background service `mydatad`. In prose, call the host "the host".

## Existing assets

- Domain: mydata.kiwi. DNS is in Cloudflare, records set to DNS only (proxy off, on purpose).
- GitHub org: `mydata-kiwi`.
- Website repo: `mydata-kiwi/mydata-kiwi.github.io`. One `index.html`, deployed by GitHub Pages from `main`. Custom domain mydata.kiwi is verified and served over HTTPS from GitHub Pages.
- Logo: hand-drawn outlined kiwi bird with a green wash. Colours: background `#E3EFBF`, wash `#A9CC4E`, ink `#2A2018`.
- Website palette: `--bg #FCFDF7`, `--surface #FFFFFF`, `--band #E3EFBF`, `--fg #2A2018`, `--muted #655646`, `--line #D6E0BD`, `--kiwi #A9CC4E`, `--kiwi-deep #4C7814`, `--skin #6B4F35`, `--cream #FBF7EC`. Fonts: Bricolage Grotesque, Figtree, JetBrains Mono. Light theme only.
- A fuller plan document exists ("myData: architecture, technical plan, and viability check"). This file supersedes it where they differ.

## Architecture

One host per household, clients on every device.

- **Host**: a background service that outlives any window and starts at login. It must also install alone on machines with no screen (Linux mini PC, NAS, Docker). On macOS it must be a native install, because Docker on a Mac gets no GPU acceleration.
- **Clients**: talk to the host over the local network, and over Tailscale when away. Never expose the model server's port to the internet. **For now the host listens on localhost only** (127.0.0.1); phone and remote access come later as a separate, explicit design.
- **The host owns data and tools; agents are replaceable.** Every agent reaches tools through one registry, which holds the permission gate: our orchestrator, or any MCP agent at `/mcp`. An irreversible call never runs until a user approves that exact held call in an app.
- **Tokens.**
  - **App tokens:** one per app (`app-tokens/<app>` in the host's folder, readable only by the user). They can do everything, including approving, and each approval records which app decided.
  - **Agent tokens:** created and revoked with `mydata agent ...` or in the myData app, with only their hash stored. They reach `/mcp` only.
- **Apps.** The product is a family of separate apps built from shared code, not one combined app with a sidebar. Each app talks to the host only through the HTTP API, with no business logic in the app. The user opens an app and the host starts by itself.
  - Only the myData app owns the host's lifetime: it has a menu-bar icon with Open and Quit, and Quit stops the host. The host enforces this: `/shutdown` refuses other apps.
  - Other apps, such as myAssistant, can start the host but never stop it.
  - The assistant is optional: the apps work without a model.
- **No app depends on the chat.** myPhotos talks to the host directly.
- **Phones cannot host.** iOS and Android suspend background apps and lack the memory. No third-party wake word on iOS; no iMessage or phone-call control.

### Data layer

- One SQLite file per service; binary files on disk.
- Every record has a device-generated ID, created and modified timestamps, and a soft-delete marker.
- The host is the source of truth.
- Backups: Litestream for SQLite, restic for files.
- Search: SQLite FTS5 for text, sqlite-vec for embeddings. Index the data; do not train on it.
- PostgreSQL with pgvector only if multi-user support is ever needed.
- Standards over invention: IMAP for mail, CardDAV for contacts, CalDAV for calendar.

### Assistant

The language model has exactly one job: choose a tool and extract plain arguments. Everything else is ordinary code.

- **Dates**: the model outputs the phrase ("next friday"). Code resolves it to a date.
- **Permissions**, enforced in code, never by asking the model to behave:
  - read: runs freely
  - reversible write: runs, with undo
  - irreversible (send mail, delete): blocked until the user approves
- **Ambiguity**: a lookup that returns several matches makes the code ask the user.
- **Structured output**: pass a JSON schema so the model can only emit valid calls.
- **Small tool set per request**: show the model only the handful of tools relevant to the request.
- **Untrusted input**: text from mail bodies or web pages can contain instructions. Nothing read from them may trigger an irreversible tool without approval.
- **Log every request** with the tools called and the outcome. This is future test data and, much later, fine-tuning data.
- **Web search** is an optional, visible, switchable tool (`web_search`, `fetch_page`). Prefer self-hosted SearXNG. Never put private data into a query without asking.

### Photos

No language model looks at photos. Search uses CLIP embeddings for descriptions, a face model for people, and metadata filters for place and date. These models total about 1GB. Immich's defaults (`ViT-B-32__openai` for CLIP, `buffalo_l` for faces, run through ONNX Runtime) are the reference; verify current names before copying.

### Client stack

**Flutter**, one codebase for macOS, Windows, Linux, web, iOS and Android; macOS first. The Dart API client is generated from `host/openapi.json` (OpenAPI Generator) and never hand-written. Flutter has no official Liquid Glass components. The web build compiles but only explains that it needs the desktop app, until remote access exists.

### Repo layout

```
host/                 Python: mydatad, mydata command, tool layer, API, MCP, orchestrator, feasibility harness
  openapi.json        generated from the app; the Dart client is generated from it
  results/            feasibility runs and reports
app/                  Dart workspace
  packages/mydata_client     generated API client
  packages/mydata_core       host lifecycle (find, start, wait, watch), app tokens, error states
  packages/mydata_ui         design system: palette, fonts, logo, shared widgets
  packages/mydata_assistant  chat, streamed replies, progress lines, approval card
  apps/mydata                the myData app
  apps/myassistant           the myAssistant app
CLAUDE.md, README.md
```

Each later app (myContacts, myCalendar, ...) is a new `app/apps/<name>` on the same packages.

## Hardware and model findings

Measured on a 24GB Apple-silicon MacBook Air:

- A 27B model crashed the machine (about 17GB of weights plus context plus macOS exceeds 24GB).
- `qwen3:14b` fits: 10GB, 100% GPU.
- With thinking on, answers took 30 to 120 seconds. Run with `--think=false`; the shipped configuration must work without thinking.
- Default context was 4,096 tokens. Too small for multi-turn or web content; raise `num_ctx` to 8,000 to 16,000 when needed and watch memory.
- Realistic ceiling on 24GB is about 20B. `gpt-oss:20b` is the candidate above 14B.
- A 16GB machine tops out around 8B. A phone handles 3 to 4B, as an offline fallback only.

### First manual test (10 requests, tools described in text, thinking off, one shared chat)

- Right tool chosen: 9 of 10, including both chained requests.
- Fully correct, judged strictly: 3 of 10.
- Failures: 4 date errors (wrong day, wrong year), 3 rule failures (skipped a confirmation, guessed at an ambiguous name, offered to delete with no delete tool).

Conclusion: tool choice is promising; dates and rules must move into code. That finding is why the architecture above assigns them to code.

## First task: the feasibility test

Build this before anything else. Its harness becomes the first version of the orchestrator, so write it as real code, not a throwaway script.

**Setup**

- Python, calling Ollama's chat API with real tool definitions (not tools described in the prompt).
- Six fake tools that only record their arguments: `search_mail`, `send_mail`, `search_photos`, `find_contact`, `list_events`, `create_event`.
- Date arguments are natural phrases. A resolver in code converts them, given a fixed "today".
- A permission gate in code blocks `send_mail` pending approval.
- `find_contact` returns canned results, including a case with several matches.
- Thinking off. One fresh context per request.

**Requests: 30, written before looking at any model output**

| Type | Count | Example | Correct behaviour |
|---|---|---|---|
| Single tool, clear | 10 | "Show photos from Goa last December" | `search_photos` with place and the date phrase |
| Arguments need care | 6 | "What's on my calendar next Friday?" | `list_events` with the right phrase |
| Two or three steps chained | 5 | "Email Rishita the time of my dentist appointment" | `list_events`, `find_contact`, then `send_mail` (gated) |
| Ambiguous | 3 | "Message Patel about tomorrow" | `find_contact` returns several; code asks |
| No tool needed | 3 | "What's 15% of 80?" | Answer directly, no calls |
| No suitable tool | 3 | "Delete all mail from my bank" | Say it cannot; call nothing |

**Method**

- Run each request 3 times per model.
- Models: `qwen3:14b` and `gpt-oss:20b`. Optionally `qwen3:8b` to see whether a faster model matches.
- Record per run: right tool, arguments correct (strict), any invented tool or argument, seconds to first tool call.
- Print a results table per model and per request type.

**Reading the result**

- 90% or more fully correct: the local-only design works. Start building.
- 70 to 90%: look at which type fails; consider a planner step or the larger model.
- Under 70%: local-only on this hardware is not viable as planned. Options are a 48GB or larger host, or a hybrid that sends hard requests to a hosted model.

Do not count "close enough" arguments as passes, and do not rewrite requests after seeing what the model is good at.

## Feasibility test result (2026-10-11)

Full detail: `myData/results/2026-10-11-full/report.md` and `REVIEW.md`. 30 requests × 3 reps, strict scoring, fixed today Wed 18 March 2026, Ollama 0.40.1, 24GB MacBook Air.

| Model | Fully correct (after hand review of refusals) |
|---|---|
| `qwen3:14b`, think off | 78/90 (87%) |
| `qwen3:8b`, think off | 67/90 (74%) |
| `gpt-oss:20b`, think low (it cannot be turned off) | 63/90 (70%) |

- Dates in code works. `qwen3:14b` got every date case right on every rep.
- Chained requests are the weak spot (`qwen3:14b` 53%). Models search mail for calendar facts, and gpt-oss writes made-up times into emails. The permission gate held every send.
- gpt-oss:20b and qwen3:8b invent optional arguments (location, duration) on every create_event. qwen3:14b does not.
- gpt-oss:20b is worse than qwen3:14b, so "use the larger model" is not the fix on 24GB. `qwen3:14b` is the working model.
- Thinking off gives a median of 2.5 to 3.9 s to the first tool call.
- Round 2 (below) tried the code fixes for chains on a new set. Never edit the 2026-10-11 set.

## Round 2 result (2026-10-11/12)

Full report: `myData/results/2026-10-11-b-REPORT.md`. New frozen set `cases_2026_10_11_b.py`: 40 requests, 15 of them chained, its own dataset, committed before any orchestrator change. Model `qwen3:14b`, thinking off, 3 reps. Each row adds one fix.

| Row | Overall runs (requests passing all reps) | Chains runs (requests) | Median s to first tool call |
|---|---|---|---|
| baseline | 65% (26/40) | 20% (3/15) | 3.8 |
| +a tool descriptions | 70% (28/40 hand-reviewed) | 28% (4/15) | 3.9 |
| +b per-request tool filtering | 70% (28/40) | 26% (4/15) | 4.5 |
| +c grounding check | 67% (27/40) | 26% (4/15) | 4.6 |

- Chains stay far under 80%. The model treats a chain as one step: it skips the lookup and acts on a guess, passes a description ("the day of Farah's housewarming") as an argument, or reads the wrong source.
- No planner was built, as agreed for this round. The report lists what one would need to fix. Measure any planner on a new frozen set; 2026-10-11-b has now been seen.
- **Kept: (a) tool descriptions and (c) grounding.**
  - (a) gave +5 runs at no cost.
  - (c) did not raise the score. It blocked 6 sends with an invented address and dropped invented event fields before the user saw them. Its one cost was a duration worked out from two times (BA03), which it dropped; fixed in Part A (see "Answer latency").
- **Not kept: (b) per-request tool filtering.** It is off by default (`Engine.route=False`); the module stays so the measurement can be reproduced. It gained nothing, added 0.6 s, and by design hides tools that a chain needs when the wording does not name the source.
- The kept combination (a + c, without b) was not itself measured.
- Scoring: raw and hand-reviewed scores are both reported, and requests count as passing only if all reps pass. The hand-review rule for refusals is automated in `scoring.py`.
- Kept configuration (a + c, routing off), measured as a whole: 68% of runs strict after hand review (27/40 requests); chains 26% on both the strict and outcome scores (4/15). Median 12.4 s to the final answer, worst 39.5 s.
- Thinking on, chains only: strict 40% (4/15 requests), outcome 48% (6/15). Median 181 s to the final answer, worst 693 s. It fixes some lookup-skipping but often asks the user for facts it could look up; too slow to ship.
- An "outcome correct" score (ignores rejected calls the model then corrected) is now reported next to strict. Defect found: grounding read "4-9" as one token and rejected "Slides 4-9" (BC14); fixed in Part A.

## Answer latency (Part A, 2026-10-12)

Full report: `host/results/2026-10-12-a-REPORT.md`. Measured on battery, with BTLEServer using one core throughout.

- **Results are shown by code.** A read tool's result goes to the app at once as a `result` event (`{kind, header, items}`), with a one-line header written by code. Single-tool requests: result on screen median 13.4 → 3.5 s, worst 35.7 → 5.9 s; end of reply 13.4 → 7.0 s, worst 35.7 → 8.2 s.
- **A model sentence is written only when the list does not answer the question.** It is streamed, capped at about 40 tokens, and decided by a code rule (`[model] followup = "rule"`, `orchestrator/followup.py`). Tool choice is unchanged: 27/40 requests before and after.
- **Rejected: a `then` field on the tool-choice call.** It changed which tools the model chose (BS10, BM04, BU01).
- **Open defect: the rule misses sentences.** It caught 4 of the 12 needed in a blind probe set (open item 1 below).
- **Keep warm.** The model is loaded while the assistant is on, and a warm-up request caches the prompt prefix. The prefix must stay byte-identical across requests (`tests/test_prompt_prefix.py`).
- **Grounding fixes.** "4-9" is grounded by "4 to 9", and a duration between two grounded times is allowed.
- **Speed.** The M4 Air peaks at about 11 tok/s generating and about 100 tok/s reading a cold prompt. On this fanless machine, heat costs about 15% within minutes, and swap bursts caused by other apps cost about 20% more. Background CPU load does not matter. The earlier 8.5 tok/s and 25 s cold read were a hot machine after 25 to 50 minutes of continuous requests.

**Open items for the next assistant round** (agreed; not built):

1. **Follow-up sentence: flip the default.** Write the short sentence unless the request is plainly a show/list request, instead of only when a question is recognised. A missed answer is worse than an extra sentence. Measure on a new blind set of about 40 requests, written before the rule changes.
2. **Keep the input usable while the second model call runs.** Cancel that call if the user sends something new.
3. **Temperature for the tool-choice call.** Measure 0 and 0.2 against today's 0.6 on a new frozen set, reporting requests that pass on all reps.
4. **Repeat the speed check plugged in, on a quiet machine,** to separate battery from heat.

## Build order after the test passes

1. ~~Host skeleton~~: done (phase 1): service, config, logging, tool layer and gate, API, MCP, tokens.
2. ~~myData and myAssistant apps~~: done (phase 2), macOS first, against the fake tools.
3. **Next:** myContacts and myCalendar (CardDAV, CalDAV), replacing the fake contact and calendar tools with real data. Smallest data; proves sync. Each is a new app in `app/apps`; switch off the demo date once real data is in.
4. myMail (IMAP sync, FTS5 search), replacing the fake mail tools.
5. myAssistant against the real tools; revisit chained requests (planner) and the sentences the follow-up rule misses (see "Answer latency").
6. myPhotos (import, CLIP index, faces). The largest piece; expect 6 to 8 weekends.
7. Phone clients and remote access (the host is localhost-only until then).
8. Packaging: installers, a bundled host binary (the place to start it is marked in `mydata_core`), Windows and Linux builds on those systems.

## Open questions

- Licence: MIT or AGPL.
- Whether to reuse existing servers (for example Radicale for CardDAV and CalDAV) or write them.
- Where to keep the conversation history (in memory now; lost when the host restarts).
- Whether myAssistant should ask the myData app to open its Setup when myData is already running. Today `--setup` only works on a cold start of myData.
- Website: may move to a static-site generator. If so, it must build to static files for GitHub Pages and keep the `CNAME` file. Not a priority.

## Known rough edges

- The website's header animation (kiwi walks in, pecks the "M" to lower case, jumps) and the pull-to-refresh kiwi-slice loader were never visually verified end to end. Expect to tune timing and positions.
- The app icon file and the newer logo (pale green background with wash and ground line) do not match yet.
- The myData and myAssistant apps still use Flutter's default app icons; the kiwi is only in their headers and the menu-bar icon.
- Windows and Linux builds of the apps have not been made: Flutter builds them only on those systems. Their code paths compile (`flutter analyze`).