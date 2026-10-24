#!/usr/bin/env bash
# Rebuilds assets/fonts/catalogue/: the theme fonts that are not among the three core fonts of the pubspec,
# loaded on demand when a theme needs one (lib/src/theme/fonts.dart; design/themes/ARCHITECTURE.md 1.5 and 3.6),
# and the core fonts' extra weights cut from google/fonts (JetBrains Mono Bold, for Terminal).
#   tool/subset_fonts.sh            (from app/packages/mydata_ui; needs curl, python3 and uv)
#
# Each font is a variable font from google/fonts at one pinned commit, checked against its SHA-256, then:
# - cut to Latin (Basic, Latin-1, Extended-A and -B, Extended Additional) and the punctuation, currency,
#   arrows and symbols the apps write, keeping only the layout features text needs (kerning, ligatures,
#   marks, tabular and lining figures);
# - pinned on every axis but weight (`wght` stays, so any weight a theme names is drawn exactly) and, for
#   Inter and Literata, optical size (`opsz` stays: their display sizes are drawn with display optics, the
#   style setting `opsz` to the role's size; MyDataTypeScale.of): Fraunces' optical size at 36 (it is a
#   display face, set at 22 px and up), Newsreader's at 16 (Notebook sets it at 14 to 16 px only, and the axis
#   would double its size), width at 100, Fraunces' SOFT 0 and WONK 0; the weight axis's default
#   moved to 400 where it was another;
# - written as assets/fonts/catalogue/<id>.ttf (and <id>-italic.ttf), with its licence as
#   assets/fonts/OFL-<id>.txt.
# Every font here is SIL OFL 1.1 with no Reserved Font Name (the copyright line of each OFL.txt was read,
# 2026-10-23), so subsets may keep the name. Add a font: its line below, its entry in
# lib/src/theme/catalogue.dart (`fontCatalogue`), then run this; test/theme/fonts_test.dart checks the two agree
# and that every app stays under the font budget.
set -euo pipefail
FONTS_COMMIT=e7db6ca603fd4862010383ff17ffd6cc4ffac1c0
FONTTOOLS=fonttools==4.60.1

# id | google/fonts folder | file | sha256 | axis pins (axis=value or axis=default, comma separated) | italic?
FONTS=$(cat <<'EOF'
inter|inter|Inter[opsz,wght].ttf|29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031||
sora|sora|Sora[wght].ttf|84ff7096ae3ec6c8be47d906d1a0ba4de7f2ce78c615275c77301964a316e16c||
manrope|manrope|Manrope[wght].ttf|3ae11c49db0455a3cc33e37d380f20fdb8c7f8b41dc07625c177e3d87a9d6ae6||
fraunces|fraunces|Fraunces[SOFT,WONK,opsz,wght].ttf|177ff6c0f14e5550a3c624247cd1189611d4eb65d000b14944c63d967958abbb|opsz=36,SOFT=0,WONK=0|
instrument-sans|instrumentsans|InstrumentSans[wdth,wght].ttf|b24f1812584816958afcf22e22d08e44318c5e51651e25d2438efdde389b33b1|wdth=default|
instrument-sans|instrumentsans|InstrumentSans-Italic[wdth,wght].ttf|a74203cc5066a3b2f8de1a7b0887ef897773c2319dc86c911f8e85350cde0d07|wdth=default|italic
fredoka|fredoka|Fredoka[wdth,wght].ttf|2ba02e68b152868aef9ba28e24b3648c7d457fe6f25c761f2c2c53fb61a73fc8|wdth=default|
nunito|nunito|Nunito[wght].ttf|bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207||
literata|literata|Literata[opsz,wght].ttf|b41138c9373112f32abb589cc22e8674b06ed4048b0c513be922bdd26f274440||
literata|literata|Literata-Italic[opsz,wght].ttf|d483dfaeba9cbf4ce71d32a52ee65df82f7e35b15fff8d1011cdb242d1fcd465||italic
atkinson-hyperlegible-next|atkinsonhyperlegiblenext|AtkinsonHyperlegibleNext[wght].ttf|5a455d1cfa099b601ab70751bb9673e8fe1854dc4500c80e1a220d0d75e31745||
atkinson-hyperlegible-next|atkinsonhyperlegiblenext|AtkinsonHyperlegibleNext-Italic[wght].ttf|ce9cffed32742ad2d9238c561a93220385e5934cdc02b8eb4097a50efa957dc6||italic
atkinson-hyperlegible-mono|atkinsonhyperlegiblemono|AtkinsonHyperlegibleMono[wght].ttf|5ce8b1698d1ded7dff2178c1a3ad159470085a58ea239e8b2cb88f4fb4a6f646||
kalam|kalam|Kalam-Bold.ttf|2f6576601db015d4f6c08678120277fc8510b98c06e932ce7a6a9cbff4cbdded||
newsreader|newsreader|Newsreader[opsz,wght].ttf|8a08d13f8a6c0d51be379a60af84f945f65369a67e509ee3c3bdcc421254d7c1|opsz=16|
newsreader|newsreader|Newsreader-Italic[opsz,wght].ttf|796668611f80b64d5adf182fde3b6f29ed83b4e7cbec7b96937e84ac01364792|opsz=16|italic
archivo-black|archivoblack|ArchivoBlack-Regular.ttf|dd9a89a019b4849f66ab75455fe7bdf931311042cbb0f0f97acc061539703180||
space-grotesk|spacegrotesk|SpaceGrotesk[wght].ttf|acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72||
pixelify-sans|pixelifysans|PixelifySans[wght].ttf|9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5||
chakra-petch|chakrapetch|ChakraPetch-SemiBold.ttf|45264de3204ddbd5fb3e14a2402acd5c630d16650ae5fc221d2c52da46a6734b||
outfit|outfit|Outfit[wght].ttf|fc7287273e66929776e2ba54f144fe699080bec29f61bf649d70d871468aeade||
EOF
)
# The core fonts' extra static weights (declared in the pubspec and registered when the app starts): the
# variable font pinned at one weight and cut to the same Latin, as assets/fonts/<file>. Its licence is the
# core font's own (assets/fonts/OFL-*.txt), already bundled.
# file | google/fonts folder | source | sha256 | axis pins
CORE=$(cat <<'EOF'
JetBrainsMono-700.ttf|jetbrainsmono|JetBrainsMono[wght].ttf|48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda|wght=700
EOF
)
UNICODES='U+0000-024F,U+0259,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20C0,U+2113,U+2122,U+2190-21FF,U+2212,U+2215,U+2303,U+2318,U+2325,U+232B,U+25A0-25FF,U+2713,U+FEFF,U+FFFD'
FEATURES='ccmp,locl,mark,mkmk,kern,liga,clig,calt,rlig,rvrn,tnum,pnum,lnum,case,frac,numr,dnom'

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/assets/fonts/catalogue"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT" "$WORK/script"
cat > "$WORK/script/cut.py" <<'EOF'
import sys
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

