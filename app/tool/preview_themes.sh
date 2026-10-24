#!/usr/bin/env bash
# The theme preview harness (design/themes/ARCHITECTURE.md 5, phase 3½): any theme file, drawn by the real
# apps on the same four screens (myContacts' people with a contact open, myCalendar's month, myAssistant's
# chat with an approval card, myData's Settings, Sources) inside the Mac window at 1280 x 900, light and
# dark, with synthetic data. Off-screen: every picture is made by `flutter test`; nothing opens a window.
#
#   app/tool/preview_themes.sh [THEME...] [--palette ID] [--contrast] [--all-screens] [--out FOLDER]
#
#   THEME          `all` (the default: every folder of design/themes), a slug of design/themes (`kiwi`), or
#                  the path of a theme file. A file in design/themes, or whose id is `mydata.<slug>`
#                  (a theme being ported), is checked as a built-in.
#   --palette ID   only that palette (a theme without it is refused).
#   --contrast     every picture at increased contrast too.
#   --all-screens  each app's other screens too, in each theme's default palette.
#   --out FOLDER   where to write (default: $TMPDIR/mydata-theme-preview). Never inside the checkout.
#
# Writes, per theme: <out>/<slug>/check.txt (the validator's report: both modes, normal and increased
# contrast), <out>/<slug>/<app>-<screen>.<palette>-<mode>.png and <out>/<slug>.png (one sheet: a row per
# palette and mode, a column per app). A theme the validator refuses is reported and not drawn; the command
# then exits 1 after drawing the others.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(dirname "$HERE")"
OUT="${TMPDIR:-/tmp}/mydata-theme-preview"
THEMES=() PALETTE="" CONTRAST=false ALL_SCREENS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --palette) PALETTE="${2:?--palette needs an id}"; shift 2 ;;
    --contrast) CONTRAST=true; shift ;;
    --all-screens) ALL_SCREENS=true; shift ;;
    --out) OUT="${2:?--out needs a folder}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option $1 (see --help)" >&2; exit 2 ;;
    *)
      if [[ "$1" == */* || "$1" == *.json ]]; then
        [ -f "$1" ] || { echo "No theme file at $1" >&2; exit 2; }
        THEMES+=("$(cd "$(dirname "$1")" && pwd)/$(basename "$1")")
      else
        THEMES+=("$1")
      fi
      shift ;;
  esac
done
[ ${#THEMES[@]} -eq 0 ] && THEMES=(all)
for t in "${THEMES[@]}"; do
  [[ "$t" == *,* ]] && { echo "A theme's name or path may not hold a comma: $t" >&2; exit 2; }
done
LIST="$(IFS=,; echo "${THEMES[*]}")"

[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
case "$OUT/" in "$(dirname "$APP")"/*) echo "Write outside the checkout (--out)" >&2; exit 2 ;; esac
mkdir -p "$OUT"
LOGS="$OUT/logs"
mkdir -p "$LOGS"
rm -f "$OUT"/*/check.txt   # the summary below lists this run's themes only

DEFINES=(
  --dart-define=MYDATA_PREVIEW="$OUT"
  --dart-define=MYDATA_PREVIEW_THEMES="$LIST"
  --dart-define=MYDATA_PREVIEW_PALETTE="$PALETTE"
  --dart-define=MYDATA_PREVIEW_CONTRAST="$CONTRAST"
  --dart-define=MYDATA_PREVIEW_ALL_SCREENS="$ALL_SCREENS"
)
status=0

step() { # name, folder, test file, extra flutter test arguments...
  local name="$1" dir="$2" file="$3"; shift 3
  printf '%-12s ' "$name"
  if (cd "$APP/$dir" && flutter test --no-pub -r expanded "$file" "${DEFINES[@]}" "$@" >"$LOGS/$name.log" 2>&1); then
    echo "ok"
  else
    echo "failed (see $LOGS/$name.log)"; status=1
  fi
}

(cd "$APP" && flutter pub get >/dev/null)
step check packages/mydata_ui test/theme/theme_preview_test.dart --plain-name 'theme preview: check'
for app in mycontacts mycalendar myassistant mydata; do
  step "$app" "apps/$app" test/theme_preview_test.dart
done
step sheets packages/mydata_ui test/theme/theme_preview_test.dart --plain-name 'theme preview: sheets'

echo
for check in "$OUT"/*/check.txt; do
  [ -f "$check" ] || continue
  slug="$(basename "$(dirname "$check")")"
  printf '%-12s %s\n' "$slug" "$(grep '^Verdict:' "$check" | cut -d' ' -f2)"
done
echo "Pictures and reports: $OUT"
exit $status
