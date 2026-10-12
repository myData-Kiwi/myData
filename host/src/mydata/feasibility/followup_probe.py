"""Follow-up probe: 24 single-lookup requests labelled by whether the shown list answers them.

The assistant answers each request with ONE lookup (calendar events, mail search,
contacts or photo search). The app then shows the lookup's result as a list under a
one-line header written by code ("2 events on Thursday 19 March", "3 emails from
Ravi", a contact card, "4 photos in Coorg"). Events show day, start-end time, title
and location; emails show sender, subject, date and a snippet; photos show place,
date and people.

Requests refer to the people, events, mail and photos in the DATA of
``cases_2026_10_11_b.py`` (today is Wednesday 18 March 2026). None of them sends or
creates anything, and none needs more than one lookup.

This set was written blind to the classifiers it is used to score: the author did not
read the orchestrator's follow-up, engine or presentation code, the tests, or any
earlier version of this file.

Labelling rule:
- ``needs_sentence = True``: a person looking at the list would still want a short
  written answer, because the list does not answer the question by itself (a yes/no
  about availability or a clash, working something out such as a duration or which
  is earlier, a comparison, a count that needs filtering beyond the header, a
  judgement).
- ``needs_sentence = False``: the list itself is the answer (show / find / what's on /
  when is X / any emails about Y / whose number), including yes/no-sounding questions
  that the list settles on sight.

12 requests are False and 12 are True, mixed in order.
"""

from __future__ import annotations

PROBES: list[tuple[str, bool]] = [
    ("Do I have anything on Friday?", False),
    ("Am I free at 2pm tomorrow?", True),
    ("What's Farah's number?", False),
    ("How long is the quarterly planning workshop?", True),
    ("Show me my photos from Hampi", False),
    ("How many of my Kabini photos are from last November's trip?", True),
    ("what's on tomorrow", False),
    ("Is there at least a two hour gap between the design review and my haircut tomorrow?", True),
    ("Did Daniel send over the deck for the design review?", False),
    ("Which comes first next week, the parent-teacher meeting or Farah's housewarming?", True),
    ("Find the TicketHive email with my concert tickets", False),
    ("What time will the Indigo Lanterns concert finish?", True),
    ("When's my physio appointment?", False),
    ("Do I have to be up before 8 on any day this week?", True),
    ("Any emails from the school?", False),
    ("How many of my appointments next week are in the morning?", True),
    ("Where is Biscuit's vet check-up?", False),
    ("Are the school fees due before sports day?", True),
    ("Can you pull up Hannah Schmidt's email address?", False),
    ("Have I got any free evenings this weekend?", True),
    ("What have I got on next week?", False),
    ("Will the parent-teacher meeting be over in time for a 5pm call?", True),
    ("pictures with Marco in them", False),
    ("How many days until Farah's housewarming?", True),
]
