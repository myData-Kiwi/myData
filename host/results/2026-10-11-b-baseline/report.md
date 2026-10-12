# Feasibility test results

- Run 2026-10-11-b-baseline, request set 2026-10-11-b (baseline), fixed today 2026-03-18, 3 reps per request, Ollama 0.40.1.
- Fingerprints: cases_sha `a654c13a124da746`, tools_sha `921c25b9aeb506c9`, tools_code_sha `92386ae0965b2214`, prompt_sha `f1e38b7a73805ead`, dates_sha `5ab197fda1944fe0`, scoring_sha `493feeea10028606`, engine_sha `cb5ee12820460152`, client_sha `e2ab4c5267dbc948`
- Models: `qwen3:14b` (think=False, num_ctx=8192)

## Overall

| Model | Runs | Right tool | Args strict | Invented | Fully correct (raw) | Fully correct (hand-reviewed) | Requests passed, all reps (raw) | Requests passed, all reps (hand-reviewed) | Verdict (hand-reviewed) | Median s to 1st tool call | Median s total | Model errors | Retried after rejection |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `qwen3:14b` | 120 | 72% | 65% | 0 | 79/120 (65%) | **79/120 (65%)** | 26/40 (65%) | 26/40 (65%) | not viable as planned (<70%) | 3.8 | 12.7 | 0 | 6 |

Fully correct = right tools, every argument strictly right, nothing invented, and the run ended the right way (answered / held for approval / stopped to ask). Model errors count as failures. A request passes only if every rep is fully correct. "Retried after rejection" counts runs where the code rejected a call and the model then fixed it; information only, never credit.

**Hand-review rule.** Hand review touches only what the scorer judges by pattern-matching free text: the answer to a no-suitable-tool request and the answer to a no-tool question. Tool choice, arguments and how the run ended are never hand-reviewed. A refusal passes if a person reading it would say it tells the user the assistant cannot do the action, and it neither claims the action was done nor offers to do that action itself; suggesting something the tools can do instead, or telling the user how to do it themselves, is fine. A no-tool answer passes if it gives the right answer. The refusal part of this rule is automated in scoring.py (says_cannot, _claims_done and _offers_action in score()), so the raw score already applies it; the hand pass only records cases where a person disagrees with the automated judgement, each with a reason, in hand_review.json.

## `qwen3:14b` by request type

| Type | Runs | Right tool | Args strict | Invented | Outcome right | Fully correct (raw) | Fully correct (hand-reviewed) | Requests passed, all reps (raw / hand) | Median s to 1st tool call |
|---|---|---|---|---|---|---|---|---|---|
| Single tool, clear | 30 | 90% | 90% | 0 | 100% | 90% | **90%** | 9/10 / 9/10 | 2.7 |
| Arguments need care | 15 | 100% | 86% | 0 | 100% | 86% | **86%** | 4/5 / 4/5 | 4.4 |
| Two or three steps chained | 45 | 33% | 20% | 0 | 80% | 20% | **20%** | 3/15 / 3/15 | 4.1 |
| Ambiguous | 12 | 100% | 100% | 0 | 100% | 100% | **100%** | 4/4 / 4/4 | 4.1 |
| No tool needed | 9 | 100% | 100% | 0 | 100% | 100% | **100%** | 3/3 / 3/3 | - |
| No suitable tool | 9 | 100% | 100% | 0 | 100% | 100% | **100%** | 3/3 / 3/3 | - |

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
| BS10 When is Biscuit's vet appointment? | 0/3 |
| BA01 Show me emails from Vikram Desai this month | 3/3 |
| BA02 What's on my calendar from Monday to Wednesday next week? | 1/3 |
| BA03 Add a team retro on the 2nd of April from 3pm to 4:30pm | 3/3 |
| BA04 Show me the photos taken from 20 December to 5 January | 3/3 |
| BA05 Did Hannah email me anything about hiring in the past three weeks? | 3/3 |
| BC01 Show me the photos from the day of Ollie's birthday drinks last month | 0/3 |
| BC02 Email Hannah to say I'd like to start our 1:1 thirty minutes later than planned, and give her the new start time | 0/3 |
| BC03 Put another physio session in my calendar for Tuesday the 31st, at the same time as my next one | 0/3 |
| BC04 Block out 10am on the day of Farah's housewarming so I can pick up a present | 0/3 |
| BC05 Pull up any emails from the person I'm meeting tomorrow afternoon | 0/3 |
| BC06 Ollie is taking Biscuit to the vet for me. Email him the clinic's address and when the appointment is | 0/3 |
| BC07 Add the Indigo Lanterns gig I bought tickets for to my calendar | 0/3 |
| BC08 Danielle says Spanish classes are starting again. If I'm free that evening, put the first class in my calendar | 0/3 |
| BC09 Marco needs the booking reference for our Mysuru train. Email it to him | 0/3 |
| BC10 Leena has moved. Send Ollie her new address, he's posting her a card | 0/3 |
| BC11 Vikram Menon sent round the plan for his safari. Show me my photos from that day | 0/3 |
| BC15 Am I free when Ravi wants to come round for the flat inspection? | 0/3 |
| BC12 Leena can't remember where we took that photo of her cycling on the beach. Email her the name of the place | 3/3 |
| BC13 Email Neha Kulkarni that book club is moving to Thursday the 9th of April, and ask if she could host this time | 3/3 |
| BC14 Send Daniel Okafor an email saying I've gone through slides 4 to 9 and will have comments to him by Friday noon | 3/3 |
| BM01 Email Vikram that I left my charger at his place | 3/3 |
| BM02 Drop Chris an email asking for the projector back | 3/3 |
| BM03 Email Kulkarni to say the invoice has been paid | 3/3 |
| BM04 Check my photos to see when I was in Hampi, and email Anand the month | 3/3 |
| BN01 It's 30 degrees Celsius here. What's that in Fahrenheit? | 3/3 |
| BN02 A recipe uses 250 grams of flour for 4 people. How much flour do I need for 6? | 3/3 |
| BN03 What's the capital of Australia? | 3/3 |
| BU01 Make a shared album of my Coorg photos and invite Kavya to it | 3/3 |
| BU02 Turn on an out-of-office auto-reply until Monday | 3/3 |
| BU03 Pay my electricity bill | 3/3 |

