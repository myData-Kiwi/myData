"""Build the app icons for the myData family from one set of parts.

Each app has its own colour and one large white glyph, as Pages, Numbers and Keynote are told apart; the kiwi
is myData's alone. The lime of the kiwi's wash is the family's one shared detail (myCalendar's marked day,
myAssistant's spark). No corner badges and no text.

Writes, next to this file:

- ``<app>.icon``: the Icon Composer document macOS 26 uses (a background fill and glyph layers, with dark
  variants; tinted and clear are the system's from the same layers). actool compiles it beside the asset
  catalog, which keeps the classic icon for older systems.
- ``<app>.svg``: the classic macOS icon (the 824 px body on the 1024 grid, Big Sur's shape and shadow) for
  128 px and up; ``<app>-small.svg``: its 16 and 32 pt master (16, 32 and 64 px files), with a larger,
  simpler glyph.
- ``<app>-tile.svg`` and ``<app>-maskable.svg``: web and Windows.

Run from the repo root (cairosvg needs the Homebrew cairo on a Mac; ictool is Xcode's, for --install's
in-app icons and the sheet):

    DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib \\
      uv run --no-project --with cairosvg --with pillow \\
      python design/assets/Logos/app-icons/make_icons.py --install [--sheet PATH]

Without --install it only writes the sources.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
APPS = REPO / "app" / "apps"
UI_ASSETS = REPO / "app" / "packages" / "mydata_ui" / "assets" / "app_icons"
ICTOOL = Path("/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool")

# Brand colours (design/assets/Logos/mydata-kiwi-logo-square.svg).
WASH = "#A9CC4E"
INK = "#2A2018"
WHITE = "#FFFFFF"
DARK_TOP, DARK_BOTTOM = "#3A3A3C", "#1C1C1E"

CANVAS = 1024
BODY = 824
BODY_ORIGIN = 100


@dataclass(frozen=True)
class App:
    id: str
    name: str
    top: str  # background gradient, light
    bottom: str
    glyph_dark: str  # the main glyph's colour on the dark background


APPS_SPEC = [
    App("mydata", "myData", "#EAF4CB", "#D9E8AE", WHITE),
    # The themes' accents (design/themes.json): Dusk, Rose and Plum.
    App("mycontacts", "myContacts", "#5B7BD6", "#3D5AA9", "#9DB4F2"),
    App("mycalendar", "myCalendar", "#F2706B", "#D23B3F", "#FF8E8A"),
    App("myassistant", "myAssistant", "#A56BC2", "#7A3E8E", "#D2A6E0"),
]

# --------------------------------------------------------------------------------------------- the kiwi
# The kiwi mark, exactly as drawn in mydata-kiwi-logo-square.svg (mark units), without the ground line.
KIWI_WASH = (
    '<path d="M50 136 C46 96 82 72 122 76 C160 80 180 110 172 142 '
    'C164 174 122 190 88 182 C66 176 52 160 50 136 Z" fill="{wash}"/>'
)
KIWI_BODY = """\
<g fill="none" stroke="{ink}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round">
<path d="M60 128 C58 94 88 76 120 78 C140 80 150 85 158 78 C162 62 184 57 192 73"/>
<path d="M191 78 C205 95 214 118 219 147 C205 127 194 112 180 98"/>
<path d="M180 98 C179 131 160 164 124 172 C92 178 62 160 60 128"/>
<path d="M104 174 C103 186 105 196 104 206 C110 205 116 207 121 206"/>
<path d="M132 171 C133 184 131 196 133 206 C139 204 145 207 150 205"/>
</g>
<circle cx="179" cy="76" r="{eye}" fill="{ink}"/>"""
KIWI_FEATHERS = """\
<g fill="none" stroke="{ink}" stroke-width="3.5" stroke-linecap="round">
<path d="M90 116 C94 122 94 129 92 135"/>
<path d="M110 110 C114 118 114 126 112 133"/>
<path d="M131 115 C134 122 134 128 132 135"/>
</g>"""
KIWI_CX, KIWI_CY = 134.5, 141.0


def _kiwi_at(inner: str, scale: float, cx: float = 512, cy: float = 512) -> str:
    tx, ty = cx - KIWI_CX * scale, cy - KIWI_CY * scale
    return f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale})">\n{inner}\n</g>'


def kiwi_wash(scale: float, small: bool = False) -> str:
    return _kiwi_at(KIWI_WASH.format(wash=WASH), scale)


def kiwi_ink(scale: float, small: bool = False) -> str:
    body = KIWI_BODY.format(ink=INK, w=9 if small else 6.5, eye=4.2 if small else 3.2)
    return _kiwi_at(body if small else body + "\n" + KIWI_FEATHERS.format(ink=INK), scale)


# --------------------------------------------------------------------------------------------- glyphs
# Each glyph is a list of layers (name, svg body, light colour or None to keep the drawn colours, dark
# colour). Drawn on the 1024 canvas, centred, within about 520 px.


def person(small: bool) -> list[tuple[str, str]]:
    k = 1.14 if small else 1.0
    r = 128 * k
    cy = 512
    head_y = cy - 120 * k
    top, bottom = cy + 54 * k, cy + 288 * k
    half = 216 * k
    x0, x1 = 512 - half, 512 + half
    c = 24 * k
    shoulders = (
        f"M{x0:.1f} {bottom - c:.1f} C{x0:.1f} {top + 70 * k:.1f} {512 - 116 * k:.1f} {top:.1f} 512 {top:.1f} "
        f"C{512 + 116 * k:.1f} {top:.1f} {x1:.1f} {top + 70 * k:.1f} {x1:.1f} {bottom - c:.1f} "
        f"Q{x1:.1f} {bottom:.1f} {x1 - c:.1f} {bottom:.1f} L{x0 + c:.1f} {bottom:.1f} Q{x0:.1f} {bottom:.1f} "
        f"{x0:.1f} {bottom - c:.1f} Z"
    )
    return [("glyph", f'<circle cx="512" cy="{head_y:.1f}" r="{r:.1f}" fill="{{main}}"/>\n'
                      f'<path d="{shoulders}" fill="{{main}}"/>')]


def calendar(small: bool) -> list[tuple[str, str]]:
    k = 1.12 if small else 1.0
    w, h = 480 * k, 460 * k
    x0, y0 = 512 - w / 2, 512 - h / 2 + 10
    rx = 64 * k
    head = 118 * k
    page = f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx:.1f}" fill="{{main}}"/>'
    # The header: the page's top band, in the background's deeper colour.
    header = (
        f'<path d="M{x0:.1f} {y0 + head:.1f} L{x0:.1f} {y0 + rx:.1f} Q{x0:.1f} {y0:.1f} {x0 + rx:.1f} {y0:.1f} '
        f'L{x0 + w - rx:.1f} {y0:.1f} Q{x0 + w:.1f} {y0:.1f} {x0 + w:.1f} {y0 + rx:.1f} L{x0 + w:.1f} {y0 + head:.1f} Z" '
        f'fill="{{deep}}"/>'
    )
    grid_top = y0 + head
    rows = (grid_top + (h - head) * 0.33, grid_top + (h - head) * 0.70)
    cols = (512 - w * 0.27, 512, 512 + w * 0.27)
    dots, marked = [], ""
    for ri, yy in enumerate(rows):
        for ci, xx in enumerate(cols):
            if (ri, ci) == (1, 2):
                marked = f'<circle cx="{xx:.1f}" cy="{yy:.1f}" r="{(58 if small else 46) * k:.1f}" fill="{WASH}"/>'
            elif not small:
                dots.append(f'<circle cx="{xx:.1f}" cy="{yy:.1f}" r="{24 * k:.1f}" fill="{{deep}}"/>')
    if small:
        # 16 and 32 pt: the page, its header and the marked day only.
        return [("glyph", page), ("header", header), ("accent", marked)]
    return [("glyph", page), ("header", header + "\n" + "\n".join(dots)), ("accent", marked)]


def assistant(small: bool) -> list[tuple[str, str]]:
    k = 1.12 if small else 1.0
    bx0, bx1 = 512 - 262 * k, 512 + 262 * k
    by0, by1 = 512 - 222 * k, 512 + 168 * k
    r = 120 * k
    tail_x = 512 - 110 * k
    bubble = (
        f"M{bx0 + r:.1f} {by0:.1f} L{bx1 - r:.1f} {by0:.1f} Q{bx1:.1f} {by0:.1f} {bx1:.1f} {by0 + r:.1f} "
        f"L{bx1:.1f} {by1 - r:.1f} Q{bx1:.1f} {by1:.1f} {bx1 - r:.1f} {by1:.1f} "
        f"L{tail_x + 40 * k:.1f} {by1:.1f} L{tail_x - 60 * k:.1f} {by1 + 104 * k:.1f} L{tail_x - 40 * k:.1f} {by1:.1f} "
        f"L{bx0 + r:.1f} {by1:.1f} Q{bx0:.1f} {by1:.1f} {bx0:.1f} {by1 - r:.1f} "
        f"L{bx0:.1f} {by0 + r:.1f} Q{bx0:.1f} {by0:.1f} {bx0 + r:.1f} {by0:.1f} Z"
    )
    sx, sy = 512, (by0 + by1) / 2
    R, rr = (170 if small else 150) * k, (46 if small else 38) * k
    spark = (
        f"M{sx:.1f} {sy - R:.1f} C{sx + 8:.1f} {sy - rr:.1f} {sx + rr:.1f} {sy - 8:.1f} {sx + R:.1f} {sy:.1f} "
        f"C{sx + rr:.1f} {sy + 8:.1f} {sx + 8:.1f} {sy + rr:.1f} {sx:.1f} {sy + R:.1f} "
        f"C{sx - 8:.1f} {sy + rr:.1f} {sx - rr:.1f} {sy + 8:.1f} {sx - R:.1f} {sy:.1f} "
        f"C{sx - rr:.1f} {sy - 8:.1f} {sx - 8:.1f} {sy - rr:.1f} {sx:.1f} {sy - R:.1f} Z"
    )
    return [("glyph", f'<path d="{bubble}" fill="{{main}}"/>'), ("accent", f'<path d="{spark}" fill="{WASH}"/>')]


def kiwi_layers(small: bool) -> list[tuple[str, str]]:
    scale = 3.7 if small else 3.0
    return [("wash", kiwi_wash(scale, small)), ("ink", kiwi_ink(scale, small))]


GLYPHS = {"mydata": kiwi_layers, "mycontacts": person, "mycalendar": calendar, "myassistant": assistant}

# The header and dots of myCalendar, in light and dark.
DEEP = {"mycalendar": ("#B02A2E", "#D23B3F")}


def layer_svg(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" '
        f'height="{CANVAS}">\n{body}\n</svg>\n'
    )


def glyph_body(app: App, small: bool, dark: bool = False) -> str:
    deep = DEEP.get(app.id, (app.bottom, app.bottom))[1 if dark else 0]
    main = app.glyph_dark if dark else WHITE
    if dark and app.id == "mycalendar":
        deep = DARK_BOTTOM
    return "\n".join(b.format(main=main, deep=deep) for _, b in GLYPHS[app.id](small))


# --------------------------------------------------------------------------------------------- flat SVGs
def squircle(x: float, y: float, size: float, n: float = 5.0, steps: int = 360) -> str:
    """A superellipse path, close to Apple's continuous-corner icon shape."""
    r = size / 2
    cx, cy = x + r, y + r
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        px = cx + r * math.copysign(abs(c) ** (2 / n), c)
        py = cy + r * math.copysign(abs(s) ** (2 / n), s)
        pts.append(f"{px:.2f} {py:.2f}")
    return "M" + " L".join(pts) + " Z"


