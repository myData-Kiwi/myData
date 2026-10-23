#!/usr/bin/env bash
# Rebuilds assets/fonts/Lucide-subset.ttf: the Lucide icon font (ISC; assets/fonts/ISC-lucide.txt) cut down to
# the icons MacIcons names (lib/src/mac/mac_icons.dart). Lucide stands in for SF Symbols, which may only be
# used through Apple's own frameworks (docs/2026-10-23-plan.md, 3(d)).
#   tool/subset_lucide.sh            (from app/packages/mydata_ui; needs curl, python3 and uv)
# Add an icon: its codepoint from the package's font/codepoints.json, here and in MacIcons, then run this.
set -euo pipefail
VERSION=1.61.0
INTEGRITY='yLAiQB3MWUJEstsEDAwenSA3m7vr1tdLvgnC16Q/XMxRRma0DWwMs8M2bWlvgShrIs1m2mWMJ+0AiahqQO4GrA=='
CODEPOINTS=U+e468,U+e46e,U+e18e,U+e1d0,U+e13d,U+e151,U+e084,U+e116,U+e133,U+e10f,U+e111,U+e1a5,U+e1f9,U+e0f9,U+e06c,U+e09e,U+e12a,U+e048

HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -sSfo "$WORK/lucide.tgz" "https://registry.npmjs.org/lucide-static/-/lucide-static-$VERSION.tgz"
python3 -I - "$WORK/lucide.tgz" "$INTEGRITY" <<'EOF'
import base64, hashlib, sys
digest = base64.b64encode(hashlib.sha512(open(sys.argv[1], 'rb').read()).digest()).decode()
sys.exit(0 if digest == sys.argv[2] else 'lucide-static does not match its published integrity')
EOF
mkdir "$WORK/x"
tar -xzf "$WORK/lucide.tgz" -C "$WORK/x" package/font/lucide.ttf package/LICENSE
uvx --from fonttools==4.60.1 pyftsubset "$WORK/x/package/font/lucide.ttf" --unicodes="$CODEPOINTS" \
  --layout-features='' --no-hinting --output-file="$HERE/assets/fonts/Lucide-subset.ttf"
cp "$WORK/x/package/LICENSE" "$HERE/assets/fonts/ISC-lucide.txt"
echo "Wrote assets/fonts/Lucide-subset.ttf from lucide-static $VERSION"
