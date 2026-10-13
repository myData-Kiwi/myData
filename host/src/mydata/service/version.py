"""Whether the host's code on disk changed since it started (`stale` in /status).

The apps compare /status's version and API version with the ones they were built against; those change only with
the API. A fix to sync, the orchestrator or the reader changes neither, so the running host also reports whether
its own source files changed after it started. An app then replaces it (`mydata stop --unless-current`), once,
when the code on disk is the API that app was built against.
"""

from __future__ import annotations

from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]  # src/mydata


def source_signature(root: Path = PACKAGE) -> tuple:
    """(path, mtime, size) of every Python file in the package: cheap enough for every /status."""
    rows = []
    for p in root.rglob("*.py"):
        try:
            st = p.stat()
        except OSError:  # removed while listing: the signature differs anyway
            continue
        rows.append((str(p.relative_to(root)), st.st_mtime_ns, st.st_size))
    return tuple(sorted(rows))


AT_START = source_signature()  # imported by the API module, so when the host starts


def code_changed() -> bool:
    return source_signature() != AT_START
