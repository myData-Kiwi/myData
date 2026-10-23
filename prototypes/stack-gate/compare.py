"""Builds the stack gate's comparison sheets: Flutter on the left, SwiftUI on the right, same scale, labelled.

    uv run --no-project --with pillow python compare.py FLUTTER_DIR SWIFTUI_DIR OUT_DIR

FLUTTER_DIR holds flutter-<state>-<mode>.png (app/apps/mycontacts/test/stack_gate_test.dart) and SWIFTUI_DIR
swiftui-<state>-<mode>.png (prototypes/people-swiftui/snapshot.sh), all 2560x1600 (1280x800 points at 2x).
Writes compare-light.png and compare-dark.png: one row per state, each image at 1280x800 (both scaled the
same way), with identical stand-in close, minimise and zoom buttons drawn on both at the window's own place
(the Flutter image has no title bar of its own: its buttons are the system's, drawn by the window).
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

STATES = [
    ("owned", "An owned contact with every kind of field"),
    ("followed", "A followed contact (This Mac) with a photo; Edit disabled"),
    ("several", "Three contacts selected (one followed)"),
]
NOTE = ("Layout and density only. Neither image shows Liquid Glass or vibrancy: off screen neither stack can draw "
        "them, so both use the same flat stand-ins (sidebar panel, toolbar capsules). Judge the look in the live "
        "windows, beside Contacts.app at the same size.")
# The SwiftUI window's close, minimise and zoom buttons, in points (the renderer's measurement).
LIGHTS = [((19, 19), (0xFF, 0x5F, 0x57)), ((42, 19), (0xFE, 0xBC, 0x2E)), ((65, 19), (0x28, 0xC8, 0x40))]
LIGHT_SIZE = 14
TILE = (1280, 800)
PAD = 24
LABEL_H = 44
HEAD_H = 92


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            f = ImageFont.truetype(path, size)
            if bold:
                try:
                    f.set_variation_by_name("Bold")
                except Exception:
                    pass
            return f
        except OSError:
            continue
    return ImageFont.load_default()


def tile(path: Path, dark: bool) -> Image.Image:
    im = Image.open(path).convert("RGB")
    scale = im.width / TILE[0]
    d = ImageDraw.Draw(im)
    for (x, y), colour in LIGHTS:
        box = [x * scale, y * scale, (x + LIGHT_SIZE) * scale - 1, (y + LIGHT_SIZE) * scale - 1]
        d.ellipse(box, fill=colour, outline=(0, 0, 0) if not dark else (0x40, 0x40, 0x40), width=1)
    return im.resize(TILE, Image.LANCZOS)


def sheet(flutter: Path, swiftui: Path, mode: str) -> Image.Image:
    dark = mode == "dark"
    bg, ink, muted = ((0x15, 0x15, 0x15), (0xF0, 0xF0, 0xF0), (0xA0, 0xA0, 0xA0)) if dark else \
        ((0xF4, 0xF4, 0xF4), (0x10, 0x10, 0x10), (0x60, 0x60, 0x60))
    width = PAD * 3 + TILE[0] * 2
    height = HEAD_H + len(STATES) * (LABEL_H + TILE[1] + PAD) + PAD
    out = Image.new("RGB", (width, height), bg)
    d = ImageDraw.Draw(out)
    d.text((PAD, 16), f"myContacts, People screen: Flutter (left) and SwiftUI (right), {mode}, 1280x800 points",
           font=font(26, True), fill=ink)
    d.text((PAD, 52), NOTE, font=font(17), fill=muted)
    y = HEAD_H
    for state, caption in STATES:
        for i, (name, folder) in enumerate((("Flutter", flutter), ("SwiftUI", swiftui))):
            x = PAD + i * (TILE[0] + PAD)
            d.text((x, y + 10), f"{name}: {caption}", font=font(20, True), fill=ink)
            out.paste(tile(folder / f"{name.lower()}-{state}-{mode}.png", dark), (x, y + LABEL_H))
            d.rectangle([x - 1, y + LABEL_H - 1, x + TILE[0], y + LABEL_H + TILE[1]], outline=muted)
        y += LABEL_H + TILE[1] + PAD
    return out


def main() -> None:
    flutter, swiftui, out = (Path(a) for a in sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    for mode in ("light", "dark"):
        sheet(flutter, swiftui, mode).save(out / f"compare-{mode}.png", optimize=True)
        print(out / f"compare-{mode}.png")


if __name__ == "__main__":
    main()
