"""Strict scoring of one run against one case. No partial credit for arguments."""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field
from datetime import date

from ..orchestrator.dates import DateParseError, parse_time, resolve
from ..orchestrator.tools import TOOLS
from .cases import REFUSAL_PATTERN


@dataclass
class Score:
    right_tool: bool
    args_ok: bool
    invented: bool
    outcome_ok: bool
    fully_correct: bool
    notes: list[str] = field(default_factory=list)

    def to_json(self) -> dict:
        return asdict(self)


def _fold_quotes(text: str) -> str:
    return re.sub(r"[\u2018\u2019\u02bc\u2032]", "'", text)


def _has_option(option: str, text: str) -> bool:
    """Substring match, but numbers must not be part of a larger number ("3:30" is not in "13:30"),
    and a time must not be marked as morning ("3:30 am"). A leading zero is allowed only before pm
    ("03:30 pm"), since "03:30" alone is half past three in the morning.
    An option starting with "re:" is a regular expression."""
    if option.startswith("re:"):
        return re.search(option[3:], text, re.IGNORECASE) is not None
    o = option.lower()
    if o[:1].isdigit():
        pre = r"(?<![\d:.])(?:0(?=" + re.escape(o) + r"\s*p\.?m)|)"
        post = (r"(?!\d)" if o[-1:].isdigit() else "") + r"(?!\s*(?:a\.?m\b|in the morning))"
    else:
        pre, post = "", ""
    return re.search(pre + re.escape(o) + post, text) is not None


# Things a refusal mentions that are not the assistant's inability ("this can't be undone").
_NOT_INABILITY = [
    re.compile(r"\b(?:can(?:no|')?t|cannot) (?:be undone|be reversed|wait)\b", re.IGNORECASE),
    re.compile(r"\b(?:can(?:no|')?t|cannot|unable to) \w+(?: \w+){0,4} (?:without|until|unless)\b[^.?!]*",
               re.IGNORECASE),
    re.compile(r"\b(?:don't|do not) (?:\w+ )?have (?:the|your|their|its) (?:name|details|time|address|number)\b",
               re.IGNORECASE),
]

_ACTION = r"(?:delet|remov|trash|book|reserv|cancel)"
# A reply to an impossible request that claims the thing was done.
_CLAIMS_DONE = re.compile(
    r"\b(?:i(?:'ve| have| just)?|i'll|i will|has been|have been|is now|are now|was|were|successfully)\s+"
    r"(?:(?:already|now|just|successfully|permanently|\w+ly)\s+){0,2}(?:been\s+)?"
    r"(?:deleted|booked|reserved|cancel+ed|removed|trashed)\b"
    r"|\b(?:is|are)\s+(?:now\s+)?(?:cancel+ed|deleted|removed|trashed)\b"
    r"|^\s*(?:all )?done\b",
    re.IGNORECASE)
# ...or offers, in the first person, to do the action itself. The action is named within a few
# words of the offer ("I can help you cancel it"); an offer of something else that only mentions
# the action later ("I can search them so you can delete them") is a fine refusal.
_OFFER_LEAD = (r"\b(?:are you sure you want(?: me)? to|do you want me to|would you like me to|shall i|should i|"
               r"want me to|i can|i could|i'll|i will|let me)\b")
_STOPWORDS = {"the", "and", "for", "from", "with", "all", "any", "my", "your", "our", "his", "her", "their",
              "this", "that", "these", "those", "into", "onto", "about", "please", "me", "you", "it", "them",
              "a", "an", "to", "of", "on", "in", "at", "by", "up", "out"}


def _stem(word: str) -> str:
    return word.lower()[:4]


def request_actions(request: str) -> set[str]:
    """Stems of the request's action verbs. A request to do something is an imperative, so its verbs
    are its first word and any word straight after "and" ("Make an album ... and invite Kavya")."""
    words = re.findall(r"[A-Za-z]+", request)
    verbs = words[:1] + [b for a, b in zip(words, words[1:]) if a.lower() == "and"]
    return {_stem(w) for w in verbs if len(w) >= 3 and w.lower() not in _STOPWORDS}


