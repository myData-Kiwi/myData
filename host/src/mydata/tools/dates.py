"""Resolve natural date phrases to concrete dates.

The model passes dates exactly as the user said them ("next friday",
"last December", "tomorrow at 3pm"). This module turns a phrase into an
inclusive date range, plus a time of day when the phrase carries one, given a
fixed "today". No model is involved.

Conventions (documented so they can be argued with, not guessed at):

- Weeks run Monday to Sunday.
- "this <weekday>" is that day in the current week; "next <weekday>" is that
  day in next week; "last <weekday>" is that day in the previous week.
  On Wednesday 18 March 2026: this Friday = 20 March, next Friday = 27 March,
  last Friday = 13 March.
- A bare weekday ("friday") is the next one after today with a future bias,
  the most recent one before today with a past bias.
- "this/next/last weekend" follow the same week rule: Saturday and Sunday of
  the current, next or previous week.
- "last N days/weeks/months" and "past N ..." are rolling windows ending today.
  "last week" alone is the previous calendar week.
- A bare month ("december") is the most recent occurrence not after the
  current month with a past bias, the next occurrence not before it with a
  future bias. "last december" is the most recent December strictly before the
  current month; "next december" the soonest strictly after it.
- Day-and-month without a year, and "the 27th", follow the bias the same way.
- A range whose ends, read alone, come out backwards ("monday to friday" on a
  Wednesday reads Monday as next week but Friday as this week) is re-read
  both ways; the reading that contains today wins, else the end is read
  forward from the start. Spans over 183 days are rejected.
- An hour without am/pm ("at 8") is morning unless the phrase says
  afternoon, evening, night or tonight. "tonight at 12" is rejected.
- Numeric dates other than ISO (3/4/2026) are rejected: day-month order is
  ambiguous.
"""

from __future__ import annotations

import calendar
import re
from dataclasses import dataclass
from datetime import date, time, timedelta
from typing import Literal

Bias = Literal["past", "future"]


class DateParseError(ValueError):
    """The phrase could not be resolved. The message is safe to show the model."""


@dataclass(frozen=True)
class Resolved:
    start: date
    end: date  # inclusive
    time: time | None = None

    def to_json(self) -> dict:
        out = {"start": self.start.isoformat(), "end": self.end.isoformat()}
        if self.time is not None:
            out["time"] = self.time.strftime("%H:%M")
        return out


WEEKDAYS = {
    "monday": 0, "mon": 0,
    "tuesday": 1, "tue": 1, "tues": 1,
    "wednesday": 2, "wed": 2,
    "thursday": 3, "thu": 3, "thur": 3, "thurs": 3,
    "friday": 4, "fri": 4,
    "saturday": 5, "sat": 5,
    "sunday": 6, "sun": 6,
}

MONTHS = {name.lower(): i for i, name in enumerate(calendar.month_name) if name}
MONTHS |= {abbr.lower(): i for i, abbr in enumerate(calendar.month_abbr) if abbr}
MONTHS["sept"] = 9

NUMBER_WORDS = {
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
    "twelve": 12, "fourteen": 14, "thirty": 30, "couple": 2, "a couple": 2,
    "couple of": 2, "a couple of": 2, "few": 3, "a few": 3,
}

_WD = "|".join(sorted(WEEKDAYS, key=len, reverse=True))
_MON = "|".join(sorted(MONTHS, key=len, reverse=True))
_NUM = r"\d+|" + "|".join(sorted((re.escape(k) for k in NUMBER_WORDS), key=len, reverse=True))
_ORD = r"(\d{1,2})(?:st|nd|rd|th)?"
_UNIT = r"(day|week|month|year)s?"


# ---------------------------------------------------------------- times


