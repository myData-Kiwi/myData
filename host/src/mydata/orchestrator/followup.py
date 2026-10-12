"""After a tool's result is on screen: is another model call needed, and does the user need a sentence?

A list of events, emails, contacts or photos usually answers the request by itself; code shows it at once
(present.py). A model-written sentence is only wanted when the request is a question the list does not
answer by itself ("Am I free at 3 on Friday?"). Two ways to decide, measured against each other:

- "field": every non-irreversible tool gets one optional control argument, `then`, filled in on the
  tool-choice call: "show" (the result answers the user: no further call), "answer" (write one short
  sentence from the result), "continue" (another tool is needed). The engine removes it before the call
  reaches the tool layer. Missing means "continue" (the old behaviour).
- "rule": code decides from the request's words whether a sentence is needed. It cannot know whether a
  chain continues, so the next call is still made but stopped at its first text when no sentence is
  needed; if the model calls another tool instead, the chain goes on.
- "full": the old behaviour: always let the model write the reply.
"""

from __future__ import annotations

import copy
import re

MODES = ("full", "rule", "field")

THEN = "then"
THEN_SCHEMA = {
    "type": "string",
    "enum": ["show", "answer", "continue"],
    "description": (
        "What happens after this call. 'show': the result itself answers the user (they asked to see or find "
        "events, emails, contacts or photos), so it is shown as a list and nothing else is needed. 'answer': "
        "the user asked a question the result alone does not answer (for example whether they are free, or "
        "whether two things clash), so you will reply in one short sentence. 'continue': you need another tool "
        "call after this one."
    ),
}

# Appended after the tool result (never in the cached prefix) when a sentence is wanted.
ANSWER_INSTRUCTION = (
    "The result above is already shown to the user as a list. Answer their question in one short sentence of "
    "at most 25 words, using only that result. Do not repeat the list."
)

# About 40 tokens: the streamed sentence is stopped after this many text pieces.
ANSWER_MAX_PIECES = 40


def with_then(definitions: list[dict], irreversible: set[str]) -> list[dict]:
    """Tool definitions with the `then` control argument on every tool that can end a request."""
    out = copy.deepcopy(definitions)
    for d in out:
        fn = d["function"]
        if fn["name"] not in irreversible:
            fn["parameters"]["properties"][THEN] = THEN_SCHEMA
    return out


# Questions the list does not answer by itself: availability and clashes, yes/no about a specific time,
# reasons, advice, comparisons and amounts that need working out.
_NEEDS_SENTENCE = re.compile(
    r"\b(am i|are we|is (?:he|she|it|they)|will i) (?:free|busy|available|around|double[- ]booked)\b"
    r"|\b(?:free|busy|available) (?:at|on|when|for|that|this|next|between)\b"
    r"|\b(?:clash\w*|conflict\w*|overlap\w*)\b"
    r"|\bin time for\b|\bmake it to\b|\blate for\b"
    r"|\bwhy\b|\bshould i\b|\bwhich (?:one|is|was)\b|\bhow long\b|\bhow (?:much|many) (?:time|hours|days|minutes)\b"
    r"|\b(?:earlier|later|before|after) than\b|\bmore than\b|\bless than\b",
    re.IGNORECASE)


def sentence_needed(request: str) -> bool:
    """The code rule: does this request ask a question the shown list does not answer by itself?"""
    return bool(_NEEDS_SENTENCE.search(request))
