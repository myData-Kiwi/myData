"""SecretStore: the memory store used in tests, and the Keychain store (only on request, never by default)."""

import os
import secrets as pysecrets

import pytest

from mydata.sources.secrets import KeychainSecretStore, MemorySecretStore, SecretStore, default_secret_store

SECRET = "abcd-efgh-ijkl-mnop"  # invented


def test_memory_round_trip_and_repr_hides_values():
    store = MemorySecretStore()
    assert isinstance(store, SecretStore)
    assert store.get("account:a1") is None
    store.set("account:a1", SECRET)
    assert store.get("account:a1") == SECRET
    assert SECRET not in repr(store) and SECRET not in str(store)
    assert "account:a1" in repr(store)
    store.delete("account:a1")
    assert store.get("account:a1") is None
    store.delete("account:a1")  # deleting a missing key is not an error


def test_default_store_is_the_keychain():
    store = default_secret_store()
    assert isinstance(store, KeychainSecretStore) and store.service == "mydata"
    assert isinstance(store, SecretStore)


def _macos_keyring() -> bool:
    try:
        import keyring
        from keyring.backends import macOS
    except Exception:
        return False
    return isinstance(keyring.get_keyring(), macOS.Keyring)


@pytest.mark.skipif(os.environ.get("MYDATA_TEST_KEYCHAIN") != "1" or not _macos_keyring(),
                    reason="touches the real Keychain: set MYDATA_TEST_KEYCHAIN=1 on a Mac to run")
def test_keychain_round_trip():
    store = KeychainSecretStore(service="mydata-test")
    key = f"test:{pysecrets.token_hex(4)}"
    value = f"invented-{pysecrets.token_hex(8)}"
    try:
        assert store.get(key) is None
        store.set(key, value)
        assert store.get(key) == value
        assert value not in repr(store)
    finally:
        store.delete(key)
    assert store.get(key) is None
    store.delete(key)  # missing: not an error
