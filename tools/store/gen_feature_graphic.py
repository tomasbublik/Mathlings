#!/usr/bin/env python3
"""Usage (from the repo root): python3 tools/store/gen_feature_graphic.py

Writes tools/store/feature_graphic_art.svg: the Google Play feature graphic
artwork (1024x500) WITHOUT the title. The "Mathlings" wordmark is drawn on
top in Baloo 2 by tools/store/render_feature_graphic.gd, which also renders
the final PNG (store/graphics/feature_graphic_1024x500.png).

Layout: soft sky gradient with clouds, a sunny sunburst spotlight with the
cheering Mathling on the left, and playful maths "candy" (+ - x = shapes)
plus a few fruit skins from the game floating around the title area on the
right. Play may crop / overlay the edges, so key content stays well inside.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.dont_write_bytecode = True  # keep tools/mascot free of __pycache__
sys.path.insert(0, os.path.join(ROOT, "tools", "mascot"))
import gen_mascot as g  # noqa: E402

W, H = 1024, 500
SKINS = os.path.join(ROOT, "assets", "images", "skins")
OUT = os.path.join(HERE, "feature_graphic_art.svg")

MINT_DARK = "#14A176"
CORAL_DARK = "#D94646"


def skin(name, cx, cy, size, rot=0.0, opacity=1.0):
    """Embeds a 128x128 game fruit skin centred at (cx, cy)."""
    src = open(os.path.join(SKINS, f"skin_{name}.svg")).read()
    src = re.sub(r"<!--.*?-->", "", src, flags=re.S)
    inner = re.sub(r"^.*?<svg[^>]*>", "", src, flags=re.S)
    inner = inner.replace("</svg>", "")
    s = size / 128.0
    return (f'<g opacity="{opacity}" transform="translate({cx} {cy}) rotate({rot}) '
            f'scale({s:.4f}) translate(-64 -64)">{inner}</g>')


def candy_bar(x, y, w, h):
    r = h / 2
    return f'<rect x="{x-w/2:.1f}" y="{y-h/2:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}"/>'


def candy(kind, cx, cy, size, fill, edge, rot=0.0):
    """Chunky rounded maths operator with a darker 'pressable' edge + shine."""
    t = size * 0.34          # stroke thickness of the glyph
    a = size / 2             # half length
    if kind == "plus":
        bars = candy_bar(0, 0, 2 * a, t) + candy_bar(0, 0, t, 2 * a)
    elif kind == "minus":
        bars = candy_bar(0, 0, 2 * a, t)
    elif kind == "times":
        bars = (f'<g transform="rotate(45)">{candy_bar(0, 0, 2 * a, t)}{candy_bar(0, 0, t, 2 * a)}</g>')
    elif kind == "equals":
        bars = candy_bar(0, -t * 0.72, 2 * a, t * 0.9) + candy_bar(0, t * 0.72, 2 * a, t * 0.9)
    else:
        raise ValueError(kind)
    edge_w = size * 0.13
    return (f'<g transform="translate({cx} {cy}) rotate({rot})">'
            f'<g transform="translate(0 {size*0.09:.1f})" fill="{edge}" stroke="{edge}" '
            f'stroke-width="{edge_w:.1f}" stroke-linejoin="round">{bars}</g>'
            f'<g fill="{edge}" stroke="{edge}" stroke-width="{edge_w:.1f}" stroke-linejoin="round">{bars}</g>'
            f'<g fill="{fill}">{bars}</g>'
            f'<circle cx="{-a*0.55:.1f}" cy="{-t*0.12:.1f}" r="{t*0.16:.1f}" fill="#FFFFFF" opacity="0.8"/>'
            f'</g>')


def cloud(cx, cy, s, opacity=0.9):
    return (f'<g fill="#FFFFFF" opacity="{opacity}" transform="translate({cx} {cy}) scale({s})">'
            '<ellipse cx="-60" cy="10" rx="70" ry="40"/><ellipse cx="10" cy="-12" rx="78" ry="52"/>'
            '<ellipse cx="80" cy="12" rx="66" ry="38"/><rect x="-120" y="10" width="260" height="40" rx="20"/>'
            '</g>')


def sparkle(cx, cy, s, fill, edge):
    return g.star4(cx, cy, s, fill, edge)


def mascot(cx, cy, scale):
    uid = "fg"
    bd, bi = g.body_parts(uid)
    md, mi = g.mouth_grin(uid)
    defs = bd + md
    inner = (g.shadow() + g.antenna() + bi + g.arms_up() + g.eyes_open() + mi)
    tx = cx - 128 * scale
    ty = cy - 128 * scale
    return defs, f'<g transform="translate({tx:.1f} {ty:.1f}) scale({scale})">{inner}</g>'


def main():
    mcx, mcy, msc = 262, 262, 1.62   # mascot centre / scale (art board 256)
    mdefs, mbody = mascot(mcx, mcy, msc)

    rays = []
    for k in range(16):
        a0 = math.radians(k * 22.5 - 5)
        a1 = math.radians(k * 22.5 + 5)
        R = 700
        sx, sy = mcx, mcy - 20
        rays.append(f"M{sx},{sy} L{sx+R*math.cos(a0):.1f},{sy+R*math.sin(a0):.1f} "
                    f"L{sx+R*math.cos(a1):.1f},{sy+R*math.sin(a1):.1f} Z")

    defs = f"""
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#63C2FF"/>
  <stop offset="0.6" stop-color="#A9DEFF"/>
  <stop offset="1" stop-color="#DDF2FF"/>