src, out, pins, unicodes, features = sys.argv[1:6]
font = TTFont(src, recalcTimestamp=False)
options = subset.Options()
options.layout_features = features.split(',')
options.hinting = False
options.notdef_outline = True
subsetter = subset.Subsetter(options)
subsetter.populate(unicodes=subset.parse_unicodes(unicodes))
subsetter.subset(font)
limits = {}
for pin in filter(None, pins.split(',')):
    axis, value = pin.split('=')
    limits[axis] = None if value == 'default' else float(value)
if limits:
    font = instancer.instantiateVariableFont(font, limits)
# The default instance at regular (400) where the axis reaches it, so text that ever loses its `wght`
# variation (a style built from the family alone) is drawn regular, not the source's default (Fraunces
# Black, Manrope and Nunito ExtraLight, Fredoka Light). The whole weight range stays. A static font (Kalam
# Bold, Archivo Black) and a core font's static instance keep their one weight.
wght = next((a for a in font['fvar'].axes if a.axisTag == 'wght'), None) if 'fvar' in font else None
if wght and wght.defaultValue != 400 and wght.minValue <= 400 <= wght.maxValue:
    font = instancer.instantiateVariableFont(font, {'wght': (wght.minValue, 400, wght.maxValue)})
    font['OS/2'].usWeightClass = 400
# Keep the source's timestamp, so a rerun writes the same bytes.
font.recalcTimestamp = False
font.save(out)
EOF

check() {
  python3 -I - "$1" "$2" <<'EOF'
import hashlib, sys
digest = hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest()
sys.exit(0 if digest == sys.argv[2] else f'{sys.argv[1]} does not match its pinned SHA-256')
EOF
}

url() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }

rm -f "$OUT"/*.ttf
while IFS='|' read -r id dir file sha pins italic; do
  [ -n "$id" ] || continue
  src="$WORK/$id-$italic.ttf"
  curl -sSfLo "$src" "https://raw.githubusercontent.com/google/fonts/$FONTS_COMMIT/ofl/$dir/$(url "$file")"
  check "$src" "$sha"
  name="$id${italic:+-italic}.ttf"
  uvx --from "$FONTTOOLS" python -I "$WORK/script/cut.py" "$src" "$OUT/$name" "$pins" "$UNICODES" "$FEATURES"
  curl -sSfLo "$HERE/assets/fonts/OFL-$id.txt" "https://raw.githubusercontent.com/google/fonts/$FONTS_COMMIT/ofl/$dir/OFL.txt"
  echo "Wrote assets/fonts/catalogue/$name ($(wc -c < "$OUT/$name" | tr -d ' ') bytes)"
done <<< "$FONTS"

while IFS='|' read -r name dir file sha pins; do
  [ -n "$name" ] || continue
  src="$WORK/core-$name"
  curl -sSfLo "$src" "https://raw.githubusercontent.com/google/fonts/$FONTS_COMMIT/ofl/$dir/$(url "$file")"
  check "$src" "$sha"
  uvx --from "$FONTTOOLS" python -I "$WORK/script/cut.py" "$src" "$HERE/assets/fonts/$name" "$pins" "$UNICODES" "$FEATURES"
  echo "Wrote assets/fonts/$name ($(wc -c < "$HERE/assets/fonts/$name" | tr -d ' ') bytes)"
done <<< "$CORE"