_TIME_12H = re.compile(r"(?<![\d.:])\b(?:at\s+)?(\d{1,2})(?:[:.]([0-5]\d))?\s*(a\.?m\.?|p\.?m\.?)(?=\W|$)")
_TIME_24H = re.compile(r"\b(?:at\s+)?([01]?\d|2[0-3])[:.]([0-5]\d)\b")
_TIME_WORDS = {"noon": time(12, 0), "midday": time(12, 0), "midnight": time(0, 0)}
_TIME_WORD = re.compile(r"\b(?:at\s+)?(?:12\s*)?(noon|midday|midnight)\b")
# A bare hour only counts at the end after "at" ("tomorrow at 9", "at 7 in the evening"),
# so "at 1 april" is not a time.
_TIME_AT_HOUR = re.compile(
    r"\bat\s+([01]?\d|2[0-3])(?:\s*o'?clock)?(?=\s+(?:in the\s+)?(?:morning|afternoon|evening|night)$|$)")
_LATER_IN_DAY = re.compile(r"\b(?:afternoon|evening|night|tonight)\b")
_TIME_OCLOCK = re.compile(r"\b([01]?\d|2[0-3])\s*o'?clock\b")


def _time_from_match(m: re.Match, twelve_hour: bool) -> time:
    hour = int(m.group(1))
    minute = int(m.group(2) or 0)
    if twelve_hour:
        if not 1 <= hour <= 12:
            raise DateParseError(f"'{m.group(0).strip()}' is not a valid time")
        pm = m.group(3).startswith("p")
        hour = hour % 12 + (12 if pm else 0)
    return time(hour, minute)


def _extract_time(text: str) -> tuple[str, time | None, bool]:
    """Pull one time of day out of text. Returns (remaining text, time, explicit).

    explicit is False for an hour that could be morning or evening ("at 8", "8:30")."""
    def cut(m: re.Match) -> str:
        return (text[: m.start()] + " " + text[m.end():]).strip()

    m = _TIME_12H.search(text)
    if m:
        return cut(m), _time_from_match(m, True), True
    m = _TIME_24H.search(text)
    if m:
        t = _time_from_match(m, False)
        return cut(m), t, not 1 <= t.hour <= 12 or m.group(1).startswith("0")
    m = _TIME_WORD.search(text)
    if m:
        return cut(m), _TIME_WORDS[m.group(1)], True
    for pattern in (_TIME_AT_HOUR, _TIME_OCLOCK):
        m = pattern.search(text)
        if m:
            t = time(int(m.group(1)), 0)
            return cut(m), t, not 1 <= t.hour <= 12
    return text, None, False


def parse_time(text: str) -> time:
    """Parse a time-of-day argument ("3pm", "15:30", "noon", "9")."""
    s = _normalize(text)
    rest, t, _ = _extract_time(s)
    if t is not None and not rest.strip():
        return t
    m = re.fullmatch(r"(?:at\s+)?([01]?\d|2[0-3])(?:\s*o'?clock)?", s)
    if m:
        return time(int(m.group(1)), 0)
    raise DateParseError(f"could not understand the time '{text}'")


# ---------------------------------------------------------------- helpers


def _normalize(text: str) -> str:
    s = text.lower().strip()
    s = s.replace("’", "'").replace("‘", "'")
    s = re.sub(r"[,;!?]", " ", s)
    s = re.sub(r"\.(?=\s|$)", " ", s)  # sentence full stops, not "a.m."
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _week_start(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _month_range(year: int, month: int) -> tuple[date, date]:
    last = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, last)


def _add_months(d: date, months: int) -> date:
    idx = d.year * 12 + (d.month - 1) + months
    year, month = divmod(idx, 12)
    month += 1
    return date(year, month, min(d.day, calendar.monthrange(year, month)[1]))


def _num(word: str) -> int:
    word = word.strip()
    if word.isdigit():
        return int(word)
    if word in NUMBER_WORDS:
        return NUMBER_WORDS[word]
    raise DateParseError(f"could not understand the number '{word}'")


