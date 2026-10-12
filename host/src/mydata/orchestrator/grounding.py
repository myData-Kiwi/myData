"""Grounding check: an argument value must come from somewhere.

Sources are the user's request and the results of earlier tool calls in the same request.
The rule depends only on the kind of argument, never on particular words:

- Date phrases are not checked here; dates.py resolves them and rejects what it cannot read.
- Text the model composes (an email's subject and body, an event title) is free wording, so only
  the facts inside it are checked: times, numbers and codes (any token with a digit), and email
  addresses must each appear in a source. A time without am/pm counts if either reading appears.
- A time or number argument must appear in a source as a time or number. Two general allowances:
  numbers joined by hyphens ("4-9", "2026-03-30") are grounded when each number is, so a range the
  user wrote as "4 to 9" grounds "4-9"; and a number of minutes is grounded when it is the difference
  between two grounded times, so "3pm to 4:30pm" grounds a 90-minute duration.
- Any other text argument (a search query, a name, a place): each content word must appear in a
  source. "Appear" allows simple inflections: words match on their first five letters.

What happens to an argument that fails: an optional one is dropped from the call (the model did
not get it from the user or a tool, so it is a guess); a required one makes the call fail with a
message back to the model.
"""

from __future__ import annotations

import json
import re
from typing import Any

from ..tools.dates import DateParseError, parse_time

COMPOSED = {("send_mail", "subject"), ("send_mail", "body"), ("create_event", "title")}
ADDRESSES = {("send_mail", "to")}

_STOPWORDS = {
    "the", "and", "for", "from", "with", "all", "any", "my", "your", "our", "his", "her", "their", "this",
    "that", "these", "those", "into", "onto", "about", "please", "you", "it", "them", "its", "are", "was",
    "were", "has", "have", "had", "will", "would", "can", "could", "should", "not", "but", "out", "off",
    "over", "under", "than", "then", "there", "here", "what", "when", "where", "which", "who", "how",
}

_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
_TIME = re.compile(
    r"(?<![\d:.])(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?)(?![a-z])"   # 3pm, 3:30 pm
    r"|(?<![\d:.])(\d{1,2})[:.](\d{2})(?![\d])"                              # 15:30, 3.30
    r"|\b(noon|midday|midnight)\b",
    re.IGNORECASE)
_DIGIT_TOKEN = re.compile(r"[A-Za-z0-9-]*\d[A-Za-z0-9-]*")


class Sources:
    """Everything the model has been told so far in this request."""

    def __init__(self, request: str, results: list[Any]):
        text = request + "\n" + "\n".join(json.dumps(r, ensure_ascii=False) for r in results if r is not None)
        self.text = text.lower()
        self.words = {_stem(w) for w in re.findall(r"[a-z]+", self.text) if len(w) >= 3}
        self.emails = {e.lower() for e in _EMAIL.findall(text)}
        self.times = _times(text)
        rest = _EMAIL.sub(" ", _TIME.sub(" ", text))
        self.tokens = {_norm_token(t) for t in _DIGIT_TOKEN.findall(rest)}
        self.tokens |= {d for t in self.tokens for d in re.findall(r"\d+", t)}
        self.tokens |= {d.lstrip("0") or "0" for d in list(self.tokens) if d.isdigit()}
        self.durations = _durations(self.times)

    def number(self, token: str) -> bool:
        """Is this number (or numeric range or date like 4-9, 2026-03-30) grounded?"""
        t = _norm_token(token)
        if t in self.tokens:
            return True
        if re.fullmatch(r"\d+(?:-\d+)+", t):
            return all((part.lstrip("0") or "0") in self.tokens for part in t.split("-"))
        return t.isdigit() and int(t) in self.durations


def _stem(word: str) -> str:
    return word.lower()[:5]


def _norm_token(token: str) -> str:
    t = re.sub(r"(?<=\d)(st|nd|rd|th)$", "", token.lower().strip("-"))
    return t.lstrip("0") or "0" if t.isdigit() else t


def _times(text: str) -> set[str]:
    """Clock times as HH:MM. A time with no am/pm also yields its pm reading."""
    out = set()
    for m in _TIME.finditer(text):
        if m.group(6):
            out.add({"noon": "12:00", "midday": "12:00", "midnight": "00:00"}[m.group(6).lower()])
            continue
        if m.group(1):
            h, mm, ap = int(m.group(1)), int(m.group(2) or 0), m.group(3).lower()
            if 1 <= h <= 12:
                out.add(f"{h % 12 + (12 if ap.startswith('p') else 0):02d}:{mm:02d}")
            continue
        h, mm = int(m.group(4)), int(m.group(5))
        if h <= 23 and mm <= 59:
            out.add(f"{h:02d}:{mm:02d}")
            if 1 <= h <= 11:
                out.add(f"{h + 12:02d}:{mm:02d}")
    return out


def _durations(times: set[str]) -> set[int]:
    """Minutes between any two grounded times on the same day (later minus earlier)."""
    mins = sorted({int(t[:2]) * 60 + int(t[3:]) for t in times})
    return {b - a for i, a in enumerate(mins) for b in mins[i + 1:]}


def _fact_problems(value: str, src: Sources) -> list[str]:
    """Facts in composed text that no source mentions."""
    problems = []
    for e in _EMAIL.findall(value):
        if e.lower() not in src.emails:
            problems.append(e)
    for m in _TIME.finditer(value):
        if not (_times(m.group(0)) & src.times):
            problems.append(m.group(0).strip())
    rest = _EMAIL.sub(" ", _TIME.sub(" ", value))
    for tok in _DIGIT_TOKEN.findall(rest):
        t = _norm_token(tok)
        if t and not src.number(t):
            problems.append(tok)
    return problems


def _word_problems(value: str, src: Sources) -> list[str]:
    words = [w for w in re.findall(r"[A-Za-z]+", value) if len(w) >= 3 and w.lower() not in _STOPWORDS]
    missing = [w for w in words if _stem(w) not in src.words]
    missing += [p for p in _fact_problems(value, src)]
    return missing


def check(tool: str, args: dict, required: list[str], skip: set[str], src: Sources
          ) -> tuple[dict, dict[str, str], dict[str, str]]:
    """Return (kept args, dropped optional args with reasons, failing required args with reasons)."""
    kept, dropped, failing = {}, {}, {}
    for name, value in args.items():
        problems: list[str] = []
        if name in skip:
            pass
        elif (tool, name) in ADDRESSES:
            # Every address in the value must come from a source; a known one cannot carry an invented one.
            found = [e.lower() for e in _EMAIL.findall(str(value))]
            problems = [e for e in found if e not in src.emails] if found else [str(value)]
        elif (tool, name) in COMPOSED:
            problems = _fact_problems(str(value), src)
        elif isinstance(value, (int, float)) and not isinstance(value, bool):
            if not src.number(str(int(value))):
                problems = [str(value)]
        elif _is_time(value):
            if not (_times(str(value)) & src.times) and _bare_hour(value) not in src.times:
                problems = [str(value)]
        else:
            problems = _word_problems(str(value), src)
        if not problems:
            kept[name] = value
            continue
        reason = f"{', '.join(repr(p) for p in problems[:4])} not in the request or any earlier result"
        if name in required:
            failing[name] = reason
            kept[name] = value
        else:
            dropped[name] = reason
    return kept, dropped, failing


def _is_time(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        parse_time(value)
        return True
    except DateParseError:
        return False


def _bare_hour(value: Any) -> str | None:
    try:
        return parse_time(str(value)).strftime("%H:%M")
    except DateParseError:
        return None
