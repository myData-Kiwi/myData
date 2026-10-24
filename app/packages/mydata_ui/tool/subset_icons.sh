#!/usr/bin/env bash
# Rebuilds the icon fonts (design/themes/ARCHITECTURE.md 1.5 and 3.6): each icon set a theme may draw, cut down
# to the glyphs tool/icons.json maps to the semantic ids (MyDataIcon), one font per weight, and writes
# lib/src/theme/icon_sets.g.dart, the const IconData tables (const, so release builds can tree-shake them).
#   tool/subset_icons.sh            (from app/packages/mydata_ui; needs curl, python3 and uv)
#
# Sets and weights bundled (Pixelarticons, Iconoir and Material Symbols Sharp come with the first theme that
# draws them):
# - Lucide (ISC): one weight, `Lucide`. Also System's icons on macOS, in place of SF Symbols, which may only
#   be used through Apple's own frameworks (docs/2026-10-23-plan.md, 3(d)).
# - Tabler Icons (MIT): stroke 200, 300 and 400 as thin, light and regular (`TablerThin`, `TablerLight`,
#   `Tabler`). Its filled set covers too few icons to stand for `fill`.
# - Phosphor (MIT): light, regular, bold and fill (`PhosphorLight`, `Phosphor`, `PhosphorBold`, `PhosphorFill`).
# - Material Symbols (Apache-2.0), Outlined and Rounded: the variable font pinned at static instances (optical
#   size 20, grade 0) at weight 300, 400 and 600 as light, regular and bold, and filled at 400 as fill
#   (`MaterialOutlinedLight` ... `MaterialRoundedFill`). From google/material-design-icons at one commit,
#   checked against its SHA-256; names from the font's own `.codepoints` file (`material` in tool/icons.json).
# A weight a set lacks is drawn in the nearest one it has (lib/src/theme/icons.dart).
# Add an icon: its id in MyDataIcon (lib/src/theme/icons.dart) and its line in tool/icons.json, then run this.
set -euo pipefail
FONTTOOLS=fonttools==4.60.1

# package | version | npm integrity (sha512) | licence file in the package
PACKAGES=$(cat <<'EOF'
lucide-static|1.61.0|yLAiQB3MWUJEstsEDAwenSA3m7vr1tdLvgnC16Q/XMxRRma0DWwMs8M2bWlvgShrIs1m2mWMJ+0AiahqQO4GrA==|LICENSE
@tabler/icons-webfont|3.49.0|kWgnmEzo17dzQyMqRmlfj+TiGV0clLMYfUtKp2WG7M+TH5418o6fsoaSlrOTK3lwESg0xS7jVfOozYrR02Ryxw==|LICENSE
@phosphor-icons/web|2.1.2|rPAR9o/bEcp4Cw4DEeZHXf+nlGCMNGkNDRizYHM47NLxz9vvEHp/Tt6FMK1NcWadzw/pFDPnRBGi/ofRya958A==|LICENSE
EOF
)

# Material Symbols: style | SHA-256 of the variable font | SHA-256 of its .codepoints
MATERIAL_COMMIT=737e3324305806514d7909874fa1818ae1808232
MATERIAL=$(cat <<'EOF'
Outlined|5ca6cdf74da4018e8a7687995c9e392b1a7ec49588fade2be3a97a2a06dd3262|225bd09137103cb7746bc93dc08d08764c9f0c3bd04f4b958d4a3c3c19432dd6
Rounded|95b24392bb49efd1bc3e92cff4e2452ad094461bab7c97e7d8723fab97e330ca|225bd09137103cb7746bc93dc08d08764c9f0c3bd04f4b958d4a3c3c19432dd6
EOF
)

HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/script"

while IFS='|' read -r name version integrity licence; do
  [ -n "$name" ] || continue
  base="${name##*/}"
  curl -sSfo "$WORK/$base.tgz" "https://registry.npmjs.org/$name/-/$base-$version.tgz"
  python3 -I - "$WORK/$base.tgz" "$integrity" "$name" <<'EOF'