def _day(d: date) -> tuple[date, date]:
    return d, d


def _safe_date(year: int, month: int, day: int, phrase: str) -> date:
    try:
        return date(year, month, day)
    except ValueError:
        raise DateParseError(f"'{phrase}' is not a real date") from None


def _month_day(month: int, day: int, year: int | None, today: date, bias: Bias, phrase: str) -> date:
    if year is not None:
        return _safe_date(year, month, day, phrase)
    this_year = _safe_date(today.year, month, day, phrase) if day <= calendar.monthrange(today.year, month)[1] else None
    if bias == "future":
        if this_year and this_year >= today:
            return this_year
        return _safe_date(today.year + 1, month, day, phrase)
    if this_year and this_year <= today:
        return this_year
    return _safe_date(today.year - 1, month, day, phrase)


def _bare_month(month: int, today: date, bias: Bias, qualifier: str | None) -> int:
    """Return the year for a month name with an optional this/last/next."""
    if qualifier == "this":
        return today.year
    if qualifier in ("last", "previous", "past"):
        return today.year if month < today.month else today.year - 1
    if qualifier in ("next", "coming"):
        return today.year if month > today.month else today.year + 1
    if bias == "future":
        return today.year if month >= today.month else today.year + 1
    return today.year if month <= today.month else today.year - 1


# ---------------------------------------------------------------- core


_STRIP_PREFIX = re.compile(r"^(?:on|for|from|during|in|by|at|of)\s+")
_THE = re.compile(r"^the\s+(?=(?:day|week|weekend|coming|next|last|past|previous|this|\d))")
_PART_OF_DAY = re.compile(r"\b(?:in the |this )?(morning|afternoon|evening|night)\b")


def resolve(phrase: str, today: date, bias: Bias = "future") -> Resolved:
    """Resolve a natural date phrase. Raises DateParseError if it cannot."""
    if not isinstance(phrase, str) or not phrase.strip():
        raise DateParseError("empty date")
    if len(phrase) > 200:
        raise DateParseError("the date phrase is too long")
    try:
        return _resolve(phrase, today, bias)
    except DateParseError:
        raise
    except (ValueError, OverflowError, RecursionError):
        raise DateParseError(f"'{phrase}' is out of range") from None


def _resolve(phrase: str, today: date, bias: Bias) -> Resolved:
    s = _normalize(phrase)
    s, t, explicit = _extract_time(s)
    if t is not None and not explicit and _LATER_IN_DAY.search(s):
        # "tonight at 8", "tomorrow afternoon at 3": an hour without am/pm is in the afternoon or evening.
        if t.hour == 12:
            raise DateParseError(f"'{phrase}': is 12 noon or midnight?")
        t = t.replace(hour=t.hour + 12)

    # A range: "from X to Y", "X to Y", "between X and Y", "X - Y" (dash with spaces).
    m = re.fullmatch(r"(?:from |between )?(.+?)(?:\s+(?:to|until|till|through|and)\s+|\s+[-\u2013\u2014]\s+)(.+)", s)
    if m and not re.search(r"\bday (?:after|before)\b", s):
        try:
            start, end = _range(m.group(1), m.group(2), today, bias, phrase)
        except DateParseError as e:
            if "ends before it starts" in str(e):
                raise
        else:
            return Resolved(start, end, t)

    start, end = _resolve_core(s, today, bias, phrase)
    return Resolved(start, end, t)