## Limits of this test

- Tool arguments are not grammar-constrained: Ollama's tools API parses the model's output; the engine validates it afterwards.
- Prompt injection from mail bodies is not tested; the permission gate is.
- For read requests, the final answer text is not checked, only the calls and how the run ended.
- Requests are in English with one fixed "today" (Wednesday 18 March 2026).

## Free-text answers, for checking by hand

Every no-call answer to a no-suitable-tool or no-tool request, so a person can check the automated judgement against the hand-review rule above.

- pass `qwen3:14b` BN01 #1: '30 degrees Celsius is equivalent to 86 degrees Fahrenheit.'
- pass `qwen3:14b` BN01 #2: '30 degrees Celsius is equivalent to 86 degrees Fahrenheit.'
- pass `qwen3:14b` BN01 #3: '30 degrees Celsius is equivalent to 86 degrees Fahrenheit.'
- pass `qwen3:14b` BN02 #1: 'To adjust the recipe for 6 people, you can use a simple proportion: $$ \\frac{250 \\text{ grams}}{4 \\text{ people}} = \\frac{x \\text{ grams}}{6 \\text{ people}} $$ Solving for $ x $: $$ x = \\frac{250 \\times 6}{4} = 375 \\text{ grams} $$ You will need **375 grams of flour** for 6 people.'
- pass `qwen3:14b` BN02 #2: 'To adjust the recipe for 6 people, you can use a simple proportion: $$ \\frac{250 \\text{ grams}}{4 \\text{ people}} = \\frac{x \\text{ grams}}{6 \\text{ people}} $$ Solving for $ x $: $$ x = \\frac{250 \\times 6}{4} = 375 \\text{ grams} $$ You will need **375 grams of flour** for 6 people.'
- pass `qwen3:14b` BN02 #3: 'To adjust the recipe for 6 people, you can calculate the amount of flour needed using a simple proportion: $$ \\text{Flour for 6 people} = \\left( \\frac{6}{4} \\right) \\times 250 = 375 \\text{ grams} $$ You will need **375 grams of flour** for 6 people.'
- pass `qwen3:14b` BN03 #1: 'The capital of Australia is Canberra.'
- pass `qwen3:14b` BN03 #2: 'The capital of Australia is Canberra.'
- pass `qwen3:14b` BN03 #3: 'The capital of Australia is Canberra.'
- pass `qwen3:14b` BU01 #1: "I can't create shared albums or invite people to them directly. However, I can help you find the Coorg photos first. Let me search for photos related to Coorg."
- pass `qwen3:14b` BU01 #2: 'I cannot create shared albums or invite people to them directly. However, I can help you find the Coorg photos in your library. Would you like me to search for photos related to Coorg?'
- pass `qwen3:14b` BU01 #3: "I can't create shared albums or invite people to them directly. However, I can help you find the Coorg photos first. Let me search for photos related to Coorg."
- pass `qwen3:14b` BU02 #1: "I cannot directly control or manage email settings such as out-of-office auto-replies. You may need to access your email client or webmail interface to set this up manually. Let me know if there's anything else I can assist with!"
- pass `qwen3:14b` BU02 #2: "I cannot directly manage out-of-office auto-replies as there is no tool available for this action. Please configure this setting through your email client or service provider's settings."
- pass `qwen3:14b` BU02 #3: "I can't directly control or manage email settings like out-of-office auto-replies. You'll need to adjust this setting manually through your email client or service provider's settings. Let me know if there's anything else I can help with!"
- pass `qwen3:14b` BU03 #1: "I can't pay your electricity bill directly. However, I can help you find the contact information for your electricity provider if you'd like. Would you like me to look up the provider's details?"
- pass `qwen3:14b` BU03 #2: "I currently don't have the capability to pay bills directly. However, I can help you find the contact information for your electricity provider if you'd like. Would you like me to look that up for you?"
- pass `qwen3:14b` BU03 #3: "I can't pay your electricity bill directly. However, I can help you find the contact information for your electricity provider if you'd like. Would you like me to look up the contact details for your electricity company?"

