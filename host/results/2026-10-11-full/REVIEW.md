# Feasibility test: hand review of run 2026-10-11-full

`report.md` holds the automatic scores. This file records the hand check that `report.md` asks for, and what the result means.

## Headline (fully correct, strict)

| Model | Automatic | After hand review | Brief's reading |
|---|---|---|---|
| `qwen3:14b` | 75/90 (83%) | 78/90 (87%) | 70-90%: look at the failing types |
| `qwen3:8b` | 66/90 (73%) | 67/90 (74%) | 70-90% |
| `gpt-oss:20b` (think=low) | 62/90 (68%) | 63/90 (70%) | at the 70% line |

The hand review overrules only refusal answers, which are scored by a pattern match on free text. No argument scores and no requests were changed.

Overruled to pass (correct refusals the automatic check failed):

- `qwen3:14b` U01 #1, U01 #2, U02 #1. Each says it cannot do it, then offers a search so the user can act. The "offers to do it" check fires because the action word appears in "so that you can decide which ones to delete".
- `gpt-oss:20b` U01 #2: "I don't have a tool to delete emails. If you'd like, I can help you search for the bank emails so you can manually review and delete them." Same cause.
- `qwen3:8b` U03 #1: "None of the tools can cancel an event." The refusal pattern does not cover "none of the tools can".

Left as failures after reading:

- `qwen3:14b` U03 #1: "I can help you cancel your dentist appointment, but I need more details."
- `qwen3:14b` U03 #3: "I'll need to look up your dentist appointment in your calendar. Let me check that for you."
- `gpt-oss:20b` U03 #3: "...Then I can help remove it from your calendar."

## Where it fails

| Type | qwen3:14b | gpt-oss:20b | qwen3:8b |
|---|---|---|---|
| Single tool, clear | 90% | 73% | 76% |
| Arguments need care (dates) | **100%** | 77% | 83% |
| Chained | **53%** | 53% | 13% |
| Ambiguous | 100% | 88% | 100% |
| No tool needed | 100% | 100% | 100% |
| No suitable tool (after hand review) | 78% | 22% | 100% |

1. **Dates in code works.** `qwen3:14b` passed every date case on every rep: next Friday, last two weeks, the week after next, Saturday the 4th of April, last Thursday, from 2024. None of the 4 date errors from the first manual test came back.
2. **Chained requests are the weak spot for every model.**
   - The most common failure: it searches mail for something that lives in the calendar. `qwen3:14b` did this on C02 in 3 of 3 reps; `qwen3:8b` on C01 and C02; `gpt-oss` on C01 and C02.
   - `gpt-oss:20b` twice wrote a send_mail body with invented facts, without looking anything up: "dentist appointment tomorrow at 10:30 AM" (actually 26 March, 15:30) and "lunch at 12:30 PM" (actually 1pm). The permission gate held both, so nothing was sent, but the user would have been asked to approve made-up content.
   - `qwen3:8b` put "Arjun's birthday" in the date argument (C03), and once guessed an email address in the same reply as the lookup (C05 #3).
3. **Unasked-for optional arguments.**
   - `gpt-oss:20b` and `qwen3:8b` filled `duration_minutes`, and gpt-oss also `location`, on every `create_event`: "Office cafeteria", "your home", 120 minutes. That alone is 9 failures each (S04, S10, A03 × 3).
   - `qwen3:14b` did not do this. Its one optional argument was wrong: C04 gave a flight duration of 85 minutes for 09:40 to 11:25, which is 105.
4. **No-suitable-tool.**
   - `gpt-oss:20b` usually calls a tool anyway. It searches the bank mail or lists the dentist appointment before saying it can't delete or cancel.
   - The qwen models refuse cleanly.
5. **`gpt-oss:20b` is not the upgrade.** It is faster per answer but worse than `qwen3:14b` on every type except one. The brief's "consider the larger model" option does not help on this machine.
6. **Speed is fine with thinking off.** Median time to the first tool call is 2.5 to 3.9 s; a whole request takes 8 to 12 s (median). Before, with thinking on, it was 30 to 120 s.

## Judgement calls a reader might dispute

The strict reading was kept for all of these.

- **`qwen3:14b` C03 (0/3).** It made one extra, harmless `find_contact("Arjun")` lookup before doing everything else right. If harmless extra reads were allowed, `qwen3:14b` would reach 81/90 (90%). The brief says not to count close-enough, so it stays a failure.
- **`qwen3:14b` S10 (0/3).** It looked up "plumber" as a contact, found none, and never created the event. This is a real failure.
- **`gpt-oss:20b` S02 #1.** It passed a whitespace-only date `" "`. The engine treats only `""` as missing, so the call was rejected. An engine fix would rescue it; the fix belongs in the orchestrator, not in this run's scores.

## Scorer defects found by this review

These are for the next test set; they are not applied to this run.

- The "offers to do it" check fires on refusals that suggest a manual alternative. It should look only at offers made in the first person to do the action itself.
- The refusal pattern lacks "none of the tools can".

## What this points to

Every one of these matches the architecture's rule that rules belong in code, not in the model.

1. **Per-request tool filtering**, which the brief already lists. Hiding `search_mail` when a request is about a calendar event would have prevented the most common chained failure.
2. **Grounding check in code.** Drop or flag any argument value that appears neither in the user's words nor in an earlier tool result. That covers invented location and duration, invented times in mail bodies, and the guessed address. Alternatively, remove optional fields such as `duration_minutes` from the schema and default them in code.
3. **A planner step for chained requests**, as the brief's 70-90% branch suggests. Alternatively, code-defined recipes for the common chains, such as "send person X a fact from event Y".
4. **Then a new, separately frozen request set** to measure the change. This set stays frozen.
