"""The Unix socket the myDataReader helper connects to: <home>/run/reader.sock.

- <home>/run is created readable only by the user (0700), and the socket file is 0600. A symbolic link or
  a file in place of <home>/run is refused, and nothing it points to is changed. The socket is
  bound under a temporary name, made 0600, then renamed into place, so reader.sock never exists with
  looser permissions whatever the umask. A stale socket file (left by a host that crashed) is removed.
- One connection at a time. A second connection while one is open is closed at once, with a warning in
  the log (which holds no data). On macOS and Linux a peer that is another user is refused as well.
- Line-based JSON: each line is at most `max_line` bytes (snapshots carry photos, so the default is
  64 MB). A longer line, or a line that stalls half-way for `stall_timeout` seconds, closes the
  connection. An idle connection is normal: the helper waits for changes.
"""

from __future__ import annotations

import logging
import os
import secrets
import socket
import stat
import struct
import sys
import threading
import time
from pathlib import Path
from typing import Callable

from ...service.logs import log

logger = logging.getLogger("mydata.mac.socket")

MAX_LINE = 64 * 1024 * 1024
STALL_TIMEOUT = 60.0
SEND_TIMEOUT = 10.0
_POLL = 0.25  # how often blocking calls wake to notice close()

# sockaddr_un.sun_path is 104 bytes on macOS (108 on Linux), including the final NUL.
MAX_PATH_BYTES = 103


class ReaderSocketError(Exception):
    """The socket could not be set up. The message is safe to show."""


def socket_path(home: Path) -> Path:
    return Path(home) / "run" / "reader.sock"


def _peer_uid(conn: socket.socket) -> int | None:
    """The connecting process's user id, where the system can say (macOS, Linux); None otherwise."""
    try:
        if sys.platform == "darwin":
            # getsockopt(SOL_LOCAL=0, LOCAL_PEERCRED=1) -> struct xucred {u_int version; uid_t uid; ...}
            raw = conn.getsockopt(0, 0x001, 76)
            _version, uid = struct.unpack_from("II", raw)
            return uid
        if sys.platform.startswith("linux"):
            raw = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
            _pid, uid, _gid = struct.unpack("3i", raw)
            return uid
    except OSError:
        return None
    return None


class Connection:
    """One accepted helper connection: send lines to it, and a thread reading its lines."""

    def __init__(self, conn: socket.socket, owner: "ReaderSocket"):
        self._sock = conn
        self._owner = owner
        self._send_lock = threading.Lock()
        self._closed = threading.Event()

    @property
    def closed(self) -> bool:
        return self._closed.is_set()

    def send(self, data: bytes) -> bool:
        if self.closed:
            return False
        with self._send_lock:
            try:
                self._sock.settimeout(SEND_TIMEOUT)
                self._sock.sendall(data)
                return True
            except OSError:
                self.close()
                return False
            finally:
                try:
                    self._sock.settimeout(_POLL)
                except OSError:
                    pass

    def close(self) -> None:
        if self._closed.is_set():
            return
        self._closed.set()
        try:
            self._sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            self._sock.close()
        except OSError:
            pass

    def read_lines(self, on_line: Callable[[bytes], None], stopping: threading.Event) -> str:
        """Read until the peer closes, the socket is closed, or a limit is broken. Returns why it ended."""
        buf = bytearray()
        partial_since: float | None = None
        self._sock.settimeout(_POLL)
        while not self.closed and not stopping.is_set():
            try:
                chunk = self._sock.recv(1024 * 1024)
            except socket.timeout:
                if partial_since is not None and time.monotonic() - partial_since > self._owner.stall_timeout:
                    return "stalled"
                continue
            except OSError:
                return "closed"
            if not chunk:
                return "closed"
            buf += chunk
            while True:
                end = buf.find(b"\n")
                if end < 0:
                    break
                line = bytes(buf[:end])
                del buf[:end + 1]
                if len(line) > self._owner.max_line:
                    return "too_long"
                if line.strip():
                    on_line(line)
            if len(buf) > self._owner.max_line:
                return "too_long"
            partial_since = (partial_since or time.monotonic()) if buf else None
        return "closed"


