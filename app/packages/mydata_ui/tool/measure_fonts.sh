#!/usr/bin/env bash
# Measures the fonts each app really carries (design/themes/ARCHITECTURE.md 3.5): builds each app's asset
# bundle (`flutter build bundle`: assets only, no native build, no signing, nothing opened) and adds up every
# font file in it, the framework's Material Icons and any Cupertino Icons included. Icon fonts are not
# tree-shaken in a bundle, as in debug and profile builds, so this is the most an app carries; a release
# build tree-shakes Material and Cupertino Icons to the glyphs it draws.
#   tool/measure_fonts.sh            (from app/packages/mydata_ui)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
APPS="$HERE/../../apps"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for app in "$APPS"/*/; do
  name="$(basename "$app")"
  (cd "$app" && flutter build bundle --release --asset-dir "$WORK/$name" >/dev/null)
  find "$WORK/$name" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec stat -f %z {} + |
    awk -v app="$name" '{s += $1} END {printf "%s: %.2f MB of fonts (%d bytes)\n", app, s / 1048576, s}'
done
