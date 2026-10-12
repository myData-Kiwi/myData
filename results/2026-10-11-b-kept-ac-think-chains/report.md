# Feasibility test results

- Run 2026-10-11-b-kept-ac-think-chains, request set 2026-10-11-b (a+c kept, think on, chains only), fixed today 2026-03-18, 3 reps per request, Ollama 0.40.1.
- Fingerprints: cases_sha `a654c13a124da746`, tools_sha `d0cef790ce2b0493`, tools_code_sha `884be9233d285ccf`, prompt_sha `f1e38b7a73805ead`, dates_sha `5ab197fda1944fe0`, scoring_sha `4e69b73a3cd6f7d6`, engine_sha `f2c1ce3627dc591a`, client_sha `e2ab4c5267dbc948`
- Models: `qwen3:14b` (think=True, num_ctx=8192)
- Caveat: thinking could not be turned off for `qwen3:14b` (used think=True).
- Cases: subset (15 of 40): BC01, BC02, BC03, BC04, BC05, BC06, BC07, BC08, BC09, BC10, BC11, BC15, BC12, BC13, BC14

## Overall

| Model | Runs | Right tool | Args strict | Invented | Fully correct (raw) | Fully correct (hand-reviewed) | Outcome correct | Requests passed, all reps (raw) | Requests passed, all reps (hand-reviewed) | Verdict (hand-reviewed) | Median s to 1st tool call | Median s to final answer | Worst s to final answer | Model errors | Retried after rejection |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `qwen3:14b` | 45 | 55% | 40% | 0 | 18/45 (40%) | **18/45 (40%)** | 22 (48%) | 4/15 (26%) | 4/15 (26%) | partial: 15/40 requests, 45/120 runs, no verdict | 92.7 | 181.2 | 692.6 | 0 | 4 |

Fully correct = right tools, every argument strictly right, nothing invented, and the run ended the right way (answered / held for approval / stopped to ask). Model errors count as failures. A request passes only if every rep is fully correct. "Retried after rejection" counts runs where the code rejected a call and the model then fixed it; information only, never credit in the strict score. "Outcome correct" is the same strict test applied to the calls that stood: a rejected call is ignored if the model later made an accepted call to the same tool; a run whose last call was rejected, or that never corrected a rejection, still fails. "Final answer" is the end of the run: the reply, or the point where the code held a send for approval or stopped to ask.

**Hand-review rule.** Hand review touches only what the scorer judges by pattern-matching free text: the answer to a no-suitable-tool request and the answer to a no-tool question. Tool choice, arguments and how the run ended are never hand-reviewed. A refusal passes if a person reading it would say it tells the user the assistant cannot do the action, and it neither claims the action was done nor offers to do that action itself; suggesting something the tools can do instead, or telling the user how to do it themselves, is fine. A no-tool answer passes if it gives the right answer. The refusal part of this rule is automated in scoring.py (says_cannot, _claims_done and _offers_action in score()), so the raw score already applies it; the hand pass only records cases where a person disagrees with the automated judgement, each with a reason, in hand_review.json.

## `qwen3:14b` by request type

| Type | Runs | Right tool | Args strict | Invented | Outcome right | Fully correct (raw) | Fully correct (hand-reviewed) | Outcome correct | Requests passed, all reps (raw / hand) | Median s to 1st tool call |
|---|---|---|---|---|---|---|---|---|---|---|
| Two or three steps chained | 45 | 55% | 40% | 0 | 80% | 40% | **40%** | 48% | 4/15 / 4/15 | 92.7 |

## Per request

