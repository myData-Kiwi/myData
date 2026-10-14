"""Accounts: add (verified before anything is stored), list, remove; the CLI on top of them.

Invented data only. The password must never reach accounts.json, output, logs or reprs."""

import json
import logging
import stat
import sys

import pytest

from mydata import cli
from mydata.sources.accounts import Account, Accounts, secret_key
from mydata.sources.providers import ICLOUD, VerificationError
from mydata.sources.secrets import MemorySecretStore

PASSWORD = "wxyz-qrst-uvwa-bcde"  # invented, distinctive so any leak is found
EMAIL = "ava.fictional@example.com"


def _ok(email, password):
    assert password == PASSWORD


def _bad(email, password):
    raise VerificationError("iCloud did not accept this email and app-specific password.")


def _file_text(home):
    p = home / "accounts.json"
    return p.read_text() if p.exists() else ""


# ------------------------------------------------------------------ Accounts


def test_add_list_get_password_remove(tmp_path):
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)
    assert accounts.list() == []
    a = accounts.add("icloud", EMAIL, PASSWORD, verify=_ok)
    assert a.provider == "icloud" and a.email == EMAIL and a.label == "iCloud" and a.created_at
    assert accounts.list() == [a]
    assert accounts.get(a.id) == a
    assert accounts.password(a.id) == PASSWORD
    assert secrets.keys() == [secret_key(a.id)] == [f"account:{a.id}"]

    b = accounts.add("icloud", "ben.invented@example.net", "other-invented-pw", verify=lambda e, p: None)
    assert {x.id for x in accounts.list()} == {a.id, b.id}  # several accounts allowed

    removed = []
    assert accounts.remove(a.id, on_remove=removed.append) == a
    assert removed == [a]
    assert secrets.get(secret_key(a.id)) is None
    assert accounts.get(a.id) is None and accounts.list() == [b]
    with pytest.raises(KeyError):
        accounts.password(a.id)
    with pytest.raises(KeyError):
        accounts.remove(a.id, on_remove=removed.append)
    assert removed == [a]


def test_failed_verification_stores_nothing(tmp_path):
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)
    with pytest.raises(VerificationError):
        accounts.add("icloud", EMAIL, PASSWORD, verify=_bad)
    assert not (tmp_path / "accounts.json").exists()
    assert secrets.keys() == []
    assert accounts.list() == []


def test_invalid_input_and_duplicates_are_refused_before_verifying(tmp_path):
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)
    calls = []

    def verify(e, p):
        calls.append(e)

    for provider, email, pw in (("google", EMAIL, PASSWORD), ("icloud", "", PASSWORD), ("icloud", "no-at-sign", PASSWORD),
                                ("icloud", EMAIL, "")):
        with pytest.raises(ValueError):
            accounts.add(provider, email, pw, verify=verify)
    assert calls == []
    accounts.add("icloud", EMAIL, PASSWORD, verify=verify)
    with pytest.raises(ValueError, match="already added"):
        accounts.add("icloud", EMAIL.upper(), PASSWORD, verify=verify)
    assert calls == [EMAIL] and len(secrets.keys()) == 1


def test_failed_save_removes_the_secret(tmp_path, monkeypatch):
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)

    def boom(_):
        raise OSError("disk full")

    monkeypatch.setattr(accounts, "_save", boom)
    with pytest.raises(OSError):
        accounts.add("icloud", EMAIL, PASSWORD, verify=_ok)
    assert secrets.keys() == []


def test_failed_data_removal_keeps_the_account(tmp_path):
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)
    a = accounts.add("icloud", EMAIL, PASSWORD, verify=_ok)

    def boom(_):
        raise RuntimeError("database locked")

    with pytest.raises(RuntimeError):
        accounts.remove(a.id, on_remove=boom)
    assert accounts.get(a.id) == a and accounts.password(a.id) == PASSWORD


