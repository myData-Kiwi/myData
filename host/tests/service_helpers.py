"""Shared helpers for the service tests: a spied registry, scripted models, and a real server on a free port."""

from __future__ import annotations

import dataclasses
import socket
import threading
import time
from contextlib import contextmanager
from datetime import date
from pathlib import Path

import uvicorn

from mydata.service.api import create_app
from mydata.service.assistant import Assistant
from mydata.service.auth import AgentStore, Authenticator
from mydata.service.config import Settings
from mydata.tools import TOOLS, Registry, ToolResult

TODAY = date(2026, 3, 18)
TOKEN = "t" * 43  # the myData app's token
ASSISTANT_TOKEN = "a" * 43  # myAssistant's token
CLI_TOKEN = "c" * 43


class Spy:
    """Wraps send_mail's handler and records every time it actually runs."""

    def __init__(self):
        self.calls: list[dict] = []

    def handler(self, args, dates, today):
        self.calls.append(dict(args))
        return ToolResult({"status": "sent", "to": args["to"]})


def spied_registry() -> tuple[Registry, Spy]:
    spy = Spy()
    tools = [dataclasses.replace(t, handler=spy.handler) if t.name == "send_mail" else t for t in TOOLS.values()]
    return Registry(tools, today=lambda: TODAY), spy


def call(_tool, **args):
    return {"function": {"name": _tool, "arguments": args}}


class Scripted:
    name = "scripted"

    def __init__(self, replies):
        self.replies = list(replies)

    def chat(self, messages, tools):
        r = self.replies.pop(0) if self.replies else {"content": "Done."}
        if isinstance(r, list):
            return {"content": "", "tool_calls": r}
        return {"content": r["content"], "tool_calls": []}


class ReadyModels:
    """Stands in for ModelManager: always ready, never touches Ollama."""

    class _S:
        def to_json(self):
            return {"name": "scripted", "state": "ready", "loaded": True, "progress": None, "error": None,
                    "ollama_reachable": True, "ollama_started_by_host": False}

        state = "ready"

    def status(self):
        return self._S()

    def ready(self):
        return True


SEND_TO_NISHA = [
    [call("find_contact", name="Nisha Patel")],
    [call("send_mail", to="nisha.patel@example.com", subject="Late", body="I'll be late tomorrow.")],
]


def make_app(tmp: Path, scripts: list[list] | None = None):
    """The guarded ASGI app with a spied registry; each assistant message takes the next script."""
    registry, spy = spied_registry()
    settings = Settings(home=tmp)
    queue = list(scripts or [])
    assistant = Assistant(settings, registry, model_factory=lambda: Scripted(queue.pop(0) if queue else []),
                          today=lambda: TODAY)
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN, "cli": CLI_TOKEN}, AgentStore(tmp))
    app = create_app(auth, registry, ReadyModels(), assistant)
    app.auth = auth  # for tests that create agent tokens
    return app, registry, spy


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@contextmanager
def serve(app, host: str = "127.0.0.1"):
    port = free_port()
    server = uvicorn.Server(uvicorn.Config(app, host=host, port=port, log_config=None, lifespan="on"))
    t = threading.Thread(target=server.run, daemon=True)
    t.start()
    deadline = time.time() + 10
    while not server.started and time.time() < deadline:
        time.sleep(0.05)
    try:
        yield f"http://127.0.0.1:{port}", port
    finally:
        server.should_exit = True
        t.join(timeout=10)


def parse_sse(text: str) -> list[tuple[str, dict]]:
    import json
    out = []
    for block in text.strip().split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line)
        if "event" in lines:
            out.append((lines["event"], json.loads(lines.get("data", "{}"))))
    return out