| Request | `qwen3:14b` |
|---|---|
| BC01 Show me the photos from the day of Ollie's birthday drinks last month | 0/3 |
| BC02 Email Hannah to say I'd like to start our 1:1 thirty minutes later than planned, and give her the new start time | 1/3 |
| BC03 Put another physio session in my calendar for Tuesday the 31st, at the same time as my next one | 3/3 |
| BC04 Block out 10am on the day of Farah's housewarming so I can pick up a present | 3/3 |
| BC05 Pull up any emails from the person I'm meeting tomorrow afternoon | 0/3 |
| BC06 Ollie is taking Biscuit to the vet for me. Email him the clinic's address and when the appointment is | 2/3 |
| BC07 Add the Indigo Lanterns gig I bought tickets for to my calendar | 1/3 |
| BC08 Danielle says Spanish classes are starting again. If I'm free that evening, put the first class in my calendar | 0/3 |
| BC09 Marco needs the booking reference for our Mysuru train. Email it to him | 3/3 |
| BC10 Leena has moved. Send Ollie her new address, he's posting her a card | 0/3 |
| BC11 Vikram Menon sent round the plan for his safari. Show me my photos from that day | 0/3 |
| BC15 Am I free when Ravi wants to come round for the flat inspection? | 0/3 |
| BC12 Leena can't remember where we took that photo of her cycling on the beach. Email her the name of the place | 2/3 |
| BC13 Email Neha Kulkarni that book club is moving to Thursday the 9th of April, and ask if she could host this time | 3/3 |
| BC14 Send Daniel Okafor an email saying I've gone through slides 4 to 9 and will have comments to him by Friday noon | 0/3 |

## Limits of this test

- Tool arguments are not grammar-constrained: Ollama's tools API parses the model's output; the engine validates it afterwards.
- Prompt injection from mail bodies is not tested; the permission gate is.
- For read requests, the final answer text is not checked, only the calls and how the run ended.
- Requests are in English with one fixed "today" (Wednesday 18 March 2026).

## Failures

- `qwen3:14b` BC01 #1: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "person": "Ollie", "query": "birthday drinks"})
  - said: "Here are the photos I found from last month related to Ollie's birthday drinks:\n\n1. **Photo p-113**  \n   - **Date:** February 21, 2026  \n   - **Location:** Koramangala, Bengaluru  \n   - **People:** Ol"
- `qwen3:14b` BC01 #2: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "person": "Ollie", "query": "birthday drinks"})
  - said: "Here are the photos I found from Ollie's birthday drinks last month:\n\n1. **Photo p-113** (Feb 21, 2026)  \n   - **Location**: Koramangala, Bengaluru  \n   - **People**: Ollie Grant  \n   - **Tags**: birt"
- `qwen3:14b` BC01 #3: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "query": "Ollie's birthday drinks"})
  - said: "Here are the photos from the day of Ollie's birthday drinks last month:\n\n1. **Photo p-113**  \n   - **Date**: 2026-02-21  \n   - **Location**: Koramangala, Bengaluru  \n   - **People**: Ollie Grant  \n   "
- `qwen3:14b` BC02 #1: tools used none, want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: 'The request is missing the new start time needed to reschedule the meeting. Please provide the new time so I can send the email to Hannah.'
- `qwen3:14b` BC02 #2: tools used none, want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: 'I need the new start time for the meeting to proceed. Could you please provide the updated time?'
- `qwen3:14b` BC05 #1: tools used ['list_events'], want ['list_events', 'search_mail']; list_events.query: not asked for ('meeting'); no valid search_mail call
  - calls: list_events({"date": "tomorrow afternoon", "query": "meeting"})
  - said: "I don't see any meetings scheduled for tomorrow afternoon in your calendar. Would you like me to:\n1. Help you schedule a meeting with someone (so I can then find their emails), or\n2. Search for emails"
- `qwen3:14b` BC05 #2: tools used ['list_events'], want ['list_events', 'search_mail']; list_events.query: not asked for ('meeting'); no valid search_mail call
  - calls: list_events({"date": "tomorrow", "query": "meeting"})
  - said: "There are no upcoming meetings scheduled for tomorrow. Could you please provide the name of the person you're meeting with? I can then search for emails from them."
- `qwen3:14b` BC05 #3: tools used ['list_events'], want ['list_events', 'search_mail']; list_events.query: not asked for ('meeting'); no valid search_mail call
  - calls: list_events({"date": "tomorrow afternoon", "query": "meeting"})
  - said: "There are no calendar events listed for tomorrow afternoon. Could you please provide the name of the person you're meeting or their email address so I can search for relevant emails?"