@pytest.mark.skipif(sys.platform.startswith("win"), reason="POSIX permissions")
def test_accounts_file_is_private_and_never_holds_the_password(tmp_path, caplog):
    caplog.set_level(logging.DEBUG)
    secrets = MemorySecretStore()
    accounts = Accounts(tmp_path, secrets)
    a = accounts.add("icloud", EMAIL, PASSWORD, verify=_ok)
    path = tmp_path / "accounts.json"
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    text = path.read_text()
    assert PASSWORD not in text
    assert json.loads(text) == [{"id": a.id, "provider": "icloud", "email": EMAIL, "created_at": a.created_at,
                                 "label": "iCloud"}]
    assert not [p for p in tmp_path.iterdir() if p.name.startswith(".accounts.")]  # no temp file left
    for r in (repr(a), str(a), repr(accounts), repr(secrets), json.dumps(a.public())):
        assert PASSWORD not in r
    assert "password" not in {f for f in Account.__dataclass_fields__}
    assert PASSWORD not in caplog.text


def test_changes_from_another_instance_are_seen(tmp_path):
    """The command line and the running host each hold their own Accounts; both read the same file."""
    secrets = MemorySecretStore()
    host, command = Accounts(tmp_path, secrets), Accounts(tmp_path, secrets)
    a = command.add("icloud", EMAIL, PASSWORD, verify=_ok)
    assert host.get(a.id) == a
    command.remove(a.id, on_remove=lambda _: None)
    assert host.list() == []


def test_icloud_start_urls():
    assert ICLOUD == {"contacts": "https://contacts.icloud.com", "calendar": "https://caldav.icloud.com"}


def test_verify_icloud_rejection_never_shows_the_password():
    """Against a server that refuses every request: a safe VerificationError, nothing else."""
    import httpx

    from mydata.sources.providers import verify_icloud

    seen = []

    def handler(request):
        seen.append((request.method, request.url.host))
        return httpx.Response(401, headers={"WWW-Authenticate": 'Basic realm="example"'})

    with pytest.raises(VerificationError) as ei:
        verify_icloud(EMAIL, PASSWORD, transport=httpx.MockTransport(handler))
    assert PASSWORD not in str(ei.value) and PASSWORD not in repr(ei.value)
    assert ei.value.__cause__ is None
    assert seen and all(host.endswith("icloud.com") for _, host in seen)


def test_verify_icloud_network_failure_says_it_could_not_reach_icloud():
    import httpx

    from mydata.sources.providers import verify_icloud

    def down(request):
        raise httpx.ConnectError("no route to host", request=request)

    with pytest.raises(VerificationError) as ei:
        verify_icloud(EMAIL, PASSWORD, transport=httpx.MockTransport(down))
    assert str(ei.value) == "Could not reach iCloud contacts. Check the connection and try again."


# ------------------------------------------------------------------ CLI


@pytest.fixture
def cli_env(tmp_path, monkeypatch, caplog):
    """Run `mydata account ...` in process, on a temporary host folder, with a memory secret store and a
    fake verify. getpass and input are patched; nothing touches the Keychain or the network."""
    caplog.set_level(logging.DEBUG)
    monkeypatch.setenv("MYDATA_HOME", str(tmp_path))
    store = MemorySecretStore()
    monkeypatch.setattr(cli, "_secret_store", lambda: store)
    verified = []

    def verify(provider, email, password):
        verified.append((provider, email))
        if password != PASSWORD:
            raise VerificationError("iCloud did not accept this email and app-specific password.")

    monkeypatch.setattr(cli, "_verify", verify)
    removed = []
    monkeypatch.setattr(cli, "_remove_account_data", lambda settings, account: removed.append(account.id))
    monkeypatch.setattr(cli.getpass, "getpass", lambda prompt="": PASSWORD)
    answers = []
    monkeypatch.setattr("builtins.input", lambda prompt="": answers.pop(0))
    return {"home": tmp_path, "store": store, "verified": verified, "removed": removed, "answers": answers,
            "caplog": caplog}


def _no_leak(env, capsys):
    out, err = capsys.readouterr()
    for text in (out, err, env["caplog"].text, _file_text(env["home"])):
        assert PASSWORD not in text
    return out, err