import base64, hashlib, sys
digest = base64.b64encode(hashlib.sha512(open(sys.argv[1], 'rb').read()).digest()).decode()
sys.exit(0 if digest == sys.argv[2] else f'{sys.argv[3]} does not match its published integrity')
EOF
  mkdir -p "$WORK/$base"
  tar -xzf "$WORK/$base.tgz" -C "$WORK/$base"
done <<< "$PACKAGES"

check() {
  python3 -I - "$1" "$2" <<'EOF'
import hashlib, sys
digest = hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest()
sys.exit(0 if digest == sys.argv[2] else f'{sys.argv[1]} does not match its pinned SHA-256')
EOF
}
mkdir -p "$WORK/material"
while IFS='|' read -r style font_sha points_sha; do
  [ -n "$style" ] || continue
  base="https://raw.githubusercontent.com/google/material-design-icons/$MATERIAL_COMMIT/variablefont/MaterialSymbols$style%5BFILL%2CGRAD%2Copsz%2Cwght%5D"
  curl -sSfLo "$WORK/material/$style.ttf" "$base.ttf"
  curl -sSfLo "$WORK/material/$style.codepoints" "$base.codepoints"
  check "$WORK/material/$style.ttf" "$font_sha"
  check "$WORK/material/$style.codepoints" "$points_sha"
done <<< "$MATERIAL"
curl -sSfLo "$WORK/material/LICENSE" "https://raw.githubusercontent.com/google/material-design-icons/$MATERIAL_COMMIT/LICENSE"

cp "$WORK/lucide-static/package/LICENSE" "$HERE/assets/fonts/ISC-lucide.txt"
cp "$WORK/icons-webfont/package/LICENSE" "$HERE/assets/fonts/MIT-tabler.txt"
cp "$WORK/web/package/LICENSE" "$HERE/assets/fonts/MIT-phosphor.txt"
cp "$WORK/material/LICENSE" "$HERE/assets/fonts/Apache-material-symbols.txt"

cat > "$WORK/script/cut.py" <<'EOF'
import json, re, sys
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

work, here = sys.argv[1:3]
icons = json.load(open(f'{here}/tool/icons.json'))['icons']

def css(path):
    text = open(path).read()
    return {m[1]: int(m[2], 16) for m in re.finditer(r'\.ti-([a-z0-9-]+):before\s*\{\s*content:\s*"\\([0-9a-f]+)"', text)}

def phosphor(weight):
    folder = 'regular' if weight == 'regular' else weight
    out = {}
    for i in json.load(open(f'{work}/web/package/src/{folder}/selection.json'))['icons']:
        for alias in i['properties']['name'].split(', '):
            out[alias.removesuffix(f'-{weight}')] = i['properties']['code']
    return out

def ttf(folder):
    return f'{work}/web/package/src/{folder}/Phosphor{"" if folder == "regular" else "-" + folder.capitalize()}.ttf'

def material(style):
    return {name: int(code, 16) for name, code in
            (line.split() for line in open(f'{work}/material/{style}.codepoints') if line.strip())}

