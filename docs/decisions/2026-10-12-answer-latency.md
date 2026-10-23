# Answer latency (Part A)

Moved verbatim from CLAUDE.md on 2026-10-23, when it was cut to the current rules. This is history: where it differs from CLAUDE.md or `docs/2026-10-23-plan.md`, CLAUDE.md wins.

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