def _share_context(x: str, y: str) -> tuple[str, str]:
    """Let qualifiers English applies to both ends of a range reach both ends."""
    x, y = x.strip(), y.strip()
    bare_day = r"(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?"
    # "the 20th to the 25th of april"
    m = re.fullmatch(rf".*?\d{{1,2}}(?:st|nd|rd|th)?\s+(?:of\s+)?((?:{_MON})(?:\s+\d{{4}})?)", y)
    if m and re.fullmatch(bare_day, x):
        x = f"{x} of {m.group(1)}"
    # "thursday to friday next week"
    m = re.fullmatch(rf"(?:{_WD})\s+((?:of\s+)?(?:the\s+)?(?:this|next|last|previous) week)", y)
    if m and re.fullmatch(rf"(?:{_WD})", x):
        x = f"{x} {m.group(1)}"
    # "march 20 to 25"
    m = re.fullmatch(rf"({_MON})\s+\d{{1,2}}(?:st|nd|rd|th)?(?:\s+(\d{{4}}))?", x)
    if m and re.fullmatch(r"\d{1,2}(?:st|nd|rd|th)?", y):
        y = f"{m.group(1)} {y}" + (f" {m.group(2)}" if m.group(2) else "")
    # "january to march 2025", "december to february 2026"
    m = re.fullmatch(rf"({_MON})\s+(\d{{4}})", y)
    if m and re.fullmatch(rf"(?:{_MON})", x):
        year = int(m.group(2)) - (1 if MONTHS[x] > MONTHS[m.group(1)] else 0)
        x = f"{x} {year}"
    return x, y


def _range(x: str, y: str, today: date, bias: Bias, phrase: str) -> tuple[date, date]:
    x, y = _share_context(x, y)
    a = _resolve_core(x, today, bias, phrase)
    b = _resolve_core(y, today, bias, phrase)
    if a[0] <= b[1]:
        return a[0], b[1]
    # Read wrongly in isolation ("monday to friday", "march 4 to today"): try the end relative to
    # the start, and the start relative to the end. Prefer a reading that contains today.
    candidates = []
    try:
        candidates.append((a[0], _resolve_core(y, a[0], "future", phrase)[1]))
    except DateParseError:
        pass
    try:
        candidates.append((_resolve_core(x, b[1], "past", phrase)[0], b[1]))
    except DateParseError:
        pass
    valid = [c for c in candidates if c[0] <= c[1] and (c[1] - c[0]).days <= 183]
    if not valid:
        raise DateParseError(f"'{phrase}' ends before it starts")
    return next((c for c in valid if c[0] <= today <= c[1]), valid[0])


