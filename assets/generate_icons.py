#!/usr/bin/env python3
"""Starwave app icon generator for Civics.

Rebuilds the Starwave logo as clean vector geometry and exports:
  - Android adaptive icon vectors (foreground/background drawables)
  - Android legacy webp mipmaps (unused at minSdk 30, kept consistent)
  - iOS AppIcon.appiconset PNGs (base + dark appearance, mac sizes)
  - Play Store 512px icon and preview composites
  - In-app branding marks: Android drawable(+night) ic_logo vectors and
    iOS Logo.imageset transparent PNGs (light + dark appearances)
  - Web browser icons (web/icons/): favicon + apple-touch-icon, inlined as
    data URIs by web/build.mjs (paper background — dark browser chrome would
    swallow the navy mark on transparency)
"""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_RES = os.path.join(ROOT, "android/app/src/main/res")
IOS_ICONSET = os.path.join(ROOT, "apple/Civics/Civics/Assets.xcassets/AppIcon.appiconset")
OUT = os.path.dirname(os.path.abspath(__file__))  # alongside this script in assets/

NAVY = (22, 38, 63)       # #16263F
NAVY_HEX = "#16263F"
BRASS = (169, 128, 47)    # #A9802F
BRASS_HEX = "#A9802F"
PAPER = (247, 244, 236)   # #F7F4EC
PAPER_HEX = "#F7F4EC"
FIELD = (15, 28, 48)      # #0F1C30

# ---- Geometry (108dp viewport, same coordinate space for vector + raster) ----
CX, CY = 47.0, 54.0       # star center (left of center; waves to the right)
R_OUT, R_IN = 20.0, 8.0   # star radii
ARCS = [                  # (radius, color) inner -> outer
    (26.5, NAVY_HEX),
    (32.0, NAVY_HEX),
    (37.5, BRASS_HEX),
]
ARC_SPAN = (-60.0, 60.0)  # degrees, opening to the right
STROKE = 4.5


def star_points(cx, cy, r_out, r_in):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts


def star_path_data():
    pts = star_points(CX, CY, R_OUT, R_IN)
    d = "M{:.2f},{:.2f}".format(*pts[0])
    d += "".join("L{:.2f},{:.2f}".format(*p) for p in pts[1:])
    return d + "Z"


def arc_path_data(r):
    a0, a1 = (math.radians(a) for a in ARC_SPAN)
    x0, y0 = CX + r * math.cos(a0), CY + r * math.sin(a0)
    x1, y1 = CX + r * math.cos(a1), CY + r * math.sin(a1)
    # y-down screen coords: -60 -> 60 is clockwise => sweep=1
    return f"M{x0:.2f},{y0:.2f}A{r:.2f},{r:.2f} 0 0 1 {x1:.2f},{y1:.2f}"


def artwork_bbox():
    """Union bbox of star + arcs in viewport coords."""
    pts = star_points(CX, CY, R_OUT, R_IN)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    r_max = max(r for r, _ in ARCS) + STROKE / 2
    a0, a1 = (math.radians(a) for a in ARC_SPAN)
    for a in (a0, 0.0, a1):
        xs.append(CX + r_max * math.cos(a))
        ys.append(CY + r_max * math.sin(a))
    return min(xs), min(ys), max(xs), max(ys)


# ---- Android vector drawables ----

def write_android_vectors():
    fg = ['<vector xmlns:android="http://schemas.android.com/apk/res/android"',
          '    android:width="108dp"',
          '    android:height="108dp"',
          '    android:viewportWidth="108"',
          '    android:viewportHeight="108">',
          f'    <path android:fillColor="{NAVY_HEX}" android:pathData="{star_path_data()}" />']
    for r, color in ARCS:
        fg.append(f'    <path android:pathData="{arc_path_data(r)}"')
        fg.append(f'        android:strokeColor="{color}"')
        fg.append(f'        android:strokeWidth="{STROKE}"')
        fg.append('        android:strokeLineCap="round"')
        fg.append(f'        android:fillColor="{NAVY_HEX}" android:fillAlpha="0" />')
    fg.append('</vector>')
    with open(os.path.join(ANDROID_RES, "drawable/ic_launcher_foreground.xml"), "w") as f:
        f.write("\n".join(fg) + "\n")

    bg = f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="{PAPER_HEX}" android:pathData="M0,0h108v108h-108z" />