## Failures

- `qwen3:14b` BS10 #1: tools used ['find_contact'], want ['list_events']; no valid list_events call; extra call(s): find_contact({'name': 'Biscuit'})
  - calls: find_contact({"name": "Biscuit"})
  - said: "I couldn't find any contact named Biscuit. Could you please provide more details or check the name?"
- `qwen3:14b` BS10 #2: tools used ['find_contact'], want ['list_events']; no valid list_events call; extra call(s): find_contact({'name': 'Biscuit'})
  - calls: find_contact({"name": "Biscuit"})
  - said: "I couldn't find any contact named Biscuit. Could you please provide more details or check the name again?"
- `qwen3:14b` BS10 #3: tools used ['find_contact'], want ['list_events']; no valid list_events call; extra call(s): find_contact({'name': 'Biscuit'})
  - calls: find_contact({"name": "Biscuit"})
  - said: "I couldn't find any contact named Biscuit. Could you please provide more information or check the name?"
- `qwen3:14b` BA02 #1: list_events.date: 'next week' resolves to 2026-03-23..2026-03-29, want 2026-03-23..2026-03-25
  - calls: list_events({"date": "next week"})
  - said: 'Here are your calendar events from Monday to Wednesday next week:\n\n- **Monday, March 23, 2026**: 1:1 meeting with Hannah (one-on-one) from 11:30 AM to 12:00 PM in Room 4B.\n- **Tuesday, March 24, 2026*'
- `qwen3:14b` BA02 #3: list_events.date: 'next week' resolves to 2026-03-23..2026-03-29, want 2026-03-23..2026-03-25
  - calls: list_events({"date": "next week"})
  - said: "Here's what's on your calendar from Monday to Wednesday next week:\n\n- **Monday, March 23, 2026**: 1:1 meeting with Hannah (one-on-one) from 11:30 AM to 12:00 PM in Room 4B.\n- **Tuesday, March 24, 2026"
- `qwen3:14b` BC01 #1: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "query": "Ollie's birthday drinks"})
  - said: "Here are the photos from the day of Ollie's birthday drinks last month:\n\n1. **Photo ID: p-113** - Taken on February 21, 2026, in Koramangala, Bengaluru. Tags: birthday, cake, candles. People: Ollie Gr"
- `qwen3:14b` BC01 #2: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "query": "Ollie's birthday drinks"})
  - said: "Here are the photos from the day of Ollie's birthday drinks last month:\n\n1. **Photo ID: p-113** - Taken on February 21, 2026, in Koramangala, Bengaluru. Tags: birthday, cake, candles. People: Ollie Gr"
- `qwen3:14b` BC01 #3: tools used ['search_photos'], want ['list_events', 'search_photos']; no valid list_events call; search_photos.date: 'last month' resolves to 2026-02-01..2026-02-28, want 2026-02-21..2026-02-21
  - calls: search_photos({"date": "last month", "query": "Ollie's birthday drinks"})
  - said: "Here are the photos from the day of Ollie's birthday drinks last month:\n\n1. **Photo ID: p-113** - Taken on 2026-02-21 in Koramangala, Bengaluru. Tags: birthday, cake, candles. People: Ollie Grant.\n2. "
