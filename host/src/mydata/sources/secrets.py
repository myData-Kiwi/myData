"""Where account passwords live: the OS keychain (macOS Keychain through `keyring`), never in a file the
host writes. Everything else reaches them through the SecretStore interface, so tests use
MemorySecretStore and never touch the real Keychain.

No method logs a value, and no repr shows one.
"""

from __future__ import annotations

import threading
from typing import Protocol, runtime_checkable

SERVICE = "mydata"


class SecretStoreError(Exception):
    """The keychain could not be used. The message never contains a secret."""


@runtime_checkable
class SecretStore(Protocol):
    def get(self, key: str) -> str | None: ...

    def set(self, key: str, value: str) -> None: ...

    def delete(self, key: str) -> None: ...


class KeychainSecretStore:
    """The OS keychain through `keyring` (on macOS the login Keychain, item service `mydata`).
    delete() of a missing key is not an error."""

    def __init__(self, service: str = SERVICE):
        self.service = service

    def __repr__(self) -> str:
        return f"KeychainSecretStore(service={self.service!r})"

    def get(self, key: str) -> str | None:
        import keyring
        from keyring.errors import KeyringError
        try:
            return keyring.get_password(self.service, key)
        except KeyringError as e:
            raise SecretStoreError(f"could not read {key!r} from the keychain ({type(e).__name__})") from None

    def set(self, key: str, value: str) -> None:
        import keyring
        from keyring.errors import KeyringError
        try:
            keyring.set_password(self.service, key, value)
        except KeyringError as e:
            raise SecretStoreError(f"could not store {key!r} in the keychain ({type(e).__name__})") from None

    def delete(self, key: str) -> None:
        import keyring
        from keyring.errors import KeyringError, PasswordDeleteError
        try:
            keyring.delete_password(self.service, key)
        except PasswordDeleteError:
            pass  # already gone
        except KeyringError as e:
            raise SecretStoreError(f"could not delete {key!r} from the keychain ({type(e).__name__})") from None


class MemorySecretStore:
    """In-memory store for tests. Its repr names the keys, never the values."""

    def __init__(self) -> None:
        self._values: dict[str, str] = {}
        self._lock = threading.Lock()

    def __repr__(self) -> str:
        return f"MemorySecretStore(keys={sorted(self._values)!r})"

    def get(self, key: str) -> str | None:
        with self._lock:
            return self._values.get(key)

    def set(self, key: str, value: str) -> None:
        with self._lock:
            self._values[key] = value

    def delete(self, key: str) -> None:
        with self._lock:
            self._values.pop(key, None)

    def keys(self) -> list[str]:
        with self._lock:
            return sorted(self._values)


def default_secret_store() -> SecretStore:
    """The store the host and the mydata command use."""
    return KeychainSecretStore()