</linearGradient>
<radialGradient id="sun" cx="{mcx/W:.3f}" cy="{(mcy-20)/H:.3f}" r="0.42" gradientUnits="objectBoundingBox">
  <stop offset="0" stop-color="#FFE9A0"/>
  <stop offset="0.45" stop-color="{g.SUNNY}" stop-opacity="0.95"/>
  <stop offset="1" stop-color="{g.SUNNY}" stop-opacity="0"/>
</radialGradient>
<radialGradient id="rayfade" cx="{mcx/W:.3f}" cy="{(mcy-20)/H:.3f}" r="0.5">
  <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
  <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
</radialGradient>
{mdefs}"""

    body = [
        f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
        f'<path d="{" ".join(rays)}" fill="url(#rayfade)"/>',
        f'<ellipse cx="{mcx}" cy="{mcy-20}" rx="330" ry="300" fill="url(#sun)"/>',
        f'<circle cx="{mcx}" cy="{mcy-10}" r="205" fill="#FFFFFF" opacity="0.18"/>',
        # clouds hugging the bottom edge + one high on the right
        cloud(900, 470, 1.25, 0.95), cloud(560, 505, 1.1, 0.9), cloud(120, 510, 1.2, 0.85),
        cloud(930, 70, 0.55, 0.7),
        # maths candy + fruit floating around the title area (right side)
        candy("plus", 520, 110, 64, g.SUNNY, g.SUNNY_DARK, -12),
        candy("times", 915, 112, 54, g.PINK, g.PINK_DARK, 8),
        candy("minus", 855, 378, 58, g.MINT, MINT_DARK, -10),
        candy("equals", 545, 375, 54, g.SKY, g.SKY_DARK, 10),
        candy("plus", 700, 405, 40, g.CORAL, CORAL_DARK, 14),
        skin("strawberry", 790, 86, 78, 12),
        skin("orange", 648, 96, 62, -10),
        skin("apple", 955, 345, 60, 10),
        skin("banana", 395, 420, 74, -20),
        skin("grape", 90, 110, 66, -14),
        skin("watermelon", 82, 360, 70, 16),
        # the Mathling, cheering
        mbody,
        sparkle(120, 230, 18, g.SUNNY, g.SUNNY_DARK),
        sparkle(410, 160, 16, g.PINK, g.PINK_DARK),
        sparkle(418, 330, 11, g.SKY, g.SKY_DARK),
        sparkle(150, 60, 10, g.MINT, MINT_DARK),
        sparkle(760, 450, 12, g.SUNNY, g.SUNNY_DARK),
        sparkle(975, 420, 10, g.PINK, g.PINK_DARK),
    ]
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
           f'<defs>{defs}</defs>{"".join(body)}</svg>\n')
    with open(OUT, "w") as f:
        f.write(svg)
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