def flat_svg(app: App, variant: str, small: bool = False) -> str:
    """variant: mac (classic macOS grid with shadow), tile (body fills the canvas: web, Windows, favicon),
    maskable (full-bleed square)."""
    defs = (
        '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{app.top}"/><stop offset="1" stop-color="{app.bottom}"/>'
        "</linearGradient></defs>"
    )
    parts = [defs]
    art = glyph_body(app, small)
    if variant == "mac":
        size, origin = BODY, BODY_ORIGIN
        for i in range(8, 0, -1):
            grow = i * 2.2
            parts.append(
                f'<path d="{squircle(origin - grow, origin - grow + 12, size + 2 * grow)}" fill="#000" '
                'fill-opacity="0.035"/>'
            )
        d = squircle(origin, origin, size)
        parts.append(f'<path d="{d}" fill="url(#bg)"/>')
        parts.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-opacity="0.10" stroke-width="2"/>')
        k = size / CANVAS
        parts.append(f'<g transform="translate({origin} {origin}) scale({k:.5f})">\n{art}\n</g>')
    elif variant == "tile":
        size, origin = 984, 20
        parts.append(f'<path d="{squircle(origin, origin, size)}" fill="url(#bg)"/>')
        k = size / CANVAS
        parts.append(f'<g transform="translate({origin} {origin}) scale({k:.5f})">\n{art}\n</g>')
    elif variant == "maskable":
        parts.append(f'<path d="M0 0 H{CANVAS} V{CANVAS} H0 Z" fill="url(#bg)"/>')
        # The artwork inside the 80 % safe circle.
        parts.append(f'<g transform="translate(102.4 102.4) scale(0.8)">\n{art}\n</g>')
    else:
        raise ValueError(variant)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" '
        f'height="{CANVAS}" role="img" aria-label="{app.name} app icon">\n' + "\n".join(parts) + "\n</svg>\n"
    )