- `qwen3:14b` BC02 #1: tools used ['find_contact', 'send_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; send_mail.body: "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]" lacks any of ['re:\\A(?=[\\s\\S]*(?:(?<![\\d:.])(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)|\\bnoon\\b|\\bmidday\\b|\\b(?:at|to)\\s+12(?![\\d:.])))(?:\\bbetween\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)\\s*(?:-|–|—|to|until|till)\\s*12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:end(?:s|ing)?(?:\\s+time)?|finish(?:es|ing)?(?:\\s+time)?|wrap(?:s|ping)?\\s+up)\\s*(?:(?:is|of|would\\s+be|will\\s+be|becomes)\\s*)?:?\\s*(?:at\\s+|by\\s+|around\\s+)?12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:run(?:s|ning)?|go(?:es|ing)?|last(?:s|ing)?)\\s+(?:until|till|to|through)\\s+12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|11[:.]30(?!\\s*(?:pm|p\\.m\\.))(?:\\s*(?:am|a\\.m\\.))?|12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|\\b(?:at|to)\\s+12(?![\\d:.])|(?!(?<![\\d:.])\\d{1,2}(?:[:.]\\d\\d)?(?:\\s*(?:am|a\\.m\\.)|\\s*(?:pm|p\\.m\\.))(?![a-z])|(?<![\\d:.])\\d{1,2}[:.]\\d\\d(?!\\d)|\\b(?:at|to|until|till|from)\\s+\\d{1,2}(?![\\d:.])|\\b(?:mov|push|shift|chang|reschedul|bump|switch|postpon|delay)\\w*(?=(?:\\s+(?!(?:to|so|and|then|would|will)\\b)[^\\s.?!;]+){0,5}?\\s+(?:from|between)\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))))[\\s\\S])*\\Z']
  - calls: find_contact({"name": "Hannah"}); send_mail({"to": "hannah.schmidt@example.com", "subject": "Rescheduling Our 1:1", "body": "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]"}) [gated]
- `qwen3:14b` BC02 #2: tools used ['find_contact', 'send_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; send_mail.body: "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]" lacks any of ['re:\\A(?=[\\s\\S]*(?:(?<![\\d:.])(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)|\\bnoon\\b|\\bmidday\\b|\\b(?:at|to)\\s+12(?![\\d:.])))(?:\\bbetween\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)\\s*(?:-|–|—|to|until|till)\\s*12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:end(?:s|ing)?(?:\\s+time)?|finish(?:es|ing)?(?:\\s+time)?|wrap(?:s|ping)?\\s+up)\\s*(?:(?:is|of|would\\s+be|will\\s+be|becomes)\\s*)?:?\\s*(?:at\\s+|by\\s+|around\\s+)?12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:run(?:s|ning)?|go(?:es|ing)?|last(?:s|ing)?)\\s+(?:until|till|to|through)\\s+12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|11[:.]30(?!\\s*(?:pm|p\\.m\\.))(?:\\s*(?:am|a\\.m\\.))?|12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|\\b(?:at|to)\\s+12(?![\\d:.])|(?!(?<![\\d:.])\\d{1,2}(?:[:.]\\d\\d)?(?:\\s*(?:am|a\\.m\\.)|\\s*(?:pm|p\\.m\\.))(?![a-z])|(?<![\\d:.])\\d{1,2}[:.]\\d\\d(?!\\d)|\\b(?:at|to|until|till|from)\\s+\\d{1,2}(?![\\d:.])|\\b(?:mov|push|shift|chang|reschedul|bump|switch|postpon|delay)\\w*(?=(?:\\s+(?!(?:to|so|and|then|would|will)\\b)[^\\s.?!;]+){0,5}?\\s+(?:from|between)\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))))[\\s\\S])*\\Z']
  - calls: find_contact({"name": "Hannah"}); send_mail({"to": "hannah.schmidt@example.com", "subject": "Rescheduling Our 1:1", "body": "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]"}) [gated]
- `qwen3:14b` BC02 #3: tools used ['find_contact', 'send_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; send_mail.body: "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]" lacks any of ['re:\\A(?=[\\s\\S]*(?:(?<![\\d:.])(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)|\\bnoon\\b|\\bmidday\\b|\\b(?:at|to)\\s+12(?![\\d:.])))(?:\\bbetween\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)\\s*(?:-|–|—|to|until|till)\\s*12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:end(?:s|ing)?(?:\\s+time)?|finish(?:es|ing)?(?:\\s+time)?|wrap(?:s|ping)?\\s+up)\\s*(?:(?:is|of|would\\s+be|will\\s+be|becomes)\\s*)?:?\\s*(?:at\\s+|by\\s+|around\\s+)?12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|\\b(?:run(?:s|ning)?|go(?:es|ing)?|last(?:s|ing)?)\\s+(?:until|till|to|through)\\s+12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|11[:.]30(?!\\s*(?:pm|p\\.m\\.))(?:\\s*(?:am|a\\.m\\.))?|12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|\\b(?:at|to)\\s+12(?![\\d:.])|(?!(?<![\\d:.])\\d{1,2}(?:[:.]\\d\\d)?(?:\\s*(?:am|a\\.m\\.)|\\s*(?:pm|p\\.m\\.))(?![a-z])|(?<![\\d:.])\\d{1,2}[:.]\\d\\d(?!\\d)|\\b(?:at|to|until|till|from)\\s+\\d{1,2}(?![\\d:.])|\\b(?:mov|push|shift|chang|reschedul|bump|switch|postpon|delay)\\w*(?=(?:\\s+(?!(?:to|so|and|then|would|will)\\b)[^\\s.?!;]+){0,5}?\\s+(?:from|between)\\s+(?:12[:.]00(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))|12\\s*(?:pm|p\\.m\\.)|noon|midday)(?:\\s*(?:-|–|—|to|until|till)\\s*|\\s+and\\s+)12[:.]30(?:\\s*(?:pm|p\\.m\\.))?(?!\\s*(?:am|a\\.m\\.))))[\\s\\S])*\\Z']
  - calls: find_contact({"name": "Hannah"}); send_mail({"body": "Hi Hannah,\n\nI'd like to start our 1:1 thirty minutes later than planned. Please let me know the new start time that works for you.\n\nBest regards,\n[Your Name]", "to": "hannah.schmidt@example.com", "subject": "Adjusting Our 1:1 Start Time"}) [gated]
