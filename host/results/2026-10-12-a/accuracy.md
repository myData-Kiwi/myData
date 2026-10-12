Set 2026-10-11-b, `qwen3:14b`, kept configuration (a + c), 3 reps. Failures per run: each run's report.md.

| Run | Overall (strict) | Overall (outcome) | Chains (strict) | Chains (outcome) | Single tool, clear | Arguments need care | Ambiguous | No tool needed | No suitable tool | Median s to 1st tool call | Median s to final answer | Worst s to final answer |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kept a+c (before) | 67% / 68% · 26/40 / 27/40 | 68% · 27/40 | 26% · 4/15 | 26% · 4/15 | 100% · 10/10 | 66% · 3/5 | 100% · 4/4 | 100% · 3/3 | 88% / 100% · 2/3 / 3/3 | 3.4 | 12.4 | 39.5 |
| followup field | 63% · 25/40 | 65% · 26/40 | 28% · 4/15 | 35% · 5/15 | 90% · 9/10 | 80% · 4/5 | 75% · 3/4 | 100% · 3/3 | 66% · 2/3 | 4.6 | 10.5 | 51.5 |
| followup rule | 68% / 69% · 26/40 / 27/40 | 69% · 27/40 | 24% · 3/15 | 24% · 3/15 | 100% · 10/10 | 80% · 4/5 | 100% · 4/4 | 100% · 3/3 | 88% / 100% · 2/3 / 3/3 | 3.5 | 6.9 | 71.3 |

Each cell: share of runs fully correct · requests passed on all reps. Where the hand-reviewed number differs from the raw automated one, both are shown as raw / hand-reviewed. Strict counts every call; outcome ignores rejected calls the model then corrected (see a run's report.md).
