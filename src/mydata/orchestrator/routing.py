"""Choose which tools the model sees for a request.

THE RULE (word cues -> tool groups; checkable in 30 seconds):

  1. Lower-case the request and split it into words. A cue matches its base
     form or a simple inflection (-s, -es, -ies, -ing).
  2. Six cue groups:
       SEND     -> send_mail + find_contact   (send, tell, ask, forward, ...)
       CREATE   -> create_event                (add, put, create, ...)
       CONTACT  -> find_contact                (contact, phone, address, ...)
       MAIL     -> search_mail                 (inbox, receipt, wrote, ...)
       CALENDAR -> list_events                 (appointment, meeting, free, ...)
       PHOTO    -> search_photos               (photo, picture, image, ...)
  3. Words whose role depends on position:
     - email/mail/message/text/write/reply/respond and book/schedule/make,
       in exactly that base form, at the start of a clause or right after
       to/and/then/please/you/me/also/just/let's, are verbs: SEND
       (book/schedule/make: CREATE).
     - email/mail/message right after "a"/"an" (one word may sit between)
       is the thing being sent: no group. Anywhere else they mean MAIL.
     - "remind me" is CREATE; "remind <someone>" is SEND. "let <someone>
       know" is SEND.
     - calendar/schedule/diary/agenda mean CALENDAR, except in a CREATE
       request, where they only name where the new event goes.
     A word may sit in two groups (forward: SEND and MAIL; invite: SEND
     and CREATE); it then counts for both.
  4. SEND or CREATE with no MAIL/CALENDAR/PHOTO cue: add all three lookup
     tools, because the details must come from somewhere we cannot guess.
  5. No cue at all: all six tools. The result is never empty.

Tools come back in the canonical order of tools.TOOLS.
"""

from __future__ import annotations

import re

from .tools import TOOLS

ALL_TOOLS: list[str] = list(TOOLS)

SEND_WORDS = {"send", "tell", "ask", "forward", "share", "notify", "invite"}
CREATE_WORDS = {"add", "put", "create", "block", "pencil", "invite", "reminder"}
CONTACT_WORDS = {"contact", "phone", "number", "address"}
MAIL_WORDS = {
    "inbox", "wrote", "written", "sent", "emailed", "mailed", "messaged", "replied", "reply",
    "response", "said", "told", "mentioned", "confirmation", "receipt", "invoice", "ticket",
    "newsletter", "attachment", "sender", "unread", "invitation", "forward",
}
CALENDAR_WORDS = {
    "appointment", "meeting", "event", "booking", "booked", "reservation", "class", "lesson",
    "plan", "scheduled", "free", "busy", "available", "availability",
}
PHOTO_WORDS = {"photo", "photograph", "picture", "pic", "image", "selfie", "video", "album", "screenshot"}

# Position-dependent words (rule 3).
MAIL_NOUNS = {"email", "mail", "message"}
SEND_VERBS = {"email", "mail", "message", "text", "write", "reply", "respond"}
CREATE_VERBS = {"book", "schedule", "make"}
CALENDAR_PLACES = {"calendar", "schedule", "diary", "agenda"}
VERB_BEFORE = {"to", "and", "then", "please", "you", "me", "also", "just", "let's", "lets"}

GROUP_TOOLS = {
    "send": ["send_mail", "find_contact"],
    "create": ["create_event"],
    "contact": ["find_contact"],
    "mail": ["search_mail"],
    "calendar": ["list_events"],
    "photo": ["search_photos"],
}
SOURCES = ("mail", "calendar", "photo")


def _forms(word: str) -> set[str]:
    out = {word, word + "s", word + "es", word + "ing"}
    if word.endswith("y"):
        out.add(word[:-1] + "ies")
    if word.endswith("e"):
        out.add(word[:-1] + "ing")
    return out


def _index(words: set[str]) -> dict[str, str]:
    return {form: w for w in words for form in _forms(w)}


_IDX = {
    name: _index(words)
    for name, words in {
        "send": SEND_WORDS, "create": CREATE_WORDS, "contact": CONTACT_WORDS,
        "mail": MAIL_WORDS, "calendar": CALENDAR_WORDS, "photo": PHOTO_WORDS,
        "mail_noun": MAIL_NOUNS, "cal_place": CALENDAR_PLACES,
    }.items()
}


def _clauses(request: str) -> list[list[str]]:
    text = request.lower().replace("’", "'").replace("e-mail", "email")
    return [
        re.findall(r"[a-z0-9]+(?:'[a-z]+)?", part)
        for part in re.split(r"[.,;:!?\n]+", text)
    ]


def select_tools(request: str) -> list[str]:
    groups: set[str] = set()
    cal_place = False
    for words in _clauses(request):
        for i, w in enumerate(words):
            prev = words[i - 1] if i > 0 else None
            nxt = words[i + 1] if i + 1 < len(words) else None
            verb_pos = prev is None or prev in VERB_BEFORE
            for g in ("send", "create", "contact", "mail", "calendar", "photo"):
                if w in _IDX[g]:
                    groups.add(g)
            if w in ("remind", "reminds", "reminding"):
                groups.add("create" if nxt == "me" else "send")
            if verb_pos and w in SEND_VERBS:
                groups.add("send")
            elif verb_pos and w in CREATE_VERBS:
                groups.add("create")
            elif w in _IDX["mail_noun"]:
                if nxt in ("address", "addresses"):
                    groups.add("contact")
                elif not ({"a", "an"} & set(words[max(0, i - 2):i])):
                    groups.add("mail")
            if w in _IDX["cal_place"]:
                cal_place = True
        joined = " ".join(words)
        if re.search(r"\blet (?!me\b)\w+(?: \w+)? know\b", joined):
            groups.add("send")

    if cal_place and "create" not in groups:
        groups.add("calendar")
    if not groups:
        return list(ALL_TOOLS)
    if groups & {"send", "create"} and not groups & set(SOURCES):
        groups.update(SOURCES)
    chosen = {t for g in groups for t in GROUP_TOOLS[g]}
    return [t for t in ALL_TOOLS if t in chosen]