- `qwen3:14b` BC03 #1: tools used ['create_event'], want ['create_event', 'list_events']; no valid list_events call; create_event.time: missing
  - calls: create_event({"date": "Tuesday the 31st", "title": "Physio Session"})
  - said: "I've added another physio session to your calendar for Tuesday the 31st. Let me know if you need any further assistance!"
- `qwen3:14b` BC03 #2: tools used ['create_event'], want ['create_event', 'list_events']; no valid list_events call; create_event.time: missing
  - calls: create_event({"date": "Tuesday the 31st", "title": "Physio Session"})
  - said: "I've added another physio session to your calendar for Tuesday, March 31st. Let me know if you need any further assistance!"
- `qwen3:14b` BC03 #3: tools used ['create_event'], want ['create_event', 'list_events']; no valid list_events call; create_event.time: missing
  - calls: create_event({"date": "Tuesday the 31st", "title": "Physio Session"})
  - said: "I've added another physio session to your calendar for Tuesday, March 31st. Let me know if you need any further assistance!"
- `qwen3:14b` BC04 #1: create_event rejected: could not understand the date 'day of Farah's housewarming'; create_event rejected: could not understand the date 'day of Farah's housewarming'; tools used ['create_event', 'find_contact', 'list_events'], want ['create_event', 'list_events']; extra call(s): find_contact({'name': 'Farah'}), create_event({'date': "day of Farah's housewarming", 'title': "Pick up present for Farah's housewarming", 'time': '10am'}), find_contact({'name': 'Farah'}), create_event({'date': "day of Farah's housewarming", 'time': '10am', 'title': "Pick up present for Farah's housewarming"}); outcome step_limit, want answered
  - calls: find_contact({"name": "Farah"}); create_event({"date": "day of Farah's housewarming", "title": "Pick up present for Farah's housewarming", "time": "10am"}) [bad_date]; find_contact({"name": "Farah"}); create_event({"date": "day of Farah's housewarming", "time": "10am", "title": "Pick up present for Farah's housewarming"}) [bad_date]; list_events({"query": "housewarming"}); create_event({"title": "Pick up present for Farah's housewarming", "date": "2026-03-28", "time": "10am"})
- `qwen3:14b` BC04 #2: create_event rejected: could not understand the date 'day of Farah's housewarming'; tools used ['create_event', 'find_contact', 'list_events'], want ['create_event', 'list_events']; create_event.duration_minutes: not asked for (30); extra call(s): find_contact({'name': 'Farah'}), create_event({'date': "day of Farah's housewarming", 'title': "Pick up present for Farah's housewarming", 'time': '10am', 'duration_minutes': 30})
  - calls: find_contact({"name": "Farah"}); create_event({"date": "day of Farah's housewarming", "title": "Pick up present for Farah's housewarming", "time": "10am", "duration_minutes": 30}) [bad_date]; list_events({"query": "Farah's housewarming"}); create_event({"date": "2026-03-28", "duration_minutes": 30, "time": "10:00", "title": "Pick up present for Farah's housewarming"})
  - said: "I've blocked out 10am on March 28th for you to pick up a present for Farah's housewarming. Let me know if you need anything else!"
- `qwen3:14b` BC04 #3: create_event rejected: could not understand the date 'day of Farah's housewarming'; create_event rejected: could not understand the date 'day of Farah's housewarming'; tools used ['create_event', 'find_contact', 'list_events'], want ['create_event', 'list_events']; create_event.duration_minutes: not asked for (30); extra call(s): find_contact({'name': 'Farah'}), create_event({'duration_minutes': 30, 'date': "day of Farah's housewarming", 'title': "Pick up present for Farah's housewarming", 'time': '10am'}), find_contact({'name': 'Farah'}), create_event({'date': "day of Farah's housewarming", 'duration_minutes': 30, 'time': '10am', 'title': "Pick up present for Farah's housewarming"}); outcome step_limit, want answered
  - calls: find_contact({"name": "Farah"}); create_event({"duration_minutes": 30, "date": "day of Farah's housewarming", "title": "Pick up present for Farah's housewarming", "time": "10am"}) [bad_date]; find_contact({"name": "Farah"}); create_event({"date": "day of Farah's housewarming", "duration_minutes": 30, "time": "10am", "title": "Pick up present for Farah's housewarming"}) [bad_date]; list_events({"query": "housewarming"}); create_event({"date": "2026-03-28", "duration_minutes": 30, "time": "10:00", "title": "Pick up present for Farah's housewarming"})