# --------------------------------------------------------------------------------------------- .icon
def srgb(hex_colour: str) -> str:
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def write_icon(app: App) -> Path:
    doc = HERE / f"{app.id}.icon"
    if doc.exists():
        shutil.rmtree(doc)
    (doc / "Assets").mkdir(parents=True)
    layers = []
    deep_light, deep_dark = DEEP.get(app.id, (app.bottom, app.bottom))
    for name, body in GLYPHS[app.id](False):
        file = f"{name}.svg"
        (doc / "Assets" / file).write_text(layer_svg(body.format(main=WHITE, deep=deep_light)), encoding="utf-8")
        layer: dict = {"image-name": file, "name": name}
        # Dark: the glyph in the app's colour on the dark ground (the lime and the kiwi as drawn).
        if name == "glyph":
            layer["fill-specializations"] = [{"appearance": "dark", "value": {"solid": srgb(app.glyph_dark)}}]
        elif name == "header" and app.id == "mycalendar":
            layer["fill-specializations"] = [{"appearance": "dark", "value": {"solid": srgb(DARK_BOTTOM)}}]
        layers.append(layer)
    # Icon Composer lists layers top first.
    layers.reverse()
    fill = {"linear-gradient": [srgb(app.top), srgb(app.bottom)]}
    icon = {
        # myData's icon is green in every appearance (design/assets/Logos/README.md): its dark variant is
        # its light one, said outright, or the system would darken it under a kiwi drawn in dark ink.
        "fill-specializations": [
            {"value": fill},
            {"appearance": "dark", "value": fill if app.id == "mydata" else {
                "linear-gradient": [srgb(DARK_TOP), srgb(DARK_BOTTOM)]}},
        ],
        "groups": [
            {
                "layers": layers,
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "translucency": {"enabled": True, "value": 0.2},
            }
        ],
        "supported-platforms": {"squares": ["macOS"]},
    }
    (doc / "icon.json").write_text(json.dumps(icon, indent=2) + "\n", encoding="utf-8")
    return doc


