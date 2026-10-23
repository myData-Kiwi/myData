#!/bin/bash
# Builds "myData Host.app" (kiwi.mydata.host): the host as a Mac app with its own Python, started at login by
# a LaunchAgent (install.sh) and independent of every app.
#
#   host/packaging/macos/build_host_app.sh [--out DIR] [--identity ID] [--python VERSION]
#
#   --out DIR         where the app goes (default host/build/macos; git ignores host/build)
#   --identity ID     the code-signing identity: a SHA-1 hash, a name, or "-" for ad hoc. Default: the
#                     identity named by CODE_SIGN_IDENTITY in the myData app's Signing.local.xcconfig (git-
#                     ignored), else $MYDATA_SIGN_IDENTITY, else ad hoc with a warning
#   --python VERSION  the CPython to bundle (default 3.11, the version CI tests)
#
# What goes in:
#   Contents/MacOS/mydatad          launcher (the bundle's executable): runs the daemon (argv[0] "mydatad")
#   Contents/MacOS/mydata           launcher: the mydata command (start, stop, status, service ...)
#   Contents/Resources/python       uv's managed CPython (python-build-standalone, relocatable), trimmed, with
#                                   the host and its locked dependencies (host/uv.lock, wheels only, hashes
#                                   checked) installed into its site-packages and every module compiled
#   Contents/Resources/THIRD-PARTY.txt  what is bundled and under which licences
#
# Nothing is fetched when the host runs. Building needs uv, the Xcode command line tools and, the first
# time, the network (the Python and the wheels; uv caches both).
#
# Signing, inside out: every Mach-O file in the Python (the interpreter, libpython, lib-dynload and the
# wheels' extension modules), then the mydata launcher, then the bundle (which signs mydatad). The result
# must pass `codesign --verify --deep --strict`. Development signing only: no hardened runtime, no
# timestamp. A public release would add a Developer ID Application certificate, `--options runtime` (and
# whatever entitlements the bundled Python then needs, likely com.apple.security.cs.allow-unsigned-
# executable-memory for cffi), secure timestamps, notarisation and stapling.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$(cd "$HERE/../.." && pwd)"
REPO_DIR="$(cd "$HOST_DIR/.." && pwd)"
APP_NAME="myData Host"
BUNDLE_ID="kiwi.mydata.host"
MIN_MACOS="13.0"
SIGNING_XCCONFIG="$REPO_DIR/app/apps/mydata/macos/Runner/Configs/Signing.local.xcconfig"

OUT="$HOST_DIR/build/macos"
IDENTITY=""
PY_REQUEST="3.11"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --identity) IDENTITY="$2"; shift 2 ;;
    --python) PY_REQUEST="$2"; shift 2 ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "build_host_app.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || { echo "build_host_app.sh: macOS only" >&2; exit 1; }
command -v uv >/dev/null || { echo "build_host_app.sh: uv is not installed (https://docs.astral.sh/uv/)" >&2; exit 1; }

# --- The signing identity ---------------------------------------------------------------------------------
resolve_identity() {
  # A name such as "Apple Development" matches every identity whose name starts with it; codesign refuses an
  # ambiguous one, so pick the single match by its hash.
  local want="$1" matches
  if [[ "$want" == "-" || "$want" =~ ^[0-9A-Fa-f]{40}$ ]]; then echo "$want"; return; fi
  matches="$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "\(.*\)"$/\1 \2/p' \
             | while read -r hash name; do [[ "$name" == "$want"* ]] && echo "$hash"; done)"
  case "$(printf '%s' "$matches" | grep -c .)" in
    1) echo "$matches" ;;
    0) echo "build_host_app.sh: no valid code-signing identity named \"$want\"" >&2; return 1 ;;
    *) echo "build_host_app.sh: several identities named \"$want\"; pass --identity with one's SHA-1 hash" >&2
       return 1 ;;
  esac
}

if [[ -z "$IDENTITY" && -f "$SIGNING_XCCONFIG" ]]; then
  IDENTITY="$(sed -n 's/^[[:space:]]*CODE_SIGN_IDENTITY[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' \
              "$SIGNING_XCCONFIG" | tail -n 1)"
fi
[[ -n "$IDENTITY" ]] || IDENTITY="${MYDATA_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  echo "build_host_app.sh: no signing identity found; signing ad hoc (every build is then a new app to macOS)" >&2
  IDENTITY="-"