- `qwen3:14b` BC05 #1: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid list_events call; no valid search_mail call; extra call(s): find_contact({'name': "the person I'm meeting tomorrow afternoon"})
  - calls: find_contact({"name": "the person I'm meeting tomorrow afternoon"})
  - said: 'It seems there are no matching contacts for "the person I\'m meeting tomorrow afternoon." Could you provide the name of the person you\'re meeting?'
- `qwen3:14b` BC05 #2: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid list_events call; no valid search_mail call; extra call(s): find_contact({'name': "the person I'm meeting tomorrow afternoon"})
  - calls: find_contact({"name": "the person I'm meeting tomorrow afternoon"})
  - said: 'It seems there are no matching contacts for "the person I\'m meeting tomorrow afternoon." Could you provide more details about the person you\'re meeting?'
- `qwen3:14b` BC05 #3: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid list_events call; no valid search_mail call; extra call(s): find_contact({'name': "the person I'm meeting tomorrow afternoon"})
  - calls: find_contact({"name": "the person I'm meeting tomorrow afternoon"})
  - said: 'It seems there are no matching contacts for "the person I\'m meeting tomorrow afternoon." Could you provide more details about the person you\'re meeting?'
- `qwen3:14b` BC06 #1: tools used ['find_contact', 'list_events', 'search_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid send_mail call; extra call(s): search_mail({'sender': 'Ollie Grant', 'query': 'vet'}), search_mail({'sender': 'Ollie Grant', 'query': 'clinic address'}); outcome answered, want pending_approval
  - calls: find_contact({"name": "Ollie"}); search_mail({"sender": "Ollie Grant", "query": "vet"}); search_mail({"sender": "Ollie Grant", "query": "clinic address"}); list_events({"query": "vet"})
  - said: "Ollie is taking Biscuit to the PawCare Vet Clinic for a check-up on March 30 at 5:30 PM. The clinic's address is 12 Outer Ring Road, Bellandur."
- `qwen3:14b` BC06 #2: tools used ['find_contact', 'search_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid list_events call; no valid send_mail call; extra call(s): search_mail({'sender': 'Biscuit Vet Clinic'}), search_mail({'sender': 'Biscuit Vet Clinic'}); outcome answered, want pending_approval
  - calls: find_contact({"name": "Ollie"}); search_mail({"sender": "Biscuit Vet Clinic"}); search_mail({"sender": "Biscuit Vet Clinic"})
  - said: "It seems there are no messages from the Biscuit Vet Clinic in your inbox. Please check if there's another source for the clinic's address and the appointment details. If you have any more information,"
- `qwen3:14b` BC06 #3: tools used ['find_contact', 'list_events', 'search_mail'], want ['find_contact', 'list_events', 'send_mail']; no valid send_mail call; extra call(s): search_mail({'sender': 'Biscuit Vet Clinic'}); outcome answered, want pending_approval
  - calls: find_contact({"name": "Ollie"}); search_mail({"sender": "Biscuit Vet Clinic"}); list_events({"query": "Biscuit"})
  - said: "Ollie, here's the information you needed:\n\n- **Clinic Address:** PawCare Vet Clinic, 12 Outer Ring Road, Bellandur\n- **Appointment Date and Time:** March 30, 2026, at 5:30 PM\n\nLet me know if you need "
- `qwen3:14b` BC07 #1: tools used ['create_event'], want ['create_event', 'search_mail']; no valid search_mail call; create_event.date: 'next friday' resolves to 2026-03-27..2026-03-27, want 2026-04-04..2026-04-04; create_event.time: '7pm' is 19:00, want 19:30; create_event.duration_minutes: 120 is not one of ['150']
  - calls: create_event({"title": "Indigo Lanterns gig", "date": "next friday", "time": "7pm", "duration_minutes": 120})
  - said: 'The event "Indigo Lanterns gig" has been added to your calendar for next Friday at 7pm. Let me know if there\'s anything else you need!'
- `qwen3:14b` BC07 #2: tools used ['create_event'], want ['create_event', 'search_mail']; no valid search_mail call; create_event.date: 'next friday' resolves to 2026-03-27..2026-03-27, want 2026-04-04..2026-04-04; create_event.time: '7pm' is 19:00, want 19:30; create_event.duration_minutes: 120 is not one of ['150']
  - calls: create_event({"time": "7pm", "duration_minutes": 120, "title": "Indigo Lanterns gig", "date": "next friday"})
  - said: 'The event "Indigo Lanterns gig" has been added to your calendar for next Friday at 7pm.'
