"""Minimal client for Ollama's /api/chat. Standard library only."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Protocol

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
    keep_alive: str = "30m"
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

    def chat(self, messages: list[dict], tools: list[dict]) -> dict:
        payload = {
            "model": self.name,
            "messages": messages,
            "tools": tools,
            "stream": False,
            "think": self.think,
            "options": self.options,
            "keep_alive": self.keep_alive,
        }
        body = self._post("/api/chat", payload)
        msg = body.get("message") or {}
        return {
            "role": "assistant",
            "content": msg.get("content") or "",
            "thinking": msg.get("thinking") or "",
            "tool_calls": msg.get("tool_calls") or [],
            "stats": {k: body.get(k) for k in ("total_duration", "load_duration", "prompt_eval_count", "eval_count")},
        }

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
