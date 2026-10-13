"""Static checks over src/mydata: no HTTP client exists anywhere except DavClient.request.

The DAV mirror is read-only because every HTTP call to a DAV server goes through DavClient.request,
which refuses write methods. These tests make that structural: they fail if any module imports an HTTP
library (or reaches one through an attribute or importlib), apart from an allow-list of files that only
talk to localhost.
"""

import ast
from pathlib import Path

import mydata

SRC = Path(mydata.__file__).parent

# Modules that can make network requests.
BANNED = ("httpx", "urllib.request", "urllib3", "requests", "http.client", "aiohttp", "socket", "pycurl",
          "httplib2", "websockets", "websocket", "ftplib", "asyncio.open_connection", "treq", "grequests")

# path (relative to src/mydata) -> modules it may use, and why.
ALLOWED = {
    "sources/dav/client.py": {"httpx"},  # DavClient.request: the one DAV choke point
    "orchestrator/ollama.py": {"urllib.request"},  # Ollama on localhost
    "service/model.py": {"urllib.request"},  # Ollama on localhost (model pull, status)
    "cli.py": {"urllib.request"},  # the host's own API on 127.0.0.1
    "feasibility/latency.py": {"urllib.request"},  # Ollama on localhost (measurement harness)
    "feasibility/timing.py": {"urllib.request"},  # Ollama on localhost (measurement harness)
}


def _banned(name: str) -> str | None:
    for b in BANNED:
        if name == b or name.startswith(b + "."):
            return b
    return None


def _dotted(node: ast.AST) -> str | None:
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
        return ".".join(reversed(parts))
    return None


def _is_type_checking(test: ast.AST) -> bool:
    return (isinstance(test, ast.Name) and test.id == "TYPE_CHECKING") or \
        (isinstance(test, ast.Attribute) and test.attr == "TYPE_CHECKING")


def network_uses(tree: ast.AST) -> list[tuple[int, str]]:
    """(line, banned module) for every runtime use of a network module."""
    found: list[tuple[int, str]] = []

    def visit(node: ast.AST) -> None:
        if isinstance(node, ast.If) and _is_type_checking(node.test):
            for child in node.orelse:  # the TYPE_CHECKING body never runs
                visit(child)
            return
        if isinstance(node, ast.Import):
            for alias in node.names:
                if b := _banned(alias.name):
                    found.append((node.lineno, b))
        elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
            names = [node.module] + [f"{node.module}.{a.name}" for a in node.names]
            for n in names:
                if b := _banned(n):
                    found.append((node.lineno, b))
                    break
        elif isinstance(node, ast.Attribute):
            dotted = _dotted(node)
            if dotted and (b := _banned(dotted)) and "." in b:  # urllib.request.urlopen after `import urllib`
                found.append((node.lineno, b))
        elif isinstance(node, ast.Call):
            fn = _dotted(node.func)
            if fn in ("importlib.import_module", "import_module", "__import__") and node.args \
                    and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str):
                if b := _banned(node.args[0].value):
                    found.append((node.lineno, b))
        for child in ast.iter_child_nodes(node):
            visit(child)

    visit(tree)
    return found


def _sources():
    for path in sorted(SRC.rglob("*.py")):
        rel = path.relative_to(SRC).as_posix()
        yield rel, ast.parse(path.read_text(), filename=str(path))


def test_the_scanner_catches_every_form():
    code = """
import httpx
import urllib.request as ur
from urllib import request
from http import client
import socket
import urllib
urllib.request.urlopen("https://example.com")
import importlib
importlib.import_module("requests")
__import__("aiohttp")
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    import httpx  # fine: never runs
"""
    hits = {b for _, b in network_uses(ast.parse(code))}
    lines = [line for line, _ in network_uses(ast.parse(code))]
    assert hits == {"httpx", "urllib.request", "http.client", "socket", "requests", "aiohttp"}
    assert 14 not in lines


def test_no_http_outside_davclient_and_the_localhost_allow_list():
    problems = []
    for rel, tree in _sources():
        allowed = ALLOWED.get(rel, set())
        for line, b in network_uses(tree):
            if b not in allowed:
                problems.append(f"{rel}:{line} uses {b}")
    assert not problems, "HTTP outside DavClient.request:\n" + "\n".join(problems)


def test_only_davclient_request_touches_the_http_client():
    """Inside client.py, the httpx client is used only by DavClient.request (built in __init__, closed in
    close); no other module reaches into a DavClient's `_http`."""
    for rel, tree in _sources():
        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute) and node.attr == "_http" and rel != "sources/dav/client.py":
                raise AssertionError(f"{rel}:{node.lineno} touches DavClient._http")
    tree = ast.parse((SRC / "sources/dav/client.py").read_text())
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "DavClient")
    users = {}
    for fn in cls.body:
        if isinstance(fn, ast.FunctionDef):
            for node in ast.walk(fn):
                if isinstance(node, ast.Attribute) and node.attr == "_http":
                    users.setdefault(fn.name, []).append(node.lineno)
    assert set(users) == {"__init__", "request", "close"}
    # Module-level code in client.py makes no requests: httpx is used only to build types and transports.
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name != "DavClient":
            for sub in ast.walk(node):
                if isinstance(sub, ast.Call) and (_dotted(sub.func) or "").split(".")[-1] in (
                        "request", "get", "post", "put", "delete", "send", "stream", "urlopen"):
                    if node.name != "_ReadOnlyTransport":
                        raise AssertionError(f"client.py:{sub.lineno} makes a call outside DavClient.request")