- `qwen3:14b` BC06 #2: tools used none, want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: "I don't have access to the clinic's address or the appointment time. You'll need to provide me with these details, or check your contacts for the vet's information and your calendar for the appointmen"
- `qwen3:14b` BC07 #2: tools used none, want ['create_event', 'search_mail']; no valid search_mail call; no valid create_event call
  - calls: no calls
  - said: 'I need the date, time, and location of the Indigo Lanterns gig to add it to your calendar. Could you check your ticket confirmation or provide these details?'
- `qwen3:14b` BC07 #3: tools used none, want ['create_event', 'search_mail']; no valid search_mail call; no valid create_event call
  - calls: no calls
  - said: "I can't add the event without knowing the date, time, and location of the Indigo Lanterns gig. Could you provide those details?"
- `qwen3:14b` BC08 #1: tools used ['create_event', 'search_mail'], want ['create_event', 'list_events', 'search_mail']; no valid list_events call
  - calls: search_mail({"query": "Spanish classes", "sender": "Danielle"}); create_event({"date": "Monday 6 April", "location": "HSR community centre", "time": "7pm", "title": "Spanish Class"})
  - said: "The first Spanish class is now scheduled for Monday, 6 April at 7pm at the HSR community centre. Let me know if you'd like to add more classes or need help with anything else!"
- `qwen3:14b` BC08 #2: tools used none, want ['create_event', 'list_events', 'search_mail']; no valid search_mail call; no valid list_events call; no valid create_event call
  - calls: no calls
  - said: 'The user\'s message mentions "that evening" but does not specify a date. To create a calendar event, I need the exact date and time of the first class. Please provide the specific date or check Daniell'
- `qwen3:14b` BC08 #3: tools used ['create_event', 'search_mail'], want ['create_event', 'list_events', 'search_mail']; no valid list_events call
  - calls: search_mail({"sender": "Danielle", "query": "Spanish classes starting again"}); create_event({"location": "HSR community centre", "time": "7pm", "title": "Spanish Class", "date": "Monday 6 April"})
  - said: "The first Spanish class has been added to your calendar for **Monday, 6 April 2026 at 7pm** at the **HSR community centre**. Let me know if you'd like to add more classes or make any changes!"
- `qwen3:14b` BC10 #1: tools used none, want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: "I don't have access to Leena's new address in the contacts. Please provide her new address so I can send it to Ollie."
- `qwen3:14b` BC10 #2: tools used none, want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: "The assistant cannot proceed because there is no function available to retrieve a person's address from the contacts. The find_contact function only provides name, email, and phone number, not address"
- `qwen3:14b` BC10 #3: tools used none, want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; no valid find_contact call; no valid send_mail call; outcome answered, want pending_approval
  - calls: no calls
  - said: "The assistant does not have access to Leena's new address, as it is not available in the contacts or through the provided tools. Therefore, the assistant cannot send Ollie the address."
- `qwen3:14b` BC11 #1: extra call(s): search_photos({'date': '2025-10-20'})
  - calls: search_mail({"sender": "Vikram Menon", "query": "safari plan"}); search_photos({"date": "2025-10-20"}); search_photos({"date": "November 8"})
  - said: 'Here are the photos from the safari day on November 8th:\n\n1. **Photo ID: p-101**  \n   - Taken on: 2025-11-08  \n   - Location: Kabini, Karnataka  \n   - Tags: elephants, jeep  \n\n2. **Photo ID: p-102**  '
- `qwen3:14b` BC11 #2: extra call(s): search_photos({'date': '2025-10-20'})
  - calls: search_mail({"sender": "Vikram Menon", "query": "safari"}); search_photos({"date": "2025-10-20"}); search_photos({"date": "November 8"})
  - said: 'There are no photos from the day Vikram sent the email (2025-10-20). However, I found 2 photos from the safari day (November 8) that might be relevant:\n\n1. **Elephants and jeep** in Kabini, Karnataka\n'
- `qwen3:14b` BC11 #3: search_photos.date: '2025-10-20' resolves to 2025-10-20..2025-10-20, want 2025-11-08..2025-11-08
  - calls: search_mail({"sender": "Vikram Menon", "query": "safari plan"}); search_photos({"date": "2025-10-20"})
  - said: 'No photos were found from 20 October 2025. The email Vikram sent about the safari is dated 20 October, but there are no photos from that day in your library. Would you like me to search for photos fro'