def test_cli_add_list_remove(cli_env, capsys):
    env = cli_env
    assert cli.main(["account", "list"]) == 0
    out, _ = _no_leak(env, capsys)
    assert "No accounts." in out

    assert cli.main(["account", "add", "icloud", "--email", EMAIL]) == 0
    out, _ = _no_leak(env, capsys)
    assert "account.apple.com" in out and EMAIL in out
    assert "next sync" in out or "mydata start" in out
    assert env["verified"] == [("icloud", EMAIL)]
    [a] = Accounts(env["home"], env["store"]).list()
    assert env["store"].get(f"account:{a.id}") == PASSWORD

    assert cli.main(["account", "list"]) == 0
    out, _ = _no_leak(env, capsys)
    assert a.id in out and EMAIL in out and "iCloud" in out and a.created_at in out

    env["answers"].append("n")
    assert cli.main(["account", "remove", a.id]) == 1
    _no_leak(env, capsys)
    assert env["removed"] == [] and env["store"].get(f"account:{a.id}") == PASSWORD

    env["answers"].append("y")
    assert cli.main(["account", "remove", a.id]) == 0
    out, _ = _no_leak(env, capsys)
    assert "Removed" in out
    assert env["removed"] == [a.id]
    assert env["store"].keys() == []
    assert Accounts(env["home"], env["store"]).list() == []


def test_cli_add_prompts_for_email_and_remove_with_yes(cli_env, capsys):
    env = cli_env
    env["answers"].append(EMAIL)
    assert cli.main(["account", "add", "icloud"]) == 0
    _no_leak(env, capsys)
    [a] = Accounts(env["home"], env["store"]).list()
    assert a.email == EMAIL
    assert cli.main(["account", "remove", a.id, "--yes"]) == 0  # no prompt: input would fail on an empty list
    _no_leak(env, capsys)
    assert env["removed"] == [a.id]


def test_cli_add_with_a_wrong_password_stores_nothing(cli_env, capsys, monkeypatch):
    env = cli_env
    wrong = "zzzz-yyyy-xxxx-wwww"  # invented
    monkeypatch.setattr(cli.getpass, "getpass", lambda prompt="": wrong)
    assert cli.main(["account", "add", "icloud", "--email", EMAIL]) == 1
    out, err = _no_leak(env, capsys)
    assert wrong not in out + err + env["caplog"].text
    assert "did not accept" in err and "Nothing was stored" in err
    assert env["store"].keys() == []
    assert not (env["home"] / "accounts.json").exists()


def test_cli_remove_unknown_id(cli_env, capsys):
    assert cli.main(["account", "remove", "nope", "--yes"]) == 1
    _, err = capsys.readouterr()
    assert "no account" in err


def test_cli_remove_data_hook_deletes_rows_with_the_stores(tmp_path, monkeypatch):
    """The real data hook opens contacts.sqlite and calendar.sqlite (only if they exist) and deletes the
    account's rows through the stores."""
    from mydata.service.config import load_settings

    calls = []

    class FakeStore:
        MIGRATIONS = {1: []}  # read by backup.open_store, which opens the stores

        def __init__(self, path):
            self.path = path

        def delete_account(self, account_id):
            calls.append((self.path.name, account_id))

    import types
    monkeypatch.setitem(sys.modules, "mydata.sources.contacts_store", types.SimpleNamespace(ContactsStore=FakeStore))
    monkeypatch.setitem(sys.modules, "mydata.sources.calendar_store", types.SimpleNamespace(CalendarStore=FakeStore))
    settings = load_settings(tmp_path)
    account = Account(id="a1", provider="icloud", email=EMAIL, created_at="2026-01-01T00:00:00+00:00", label="iCloud")
    cli._remove_account_data(settings, account)
    assert calls == []  # no databases yet: nothing is created
    (tmp_path / "contacts.sqlite").touch()
    (tmp_path / "calendar.sqlite").touch()
    cli._remove_account_data(settings, account)
    assert calls == [("contacts.sqlite", "a1"), ("calendar.sqlite", "a1")]
