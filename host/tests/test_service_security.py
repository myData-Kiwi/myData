"""Requests without the token are refused everywhere; the service listens on localhost only."""

from __future__ import annotations

import os
import socket
import stat
import subprocess
import sys

import httpx
from starlette.testclient import TestClient
import pytest

from mydata.service.config import ConfigError, DEFAULT_CONFIG, load_settings
from mydata.service.security import TokenError, ensure_token, read_token

from service_helpers import TOKEN, make_app, serve

ROUTES = [("GET", "/status"), ("GET", "/tools"), ("GET", "/approvals"), ("GET", "/approvals/x"),
          ("POST", "/approvals/x"), ("POST", "/assistant/messages"), ("GET", "/mcp"), ("POST", "/mcp"),
          ("GET", "/openapi.json"), ("GET", "/docs"), ("GET", "/no-such-route")]


@pytest.mark.parametrize("method,path", ROUTES)
@pytest.mark.parametrize("auth", [None, "Bearer wrong", f"bearer {TOKEN}", TOKEN, f"Bearer {TOKEN} ", "Basic x"])
def test_every_route_refuses_without_the_token(tmp_path, method, path, auth):
    app, registry, spy = make_app(tmp_path)
    headers = {"Authorization": auth} if auth else {}
    with TestClient(app, base_url="http://127.0.0.1") as c:
        r = c.request(method, path, headers=headers, json={"decision": "approve", "text": "hi"})
    assert r.status_code == 401
    assert spy.calls == [] and registry.approvals() == []


@pytest.mark.parametrize("host", ["evil.example", "evil.example:47821", "192.168.1.10", "127.0.0.1.evil.example",
                                  "localhost.evil.example", "", "[::1].evil.example", "[::1]evil", "[::1]x:47821",
                                  "localhost.:47821", "127.0.0.1:47821@evil.example"])
def test_non_local_host_header_is_refused(tmp_path, host):
    app, *_ = make_app(tmp_path)
    with TestClient(app, base_url="http://127.0.0.1") as c:
        r = c.get("/status", headers={"Authorization": f"Bearer {TOKEN}", "Host": host})
    assert r.status_code == 421


@pytest.mark.parametrize("host", ["127.0.0.1", "127.0.0.1:47821", "localhost:47821", "[::1]:47821"])
def test_local_host_header_is_accepted(tmp_path, host):
    app, *_ = make_app(tmp_path)
    with TestClient(app, base_url="http://127.0.0.1") as c:
        assert c.get("/status", headers={"Authorization": f"Bearer {TOKEN}", "Host": host}).status_code == 200


def test_token_file_is_private_and_stable(tmp_path):
    path = tmp_path / "token"
    token = ensure_token(path)
    assert len(token) >= 40 and ensure_token(path) == token and read_token(path) == token
    if not sys.platform.startswith("win"):
        assert stat.S_IMODE(path.stat().st_mode) == 0o600


@pytest.mark.skipif(sys.platform.startswith("win"), reason="POSIX permissions")
def test_exposed_token_is_refused_by_clients_and_replaced_by_the_host(tmp_path):
    path = tmp_path / "token"
    old = ensure_token(path)
    os.chmod(path, 0o644)
    with pytest.raises(TokenError):
        read_token(path)
    new = ensure_token(path)
    assert new != old and stat.S_IMODE(path.stat().st_mode) == 0o600


@pytest.mark.skipif(sys.platform.startswith("win"), reason="POSIX symlinks")
@pytest.mark.parametrize("damage", ["empty", "short", "symlink"])
def test_damaged_token_is_replaced(tmp_path, damage):
    path = tmp_path / "token"
    if damage == "symlink":
        (tmp_path / "elsewhere").write_text("x" * 43)
        path.symlink_to(tmp_path / "elsewhere")
    else:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT, 0o600)
        os.write(fd, b"" if damage == "empty" else b"abc")
        os.close(fd)
    token = ensure_token(path)
    assert len(token) >= 40 and not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600


def test_websocket_upgrade_is_closed_cleanly(tmp_path):
    from starlette.websockets import WebSocketDisconnect
    app, *_ = make_app(tmp_path)
    with TestClient(app, base_url="http://127.0.0.1") as c:
        with pytest.raises(WebSocketDisconnect):
            with c.websocket_connect("/status", headers={"Authorization": f"Bearer {TOKEN}"}):
                pass


@pytest.mark.parametrize("bad", ['port = "abc"', "port = true", 'start_ollama = "false"', 'num_ctx = "8k"',
                                 'level = "LOUD"'])
def test_config_values_are_type_checked(tmp_path, bad):
    key = bad.split(" = ")[0]
    text = "\n".join(bad if line.split(" = ")[0] == key else line for line in DEFAULT_CONFIG.splitlines())
    (tmp_path / "config.toml").write_text(text)
    with pytest.raises(ConfigError):
        load_settings(tmp_path)


@pytest.mark.parametrize("host", ["0.0.0.0", "::", "192.168.1.10", "example.com"])
def test_config_refuses_non_loopback_address(tmp_path, host):
    (tmp_path / "config.toml").write_text(DEFAULT_CONFIG.replace('host = "127.0.0.1"', f'host = "{host}"'))
    with pytest.raises(ConfigError):
        load_settings(tmp_path)


def test_daemon_will_not_start_on_a_non_loopback_address(tmp_path):
    (tmp_path / "config.toml").write_text(DEFAULT_CONFIG.replace('host = "127.0.0.1"', 'host = "0.0.0.0"'))
    r = subprocess.run([sys.executable, "-m", "mydata.service.daemon"], env={**os.environ, "MYDATA_HOME": str(tmp_path)},
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 2 and "loopback" in r.stderr


def _lan_address() -> str | None:
    """This machine's address on its network (not loopback), if it has one."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("10.255.255.255", 1))  # no packet is sent; this only picks a route
            ip = s.getsockname()[0]
        except OSError:
            return None
    return None if ip.startswith("127.") else ip


def test_running_server_is_not_reachable_from_the_network_address(tmp_path):
    app, *_ = make_app(tmp_path)
    ip = _lan_address()
    if ip is None:
        pytest.skip("no non-loopback address on this machine")
    with serve(app) as (base, port):
        assert httpx.get(f"{base}/status", headers={"Authorization": f"Bearer {TOKEN}"}).status_code == 200
        with pytest.raises(OSError):
            socket.create_connection((ip, port), timeout=2).close()
