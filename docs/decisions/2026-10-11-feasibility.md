# The feasibility test: hardware findings, the test's design and its result

Moved verbatim from CLAUDE.md on 2026-10-23, when it was cut to the current rules. This is history: where it differs from CLAUDE.md or `docs/2026-10-23-plan.md`, CLAUDE.md wins.

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