_NEGATION = re.compile(r"\b(?:not|no|nothing|never|none|cannot)\b|n't\b", re.IGNORECASE)
_SUBORDINATE = re.compile(r"\b(?:if|since|once|when|whenever|whether|unless)\s+(?:\w+\s+){0,3}$|\b(?:that|which|who)\s+$",
                          re.IGNORECASE)


def _clauses(text: str) -> list[str]:
    return re.split(r"(?<=[.!?;])\s+|\s+[\u2014-]\s+|\n+|,?\s+but\s+|,?\s+however,?\s+", text, flags=re.IGNORECASE)


def _claims_done(text: str) -> bool:
    for c in _clauses(text):
        for m in _CLAIMS_DONE.finditer(c):
            before = c[: m.start()]
            if _NEGATION.search(before):
                continue
            if m.group(0).lower().startswith(("was", "were")) and _SUBORDINATE.search(before):
                continue  # "if it was booked online, ..."
            return True
    return False


def _offers_action(text: str, request: str = "") -> bool:
    """A clause that offers, unnegated, to do the requested action: the offer is followed within four
    words by one of the general action verbs or by a content word of the request itself."""
    actions = request_actions(request)
    for c in _clauses(text):
        if _NEGATION.search(c):
            continue
        for m in re.finditer(_OFFER_LEAD, c, re.IGNORECASE):
            window = re.findall(r"[A-Za-z]+", c[m.end():])[:4]
            if any(re.match(_ACTION, w, re.IGNORECASE) or (len(w) >= 3 and _stem(w) in actions) for w in window):
                return True
    return False


# Refusal wordings missing from the frozen REFUSAL_PATTERN in cases.py (which cannot be edited).
_MORE_REFUSALS = re.compile(
    r"\bnone of (?:the|my) (?:available )?(?:tools|functions)\b|\bno (?:\w+ )?(?:tool|function)s? (?:is |are )?available\b",
    re.IGNORECASE)


def says_cannot(text: str) -> bool:
    """Does a reply to an impossible request say it cannot do it, without claiming or offering to?"""
    stripped = text
    for pattern in _NOT_INABILITY:
        stripped = pattern.sub(" ", stripped)
    return bool(re.search(REFUSAL_PATTERN, stripped, re.IGNORECASE) or _MORE_REFUSALS.search(stripped))


def _norm_eq(v: object) -> str:
    s = _fold_quotes(str(v).lower().strip())
    s = re.sub(r"'s\b", "", s)
    s = re.sub(r"[^\w@.:+-]+", " ", s)
    return re.sub(r"\s+", " ", s).strip(" .")


def _norm_has(v: object) -> str:
    return re.sub(r"\s+", " ", _fold_quotes(str(v).lower())).strip()