def _resolve_core(s: str, today: date, bias: Bias, phrase: str) -> tuple[date, date]:
    s = s.strip()
    m = re.fullmatch(rf"in\s+({_NUM})\s+{_UNIT}(?:'s time| time)?", s)
    if m:
        return _day(_shift(today, _num(m.group(1)), m.group(2)))
    s = _THE.sub("", s)
    while True:
        new = _THE.sub("", _STRIP_PREFIX.sub("", s))
        if new == s:
            break
        s = new
    m = _PART_OF_DAY.search(s)
    if m:
        rest = (s[: m.start()] + s[m.end():]).strip()
        if m.group(1) == "night" and not rest:
            rest = "today"
        s = rest or "today"
    s = re.sub(r"\btonight\b", "today", s).strip()
    if not s:
        raise DateParseError(f"could not understand the date '{phrase}'")

    # ISO date
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        return _day(_safe_date(int(m.group(1)), int(m.group(2)), int(m.group(3)), phrase))

    if re.fullmatch(r"\d{1,2}[/.]\d{1,2}(?:[/.]\d{2,4})?", s):
        raise DateParseError(f"'{phrase}' is ambiguous (day/month order); use a month name")

    simple = {
        "today": 0, "now": 0, "tomorrow": 1, "tmrw": 1, "tmr": 1, "yesterday": -1,
        "day after tomorrow": 2, "day before yesterday": -2,
    }
    if s in simple:
        return _day(today + timedelta(days=simple[s]))

    # Weekday forms
    m = re.fullmatch(
        rf"(this coming|this past|this|next|last|coming|previous|past)?\s*({_WD})"
        rf"(?:\s+(?:of\s+|in\s+)?(?:the\s+)?(this|next|last|previous) week)?", s)
    if m:
        qual, wd_name, week_qual = m.group(1), m.group(2), m.group(3)
        qual = {"this coming": "coming", "this past": "past"}.get(qual, qual)
        wd = WEEKDAYS[wd_name]
        if qual and week_qual:
            raise DateParseError(f"'{phrase}' is contradictory")
        if week_qual:
            qual = week_qual
        return _day(_weekday(wd, qual, today, bias))
    m = re.fullmatch(rf"(this|next|last|previous) week(?:'s)?\s+({_WD})", s)
    if m:
        return _day(_weekday(WEEKDAYS[m.group(2)], m.group(1), today, bias))
    m = re.fullmatch(rf"({_WD})\s+(?:the\s+)?(.+)", s)
    if m:
        # "saturday the 4th of april", "friday march 27": resolve the rest, check the weekday.
        if re.match(rf"(?:{_WD})\b", m.group(2)):
            raise DateParseError(f"could not understand the date '{phrase}'")
        start, end = _resolve_core(m.group(2), today, bias, phrase)
        if start != end:
            raise DateParseError(f"could not understand the date '{phrase}'")
        if start.weekday() != WEEKDAYS[m.group(1)]:
            raise DateParseError(f"'{phrase}' names a weekday that does not match the date")
        return start, end

    # Weeks and weekends
    if s in ("week after next", "the week after next"):
        ws = _week_start(today) + timedelta(weeks=2)
        return ws, ws + timedelta(days=6)
    m = re.fullmatch(r"(this coming|this past|this|next|last|previous|coming|past)?\s*(week|weekend)", s)
    if m and not (m.group(1) == "past" and m.group(2) == "week"):  # "past week" is a rolling window, below
        qual = m.group(1) or "this"
        offset = {"this": 0, "coming": 0, "this coming": 0, "next": 1, "last": -1, "previous": -1,
                  "past": -1, "this past": -1}[qual]
        ws = _week_start(today) + timedelta(weeks=offset)
        if m.group(2) == "week":
            return ws, ws + timedelta(days=6)
        return ws + timedelta(days=5), ws + timedelta(days=6)

    # Months and years by qualifier
    m = re.fullmatch(r"(this|next|last|previous)\s+(month|year)", s)
    if m:
        offset = {"this": 0, "next": 1, "last": -1, "previous": -1}[m.group(1)]
        if m.group(2) == "month":
            first = _add_months(today.replace(day=1), offset)
            return _month_range(first.year, first.month)
        y = today.year + offset
        return date(y, 1, 1), date(y, 12, 31)

    # Forward window: "the next two weeks", "coming 10 days"
    m = re.fullmatch(rf"(?:next|coming)\s+({_NUM})\s+{_UNIT}", s)
    if m:
        return today, _shift(today, _num(m.group(1)), m.group(2))

    # Rolling windows: "last 2 weeks", "past 10 days", "past week", "the last couple of days"
    m = re.fullmatch(rf"(?:last|past|previous)\s+({_NUM})\s+{_UNIT}", s)
    if m:
        n = _num(m.group(1))
        return _rolling(n, m.group(2), today), today
    m = re.fullmatch(rf"(?:past)\s+{_UNIT}", s)
    if m:
        return _rolling(1, m.group(1), today), today

    # Relative points: "in 3 days", "2 weeks ago", "ten days from now"
    m = re.fullmatch(rf"in\s+({_NUM})\s+{_UNIT}", s)
    if m:
        return _day(_shift(today, _num(m.group(1)), m.group(2)))
    m = re.fullmatch(rf"({_NUM})\s+{_UNIT}\s+(?:from now|from today|later|time)", s)
    if m:
        return _day(_shift(today, _num(m.group(1)), m.group(2)))
    m = re.fullmatch(rf"({_NUM})\s+{_UNIT}\s+ago", s)
    if m:
        return _day(_shift(today, -_num(m.group(1)), m.group(2)))

    # Month + day: "march 25", "march 25th 2026", "25 march", "25th of march 2026"
    m = re.fullmatch(rf"({_MON})\s+{_ORD}(?:\s+(\d{{4}}))?", s)
    if m:
        d = _month_day(MONTHS[m.group(1)], int(m.group(2)), _opt_int(m.group(3)), today, bias, phrase)
        return _day(d)
    m = re.fullmatch(rf"{_ORD}\s+(?:of\s+)?({_MON})(?:\s+(\d{{4}}))?", s)
    if m:
        d = _month_day(MONTHS[m.group(2)], int(m.group(1)), _opt_int(m.group(3)), today, bias, phrase)
        return _day(d)

    # Day of month alone: "the 27th", "27th"
    m = re.fullmatch(r"(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)", s)
    if m:
        return _day(_day_of_month(int(m.group(1)), today, bias, phrase))

    # Month with a relative year: "december last year", "dec of this year"
    m = re.fullmatch(rf"({_MON})\s+(?:of\s+)?(this|last|next|previous) year", s)
    if m:
        offset = {"this": 0, "next": 1, "last": -1, "previous": -1}[m.group(2)]
        return _month_range(today.year + offset, MONTHS[m.group(1)])

    # Month, optionally qualified, optionally with a year
    m = re.fullmatch(
        rf"(this coming|this past|this|next|last|previous|past|coming)?\s*({_MON})(?:\s+(?:of\s+)?(\d{{4}}))?", s)
    if m:
        month = MONTHS[m.group(2)]
        qual = {"this coming": "next", "this past": "last"}.get(m.group(1), m.group(1))
        if m.group(3):
            year = int(m.group(3))
            if qual and _bare_month(month, today, bias, qual) != year:
                raise DateParseError(f"'{phrase}' is contradictory")
        else:
            year = _bare_month(month, today, bias, qual)
        return _month_range(year, month)

    # Year
    m = re.fullmatch(r"(\d{4})", s)
    if m:
        y = int(m.group(1))
        return date(y, 1, 1), date(y, 12, 31)

    raise DateParseError(f"could not understand the date '{phrase}'")


