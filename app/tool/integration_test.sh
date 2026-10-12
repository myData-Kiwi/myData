#!/usr/bin/env bash
# Integration tests for both apps on macOS, each against its own freshly set-up host.
#   app/tool/integration_test.sh [mydata|myassistant]   (default: both)
# Each app gets a temporary host folder (passed with --dart-define=MYDATA_HOME), its own port, and the
# development host command written by `mydata dev-setup`. The app starts the host itself, as it would
# for a user. myAssistant's test needs Ollama and the model (qwen3:14b); myData's does not.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(dirname "$HERE")"
HOST="$(dirname "$APP")/host"
WHICH="${1:-all}"
status=0

run_one() {
  local name="$1" port="$2" ollama_line="$3"
  local home; home="$(mktemp -d "${TMPDIR:-/tmp}/mydata-it-$name.XXXXXX")"
  (cd "$HOST" && MYDATA_HOME="$home" uv run python -c \
    "from mydata.service.config import DEFAULT_CONFIG as D; print(D.replace('port = 47821', 'port = $port')$ollama_line)" \
    > "$home/config.toml")
  (cd "$HOST" && MYDATA_HOME="$home" uv run mydata dev-setup >/dev/null)
  echo "== $name: host folder $home, port $port"
  (cd "$APP/apps/$name" && flutter test integration_test/app_test.dart -d macos --dart-define=MYDATA_HOME="$home")
  local rc=$?
  (cd "$HOST" && MYDATA_HOME="$home" uv run mydata stop >/dev/null)
  if [ $rc -ne 0 ]; then
    echo "== $name: FAILED (host log: $home/logs/mydatad.log)"; status=1
  else
    echo "== $name: passed"; rm -rf "$home"
  fi
}

# myData: no model needed; the test skips the assistant. Point Ollama at a dead port so nothing loads.
[ "$WHICH" = all ] || [ "$WHICH" = mydata ] && \
  run_one mydata 47861 ".replace('http://127.0.0.1:11434', 'http://127.0.0.1:9').replace('start_ollama = true', 'start_ollama = false')"
# myAssistant: the real local Ollama and model.
[ "$WHICH" = all ] || [ "$WHICH" = myassistant ] && run_one myassistant 47862 ""
exit $status
