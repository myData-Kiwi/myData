"""Starting the myDataReader helper.

The helper lives inside the myData app: myData.app/Contents/Helpers/myDataReader.app. macOS attributes it
to the containing app, so the permission prompt names myData and the grant belongs to myData.app.

The host never runs the helper's binary itself: a child process makes its parent the "responsible" app
for privacy prompts (the host's Python, or a terminal). It asks LaunchServices instead:

    /usr/bin/open -g -j -n -a <helper path> --args --socket <socket path>    (or -b kiwi.mydata.reader)

-g: do not bring it forward; -j: launch it hidden; -n: a new instance even if one is running.

Where the helper is: (a) the path the myData app reported (PUT /sources/mac/reader, kept in state.json),
checked again before every launch; else (b) LaunchServices finds it by bundle id. The check
(validate_helper_path) resolves symbolic links, then requires:
- the path to end in <something>.app/Contents/Helpers/myDataReader.app, with the bundle id
  kiwi.mydata.reader in the helper's Info.plist;
- the containing app to be the myData app (bundle id kiwi.mydata.mydata);
- `codesign --verify --deep --strict` to pass on the containing app, whose seal covers the helper; and
- the helper to be signed by the same identity as the containing app (team and certificate, or both ad hoc).
So the host starts only a helper that came inside a signed myData app. A development build is signed ad
hoc, which proves less: anyone can sign a copy ad hoc. Pinning a team id is possible once releases are
signed with a Developer ID (see "Open questions" in CLAUDE.md).
"""

from __future__ import annotations

import os
import plistlib
import re
import subprocess
from pathlib import Path
from typing import Callable

BUNDLE_ID = "kiwi.mydata.reader"
APP_BUNDLE_ID = "kiwi.mydata.mydata"
HELPER_SUFFIX = ("Contents", "Helpers", "myDataReader.app")
OPEN = "/usr/bin/open"
CODESIGN = "/usr/bin/codesign"


class LaunchError(Exception):
    """The helper could not be started. The message is safe to show."""


def _bundle_id(bundle: Path) -> str | None:
    try:
        with (bundle / "Contents" / "Info.plist").open("rb") as fh:
            info = plistlib.load(fh)
    except FileNotFoundError:
        return None
    except (OSError, plistlib.InvalidFileException, ValueError):
        raise ValueError("An Info.plist at that path could not be read.") from None
    value = info.get("CFBundleIdentifier") if isinstance(info, dict) else None
    return value if isinstance(value, str) else None


def _codesign(args: list[str]) -> subprocess.CompletedProcess:
    """Run /usr/bin/codesign. (The host's tests replace it where they use bundles made up for the test.)"""
    return subprocess.run([CODESIGN, *args], capture_output=True, text=True, timeout=60, check=False)


def signing_identity(details: str) -> tuple[str, str]:
    """(team, signer) from `codesign -dvv` output: the team identifier and the first authority, or "adhoc"."""
    team = re.search(r"^TeamIdentifier=(.*)$", details, re.M)
    authority = re.search(r"^Authority=(.*)$", details, re.M)
    adhoc = re.search(r"^Signature=adhoc$", details, re.M)
    return (team.group(1).strip() if team else "not set",
            "adhoc" if adhoc or authority is None else authority.group(1).strip())


def check_signature(app: Path, helper: Path, run: Callable[[list[str]], subprocess.CompletedProcess] = _codesign
                    ) -> None:
    """The myData app's signature is valid, seals the helper, and both are signed by one identity. Raises
    ValueError with a message for the user."""
    try:
        verified = run(["--verify", "--deep", "--strict", str(app)])
        if verified.returncode != 0:
            raise ValueError("The myData app around the reader is not validly signed.")
        app_info, helper_info = run(["-dvv", str(app)]), run(["-dvv", str(helper)])
    except (OSError, subprocess.SubprocessError):
        raise ValueError("The reader's signature could not be checked.") from None
    if app_info.returncode != 0 or helper_info.returncode != 0:
        raise ValueError("The reader's signature could not be read.")
    if signing_identity(app_info.stderr) != signing_identity(helper_info.stderr):
        raise ValueError("The reader is not signed by the same identity as the myData app around it.")


def validate_helper_path(path: str | Path, *, signature: Callable[[Path, Path], None] | None = check_signature
                         ) -> Path:
    """The helper's path, checked (see the top of this file) and with symbolic links resolved. Raises
    ValueError with a message for the user. `signature` checks the signatures (None skips that: only for
    tests that use bundles made up for the test)."""
    p = Path(path)
    if not p.is_absolute():
        raise ValueError("The reader's path must be absolute.")
    if ".." in p.parts:
        raise ValueError("The reader's path must not contain '..'.")
    real = Path(os.path.realpath(p))
    if tuple(real.parts[-3:]) != HELPER_SUFFIX or not real.parents[2].name.endswith(".app"):
        raise ValueError("The reader's path must end in .app/Contents/Helpers/myDataReader.app.")
    helper_id = _bundle_id(real)
    if helper_id is None:
        raise ValueError("There is no reader at that path.")
    if helper_id != BUNDLE_ID:
        raise ValueError(f"The app at that path is not the reader ({BUNDLE_ID}).")
    app = real.parents[2]
    if _bundle_id(app) != APP_BUNDLE_ID:
        raise ValueError(f"The reader is not inside the myData app ({APP_BUNDLE_ID}).")
    if signature is not None:
        signature(app, real)
    return real


def launch_command(socket_path: Path, helper_path: Path | None) -> list[str]:
    target = ["-a", str(helper_path)] if helper_path is not None else ["-b", BUNDLE_ID]
    return [OPEN, "-g", "-j", "-n", *target, "--args", "--socket", str(socket_path)]


def _open_run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run /usr/bin/open. (Replaced in the host's tests, which never start the real reader.)"""
    return subprocess.run(cmd, **kwargs)


class MacReaderLauncher:
    """Starts the helper through LaunchServices. `run` (default: subprocess.run) and `signature` (default:
    codesign) are injectable for tests."""

    def __init__(self, run: Callable[..., subprocess.CompletedProcess] | None = None, timeout: float = 30.0,
                 signature: Callable[[Path, Path], None] | None = check_signature):
        self._run = run
        self.timeout = timeout
        self.signature = signature

    def validate(self, path: str | Path) -> Path:
        """validate_helper_path with this launcher's signature check."""
        return validate_helper_path(path, signature=self.signature)

    def launch(self, socket_path: Path, helper_path: Path | None) -> None:
        if helper_path is not None:
            try:
                helper_path = self.validate(helper_path)
            except ValueError:
                helper_path = None  # moved or deleted since it was reported: fall back to the bundle id
        cmd = launch_command(socket_path, helper_path)
        try:
            result = (self._run or _open_run)(cmd, capture_output=True, timeout=self.timeout, check=False)
        except (OSError, subprocess.SubprocessError) as e:
            raise LaunchError(f"Could not start the reader ({type(e).__name__}).") from None
        if result.returncode != 0:
            raise LaunchError("The reader was not found. Open the myData app once, so the host can find it.")
