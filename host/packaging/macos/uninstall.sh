#!/bin/bash
# Removes the host's login service: boots the LaunchAgent out (the host stops cleanly), removes its plist, takes
# the installed host's commands out of <home>/app_config.json and deletes "myData Host.app". The data in the
# host folder ($MYDATA_HOME, or ~/Library/Application Support/myData) is left as it is. Idempotent.
#
#   host/packaging/macos/uninstall.sh [--dest DIR] [--label LABEL] [--agents-dir DIR] [--dry-run]
#
#   --dest DIR        where the app is (default ~/Applications)
#   --label LABEL     the launchd label (default: the one recorded in app_config.json, else kiwi.mydata.host)
#   --agents-dir DIR  where the plist is (default: the recorded one, else ~/Library/LaunchAgents)
#   --dry-run         print what would be done, change nothing
#
# Afterwards the apps have no command to start the host with; run `uv run mydata dev-setup` in host/ to point
# them at a development checkout, or install.sh again.
set -euo pipefail

APP_NAME="myData Host.app"
DEST_DIR="$HOME/Applications"
LABEL=""
AGENTS_DIR=""
DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST_DIR="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ "$(uname -s)" == "Darwin" ]] || { echo "uninstall.sh: macOS only" >&2; exit 1; }

say() { if [[ $DRY -eq 1 ]]; then echo "would $*"; else echo "$*"; fi; }
APP="$DEST_DIR/$APP_NAME"
DRY_ARG=(); [[ $DRY -eq 0 ]] || DRY_ARG=(--dry-run)
ARGS=()
[[ -z "$LABEL" ]] || ARGS+=(--label "$LABEL")
[[ -z "$AGENTS_DIR" ]] || ARGS+=(--agents-dir "$AGENTS_DIR")

if [[ -x "$APP/Contents/MacOS/mydata" ]]; then
  "$APP/Contents/MacOS/mydata" service uninstall "${ARGS[@]+"${ARGS[@]}"}" "${DRY_ARG[@]+"${DRY_ARG[@]}"}"
else
  # The app is gone already: unload and remove the agent by hand, if it serves this host folder.
  HOME_DIR="${MYDATA_HOME:-$HOME/Library/Application Support/myData}"
  LABEL="${LABEL:-kiwi.mydata.host}"
  PLIST="${AGENTS_DIR:-$HOME/Library/LaunchAgents}/$LABEL.plist"
  if [[ -f "$PLIST" ]]; then
    SERVED="$(plutil -extract EnvironmentVariables.MYDATA_HOME raw -o - "$PLIST" 2>/dev/null \
              || echo "$HOME/Library/Application Support/myData")"
    if [[ "$SERVED" != "$HOME_DIR" ]]; then
      echo "uninstall.sh: $PLIST serves another host folder ($SERVED); nothing done" >&2
      exit 1
    fi
  fi
  if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    say "boot out the LaunchAgent $LABEL (it stops the host it runs)"
    [[ $DRY -eq 1 ]] || launchctl bootout "gui/$(id -u)/$LABEL"
  fi
  if [[ -f "$PLIST" ]]; then
    say "remove $PLIST"
    [[ $DRY -eq 1 ]] || rm -f "$PLIST"
  fi
  echo "$APP is not there, so $HOME_DIR/app_config.json was not changed; run \`uv run mydata dev-setup\` in" \
       "host/ (or install.sh) to give the apps a host to start."
fi

if [[ -e "$APP" ]]; then
  say "remove $APP"
  [[ $DRY -eq 1 ]] || rm -rf "$APP"
fi
