`qwen3:14b`, set 2026-10-11-b, the 10 single-tool requests × 3. Seconds, median / worst.

| Configuration | Time to result on screen | Time to end of reply | Model calls (median) | Reply written by code |
|---|---|---|---|---|
| Before: model writes every reply, nothing shown until it ends | 13.4 / 35.7 | 13.4 / 35.7 | 2 | 0/30 |
| Result shown at once, model still writes the reply ("full") | 3.2 / 5.9 | 13.4 / 35.7 | 2 | 0/30 |
| After, code rule decides ("rule") | 3.5 / 5.9 | 7.0 / 8.2 | 2 | 30/30 |
| After, tool-choice field decides ("field") | 4.8 / 6.6 | 4.9 / 38.5 | 1 | 18/30 |

Runs where no result was shown (no read tool succeeded) count their end of reply as the time to result.
