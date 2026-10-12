"""Minimal client for Ollama's /api/chat. Standard library only."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Callable, Protocol

DEFAULT_HOST = "http://127.0.0.1:11434"


class ChatModel(Protocol):
    name: str

    def chat(self, messages: list[dict], tools: list[dict]) -> dict:
        """Return the assistant message: {"role", "content", "tool_calls"?}."""
        ...


class OllamaError(RuntimeError):
    pass


@dataclass
class OllamaChat:
    name: str
    host: str = DEFAULT_HOST
    # False turns thinking off. gpt-oss cannot turn it off; it takes "low".
    think: bool | str = False
    options: dict[str, Any] = field(default_factory=lambda: {"num_ctx": 8192})
    # How long Ollama keeps the model loaded after a request ("30m"; -1 keeps it until unloaded).
    keep_alive: str | int = "30m"
    timeout: float = 600.0

    def _post(self, path: str, payload: dict) -> dict:
        req = urllib.request.Request(
            self.host + path,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            raise OllamaError(f"{e.code}: {e.read().decode(errors='replace')}") from None
        except urllib.error.URLError as e:
            raise OllamaError(f"cannot reach Ollama at {self.host}: {e.reason}") from None

    # The engine may pass on_delta to receive reply text as it is generated.
    streams = True

    def chat(self, messages: list[dict], tools: list[dict], on_delta: Callable[[str], None] | None = None,
             max_text: int | None = None, stop_on_text: bool = False) -> dict:
        """max_text: stop after this many streamed text pieces (about that many tokens). stop_on_text: stop at
        the first text (only a tool call is wanted). A stopped reply has "aborted": True."""
        streamed = on_delta is not None or max_text is not None or stop_on_text
        payload = {
            "model": self.name,
            "messages": messages,
            "tools": tools,
            "stream": streamed,
            "think": self.think,
            "options": self.options,
            "keep_alive": self.keep_alive,
        }
        body = self._stream("/api/chat", payload, on_delta, max_text, stop_on_text) if streamed \
            else self._post("/api/chat", payload)
        msg = body.get("message") or {}
        return {
            "role": "assistant",
            "content": msg.get("content") or "",
            "thinking": msg.get("thinking") or "",
            "tool_calls": msg.get("tool_calls") or [],
            "stats": {k: body.get(k) for k in ("total_duration", "load_duration", "prompt_eval_count",
                                               "prompt_eval_duration", "eval_count", "eval_duration")},
            "aborted": bool(body.get("aborted")),
        }

    def _stream(self, path: str, payload: dict, on_delta: Callable[[str], None] | None,
                max_text: int | None = None, stop_on_text: bool = False) -> dict:
        """Read Ollama's streamed reply (one JSON object per line) and assemble it like a non-streamed one.
        Stopping early closes the connection, which makes Ollama stop generating."""
        req = urllib.request.Request(self.host + path, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
        content, thinking, calls, last, aborted = [], [], [], {}, False
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                for line in resp:
                    if not line.strip():
                        continue
                    chunk = json.loads(line)
                    if chunk.get("error"):
                        raise OllamaError(str(chunk["error"]))
                    m = chunk.get("message") or {}
                    if m.get("content"):
                        if stop_on_text and m["content"].strip():
                            aborted = True
                            break
                        content.append(m["content"])
                        if on_delta:
                            on_delta(m["content"])
                        if max_text is not None and len(content) >= max_text:
                            aborted = True
                            break
                    if m.get("thinking"):
                        thinking.append(m["thinking"])
                    calls.extend(m.get("tool_calls") or [])
                    last = chunk
        except urllib.error.HTTPError as e:
            raise OllamaError(f"{e.code}: {e.read().decode(errors='replace')}") from None
        except urllib.error.URLError as e:
            raise OllamaError(f"cannot reach Ollama at {self.host}: {e.reason}") from None
        return {**last, "aborted": aborted,
                "message": {"content": "".join(content), "thinking": "".join(thinking), "tool_calls": calls}}

    def warm(self, system: dict, tools: list[dict]) -> None:
        """One tiny request with the real system message and tool definitions, so Ollama loads the model and
        caches the shared prompt prefix before the first user request."""
        self._post("/api/chat", {
            "model": self.name, "messages": [system, {"role": "user", "content": "Hello"}], "tools": tools,
            "stream": False, "think": self.think, "options": {**self.options, "num_predict": 1},
            "keep_alive": self.keep_alive})

    def load(self) -> None:
        """Load the model into memory so the first timed request does not pay for it."""
        # Same options as chat(), or the first real request reloads the model at the new context size.
        self._post("/api/chat", {"model": self.name, "messages": [], "options": self.options,
                                 "keep_alive": self.keep_alive})

    def version(self) -> str:
        req = urllib.request.Request(self.host + "/api/version")
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read()).get("version", "")

    def digest(self) -> str:
        req = urllib.request.Request(self.host + "/api/tags")
        with urllib.request.urlopen(req, timeout=10) as resp:
            models = json.loads(resp.read()).get("models", [])
        return next((m.get("digest", "") for m in models if m.get("name") == self.name), "")

    def show(self) -> dict:
        """Model details: digest-bearing info, parameters and template."""
        return self._post("/api/show", {"model": self.name})

    def unload(self) -> None:
        self._post("/api/chat", {"model": self.name, "messages": [], "keep_alive": 0})