- `qwen3:14b` BC07 #3: tools used ['create_event'], want ['create_event', 'search_mail']; no valid search_mail call; create_event.date: 'next friday' resolves to 2026-03-27..2026-03-27, want 2026-04-04..2026-04-04; create_event.time: '7pm' is 19:00, want 19:30; create_event.duration_minutes: 120 is not one of ['150']
  - calls: create_event({"time": "7pm", "duration_minutes": 120, "title": "Indigo Lanterns gig", "date": "next friday"})
  - said: 'The event "Indigo Lanterns gig" has been added to your calendar for next Friday at 7pm. Let me know if you need any further assistance!'
- `qwen3:14b` BC08 #1: tools used ['create_event', 'find_contact', 'search_mail'], want ['create_event', 'list_events', 'search_mail']; no valid list_events call; extra call(s): find_contact({'name': 'Danielle'})
  - calls: find_contact({"name": "Danielle"}); search_mail({"sender": "Danielle Moreau", "query": "Spanish classes"}); create_event({"duration_minutes": 90, "title": "Spanish class", "location": "HSR community centre", "date": "Monday 6 April", "time": "7pm"})
  - said: 'The first Spanish class has been added to your calendar for Monday, 6 April at 7pm at the HSR community centre. Let me know if you need further assistance!'
- `qwen3:14b` BC08 #2: tools used ['create_event', 'find_contact', 'search_mail'], want ['create_event', 'list_events', 'search_mail']; no valid list_events call; extra call(s): find_contact({'name': 'Danielle'})
  - calls: find_contact({"name": "Danielle"}); search_mail({"sender": "Danielle Moreau", "query": "Spanish classes"}); create_event({"title": "Spanish class", "location": "HSR community centre", "date": "Monday 6 April", "time": "7pm", "duration_minutes": 90})
  - said: 'The first Spanish class has been added to your calendar for Monday 6 April at 7pm at the HSR community centre. Let me know if you need further assistance!'
- `qwen3:14b` BC08 #3: tools used ['find_contact', 'send_mail'], want ['create_event', 'list_events', 'search_mail']; no valid search_mail call; no valid list_events call; no valid create_event call; extra call(s): find_contact({'name': 'Danielle'}), send_mail({'to': 'danielle.moreau@example.com', 'subject': 'Confirming Spanish Class Timing', 'body': "Hi Danielle,\n\nCould you please confirm the time of the first Spanish class? I'd like to add it to my calendar if I'm free that evening.\n\nThanks,\n[Your Name]"}); outcome pending_approval, want answered
  - calls: find_contact({"name": "Danielle"}); send_mail({"to": "danielle.moreau@example.com", "subject": "Confirming Spanish Class Timing", "body": "Hi Danielle,\n\nCould you please confirm the time of the first Spanish class? I'd like to add it to my calendar if I'm free that evening.\n\nThanks,\n[Your Name]"}) [gated]
- `qwen3:14b` BC09 #1: search_mail.sender: not asked for ('Marco'); send_mail.body: 'Here is the booking reference for our Mysuru train: [insert reference here]. Let me know if you need anything else!' lacks any of ['58213']
  - calls: find_contact({"name": "Marco"}); search_mail({"query": "Mysuru train booking reference", "sender": "Marco"}); send_mail({"to": "marco.bianchi@example.com", "subject": "Mysuru train booking reference", "body": "Here is the booking reference for our Mysuru train: [insert reference here]. Let me know if you need anything else!"}) [gated]
- `qwen3:14b` BC09 #2: search_mail.sender: not asked for ('Marco'); send_mail.body: 'Here is the booking reference for the Mysuru train: [Insert Reference Here]. Let me know if you need anything else!' lacks any of ['58213']
  - calls: find_contact({"name": "Marco"}); search_mail({"sender": "Marco", "query": "booking reference Mysuru train"}); send_mail({"to": "marco.bianchi@example.com", "subject": "Booking reference for Mysuru train", "body": "Here is the booking reference for the Mysuru train: [Insert Reference Here]. Let me know if you need anything else!"}) [gated]
- `qwen3:14b` BC09 #3: search_mail.sender: not asked for ('Marco'); send_mail.body: 'Here is the booking reference for our Mysuru train: [insert booking reference here]. Let me know if you need anything else!' lacks any of ['58213']
  - calls: find_contact({"name": "Marco"}); search_mail({"sender": "Marco", "query": "booking reference Mysuru train"}); send_mail({"to": "marco.bianchi@example.com", "subject": "Booking reference for Mysuru train", "body": "Here is the booking reference for our Mysuru train: [insert booking reference here]. Let me know if you need anything else!"}) [gated]
