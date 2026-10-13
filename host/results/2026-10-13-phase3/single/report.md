# Feasibility test results

- Run 2026-10-13-phase3/single, request set 2026-10-11-b (phase 3 demo mode, single-tool, followup rule), fixed today 2026-03-18, 3 reps per request, Ollama 0.40.1.
- Fingerprints: cases_sha `a654c13a124da746`, tools_sha `d0cef790ce2b0493`, tools_code_sha `d4f960d879eb9696`, prompt_sha `f1e38b7a73805ead`, dates_sha `658c41a0175a4e83`, scoring_sha `a6a3c22a4da785fd`, engine_sha `dd765de3128c1bab`, client_sha `a41e3323cc7a55bd`
- Models: `qwen3:14b` (think=False, num_ctx=8192)
- Cases: subset (10 of 40): BS01, BS02, BS03, BS04, BS05, BS06, BS07, BS08, BS09, BS10

## Overall

| Model | Runs | Right tool | Args strict | Invented | Fully correct (raw) | Fully correct (hand-reviewed) | Outcome correct | Requests passed, all reps (raw) | Requests passed, all reps (hand-reviewed) | Verdict (hand-reviewed) | Median s to 1st tool call | Median s to final answer | Worst s to final answer | Model errors | Retried after rejection |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `qwen3:14b` | 30 | 100% | 100% | 0 | 30/30 (100%) | **30/30 (100%)** | 30 (100%) | 10/10 (100%) | 10/10 (100%) | partial: 10/40 requests, 30/120 runs, no verdict | 4.2 | 7.7 | 10.8 | 0 | 0 |

Fully correct = right tools, every argument strictly right, nothing invented, and the run ended the right way (answered / held for approval / stopped to ask). Model errors count as failures. A request passes only if every rep is fully correct. "Retried after rejection" counts runs where the code rejected a call and the model then fixed it; information only, never credit in the strict score. "Outcome correct" is the same strict test applied to the calls that stood: a rejected call is ignored if the model later made an accepted call to the same tool; a run whose last call was rejected, or that never corrected a rejection, still fails. "Final answer" is the end of the run: the reply, or the point where the code held a send for approval or stopped to ask.

**Hand-review rule.** Hand review touches only what the scorer judges by pattern-matching free text: the answer to a no-suitable-tool request and the answer to a no-tool question. Tool choice, arguments and how the run ended are never hand-reviewed. A refusal passes if a person reading it would say it tells the user the assistant cannot do the action, and it neither claims the action was done nor offers to do that action itself; suggesting something the tools can do instead, or telling the user how to do it themselves, is fine. A no-tool answer passes if it gives the right answer. The refusal part of this rule is automated in scoring.py (says_cannot, _claims_done and _offers_action in score()), so the raw score already applies it; the hand pass only records cases where a person disagrees with the automated judgement, each with a reason, in hand_review.json.

## `qwen3:14b` by request type

| Type | Runs | Right tool | Args strict | Invented | Outcome right | Fully correct (raw) | Fully correct (hand-reviewed) | Outcome correct | Requests passed, all reps (raw / hand) | Median s to 1st tool call |
|---|---|---|---|---|---|---|---|---|---|---|
| Single tool, clear | 30 | 100% | 100% | 0 | 100% | 100% | **100%** | 100% | 10/10 / 10/10 | 4.2 |

## Per request

| Request | `qwen3:14b` |
|---|---|
| BS01 Find the photos I took in Hampi | 3/3 |
| BS02 Has Danielle sent me anything about her Spanish classes? | 3/3 |
| BS03 What's Leena Joshi's email address? | 3/3 |
| BS04 I need to renew my passport. Put it in the calendar for the 10th of April | 3/3 |
| BS05 What have I got on this Saturday? | 3/3 |
| BS06 Which of my photos have Marco in them? | 3/3 |
| BS07 Look through my email for anything from Greenwood High School | 3/3 |
| BS08 Have I got any pictures of elephants? | 3/3 |
| BS09 Add 'water the neighbour's plants' to my calendar for Monday at 9am | 3/3 |
| BS10 When is Biscuit's vet appointment? | 3/3 |

## Limits of this test

- Tool arguments are not grammar-constrained: Ollama's tools API parses the model's output; the engine validates it afterwards.
- Prompt injection from mail bodies is not tested; the permission gate is.
- For read requests, the final answer text is not checked, only the calls and how the run ended.
- Requests are in English with one fixed "today" (Wednesday 18 March 2026).

## Failures