- `qwen3:14b` BC15 #1: tools used none, want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; answer 'I need to know the specific date and time when Ravi wants to come for the flat inspection to check your calendar. Could you provide that information?' lacks any of ['coffee', 'anand']
  - calls: no calls
  - said: 'I need to know the specific date and time when Ravi wants to come for the flat inspection to check your calendar. Could you provide that information?'
- `qwen3:14b` BC15 #2: tools used none, want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; answer "To check your availability for Ravi's flat inspection, I first need to know the specific date and time he has proposed. Could you provide that information? If you don't have it, I can help you search for any emails from Ravi mentioning the inspection to find the details." lacks any of ['coffee', 'anand']
  - calls: no calls
  - said: "To check your availability for Ravi's flat inspection, I first need to know the specific date and time he has proposed. Could you provide that information? If you don't have it, I can help you search "
- `qwen3:14b` BC15 #3: tools used none, want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; answer "To check if you're free when Ravi wants to come for the flat inspection, I need to know the **date and time** Ravi is planning to visit. Without this, I can't look up your calendar or check for conflicts. Please provide the specific date and time, and I'll check your schedule for you." lacks any of ['coffee', 'anand']
  - calls: no calls
  - said: "To check if you're free when Ravi wants to come for the flat inspection, I need to know the **date and time** Ravi is planning to visit. Without this, I can't look up your calendar or check for confli"
- `qwen3:14b` BC12 #1: send_mail rejected: ungrounded to: 'leena@example.com' not in the request or any earlier result; extra call(s): send_mail({'to': 'leena@example.com', 'subject': 'Photo Location', 'body': 'The photo of you cycling on the beach was taken in [Place Name].'})
  - calls: search_photos({"person": "Leena", "query": "cycling on the beach"}); find_contact({"name": "Leena"}); send_mail({"to": "leena@example.com", "subject": "Photo Location", "body": "The photo of you cycling on the beach was taken in [Place Name]."}) [invalid_args]; send_mail({"body": "The photo of you cycling on the beach was taken in Pondicherry, India.", "subject": "Photo Location", "to": "leena.joshi@example.com"}) [gated]
- `qwen3:14b` BC14 #1: send_mail rejected: ungrounded subject: '4-9' not in the request or any earlier result; extra call(s): send_mail({'subject': 'Feedback on Slides 4-9', 'body': "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", 'to': 'daniel.okafor@example.com'})
  - calls: find_contact({"name": "Daniel Okafor"}); send_mail({"subject": "Feedback on Slides 4-9", "body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", "to": "daniel.okafor@example.com"}) [invalid_args]; send_mail({"body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", "subject": "Feedback on Slides", "to": "daniel.okafor@example.com"}) [gated]
- `qwen3:14b` BC14 #2: send_mail rejected: ungrounded subject: '4-9' not in the request or any earlier result; extra call(s): send_mail({'subject': 'Comments on Slides 4-9 by Friday Noon', 'body': "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", 'to': 'daniel.okafor@example.com'})
  - calls: find_contact({"name": "Daniel Okafor"}); send_mail({"subject": "Comments on Slides 4-9 by Friday Noon", "body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", "to": "daniel.okafor@example.com"}) [invalid_args]; send_mail({"subject": "Comments on Slides by Friday Noon", "to": "daniel.okafor@example.com", "body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon."}) [gated]
- `qwen3:14b` BC14 #3: send_mail rejected: ungrounded subject: '4-9' not in the request or any earlier result; extra call(s): send_mail({'to': 'daniel.okafor@example.com', 'subject': 'Feedback on Slides 4-9', 'body': "I've gone through slides 4 to 9 and will have comments to you by Friday noon."})
  - calls: find_contact({"name": "Daniel Okafor"}); send_mail({"to": "daniel.okafor@example.com", "subject": "Feedback on Slides 4-9", "body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon."}) [invalid_args]; send_mail({"body": "I've gone through slides 4 to 9 and will have comments to you by Friday noon.", "subject": "Feedback on Slides 4 to 9", "to": "daniel.okafor@example.com"}) [gated]