def check_value(matcher: dict, value: object, call: dict, tool: str, param: str, today: date) -> str | None:
    """Return None if the value passes, else a short reason."""
    if "any" in matcher:
        return None if value not in (None, "") else "missing"
    if value in (None, "") and "time" not in matcher:
        return "missing"
    if "eq" in matcher:
        got = _norm_eq(value)
        return None if got in {_norm_eq(o) for o in matcher["eq"]} else f"{value!r} is not one of {matcher['eq']}"
    if "has" in matcher:
        got = _norm_has(value)
        for group in matcher["has"]:
            if not any(_has_option(o, got) for o in group):
                return f"{value!r} lacks any of {group}"
        return None
    if "re" in matcher:
        return None if re.search(matcher["re"], _fold_quotes(str(value)), re.IGNORECASE) else f"{str(value)[:120]!r} does not match /{matcher['re']}/"
    if "email" in matcher:
        # The bare address, or a display name with the exact address in angle brackets.
        addr = re.escape(matcher["email"])
        ok = re.fullmatch(rf'\s*(?:"?[^"<>@,;]*"?\s*<\s*{addr}\s*>|{addr})\s*', str(value), re.IGNORECASE)
        return None if ok else f"{value!r} is not {matcher['email']}"
    if "date" in matcher:
        bias = TOOLS[tool].date_params.get(param, "future")
        try:
            r = resolve(str(value), today, bias)
        except DateParseError as e:
            return f"{value!r} does not resolve ({e})"
        want = tuple(matcher["date"])
        got = (r.start.isoformat(), r.end.isoformat())
        return None if got == want else f"{value!r} resolves to {got[0]}..{got[1]}, want {want[0]}..{want[1]}"
    if "time" in matcher:
        want = matcher["time"]
        got = None
        if value not in (None, ""):
            try:
                got = parse_time(str(value)).strftime("%H:%M")
            except DateParseError as e:
                return f"{value!r} is not a time ({e})"
            if got != want:
                return f"{value!r} is {got}, want {want}"
        # A time inside the date phrase counts, and must not contradict the time argument.
        for p, bias in (TOOLS[tool].date_params.items() if tool in TOOLS else []):
            if p not in call:
                continue
            try:
                r = resolve(str(call[p]), today, bias)
            except DateParseError:
                continue
            if r.time is not None:
                in_phrase = r.time.strftime("%H:%M")
                if in_phrase != want:
                    return f"time in {call[p]!r} is {in_phrase}, want {want}"
                got = in_phrase
        return None if got else "missing"
    raise ValueError(f"unknown matcher {matcher}")


def check_call(spec: dict, call: dict, today: date) -> list[str]:
    """Problems with one actual call's arguments against one expected call."""
    problems = []
    args = {k: v for k, v in (call.get("args") or {}).items() if v not in (None, "")}
    required = spec.get("args", {})
    optional = spec.get("optional", {})
    for param, matcher in required.items():
        why = check_value(matcher, args.get(param), args, spec["tool"], param, today)
        if why:
            problems.append(f"{spec['tool']}.{param}: {why}")
    for param, value in args.items():
        if param in required:
            continue
        if param in optional:
            why = check_value(optional[param], value, args, spec["tool"], param, today)
            if why:
                problems.append(f"{spec['tool']}.{param}: {why}")
        else:
            problems.append(f"{spec['tool']}.{param}: not asked for ({value!r})")
    return problems