fi
SIGN_HASH="$(resolve_identity "$IDENTITY")"

# --- The Python ---------------------------------------------------------------------------------------------
uv python install --quiet "$PY_REQUEST"
PY_SRC_EXE="$(uv python find --managed-python --no-project "$PY_REQUEST")"
PY_SRC="$(cd "$(dirname "$PY_SRC_EXE")/.." && pwd -P)"
PYVER="$("$PY_SRC_EXE" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PYFULL="$("$PY_SRC_EXE" -c 'import platform; print(platform.python_version())')"
PBS_BUILD="$(cat "$PY_SRC/BUILD" 2>/dev/null || echo unknown)"
HOST_VERSION="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$HOST_DIR/src/mydata/__init__.py")"
[[ -n "$HOST_VERSION" ]] || { echo "build_host_app.sh: cannot read the host's version" >&2; exit 1; }

echo "Building $APP_NAME.app $HOST_VERSION with CPython $PYFULL (python-build-standalone $PBS_BUILD)"

mkdir -p "$OUT"
WORK="$(mktemp -d "$OUT/.build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/$APP_NAME.app"
CONTENTS="$APP/Contents"
PYROOT="$CONTENTS/Resources/python"
BPY="$PYROOT/bin/python$PYVER"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# A copy, never the original: uv's Python is also what the development venv runs.
ditto "$PY_SRC" "$PYROOT"
STDLIB="$PYROOT/lib/python$PYVER"
# Trim what the host never uses: headers, Tcl/Tk, IDLE, the test suite, pip and setuptools, the static
# library, every other program in bin/.
rm -rf "$PYROOT/include" "$PYROOT/share" "$PYROOT/lib/pkgconfig" "$PYROOT"/lib/tcl* "$PYROOT"/lib/tk* \
       "$PYROOT"/lib/itcl* "$PYROOT"/lib/thread* "$PYROOT"/lib/libtcl* \
       "$STDLIB/test" "$STDLIB/idlelib" "$STDLIB/tkinter" "$STDLIB/turtledemo" "$STDLIB/ensurepip" \
       "$STDLIB"/config-"$PYVER"-* "$STDLIB/EXTERNALLY-MANAGED" \
       "$STDLIB"/site-packages/pip "$STDLIB"/site-packages/pip-* "$STDLIB"/site-packages/setuptools \
       "$STDLIB"/site-packages/setuptools-* "$STDLIB"/site-packages/_distutils_hack \
       "$STDLIB"/site-packages/distutils-precedence.pth "$STDLIB"/lib-dynload/_tkinter* \
       "$STDLIB"/lib-dynload/_test* "$STDLIB"/lib-dynload/xxlimited*
find "$PYROOT/bin" -mindepth 1 ! -name "python$PYVER" -exec rm -f {} +
find "$PYROOT" -name __pycache__ -type d -prune -exec rm -rf {} +

# --- The host and its locked dependencies -------------------------------------------------------------------
uv export --project "$HOST_DIR" --frozen --no-dev --no-emit-project --format requirements.txt --quiet \
  -o "$WORK/requirements.txt"
uv pip install --python "$BPY" --quiet --no-config --link-mode copy --no-deps --require-hashes \
  --only-binary :all: -r "$WORK/requirements.txt"
uv build --project "$HOST_DIR" --wheel --quiet --out-dir "$WORK/dist" "$HOST_DIR"
uv pip install --python "$BPY" --quiet --no-config --link-mode copy --no-deps "$WORK"/dist/mydata-*.whl
# The installers' console scripts name the build folder's interpreter; the launchers replace them.
find "$PYROOT/bin" -mindepth 1 ! -name "python$PYVER" -exec rm -f {} +
# The daemon's interpreter is a copy named mydatad, so the process is called mydatad.
cp "$BPY" "$PYROOT/bin/mydatad"

# Compile every module now: the host runs with -B and never writes into its signed bundle. Unchecked hashes:
# a copy of the app (which may change file times) still uses them.
"$BPY" -I -m compileall -q -f -j 0 --invalidation-mode unchecked-hash "$STDLIB" >"$WORK/compileall.log" 2>&1 || {
  # A few test files of third-party packages are not valid Python on purpose; only report.
  echo "build_host_app.sh: compileall reported problems (see below); the modules it compiled are kept" >&2
  grep -E '^\*\*\*|Error' "$WORK/compileall.log" | head -n 20 >&2 || true
}