lucide = json.load(open(f'{work}/lucide-static/package/font/codepoints.json'))
tabler = css(f'{work}/icons-webfont/package/dist/tabler-icons.css')
fonts = [
    # family, set, weight, source font, name -> code point, tool/icons.json key, variable instance (or None)
    ('Lucide', 'lucide', 'regular', f'{work}/lucide-static/package/font/lucide.ttf', lucide, 'lucide', None),
    ('TablerThin', 'tabler', 'thin', f'{work}/icons-webfont/package/dist/fonts/tabler-icons-200.ttf', tabler,
     'tabler', None),
    ('TablerLight', 'tabler', 'light', f'{work}/icons-webfont/package/dist/fonts/tabler-icons-300.ttf', tabler,
     'tabler', None),
    ('Tabler', 'tabler', 'regular', f'{work}/icons-webfont/package/dist/fonts/tabler-icons.ttf', tabler, 'tabler',
     None),
    ('PhosphorLight', 'phosphor', 'light', ttf('light'), phosphor('light'), 'phosphor', None),
    ('Phosphor', 'phosphor', 'regular', ttf('regular'), phosphor('regular'), 'phosphor', None),
    ('PhosphorBold', 'phosphor', 'bold', ttf('bold'), phosphor('bold'), 'phosphor', None),
    ('PhosphorFill', 'phosphor', 'fill', ttf('fill'), phosphor('fill'), 'phosphor', None),
]
for style in ('Outlined', 'Rounded'):
    for weight, fill, wght in (('light', 0, 300), ('regular', 0, 400), ('bold', 0, 600), ('fill', 1, 400)):
        family = f'Material{style}{"" if weight == "regular" else weight.capitalize()}'
        fonts.append((family, f'material-{style.lower()}', weight, f'{work}/material/{style}.ttf', material(style),
                      'material', {'FILL': fill, 'GRAD': 0, 'opsz': 20, 'wght': wght}))

def camel(family):
    return family[0].lower() + family[1:]

lines = [
    '// GENERATED by tool/subset_icons.sh from tool/icons.json. Do not edit.',
    '//',
    '// Each icon set\'s glyph for each semantic id, per weight. Const, so a release build tree-shakes the icon',
    '// fonts (`flutter build --tree-shake-icons`, the default).',
    '',
    "import 'package:flutter/widgets.dart';",
    '',
    "import 'catalogue.dart';",
    "import 'icons.dart';",
    '',
]
tables = {}
for family, s, weight, source, codes, key, pins in fonts:
    missing = [i['id'] for i in icons if i[key] not in codes]
    if missing:
        sys.exit(f'{family} has no glyph for {", ".join(missing)}')
    points = sorted({codes[i[key]] for i in icons})
    options = subset.Options()
    options.layout_features = []
    options.hinting = False
    options.notdef_outline = True
    # Loaded and saved as pyftsubset does: a font opened with TTFont's defaults has its bounds recalculated
    # on save, which moves Lucide's outlines off their side bearings (and off System's goldens).
    font = subset.load_font(source, options)
    sub = subset.Subsetter(options)
    sub.populate(unicodes=points)
    sub.subset(font)
    if pins:
        # A static instance per weight (and for the fill), as Phosphor ships them: an Icon draws a variable
        # font at its default instance unless it sets every axis itself.
        font = instancer.instantiateVariableFont(font, pins)
    subset.save_font(font, f'{here}/assets/fonts/{family}-subset.ttf', options)
    name = f'{camel(family)}Icons'
    tables.setdefault(s, []).append((weight, name))
    lines.append(f'/// {family}: {s}, {weight}.')
    lines.append(f'const {name} = <MyDataIcon, IconData>{{')
    for i in icons:
        lines.append(f"  MyDataIcon.{i['id']}: IconData(0x{codes[i[key]]:x}, fontFamily: '{family}', fontPackage: fontPackage), "
                     f"// {i[key]}")
    lines.append('};')
    lines.append('')
lines.append('/// Every bundled icon font, by set and weight.')
lines.append('const iconTables = <String, Map<String, Map<MyDataIcon, IconData>>>{')
for s, ws in tables.items():
    lines.append(f"  '{s}': {{" + ', '.join(f"'{w}': {n}" for w, n in ws) + '},')
lines.append('};')
open(f'{here}/lib/src/theme/icon_sets.g.dart', 'w').write('\n'.join(lines) + '\n')
print('\n'.join(f'{f}: {len(icons)} icons' for f, *_ in fonts))
EOF
uvx --from "$FONTTOOLS" python -I "$WORK/script/cut.py" "$WORK" "$HERE"
