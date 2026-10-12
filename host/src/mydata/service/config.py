"""Where the host keeps its files, and its config file.

Everything lives in one per-user folder (override with MYDATA_HOME):
  macOS   ~/Library/Application Support/myData
  Linux   $XDG_DATA_HOME/mydata (default ~/.local/share/mydata)
  Windows %APPDATA%\\myData

  config.toml   settings (written with defaults on first start)
  app-tokens/   one token per app (mydata, myassistant, cli), each readable only by this user
  agents.json   agent tokens (hashes only), managed with `mydata agent ...`
  mydatad.pid   the running service's process id
  logs/         mydatad.log (structured), assistant.jsonl (every assistant request)
"""

from __future__ import annotations

import ipaddress
import os
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_CONFIG = """\
# myData host settings. The host only ever listens on this machine (loopback).

[server]
host = "127.0.0.1"
port = 47821

[model]
name = "qwen3:14b"
ollama_url = "http://127.0.0.1:11434"
# Start `ollama serve` if Ollama is installed but not running, and stop it again on shutdown.
start_ollama = true
# Download the model if it is missing.
pull_if_missing = true
think = false
num_ctx = 8192

[log]
level = "INFO"
"""


class ConfigError(Exception):
    pass


def home_dir() -> Path:
    if os.environ.get("MYDATA_HOME"):
        return Path(os.environ["MYDATA_HOME"])
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "myData"
    if sys.platform.startswith("win"):
        return Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming")) / "myData"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "mydata"


@dataclass
class Settings:
    home: Path
    host: str = "127.0.0.1"
    port: int = 47821
    model: str = "qwen3:14b"
    ollama_url: str = "http://127.0.0.1:11434"
    start_ollama: bool = True
    pull_if_missing: bool = True
    think: bool = False
    num_ctx: int = 8192
    log_level: str = "INFO"
    extra: dict = field(default_factory=dict)

    @property
    def config_path(self) -> Path:
        return self.home / "config.toml"

    def app_token_path(self, app: str) -> Path:
        from .auth import app_token_path
        return app_token_path(self.home, app)

    @property
    def pid_path(self) -> Path:
        return self.home / "mydatad.pid"

    @property
    def log_dir(self) -> Path:
        return self.home / "logs"

    @property
    def base_url(self) -> str:
        host = f"[{self.host}]" if ":" in self.host else self.host
        return f"http://{host}:{self.port}"


def is_loopback(host: str) -> bool:
    if host == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def _table(raw: dict, name: str) -> dict:
    v = raw.get(name, {})
    if not isinstance(v, dict):
        raise ConfigError(f"[{name}] must be a table")
    return v


def _get(table: dict, key: str, kind: type, default):
    v = table.get(key.split(".", 1)[1], default)
    # bool is an int in Python; in the config they are different things ("false" is not false either).
    if not isinstance(v, kind) or (kind is int and isinstance(v, bool)):
        raise ConfigError(f"{key} must be a {kind.__name__}, not {v!r}")
    return v


def load_settings(home: Path | None = None, create: bool = True) -> Settings:
    """Read config.toml, writing the defaults first if it does not exist."""
    home = home or home_dir()
    path = home / "config.toml"
    if not path.exists():
        if not create:
            raise ConfigError(f"no config at {path}; start the host once to create it")
        home.mkdir(parents=True, exist_ok=True)
        path.write_text(DEFAULT_CONFIG)
    try:
        raw = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: {e}") from None
    server, model, log = _table(raw, "server"), _table(raw, "model"), _table(raw, "log")
    s = Settings(
        home=home,
        host=_get(server, "server.host", str, "127.0.0.1"),
        port=_get(server, "server.port", int, 47821),
        model=_get(model, "model.name", str, "qwen3:14b"),
        ollama_url=_get(model, "model.ollama_url", str, "http://127.0.0.1:11434").rstrip("/"),
        start_ollama=_get(model, "model.start_ollama", bool, True),
        pull_if_missing=_get(model, "model.pull_if_missing", bool, True),
        think=_get(model, "model.think", bool, False),
        num_ctx=_get(model, "model.num_ctx", int, 8192),
        log_level=_get(log, "log.level", str, "INFO").upper(),
    )
    if s.log_level not in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
        raise ConfigError(f"log.level {s.log_level!r} is not a log level")
    if s.num_ctx <= 0:
        raise ConfigError("model.num_ctx must be positive")
    # Nothing listens beyond this machine. Phone access comes later, through a separate, explicit design.
    if not is_loopback(s.host):
        raise ConfigError(f"server.host must be a loopback address (127.0.0.1, ::1 or localhost), not {s.host!r}")
    if not 0 < s.port < 65536:
        raise ConfigError(f"server.port {s.port} is not a valid port")
    return s