def ictool(doc: Path, out: Path, px: int, rendition: str = "Default") -> None:
    subprocess.run(
        [str(ICTOOL), str(doc), "--export-image", "--output-file", str(out), "--platform", "macOS",
         "--rendition", rendition, "--width", str(px), "--height", str(px), "--scale", "1"],
        check=True, capture_output=True,
    )


# --------------------------------------------------------------------------------------------- render
def write_sources() -> dict[tuple[str, str], Path]:
    out = {}
    for app in APPS_SPEC:
        for variant, small, suffix in (("mac", False, ""), ("mac", True, "-small"), ("tile", False, "-tile"),
                                       ("maskable", False, "-maskable")):
            path = HERE / f"{app.id}{suffix}.svg"
            path.write_text(flat_svg(app, variant, small), encoding="utf-8")
            out[(app.id, suffix or "mac")] = path
        out[(app.id, "icon")] = write_icon(app)
    return out


def render(path: Path, px: int):
    import cairosvg
    from PIL import Image

    # Render large, then shrink: smoother at 16 and 32 than a direct render.
    big = max(px * 4, 1024) if px <= 256 else px
    png = cairosvg.svg2png(url=str(path), output_width=big, output_height=big)
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    if big != px:
        img = img.resize((px, px), Image.LANCZOS)
    return img


def render_icon(doc: Path, px: int, rendition: str = "Default"):
    from PIL import Image

    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "i.png"
        ictool(doc, out, px, rendition)
        return Image.open(out).convert("RGBA").copy()