def _opt_int(s: str | None) -> int | None:
    return int(s) if s else None


def _weekday(wd: int, qual: str | None, today: date, bias: Bias) -> date:
    ws = _week_start(today)
    if qual == "this":
        return ws + timedelta(days=wd)
    if qual == "next":
        return ws + timedelta(weeks=1, days=wd)
    if qual in ("last", "previous"):
        return ws - timedelta(weeks=1) + timedelta(days=wd)
    if qual == "coming" or (qual is None and bias == "future"):
        delta = (wd - today.weekday()) % 7 or 7
        return today + timedelta(days=delta)
    # bare weekday, past bias, or "past friday"
    delta = (today.weekday() - wd) % 7 or 7
    return today - timedelta(days=delta)


def _day_of_month(day: int, today: date, bias: Bias, phrase: str) -> date:
    if not 1 <= day <= 31:
        raise DateParseError(f"'{phrase}' is not a real date")
    first = today.replace(day=1)
    for step in range(0, 13):
        month_first = _add_months(first, step if bias == "future" else -step)
        if day > calendar.monthrange(month_first.year, month_first.month)[1]:
            continue
        d = month_first.replace(day=day)
        if (bias == "future" and d >= today) or (bias == "past" and d <= today):
            return d
    raise DateParseError(f"could not understand the date '{phrase}'")


def _shift(d: date, n: int, unit: str) -> date:
    if unit == "day":
        return d + timedelta(days=n)
    if unit == "week":
        return d + timedelta(weeks=n)
    if unit == "month":
        return _add_months(d, n)
    return _add_months(d, 12 * n)


def _rolling(n: int, unit: str, today: date) -> date:
    return _shift(today, -n, unit)
