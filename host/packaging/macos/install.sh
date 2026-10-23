#!/bin/bash
# Installs the host as a login service on this Mac: "myData Host.app" in ~/Applications, started at login by a
# LaunchAgent and independent of every app. Run it again to update; it is idempotent.
#
#   host/packaging/macos/install.sh [--build] [--app PATH] [--dest DIR] [--label LABEL] [--agents-dir DIR]
#                                   [--dry-run]
#
#   --build           build the app first (build_host_app.sh), even if a build exists
#   --app PATH        install this built app (default host/build/macos/myData Host.app, built if missing)
#   --dest DIR        where the app goes (default ~/Applications)
#   --label LABEL     the launchd label (default kiwi.mydata.host)
#   --agents-dir DIR  where the LaunchAgent's plist goes (default ~/Library/LaunchAgents)
#   --dry-run         print what would be done, change nothing
#
# The host folder is $MYDATA_HOME, or ~/Library/Application Support/myData; the LaunchAgent sets MYDATA_HOME
# only when it is not the default. The installed app's `mydata service install` then:
#   - boots out a loaded agent with the same label (its host stops cleanly) and stops any other host running
#     on that folder (a development host started with `mydata start`);
#   - writes the plist and <home>/app_config.json, whose start and stop commands the apps run (the installed
#     app's `mydata start` and `mydata stop`);
#   - bootstraps the agent into this login session, which starts the host, and waits for it to answer.
# The data in the host folder is never touched. uninstall.sh undoes it.
#
# Rebuild and reinstall the myData app before or with the first install: a myData built before 2026-10-23
# still stops the host when it quits, and the installed host then stays stopped until the next login or until
# an app starts it. If launchd will not load the agent because it is switched off in System Settings > General >
# Login Items & Extensions, switch it on and run this again.
#
# Local installs only: an app signed with an Apple Development certificate and downloaded from elsewhere is
# quarantined and blocked by Gatekeeper; that needs Developer ID and notarisation.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$(cd "$HERE/../.." && pwd)"
APP_NAME="myData Host.app"

BUILD=0
SRC_APP=""
DEST_DIR="$HOME/Applications"
DRY=0
SERVICE_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD=1; shift ;;
    --app) SRC_APP="$2"; shift 2 ;;
    --dest) DEST_DIR="$2"; shift 2 ;;
    --label|--agents-dir) SERVICE_ARGS+=("$1" "$2"); shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ "$(uname -s)" == "Darwin" ]] || { echo "install.sh: macOS only" >&2; exit 1; }

say() { if [[ $DRY -eq 1 ]]; then echo "would $*"; else echo "$*"; fi; }

if [[ -z "$SRC_APP" ]]; then
  SRC_APP="$HOST_DIR/build/macos/$APP_NAME"
  if [[ $BUILD -eq 1 || ! -d "$SRC_APP" ]]; then
    say "build $SRC_APP (build_host_app.sh)"
    [[ $DRY -eq 1 ]] || "$HERE/build_host_app.sh"
  fi
elif [[ $BUILD -eq 1 ]]; then
  echo "install.sh: --build and --app are exclusive" >&2; exit 2
fi
absolute() { case "$1" in /*) echo "${1%/}" ;; *) echo "$PWD/${1%/}" ;; esac; }
SRC_APP="$(absolute "$SRC_APP")"
DEST_DIR="$(absolute "$DEST_DIR")"
DEST="$DEST_DIR/$APP_NAME"

if [[ -d "$SRC_APP" ]]; then
  codesign --verify --deep --strict "$SRC_APP" || { echo "install.sh: $SRC_APP is not validly signed" >&2; exit 1; }
elif [[ $DRY -eq 0 ]]; then
  echo "install.sh: no app at $SRC_APP" >&2; exit 1
fi

if [[ "$SRC_APP" != "$DEST" ]]; then
  say "copy $SRC_APP to $DEST"
  if [[ $DRY -eq 0 ]]; then
    # Copy beside it, then swap: a host still running from the old copy keeps its files until it is stopped.
    NEW="$DEST_DIR/.$APP_NAME.new"
    OLD="$DEST_DIR/.$APP_NAME.old"
    mkdir -p "$DEST_DIR"
    rm -rf "$NEW" "$OLD"
    ditto "$SRC_APP" "$NEW"
    [[ ! -e "$DEST" ]] || mv "$DEST" "$OLD"
    mv "$NEW" "$DEST"
    codesign --verify --deep --strict "$DEST"
  fi
fi

if [[ $DRY -eq 1 ]]; then
  # The plan from the built app's own command (the installed copy may not exist yet).
  if [[ -x "$SRC_APP/Contents/MacOS/mydata" ]]; then
    "$SRC_APP/Contents/MacOS/mydata" service install --app "$DEST" "${SERVICE_ARGS[@]+"${SERVICE_ARGS[@]}"}" --dry-run
  else
    echo "would run: \"$DEST/Contents/MacOS/mydata\" service install --app \"$DEST\" ${SERVICE_ARGS[*]-}"
  fi
  exit 0
fi

"$DEST/Contents/MacOS/mydata" service install --app "$DEST" "${SERVICE_ARGS[@]+"${SERVICE_ARGS[@]}"}"
rm -rf "$DEST_DIR/.$APP_NAME.old"