</vector>
'''
    with open(os.path.join(ANDROID_RES, "drawable/ic_launcher_background.xml"), "w") as f:
        f.write(bg)


# ---- Raster rendering (Pillow) ----

def render_master(px, bg, star_color, arc_colors, art_frac=0.60, supersample=4):
    """Render the icon at px*supersample then downscale. Art occupies art_frac of canvas."""
    big = px * supersample
    img = Image.new("RGB", (big, big), bg)
    draw = ImageDraw.Draw(img)

    x0, y0, x1, y1 = artwork_bbox()
    w, h = x1 - x0, y1 - y0
    s = big * art_frac / max(w, h)
    ox = big / 2 - (x0 + w / 2) * s
    oy = big / 2 - (y0 + h / 2) * s

    def T(p):
        return (p[0] * s + ox, p[1] * s + oy)

    # star
    star = [T(p) for p in star_points(CX, CY, R_OUT, R_IN)]
    draw.polygon(star, fill=star_color)
    # arcs
    for (r, _), color in zip(ARCS, arc_colors):
        bbox = [CX * s + ox - r * s, CY * s + oy - r * s,
                CX * s + ox + r * s, CY * s + oy + r * s]
        draw.arc(bbox, start=ARC_SPAN[0], end=ARC_SPAN[1], fill=color,
                 width=int(STROKE * s))
    return img.resize((px, px), Image.LANCZOS)


def rounded(img, radius_frac=0.2237):  # iOS superellipse approx
    px = img.width
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, px, px], radius=int(px * radius_frac), fill=255)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def circle(img):
    px = img.width
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, px, px], fill=255)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


ARC_COLORS = [NAVY, NAVY, BRASS]
ARC_COLORS_DARK = [PAPER, PAPER, BRASS]


def write_android_webp():
    master = render_master(1024, PAPER, NAVY, ARC_COLORS)
    master_round = circle(render_master(1024, PAPER, NAVY, ARC_COLORS))
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in densities.items():
        d = os.path.join(ANDROID_RES, f"mipmap-{name}")
        master.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.webp"), "WEBP", quality=95)
        master_round.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher_round.webp"), "WEBP", quality=95)


def write_ios():
    base = render_master(1024, PAPER, NAVY, ARC_COLORS)
    dark = render_master(1024, FIELD, PAPER, ARC_COLORS_DARK)
    base.save(os.path.join(IOS_ICONSET, "icon-1024.png"))
    dark.save(os.path.join(IOS_ICONSET, "icon-1024-dark.png"))
    # Must match the logical sizes declared in Contents.json below.
    for logical in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = logical * scale
            render_master(px, PAPER, NAVY, ARC_COLORS, supersample=max(1, 1024 // px * 2)).save(
                os.path.join(IOS_ICONSET, f"icon-{logical}@{scale}x.png"))

    import json
    contents = {
        "images": [
            {"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "icon-1024-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    for logical in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            contents["images"].append({
                "filename": f"icon-{logical}@{scale}x.png",
                "idiom": "mac", "scale": f"{scale}x", "size": f"{logical}x{logical}"})
    with open(os.path.join(IOS_ICONSET, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


def write_store_and_previews():
    render_master(512, PAPER, NAVY, ARC_COLORS).save(os.path.join(OUT, "play-store-icon-512.png"))

    # preview: iOS rounded + Android circle side by side on paper
    px = 512
    canvas = Image.new("RGB", (px * 2 + 240, px + 240), PAPER)
    ios_icon = rounded(render_master(px, PAPER, NAVY, ARC_COLORS, art_frac=0.60))
    and_icon = circle(render_master(px, PAPER, NAVY, ARC_COLORS, art_frac=0.66))
    # subtle border around icons
    canvas.paste(ios_icon, (80, 120), ios_icon)
    canvas.paste(and_icon, (px + 160, 120), and_icon)
    canvas.save(os.path.join(OUT, "starwave-preview.png"))


# ---- In-app branding mark (small logo shown in screen headers) ----

LOGO_PAD = 2.0  # breathing room around the artwork bbox, in viewport units
IOS_LOGO_SET = os.path.join(ROOT, "apple/Civics/Civics/Assets.xcassets/Logo.imageset")
ARC_COLORS_HEX = [NAVY_HEX, NAVY_HEX, BRASS_HEX]
ARC_COLORS_DARK_HEX = [PAPER_HEX, PAPER_HEX, BRASS_HEX]


def logo_viewbox():
    """Square viewbox tightly framing the artwork (bbox + pad, centered)."""
    x0, y0, x1, y1 = artwork_bbox()
    x0, y0, x1, y1 = x0 - LOGO_PAD, y0 - LOGO_PAD, x1 + LOGO_PAD, y1 + LOGO_PAD
    w, h = x1 - x0, y1 - y0
    side = max(w, h)
    return x0 - (side - w) / 2, y0 - (side - h) / 2, side


def android_logo_xml(star_color, arc_colors):
    """Vector of just the mark; the launcher foreground keeps its adaptive-icon padding."""
    vx, vy, side = logo_viewbox()
    lines = ['<vector xmlns:android="http://schemas.android.com/apk/res/android"',
             f'    android:width="{side:.0f}dp"',
             f'    android:height="{side:.0f}dp"',
             f'    android:viewportWidth="{side:.2f}"',
             f'    android:viewportHeight="{side:.2f}">',
             f'    <group android:translateX="{-vx:.2f}" android:translateY="{-vy:.2f}">',
             f'        <path android:fillColor="{star_color}" android:pathData="{star_path_data()}" />']
    for (r, _), color in zip(ARCS, arc_colors):
        lines += [f'        <path android:pathData="{arc_path_data(r)}"',
                  f'            android:strokeColor="{color}"',
                  f'            android:strokeWidth="{STROKE}"',
                  '            android:strokeLineCap="round"',
                  f'            android:fillColor="{star_color}" android:fillAlpha="0" />']
    lines.append('    </group>')
    lines.append('</vector>')
    return "\n".join(lines) + "\n"


def render_logo_rgba(px, star_color, arc_colors, art_frac=0.94, supersample=4):
    """Transparent-background render of just the mark, tightly framed."""
    big = px * supersample
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x0, y0, x1, y1 = artwork_bbox()
    w, h = x1 - x0, y1 - y0
    s = big * art_frac / max(w, h)
    ox = big / 2 - (x0 + w / 2) * s
    oy = big / 2 - (y0 + h / 2) * s

    star = [(p[0] * s + ox, p[1] * s + oy) for p in star_points(CX, CY, R_OUT, R_IN)]
    draw.polygon(star, fill=star_color + (255,))
    for (r, _), color in zip(ARCS, arc_colors):
        bbox = [CX * s + ox - r * s, CY * s + oy - r * s,
                CX * s + ox + r * s, CY * s + oy + r * s]
        draw.arc(bbox, start=ARC_SPAN[0], end=ARC_SPAN[1], fill=color + (255,),
                 width=int(STROKE * s))
    return img.resize((px, px), Image.LANCZOS)


def write_branding():
    with open(os.path.join(ANDROID_RES, "drawable/ic_logo.xml"), "w") as f:
        f.write(android_logo_xml(NAVY_HEX, ARC_COLORS_HEX))
    night_dir = os.path.join(ANDROID_RES, "drawable-night")
    os.makedirs(night_dir, exist_ok=True)
    with open(os.path.join(night_dir, "ic_logo.xml"), "w") as f:
        f.write(android_logo_xml(PAPER_HEX, ARC_COLORS_DARK_HEX))

    os.makedirs(IOS_LOGO_SET, exist_ok=True)
    import json
    images = []
    for scale in (1, 2, 3):
        render_logo_rgba(64 * scale, NAVY, ARC_COLORS).save(
            os.path.join(IOS_LOGO_SET, f"logo-light@{scale}x.png"))
        render_logo_rgba(64 * scale, PAPER, ARC_COLORS_DARK).save(
            os.path.join(IOS_LOGO_SET, f"logo-dark@{scale}x.png"))
        images.append({"filename": f"logo-light@{scale}x.png",
                       "idiom": "universal", "scale": f"{scale}x"})
        images.append({"appearances": [{"appearance": "luminosity", "value": "dark"}],
                       "filename": f"logo-dark@{scale}x.png",
                       "idiom": "universal", "scale": f"{scale}x"})
    with open(os.path.join(IOS_LOGO_SET, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)


def write_web():
    """Browser icons for the web app; web/build.mjs inlines them as data URIs."""
    web_icons = os.path.join(ROOT, "web/icons")
    os.makedirs(web_icons, exist_ok=True)
    # Favicon shows at 16px: art fills more of the canvas than an app icon.
    render_master(32, PAPER, NAVY, ARC_COLORS, art_frac=0.78).save(
        os.path.join(web_icons, "favicon-32.png"))
    render_master(180, PAPER, NAVY, ARC_COLORS, art_frac=0.66).save(
        os.path.join(web_icons, "apple-touch-icon.png"))


if __name__ == "__main__":
    write_android_vectors()
    write_android_webp()
    write_ios()
    write_store_and_previews()
    write_branding()
    write_web()
    print("bbox:", artwork_bbox())
    print("done")