def install(src: dict[tuple[str, str], Path]) -> list[Path]:
    written: list[Path] = []
    UI_ASSETS.mkdir(parents=True, exist_ok=True)
    for app in APPS_SPEC:
        root = APPS / app.id
        runner = root / "macos/Runner"
        iconset = runner / "Assets.xcassets/AppIcon.appiconset"
        if iconset.is_dir():
            for px in (16, 32, 64, 128, 256, 512, 1024):
                # 16 and 32 pt (16, 32 and 64 px): the small master.
                master = src[(app.id, "-small")] if px <= 64 else src[(app.id, "mac")]
                p = iconset / f"app_icon_{px}.png"
                render(master, px).save(p, optimize=True)
                written.append(p)
            target = runner / "AppIcon.icon"
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(src[(app.id, "icon")], target)
            written.append(target)
        web = root / "web"
        if web.is_dir():
            render(src[(app.id, "-small")], 16).save(web / "favicon.png", optimize=True)
            written.append(web / "favicon.png")
            for px in (192, 512):
                p = web / "icons" / f"Icon-{px}.png"
                render(src[(app.id, "-tile")], px).save(p, optimize=True)
                written.append(p)
                p = web / "icons" / f"Icon-maskable-{px}.png"
                render(src[(app.id, "-maskable")], px).save(p, optimize=True)
                written.append(p)
        ico = root / "windows/runner/resources/app_icon.ico"
        if ico.parent.is_dir():
            sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
            imgs = [render(src[(app.id, "-small" if s <= 32 else "-tile")], s) for s in sizes]
            imgs[-1].save(ico, format="ICO", sizes=[(s, s) for s in sizes], append_images=imgs[:-1])
            written.append(ico)
        # The icon an alert shows inside the app (MyDataAppIcons in mydata_ui): macOS 26's rendering.
        p = UI_ASSETS / f"{app.id}.png"
        render_icon(src[(app.id, "icon")], 256).save(p, optimize=True)
        written.append(p)
    return written


def make_sheet(src, out: Path) -> None:
    """Every rendition macOS 26 draws (ictool), the classic icon from 128 to 16 px with 16 and 32 enlarged,
    a Dock at 64 px and a Finder list at 16 px, on light and dark grounds."""
    from PIL import Image, ImageDraw

    pad, cell = 24, 160
    renditions = ["Default", "Dark", "TintedLight", "TintedDark", "ClearLight", "ClearDark"]
    rows = len(APPS_SPEC)
    width = pad + len(renditions) * (cell + pad) + 520
    height = pad + rows * (cell + pad) + 2 * (96 + pad) + 2 * (4 * 22 + pad) + pad
    sheet = Image.new("RGBA", (width, height), "#9A9A9A")
    draw = ImageDraw.Draw(sheet)
    for ai, app in enumerate(APPS_SPEC):
        y = pad + ai * (cell + pad)
        for ri, r in enumerate(renditions):
            sheet.alpha_composite(render_icon(src[(app.id, "icon")], cell, r), (pad + ri * (cell + pad), y))
        x = pad + len(renditions) * (cell + pad)
        for ground in ("#FFFFFF", "#1E1E1E"):
            draw.rectangle([x - 8, y, x + 250, y + cell], fill=ground)
            xx = x
            for s in (128, 32, 16):
                master = src[(app.id, "-small")] if s <= 32 else src[(app.id, "mac")]
                sheet.alpha_composite(render(master, s), (xx, y + (cell - s) // 2))
                xx += s + 8
            for s in (16, 32):
                zoom = render(src[(app.id, "-small")], s).resize((64, 64), Image.NEAREST)
                sheet.alpha_composite(zoom, (xx, y + (cell - 64) // 2))
                xx += 64 + 6
            x += 262
    # A Dock at 64 px, light and dark, with macOS 26's renditions.
    y = pad + rows * (cell + pad)
    for ground, rendition in (("#E8E8EA", "Default"), ("#2B2B2E", "Dark")):
        draw.rounded_rectangle([pad, y, pad + 4 * 80 + 24, y + 96], radius=24, fill=ground)
        for ai, app in enumerate(APPS_SPEC):
            sheet.alpha_composite(render_icon(src[(app.id, "icon")], 64, rendition), (pad + 16 + ai * 80, y + 16))
        y += 96 + pad
    # A Finder list at 16 px: the classic small master, as Finder draws it from the asset catalog.
    for ground, ink in (("#FFFFFF", "#000000"), ("#1E1E1E", "#FFFFFF")):
        draw.rectangle([pad, y, pad + 300, y + 4 * 22], fill=ground)
        for ai, app in enumerate(APPS_SPEC):
            sheet.alpha_composite(render(src[(app.id, "-small")], 16), (pad + 8, y + 3 + ai * 22))
            draw.text((pad + 32, y + 4 + ai * 22), f"{app.name}.app", fill=ink)
        y += 4 * 22 + pad
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", action="store_true", help="render into the apps and mydata_ui")
    ap.add_argument("--sheet", type=Path, help="write a contact sheet PNG here")
    args = ap.parse_args()
    src = write_sources()
    if args.install:
        for p in install(src):
            print(p.relative_to(REPO) if p.is_relative_to(REPO) else p)
    if args.sheet:
        make_sheet(src, args.sheet)
        print(args.sheet)


if __name__ == "__main__":
    main()