# --- What is bundled, and under which licences -------------------------------------------------------------
"$BPY" -I - "$PYFULL" "$PBS_BUILD" >"$CONTENTS/Resources/THIRD-PARTY.txt" <<'PY'
import sys
from importlib.metadata import distributions
py, build = sys.argv[1], sys.argv[2]
print("myData Host bundles the following.\n")
print(f"CPython {py} (PSF License 2.0; lib/python*/LICENSE.txt), built by python-build-standalone {build}")
print("(https://github.com/astral-sh/python-build-standalone, BSD-3-Clause), which links OpenSSL (Apache-2.0),")
print("SQLite (public domain), libffi (MIT), XZ Utils (0BSD), zlib (Zlib), bzip2 (bzip2-1.0.6), mpdecimal")
print("(BSD-2-Clause), libedit (BSD-3-Clause), ncurses (X11) and libuuid (BSD-3-Clause).\n")
print("Python packages (each one's licence text is in its .dist-info folder):")
rows = []
for d in distributions():
    m = d.metadata
    classifiers = [c.split(" :: ")[-1] for c in (m.get_all("Classifier") or []) if c.startswith("License ::")]
    short = ((m.get("License") or "").strip().splitlines() or [""])[0][:60]
    lic = m.get("License-Expression") or ", ".join(classifiers) or short or "see its metadata"
    rows.append((m["Name"], d.version, lic))
for name, version, lic in sorted(rows, key=lambda r: r[0].lower()):
    print(f"  {name} {version}: {lic}")
PY

# --- Launchers and Info.plist -------------------------------------------------------------------------------
ARCH="$(uname -m)"
for spec in "mydatad:mydatad:mydata.service.daemon" "mydata:python$PYVER:mydata.cli"; do
  IFS=: read -r name python module <<<"$spec"
  xcrun --sdk macosx clang -O2 -Wall -Wextra -Werror -arch "$ARCH" -mmacosx-version-min="$MIN_MACOS" \
    -DMYDATA_NAME="\"$name\"" -DMYDATA_PYTHON="\"$python\"" -DMYDATA_MODULE="\"$module\"" \
    -o "$CONTENTS/MacOS/$name" "$HERE/launcher.c"
done

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>mydatad</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$HOST_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$HOST_VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>myData, AGPL-3.0-or-later</string>
</dict>
</plist>
PLIST
plutil -lint -s "$CONTENTS/Info.plist"

# --- Signing, inside out ------------------------------------------------------------------------------------
echo "Signing with ${IDENTITY} (${SIGN_HASH})"
# codesign says "replacing existing signature" for every file the wheels or uv had signed ad hoc.
quiet() { grep -v ': replacing existing signature$' >&2 || true; }
sign() { codesign --force --timestamp=none --sign "$SIGN_HASH" "$@" 2> >(quiet); }
# Every Mach-O file in the Python, except the two interpreters, which get identifiers of their own.
find "$PYROOT" -type f \( -name '*.so' -o -name '*.dylib' \) -print0 | xargs -0 -n 64 codesign --force \
  --timestamp=none --sign "$SIGN_HASH" 2> >(quiet)
leftover="$(find "$PYROOT" -type f -perm +111 ! -name '*.so' ! -name '*.dylib' -print0 \
            | xargs -0 file -h | grep 'Mach-O' | cut -d: -f1 | grep -v -e "/bin/python$PYVER\$" -e '/bin/mydatad$' || true)"
[[ -z "$leftover" ]] || { echo "build_host_app.sh: unexpected programs in the Python:" >&2; echo "$leftover" >&2; exit 1; }
sign --identifier "$BUNDLE_ID.python" "$BPY"
sign --identifier "$BUNDLE_ID.mydatad" "$PYROOT/bin/mydatad"
sign --identifier "$BUNDLE_ID.mydata" "$CONTENTS/MacOS/mydata"
sign "$APP"
codesign --verify --deep --strict "$APP"

# --- Done: replace the previous build ------------------------------------------------------------------------
rm -rf "$OUT/$APP_NAME.app"
mv "$APP" "$OUT/$APP_NAME.app"
echo "Built $OUT/$APP_NAME.app ($(du -sh "$OUT/$APP_NAME.app" | cut -f1), signed by ${IDENTITY})"
