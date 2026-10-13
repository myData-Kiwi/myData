"""Gets the model ready without the user doing anything.

States, in order: starting → (ollama_starting) → (pulling) → loading → ready.
Failure states: ollama_missing (Ollama is not installed), error (anything else, with a message).
disabled: the user switched the assistant off (nothing is downloaded or loaded).

- If Ollama is not reachable and start_ollama is on, start `ollama serve` as a child process,
  bound to 127.0.0.1, and stop it again on shutdown. If the host did not start it, it leaves it alone.
- If the model is not downloaded and pull_if_missing is on, pull it and report progress.
- Then load it into memory, so the first request does not wait for the load.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable

from .config import Settings
from .logs import log

logger = logging.getLogger("mydata.model")

OLLAMA_CANDIDATES = [
    "/usr/local/bin/ollama",
    "/opt/homebrew/bin/ollama",
    "/Applications/Ollama.app/Contents/Resources/ollama",
    "/usr/bin/ollama",
]


@dataclass
class ModelStatus:
    name: str
    state: str = "starting"
    loaded: bool = False
    progress: dict | None = None  # {"status", "completed", "total", "percent"} while pulling
    error: str | None = None
    ollama_reachable: bool = False
    ollama_started_by_host: bool = False
    updated: float = field(default_factory=time.time)

    def to_json(self) -> dict:
        out = asdict(self)
        out.pop("updated")
        return out


class ModelManager:
    def __init__(self, settings: Settings, log_dir: Path | None = None, enabled: bool = True,
                 warm: Callable[[], None] | None = None):
        self.settings = settings
        # Loads the model with the assistant's real prompt prefix (Assistant.warm); None loads it bare.
        self._warm = warm
        self._enabled = enabled
        self._cancel = threading.Event()  # set when the assistant is switched off mid-preparation
        self.log_dir = log_dir or settings.log_dir
        self._status = ModelStatus(name=settings.model)
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._supervisor: threading.Thread | None = None
        self._child: subprocess.Popen | None = None
        self._stopping = threading.Event()
        self.retry_every = 15.0
        # A preparation in progress, and whether the prompt prefix changed while it ran (see rewarm).
        self._warm_lock = threading.Lock()
        self._preparing = False
        self._stale = False

    # ---------------------------------------------------------------- public

    def status(self) -> ModelStatus:
        with self._lock:
            s = ModelStatus(**asdict(self._status))
        if s.state == "ready":
            # Report what is true now: Ollama may have died, and it unloads idle models.
            if self._child is not None and self._child.poll() is not None:
                self._set(state="error", loaded=False, ollama_reachable=False,
                          error=f"ollama serve exited with code {self._child.returncode}; "
                                f"see {self.log_dir / 'ollama.log'}")
                return self.status()
            loaded = self._is_loaded()
            if loaded is None:
                self._set(state="error", loaded=False, ollama_reachable=False,
                          error=f"Ollama stopped responding at {self.settings.ollama_url}")
                return self.status()
            s.loaded = loaded
        return s

    def ready(self) -> bool:
        return self.status().state == "ready"

    @property
    def enabled(self) -> bool:
        return self._enabled

    def set_enabled(self, enabled: bool) -> None:
        """Switch the assistant on (start getting the model ready) or off (stop, unload, download nothing)."""
        self._enabled = enabled
        if enabled:
            self._cancel.clear()
            self.retry()
            return
        self._cancel.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=10)
        if self._reachable():
            try:  # free the memory
                self._post("/api/chat", {"model": self.settings.model, "messages": [], "keep_alive": 0}, 30)
            except Exception:
                logger.warning("could not unload the model", exc_info=True)
        self._set(state="disabled", loaded=False, progress=None, error=None)

    def start(self) -> None:
        """Begin getting the model ready in the background, and keep watching so a failed state recovers
        by itself once it can (Ollama comes back, gets installed, or our own child can be restarted)."""
        self._stopping.clear()
        self.retry()
        if not (self._supervisor and self._supervisor.is_alive()):
            self._supervisor = threading.Thread(target=self._supervise, name="model-supervisor", daemon=True)
            self._supervisor.start()

    def retry(self) -> None:
        """Try again now (the app's retry button). Does nothing while an attempt is running or while the
        assistant is switched off. Never after stop(): a supervisor mid-check must not start Ollama again."""
        if self._stopping.is_set():
            return
        if not self._enabled:
            self._set(state="disabled", loaded=False, progress=None, error=None)
            return
        with self._warm_lock:
            if self._preparing or (self._thread and self._thread.is_alive()):
                return
            self._preparing = True
            self._thread = threading.Thread(target=self._prepare, name="model-manager", daemon=True)
        self._thread.start()

    def rewarm(self) -> None:
        """Re-run the warm-up in the background (the prompt prefix changed: the host switched between demo
        and real mode). Only when the model is ready. A preparation in progress is told instead: if it has
        already sent the old prefix (its loading step), it warms again with the new one before it reports
        ready. A switched-off assistant loads nothing."""
        if not self._enabled or self._warm is None:
            return
        with self._warm_lock:
            if self._preparing:
                self._stale = True
                return
        if self.status().state != "ready":
            return

        def run() -> None:
            try:
                self._warm()
                log(logger, logging.INFO, "model re-warmed with the new prompt prefix")
            except Exception:
                logger.warning("re-warming the model failed; the next request loads the prefix", exc_info=True)

        threading.Thread(target=run, name="model-rewarm", daemon=True).start()

    def _supervise(self) -> None:
        while not self._stopping.wait(self.retry_every):
            state = self.status().state  # status() also notices a dead Ollama
            if not self._enabled or state not in ("error", "ollama_missing") or (self._thread and self._thread.is_alive()):
                continue
            installed = bool(shutil.which("ollama") or any(Path(p).exists() for p in OLLAMA_CANDIDATES))
            if self._reachable() or (self.settings.start_ollama and installed):
                log(logger, logging.INFO, "retrying model preparation", previous_state=state)
                self.retry()

    def stop(self) -> None:
        self._stopping.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=5)
        # The model is kept loaded while the host runs; free the memory when the host stops (unless Ollama
        # itself is about to stop because the host started it).
        if self._enabled and not self._child and self._status.loaded and self._reachable():
            try:
                self._post("/api/chat", {"model": self.settings.model, "messages": [], "keep_alive": 0}, 30)
            except Exception:
                logger.warning("could not unload the model", exc_info=True)
        if self._child and self._child.poll() is None:
            log(logger, logging.INFO, "stopping the Ollama server the host started", pid=self._child.pid)
            self._child.terminate()
            try:
                self._child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._child.kill()
        self._child = None

    # ---------------------------------------------------------------- steps

    def _set(self, **changes) -> None:
        with self._lock:
            for k, v in changes.items():
                setattr(self._status, k, v)
            self._status.updated = time.time()
        if "state" in changes:
            log(logger, logging.INFO, "model state", **{k: v for k, v in changes.items() if k != "progress"})

    def _prepare(self) -> None:
        try:
            self._set(state="starting", error=None, progress=None)
            if not self._reachable():
                if not self.settings.start_ollama:
                    self._set(state="error", error=f"Ollama is not running at {self.settings.ollama_url}")
                    return
                if not self._start_ollama():
                    return
            self._set(ollama_reachable=True)
            if not self._has_model():
                if not self.settings.pull_if_missing:
                    self._set(state="error", error=f"model {self.settings.model} is not downloaded")
                    return
                self._pull()
                if self._stopping.is_set() or self._cancel.is_set():
                    return
            if self._cancel.is_set():
                return
            self._set(state="loading", progress=None)
            while True:
                with self._warm_lock:
                    self._stale = False  # the warm-up below reads the prefix as it is now
                if self._warm:
                    self._warm()
                else:
                    self._post("/api/chat", {"model": self.settings.model, "messages": [],
                                             "options": {"num_ctx": self.settings.num_ctx}, "keep_alive": -1}, 600)
                if self._cancel.is_set():
                    return
                with self._warm_lock:
                    if self._stale and self._warm:  # the mode switched while loading: warm the new prefix
                        log(logger, logging.INFO, "prompt prefix changed while loading; warming again")
                        continue
                    # Ready is set before the preparation ends, under the same lock rewarm checks, so a
                    # switch from now on finds the model ready and re-warms it itself.
                    self._set(state="ready", loaded=True, error=None)
                    self._preparing = False
                    break
        except Exception as e:  # any failure is a state the app can show, with a retry
            self._set(state="error", error=f"{type(e).__name__}: {e}")
            logger.exception("model preparation failed")
        finally:
            with self._warm_lock:
                self._preparing = False

    def _start_ollama(self) -> bool:
        binary = shutil.which("ollama") or next((p for p in OLLAMA_CANDIDATES if Path(p).exists()), None)
        if not binary:
            self._set(state="ollama_missing", error="Ollama is not installed. Install it from ollama.com, then retry.")
            return False
        self._set(state="ollama_starting")
        host = self.settings.ollama_url.split("://", 1)[-1]
        env = {**os.environ, "OLLAMA_HOST": host}  # keep the model server on this machine
        from .config import private_dir
        from .logs import open_private
        private_dir(self.log_dir)
        out = open_private(self.log_dir / "ollama.log", "ab")
        kwargs: dict = {"stdout": out, "stderr": subprocess.STDOUT, "stdin": subprocess.DEVNULL, "env": env}
        if sys.platform.startswith("win"):
            kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
        self._child = subprocess.Popen([binary, "serve"], **kwargs)
        self._set(ollama_started_by_host=True)
        log(logger, logging.INFO, "started ollama serve", pid=self._child.pid, binary=binary)
        deadline = time.time() + 30
        while time.time() < deadline and not self._stopping.is_set():
            if self._child.poll() is not None:
                self._set(state="error", error=f"ollama serve exited with code {self._child.returncode}; "
                                               f"see {self.log_dir / 'ollama.log'}")
                return False
            if self._reachable():
                return True
            time.sleep(0.5)
        self._set(state="error", error="Ollama did not start within 30 seconds")
        return False

    def _pull(self) -> None:
        self._set(state="pulling", progress={"status": "starting", "completed": 0, "total": 0, "percent": 0.0})
        req = urllib.request.Request(self.settings.ollama_url + "/api/pull",
                                     data=json.dumps({"model": self.settings.model, "stream": True}).encode(),
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=3600) as resp:
            for line in resp:
                if self._stopping.is_set() or self._cancel.is_set():
                    return
                if not line.strip():
                    continue
                chunk = json.loads(line)
                if chunk.get("error"):
                    raise RuntimeError(f"pull failed: {chunk['error']}")
                total, done = chunk.get("total") or 0, chunk.get("completed") or 0
                self._set(progress={"status": chunk.get("status", ""), "completed": done, "total": total,
                                    "percent": round(100 * done / total, 1) if total else 0.0})

    # ---------------------------------------------------------------- Ollama calls

    def _get(self, path: str, timeout: float = 3) -> dict:
        with urllib.request.urlopen(self.settings.ollama_url + path, timeout=timeout) as resp:
            return json.loads(resp.read())

    def _post(self, path: str, payload: dict, timeout: float) -> dict:
        req = urllib.request.Request(self.settings.ollama_url + path, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())

    def _reachable(self) -> bool:
        try:
            self._get("/api/version")
            return True
        except (urllib.error.URLError, OSError, ValueError):
            return False

    def _has_model(self) -> bool:
        names = {m.get("name") for m in self._get("/api/tags").get("models", [])}
        want = self.settings.model
        return want in names or (":" not in want and f"{want}:latest" in names)

    def model_bytes(self) -> int | None:
        """Memory the loaded model takes in Ollama, if it is loaded."""
        try:
            for m in self._get("/api/ps", 2).get("models", []):
                if m.get("name") == self.settings.model:
                    return int(m.get("size") or 0)
        except (urllib.error.URLError, OSError, ValueError):
            return None
        return None

    def _is_loaded(self) -> bool | None:
        """True/False from Ollama; None if Ollama does not answer."""
        try:
            return any(m.get("name") == self.settings.model for m in self._get("/api/ps", 2).get("models", []))
        except (urllib.error.URLError, OSError, ValueError):
            return None