class ReaderSocket:
    """Listen on <home>/run/reader.sock for the helper. on_connect(conn) runs when it connects,
    on_line(bytes) for each line, on_disconnect(why) when it goes; all on the connection's thread."""

    def __init__(self, home: Path, *, on_line: Callable[[bytes], None],
                 on_connect: Callable[[Connection], None] | None = None,
                 on_disconnect: Callable[[str], None] | None = None,
                 max_line: int = MAX_LINE, stall_timeout: float = STALL_TIMEOUT):
        self.path = socket_path(home)
        self.max_line, self.stall_timeout = max_line, stall_timeout
        self._on_line, self._on_connect, self._on_disconnect = on_line, on_connect, on_disconnect
        self._listener: socket.socket | None = None
        self._active: Connection | None = None
        self._lock = threading.Lock()
        self._stopping = threading.Event()
        self._threads: list[threading.Thread] = []
        self.rejected = 0  # connections refused (a second one, or another user's)

    def __repr__(self) -> str:
        return f"ReaderSocket(path={str(self.path)!r})"

    # ---------------------------------------------------------------- lifecycle

    def start(self) -> Path:
        if self._listener is not None:
            return self.path
        if len(os.fsencode(self.path)) > MAX_PATH_BYTES:
            raise ReaderSocketError("The host folder's path is too long for the reader's socket. Use a shorter "
                                    "host folder (MYDATA_HOME).")
        try:
            self._private_run_folder()
            self._remove_stale()
        except OSError as e:
            raise ReaderSocketError(f"Could not prepare the reader's socket folder ({type(e).__name__}).") from None
        run = self.path.parent
        tmp = run / f".reader.{secrets.token_hex(4)}.sock"
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            listener.bind(str(tmp))
            os.chmod(tmp, 0o600)
            os.replace(tmp, self.path)
            listener.listen(4)
            listener.settimeout(_POLL)
        except OSError as e:
            listener.close()
            tmp.unlink(missing_ok=True)
            raise ReaderSocketError(f"Could not open the reader's socket ({type(e).__name__}).") from None
        self._stopping.clear()
        self._listener = listener
        t = threading.Thread(target=self._accept_loop, name="mac-reader-accept", daemon=True)
        self._threads = [t]
        t.start()
        return self.path

    def _private_run_folder(self) -> None:
        """Make <home>/run a folder only this user can use (0700). It is opened without following a symbolic
        link and checked before its mode is changed, so a link or a file in its place is refused and nothing
        it points to is touched."""
        run = self.path.parent
        try:
            run.mkdir(mode=0o700, parents=True)
        except FileExistsError:
            pass
        flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
        try:
            fd = os.open(run, flags)
        except OSError:
            if os.path.islink(run) or not os.path.isdir(run):
                raise ReaderSocketError("The host's run folder is not a folder owned by this user.") from None
            raise
        try:
            info = os.fstat(fd)
            if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
                raise ReaderSocketError("The host's run folder is not a folder owned by this user.")
            if stat.S_IMODE(info.st_mode) != 0o700:
                os.fchmod(fd, 0o700)
        finally:
            os.close(fd)

    def _remove_stale(self) -> None:
        try:
            info = os.lstat(self.path)
        except FileNotFoundError:
            return
        if not stat.S_ISSOCK(info.st_mode):
            raise ReaderSocketError("Something that is not a socket is in the way of the reader's socket.")
        self.path.unlink()
        log(logger, logging.INFO, "removed a stale reader socket")

    def close(self) -> None:
        """Stop listening, drop the connection and remove the socket file."""
        self._stopping.set()
        listener, self._listener = self._listener, None
        if listener is not None:
            try:
                listener.close()
            except OSError:
                pass
        with self._lock:
            active, self._active = self._active, None
        if active is not None:
            active.close()
        for t in self._threads:
            if t is not threading.current_thread():
                t.join(timeout=5)
        self._threads = []
        try:
            if stat.S_ISSOCK(os.lstat(self.path).st_mode):
                self.path.unlink()
        except FileNotFoundError:
            pass

    @property
    def listening(self) -> bool:
        return self._listener is not None

    @property
    def connected(self) -> bool:
        with self._lock:
            return self._active is not None and not self._active.closed

    def send(self, data: bytes) -> bool:
        """Send one encoded line to the helper. False when nothing is connected or sending failed."""
        with self._lock:
            active = self._active
        return active.send(data) if active is not None else False

    def drop(self) -> None:
        """Close the current connection (the helper exits when its socket closes)."""
        with self._lock:
            active = self._active
        if active is not None:
            active.close()

    # ---------------------------------------------------------------- accepting

    def _accept_loop(self) -> None:
        while not self._stopping.is_set():
            listener = self._listener
            if listener is None:
                return
            try:
                conn, _ = listener.accept()
            except socket.timeout:
                continue
            except OSError:
                if self._stopping.is_set():
                    return
                time.sleep(_POLL)
                continue
            uid = _peer_uid(conn)
            if uid is not None and uid != os.getuid():
                self.rejected += 1
                log(logger, logging.WARNING, "refused a reader connection from another user")
                _close(conn)
                continue
            with self._lock:
                busy = self._active is not None and not self._active.closed
                if not busy:
                    self._active = Connection(conn, self)
                    active = self._active
            if busy:
                self.rejected += 1
                log(logger, logging.WARNING, "refused a second reader connection while one is open")
                _close(conn)
                continue
            t = threading.Thread(target=self._serve, args=(active,), name="mac-reader-conn", daemon=True)
            self._threads.append(t)
            t.start()

    def _serve(self, conn: Connection) -> None:
        why = "closed"
        try:
            if self._on_connect is not None:
                self._on_connect(conn)
            why = conn.read_lines(self._on_line, self._stopping)
        except Exception:  # noqa: BLE001 - a handler bug must not leave the connection half open
            logger.exception("reader connection failed")
            why = "error"
        finally:
            conn.close()
            with self._lock:
                if self._active is conn:
                    self._active = None
            if why in ("too_long", "stalled"):
                log(logger, logging.WARNING, "closed the reader connection", reason=why)
            if self._on_disconnect is not None and not self._stopping.is_set():
                try:
                    self._on_disconnect(why)
                except Exception:  # noqa: BLE001
                    logger.exception("after the reader disconnected")


def _close(conn: socket.socket) -> None:
    try:
        conn.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass
    conn.close()
