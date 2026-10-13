"""Where the host keeps its files, and its config file.

Everything lives in one per-user folder (override with MYDATA_HOME):
  macOS   ~/Library/Application Support/myData
  Linux   $XDG_DATA_HOME/mydata (default ~/.local/share/mydata)
  Windows %APPDATA%\\myData

  config.toml   settings (written with defaults on first start)
  app-tokens/   one token per app (mydata, myassistant, mycontacts, mycalendar, cli), each readable only by this user
  agents.json   agent tokens (hashes only), managed with `mydata agent ...`
  mydatad.pid   the running service's process id
  logs/         mydatad.log (structured), assistant.jsonl (every assistant request)
  accounts.json linked accounts (no passwords: those are in the Keychain)
  contacts.sqlite, calendar.sqlite   the read-only mirror of the linked accounts

Once an account is linked these hold the user's real contacts and calendars, and the request log holds
real requests and results. So the folder may never be inside the source checkout (load_settings and
setup_logging refuse it), and .gitignore keeps these files out of git in any case. The folder and logs/
are readable only by this user (0700), and so is every file the host writes in them (0600).
"""

from __future__ import annotations

import ipaddress
import os
from datetime import date
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
# After a tool's result is shown: "field" (the tool-choice call says whether a sentence is needed),
# "rule" (code decides from the request), or "full" (the model always writes the reply).
followup = "rule"

[log]
level = "INFO"

[dev]
# Demo mode (no linked account): the tools serve fake data dated around 18 March 2026, so the host's
# "today" is pinned to that date: "tomorrow" then means 19 March and finds the demo events. Set to
# false to use the real date. Real mode (an account is linked) always uses the real date.
pin_today = "2026-03-18"
"""


class ConfigError(Exception):
    pass


def source_checkout() -> Path | None:
    """The git checkout this code runs from (development), or None (an installed host)."""
    for parent in Path(__file__).resolve().parents:
        if (parent / ".git").exists():
            return parent
    return None


def inside_checkout(path: Path) -> bool:
    checkout = source_checkout()
    if checkout is None:
        return False
    try:
        Path(path).resolve().relative_to(checkout)
        return True
    except ValueError:
        return False


def ensure_outside_checkout(path: Path, what: str) -> None:
    """Personal data (the mirror, request logs) must never be written inside the repository."""
    if inside_checkout(path):
        raise ConfigError(f"{what} {path} is inside the source checkout {source_checkout()}; the host keeps "
                          "personal data there, so it must live outside the repository (set MYDATA_HOME)")


def private_dir(path: Path) -> Path:
    """Create `path` (and its parents) if needed, and make it readable only by this user (0700), also
    when it already existed with looser permissions. Returns it."""
    path = Path(path)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not sys.platform.startswith("win"):
        os.chmod(path, 0o700)
    return path


def private_file(path: Path) -> Path:
    """Make an existing file readable only by this user (0600); a missing one is left missing."""
    if not sys.platform.startswith("win"):
        try:
            os.chmod(path, 0o600)
        except FileNotFoundError:
            pass
    return Path(path)


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
    followup: str = "rule"
    log_level: str = "INFO"
    # Development: the date the host treats as today (None = the real date). See DEFAULT_CONFIG [dev].
    pin_today: date | None = None
    extra: dict = field(default_factory=dict)

    def today(self) -> date:
        return self.pin_today or date.today()

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


def _pin_today(dev: dict) -> date | None:
    """On by default (also for config files written before the setting existed) while the tools are fakes."""
    from ..orchestrator.fixtures import TODAY as DEMO_TODAY
    v = dev.get("pin_today", DEMO_TODAY.isoformat())
    if v is False or v == "":
        return None
    if not isinstance(v, str):
        raise ConfigError(f"dev.pin_today must be a date like \"2026-03-18\" or false, not {v!r}")
    try:
        return date.fromisoformat(v)
    except ValueError:
        raise ConfigError(f"dev.pin_today {v!r} is not a date (YYYY-MM-DD)") from None


def load_settings(home: Path | None = None, create: bool = True) -> Settings:
    """Read config.toml, writing the defaults first if it does not exist."""
    home = home or home_dir()
    ensure_outside_checkout(home, "the host folder")
    path = home / "config.toml"
    if not path.exists():
        if not create:
            raise ConfigError(f"no config at {path}; start the host once to create it")
        private_dir(home)
        path.write_text(DEFAULT_CONFIG)
    try:
        raw = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: {e}") from None
    server, model, log, dev = _table(raw, "server"), _table(raw, "model"), _table(raw, "log"), _table(raw, "dev")
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
        followup=_get(model, "model.followup", str, "rule"),
        log_level=_get(log, "log.level", str, "INFO").upper(),
        pin_today=_pin_today(dev),
    )
    if s.log_level not in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
        raise ConfigError(f"log.level {s.log_level!r} is not a log level")
    if s.followup not in ("full", "rule", "field"):
        raise ConfigError(f"model.followup must be full, rule or field, not {s.followup!r}")
    if s.num_ctx <= 0:
        raise ConfigError("model.num_ctx must be positive")
    # Nothing listens beyond this machine. Phone access comes later, through a separate, explicit design.
    if not is_loopback(s.host):
        raise ConfigError(f"server.host must be a loopback address (127.0.0.1, ::1 or localhost), not {s.host!r}")
    if not 0 < s.port < 65536:
        raise ConfigError(f"server.port {s.port} is not a valid port")
    return s