- `qwen3:14b` BC10 #1: tools used ['find_contact', 'send_mail'], want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; send_mail.body: 'Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there.' lacks any of ['lakeview', 'hennur']; extra call(s): find_contact({'name': 'Leena'})
  - calls: find_contact({"name": "Leena"}); find_contact({"name": "Ollie"}); send_mail({"to": "ollie.grant@example.com", "subject": "Leena's New Address", "body": "Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there."}) [gated]
- `qwen3:14b` BC10 #2: tools used ['find_contact', 'send_mail'], want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; send_mail.body: 'Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there.' lacks any of ['lakeview', 'hennur']; extra call(s): find_contact({'name': 'Leena'})
  - calls: find_contact({"name": "Leena"}); find_contact({"name": "Ollie"}); send_mail({"to": "ollie.grant@example.com", "subject": "Leena's New Address", "body": "Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there."}) [gated]
- `qwen3:14b` BC10 #3: tools used ['find_contact', 'send_mail'], want ['find_contact', 'search_mail', 'send_mail']; no valid search_mail call; send_mail.body: 'Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there.' lacks any of ['lakeview', 'hennur']; extra call(s): find_contact({'name': 'Leena'})
  - calls: find_contact({"name": "Leena"}); find_contact({"name": "Ollie"}); send_mail({"subject": "Leena's New Address", "body": "Ollie, Leena has moved. Her new address is 123 Main Street, Cityville. Feel free to send her a card there.", "to": "ollie.grant@example.com"}) [gated]
- `qwen3:14b` BC11 #1: search_photos rejected: could not understand the date 'the day Vikram Menon sent the plan for his safari'; extra call(s): search_photos({'date': 'the day Vikram Menon sent the plan for his safari'})
  - calls: search_photos({"date": "the day Vikram Menon sent the plan for his safari"}) [bad_date]; search_mail({"sender": "Vikram Menon", "query": "safari plan"}); search_photos({"date": "November 8"})
  - said: 'Here are the photos from the day of the safari on November 8:\n\n1. **Photo ID: p-101** - Taken in Kabini, Karnataka. Tags: elephants, jeep.\n2. **Photo ID: p-102** - Taken in Kabini, Karnataka. Tags: ri'
- `qwen3:14b` BC11 #2: search_photos rejected: could not understand the date 'the day Vikram Menon sent the plan for his safari'; extra call(s): search_photos({'date': 'the day Vikram Menon sent the plan for his safari'})
  - calls: search_photos({"date": "the day Vikram Menon sent the plan for his safari"}) [bad_date]; search_mail({"sender": "Vikram Menon", "query": "safari plan"}); search_photos({"date": "8 November"})
  - said: 'Here are the photos from the day of the safari on 8 November:\n\n1. **Photo ID: p-101** - Taken in Kabini, Karnataka. Tags: elephants, jeep.\n2. **Photo ID: p-102** - Taken in Kabini, Karnataka. Tags: ri'
- `qwen3:14b` BC11 #3: search_photos rejected: could not understand the date 'the day Vikram Menon sent round the plan for his safari'; extra call(s): search_photos({'date': 'the day Vikram Menon sent round the plan for his safari'})
  - calls: search_photos({"date": "the day Vikram Menon sent round the plan for his safari"}) [bad_date]; search_mail({"sender": "Vikram Menon", "query": "safari"}); search_photos({"date": "8 November"})
  - said: 'Here are the photos from the day of the safari on 8 November:\n\n1. **Photo ID: p-101** - Taken in Kabini, Karnataka. Tags: elephants, jeep.\n2. **Photo ID: p-102** - Taken in Kabini, Karnataka. Tags: ri'
- `qwen3:14b` BC15 #1: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; extra call(s): find_contact({'name': 'Ravi'}); answer 'It seems there is no contact named Ravi in your contacts. Could you provide more details or check the name?' lacks any of ['coffee', 'anand']
  - calls: find_contact({"name": "Ravi"})
  - said: 'It seems there is no contact named Ravi in your contacts. Could you provide more details or check the name?'
- `qwen3:14b` BC15 #2: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; extra call(s): find_contact({'name': 'Ravi'}); answer 'It seems there is no contact named Ravi in your contacts. Could you provide more details or check the name?' lacks any of ['coffee', 'anand']
  - calls: find_contact({"name": "Ravi"})
  - said: 'It seems there is no contact named Ravi in your contacts. Could you provide more details or check the name?'
- `qwen3:14b` BC15 #3: tools used ['find_contact'], want ['list_events', 'search_mail']; no valid search_mail call; no valid list_events call; extra call(s): find_contact({'name': 'Ravi'}); answer 'It seems there is no contact information available for Ravi. Could you provide more details or check the name again?' lacks any of ['coffee', 'anand']
  - calls: find_contact({"name": "Ravi"})
  - said: 'It seems there is no contact information available for Ravi. Could you provide more details or check the name again?'

