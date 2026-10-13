"""The user's linked accounts (iCloud for now), shared by the host and the mydata command.

<home>/accounts.json holds who each account is (id, provider, email, created, label): readable only by
the user, written atomically, re-read on every call so a change made by the command reaches the running
host. The password is never in it: it lives in the SecretStore (the macOS Keychain) under
f"account:{id}", and is stored only after the provider's verify check has passed.

Removing an account deletes its secret and, through the caller's on_remove hook, its mirrored data.
"""

from __future__ import annotations

import json
import logging
import os
import secrets
import sys
import tempfile
import threading
from dataclasses import asdict, dataclass, fields
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from .providers import PROVIDER_NAMES
from .secrets import SecretStore

log = logging.getLogger("mydata.sources.accounts")


def secret_key(account_id: str) -> str:
    return f"account:{account_id}"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@dataclass(frozen=True)
class Account:
    id: str
    provider: str  # "icloud"
    email: str
    created_at: str
    label: str

    def public(self) -> dict:
        return asdict(self)


class Accounts:
    def __init__(self, home: Path, secrets: SecretStore):
        self.path = home / "accounts.json"
        self._secrets = secrets
        self._lock = threading.Lock()

    def __repr__(self) -> str:
        return f"Accounts(path={str(self.path)!r})"

    # ---------------------------------------------------------------- file

    def _load(self) -> list[Account]:
        try:
            text = self.path.read_text()
        except FileNotFoundError:
            return []
        names = {f.name for f in fields(Account)}
        return [Account(**{k: v for k, v in raw.items() if k in names}) for raw in json.loads(text or "[]")]

    def _save(self, accounts: list[Account]) -> None:
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".accounts.")
        try:
            if not sys.platform.startswith("win"):
                os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as fh:
                json.dump([asdict(a) for a in accounts], fh, indent=2)
                fh.flush()
                os.fsync(fh.fileno())
            os.replace(tmp, self.path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    # ---------------------------------------------------------------- reads

    def list(self) -> list[Account]:
        with self._lock:
            return self._load()

    def get(self, account_id: str) -> Account | None:
        return next((a for a in self.list() if a.id == account_id), None)

    def password(self, account_id: str) -> str:
        """The account's password, from the SecretStore only. KeyError if the account or its secret is gone."""
        if self.get(account_id) is None:
            raise KeyError(f"no account with id {account_id!r}")
        value = self._secrets.get(secret_key(account_id))
        if value is None:
            raise KeyError(f"no password is stored for account {account_id!r}; remove it and add it again")
        return value

    # ---------------------------------------------------------------- writes

    def add(self, provider: str, email: str, password: str, *, verify: Callable[[str, str], None],
            label: str | None = None) -> Account:
        """Verify, then store. verify(email, password) raises on bad credentials; when it does (or anything
        else fails) nothing is stored: no accounts.json entry and no secret."""
        if provider not in PROVIDER_NAMES:
            raise ValueError(f"unknown provider {provider!r}; supported: {', '.join(sorted(PROVIDER_NAMES))}")
        email = email.strip()
        if not email or "@" not in email or len(email) > 254:
            raise ValueError("enter the account's email address")
        if not password:
            raise ValueError("the password is empty")
        if any(a.provider == provider and a.email.lower() == email.lower() for a in self.list()):
            raise ValueError(f"{PROVIDER_NAMES[provider]} account {email} is already added")

        verify(email, password)

        with self._lock:
            current = self._load()
            if any(a.provider == provider and a.email.lower() == email.lower() for a in current):
                raise ValueError(f"{PROVIDER_NAMES[provider]} account {email} is already added")
            taken = {a.id for a in current}
            account_id = secrets.token_hex(6)
            while account_id in taken:
                account_id = secrets.token_hex(6)
            account = Account(id=account_id, provider=provider, email=email, created_at=_now(),
                              label=(label or "").strip() or PROVIDER_NAMES[provider])
            self._secrets.set(secret_key(account_id), password)
            try:
                self._save([*current, account])
            except BaseException:
                self._secrets.delete(secret_key(account_id))
                raise
        log.info("account added", extra={"account_id": account.id, "provider": provider})
        return account

    def remove(self, account_id: str, *, on_remove: Callable[[Account], None]) -> Account:
        """Delete the account's mirrored data (on_remove, run first so a failure leaves the account in place
        to retry), then its secret, then its entry. KeyError if there is no such account."""
        account = self.get(account_id)
        if account is None:
            raise KeyError(f"no account with id {account_id!r}")
        on_remove(account)
        self._secrets.delete(secret_key(account_id))
        with self._lock:
            self._save([a for a in self._load() if a.id != account_id])
        log.info("account removed", extra={"account_id": account_id, "provider": account.provider})
        return account