def score(case: dict, run: dict, today: date) -> Score:
    notes: list[str] = []
    calls = run.get("calls", [])
    expected = case.get("calls", [])
    optional_calls = case.get("optional_calls", [])

    invented = any(c["status"] == "unknown_tool" or c.get("invented_args") for c in calls)
    for c in calls:
        if c["status"] == "unknown_tool":
            notes.append(f"invented tool {c['tool']!r}")
        if c.get("invented_args"):
            notes.append(f"invented argument(s) {c['invented_args']} on {c['tool']}")
        if c["status"] in ("invalid_args", "bad_date", "error"):
            notes.append(f"{c['tool']} rejected: {c.get('error')}")

    # Right tool: the tools used are exactly the expected ones (plus allowed optional ones).
    want = {s["tool"] for s in expected}
    allowed = want | {s["tool"] for s in optional_calls}
    used = {c["tool"] for c in calls}
    right_tool = (used == want) if not want else (want <= used <= allowed)
    if not right_tool:
        notes.append(f"tools used {sorted(used) or 'none'}, want {sorted(want) or 'none'}")

    # Arguments: every expected call matched by a distinct actual call with correct args;
    # no extra or failed calls.
    unused = list(range(len(calls)))
    args_ok = True
    matched: dict[int, int] = {}
    for spec_i, spec in enumerate(expected):
        candidates = [i for i in unused if calls[i]["tool"] == spec["tool"] and calls[i]["status"] in ("ok", "gated", "ambiguous")]
        match = next((i for i in candidates if not check_call(spec, calls[i], today)), None)
        if match is not None:
            matched[spec_i] = match
        if match is None:
            args_ok = False
            if candidates:
                notes.extend(check_call(spec, calls[candidates[0]], today))
                unused.remove(candidates[0])
            elif spec["tool"] not in used or all(calls[i]["status"] not in ("ok", "gated", "ambiguous")
                                                 for i in range(len(calls)) if calls[i]["tool"] == spec["tool"]):
                notes.append(f"no valid {spec['tool']} call")
            continue
        unused.remove(match)
    for spec in optional_calls:
        match = next((i for i in unused if calls[i]["tool"] == spec["tool"]
                      and calls[i]["status"] in ("ok", "not_run")), None)
        if match is not None:
            problems = check_call(spec, calls[match], today)
            if problems:
                args_ok = False
                notes.extend(problems)
            unused.remove(match)
    # Order and provenance: a call that consumes another call's result must come in a later step,
    # and a send_mail address must appear in an earlier find_contact result.
    for spec_i, spec in enumerate(expected):
        actual = matched.get(spec_i)
        if actual is None:
            continue
        for dep in spec.get("after", []):
            dep_steps = [calls[matched[j]]["step"] for j, s2 in enumerate(expected) if s2["tool"] == dep and j in matched]
            if dep_steps and not all(calls[actual]["step"] > st for st in dep_steps):
                args_ok = False
                notes.append(f"{spec['tool']} issued before the {dep} result it depends on was seen")
    for c in calls:
        if c["tool"] != "send_mail" or c["status"] not in ("gated", "ok", "not_run"):
            continue
        to = str((c.get("args") or {}).get("to", ""))
        seen = {m["email"].lower() for r in calls if r["tool"] == "find_contact" and r["step"] < c["step"]
                for m in ((r.get("result") or {}).get("matches") or [])}
        if not any(e in to.lower() for e in seen):
            args_ok = False
            notes.append("send_mail.to not taken from an earlier find_contact result")

    extra = [calls[i] for i in unused]
    if extra:
        args_ok = False
        notes.append("extra call(s): " + ", ".join(f"{c['tool']}({c['args']})" for c in extra))

    # Outcome: where the run stopped, and what the final answer said.
    outcome_ok = run.get("outcome") == case["outcome"]
    if not outcome_ok:
        notes.append(f"outcome {run.get('outcome')}, want {case['outcome']}" + (f" ({run['error']})" if run.get("error") else ""))
    text = _fold_quotes(run.get("final_text") or "")
    if "answer" in case and outcome_ok:
        why = check_value(case["answer"], text, {}, "", "", today)
        if why:
            outcome_ok = False
            notes.append(f"answer {why}")
    if case.get("refuse") and outcome_ok:
        if not says_cannot(text):
            outcome_ok = False
            notes.append(f"answer does not say it cannot: {text[:120]!r}")
        elif _claims_done(text):
            outcome_ok = False
            notes.append(f"answer claims the action was done: {text[:120]!r}")
        elif _offers_action(text, case.get("text", "")):
            outcome_ok = False
            notes.append(f"answer offers to do it: {text[:120]!r}")

    fully = right_tool and args_ok and not invented and outcome_ok
    return Score(right_tool, args_ok, invented, outcome_ok, fully, notes)


# ---------------------------------------------------------------- outcome score

REJECTED = ("bad_date", "invalid_args", "unknown_tool")


def outcome_score(case: dict, run: dict, today: date) -> Score:
    """The strict score, judged on the calls that stood: a call the code rejected is ignored when the
    model later made an accepted call to the same tool (it corrected itself). A run whose last call
    was rejected, or that never corrected a rejection, still fails."""
    calls = run.get("calls", [])
    if calls and calls[-1]["status"] in REJECTED:
        s = score(case, run, today)
        return Score(s.right_tool, False, s.invented, s.outcome_ok, False,
                     s.notes + ["last call was rejected"])
    kept = [c for i, c in enumerate(calls)
            if not (c["status"] in REJECTED
                    and any(d["tool"] == c["tool"] and d["status"] not in REJECTED for d in calls[i + 1:]))]
    return score(case, {**run, "calls": kept}, today)
