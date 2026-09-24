#!/usr/bin/env python3
"""Usage (from tools/mascot/): python3 gen_icon.py ../../assets/images/icon ../.. [debug]
(also writes store_icon.svg into the cwd; render at 512 px for the Play listing)
Mathlings launcher icon built from the mascot art. Writes into <icon_dir>
(ic_foreground/background/monochrome/launcher.svg) and <root>/icon.svg."""
import os, sys
import gen_mascot as g

ICON_DIR, ROOT = sys.argv[1], sys.argv[2]
DEBUG = len(sys.argv) > 3

# Mascot art centre (256 art board) → icon centre (216,216).
ART_C = (128, 122)


def place(scale, cx=216, cy=216):
    tx = cx - ART_C[0] * scale
    ty = cy - ART_C[1] * scale
    return f'translate({tx:.2f} {ty:.2f}) scale({scale})'


def mascot_art(uid):
    bd, bi = g.body_parts(uid)
    md, mi = g.mouth_grin(uid)
    inner = (g.antenna() + bi + g.arms_up() + g.eyes_open() + mi)
    return bd + md, inner


def bg_parts(uid=""):
    defs = f"""
<radialGradient id="sun{uid}" cx="0.5" cy="0.42" r="0.72">
  <stop offset="0" stop-color="#FFE38A"/>
  <stop offset="0.55" stop-color="{g.SUNNY}"/>
  <stop offset="1" stop-color="#FFA928"/>
</radialGradient>"""
    # soft sunburst + scattered pluses
    rays = []
    import math
    for k in range(12):
        a0 = math.radians(k * 30 - 6)
        a1 = math.radians(k * 30 + 6)
        R = 420
        rays.append(f'M216,200 L{216+R*math.cos(a0):.1f},{200+R*math.sin(a0):.1f} '
                    f'L{216+R*math.cos(a1):.1f},{200+R*math.sin(a1):.1f} Z')
    pluses = ""
    for (x, y, s) in [(70, 88, 14), (360, 84, 11), (58, 330, 10), (378, 340, 14), (112, 392, 8), (330, 400, 8), (40, 208, 8), (396, 214, 9)]:
        t = s * 0.42
        pluses += (f'<rect x="{x-s}" y="{y-t/2}" width="{2*s}" height="{t}" rx="{t/2}"/>'
                   f'<rect x="{x-t/2}" y="{y-s}" width="{t}" height="{2*s}" rx="{t/2}"/>')
    inner = (f'<rect width="432" height="432" fill="url(#sun{uid})"/>'
             f'<path d="{" ".join(rays)}" fill="#FFFFFF" opacity="0.16"/>'
             f'<circle cx="216" cy="206" r="150" fill="#FFFFFF" opacity="0.22"/>'
             f'<g fill="#FFFFFF" opacity="0.55">{pluses}</g>')
    return defs, inner


def fg_parts(scale, uid=""):
    d, i = mascot_art(uid)
    shadow = f'<ellipse cx="216" cy="{216 + 108*scale:.1f}" rx="{74*scale:.1f}" ry="{11*scale:.1f}" fill="#B86A00" opacity="0.28"/>'
    return d, shadow + f'<g transform="{place(scale)}">{i}</g>'


def wrap(inner, defs="", w=432, h=432, vb="0 0 432 432", comment=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{w}" height="{h}">\n'
            f'<!-- {comment} -->\n<defs>{defs}</defs>\n{inner}\n</svg>\n')


FG_SCALE = 1.0   # safe zone: circle r≈143 around the centre
LEG_SCALE = 1.30

fd, fi = fg_parts(FG_SCALE)
dbg = ('<circle cx="216" cy="216" r="132" fill="none" stroke="red" stroke-width="2"/>'
       '<circle cx="216" cy="216" r="216" fill="none" stroke="blue" stroke-width="2"/>') if DEBUG else ""
open(os.path.join(ICON_DIR, "ic_foreground.svg"), "w").write(wrap(fi + dbg, fd, comment=(
    "Adaptive icon foreground (432x432): the Mathling mascot cheering. "
    "All detail sits inside the central safe-zone circle (r~143). Generated from the mascot art "
    "in assets/images/mascot/ - keep the two in sync.")))

bd, bi = bg_parts()
open(os.path.join(ICON_DIR, "ic_background.svg"), "w").write(wrap(bi, bd, comment=(
    "Adaptive icon background (432x432): SUNNY radial gradient, soft sunburst, white plus signs.")))

# Monochrome: white silhouette with the face cut out via a luminance mask.
sil = (f'<path d="M128,76 C126,58 132,44 144,34" fill="none" stroke="#FFFFFF" stroke-width="{g.SW+3}" stroke-linecap="round"/>'
       f'<g fill="#FFFFFF">'
       f'<rect x="128.5" y="21.5" width="39" height="13" rx="6.5"/><rect x="141.5" y="8.5" width="13" height="39" rx="6.5"/>'
       f'<path d="{g.BODY_D}"/>'
       f'<ellipse cx="98" cy="222" rx="24" ry="14"/><ellipse cx="158" cy="222" rx="24" ry="14"/>'
       f'<ellipse cx="26" cy="128" rx="15" ry="26" transform="rotate(-48 26 128)"/>'
       f'<ellipse cx="230" cy="128" rx="15" ry="26" transform="rotate(48 230 128)"/></g>')
face = (f'<g fill="#000000">'
        f'<ellipse cx="{g.EL}" cy="{g.EY}" rx="16" ry="21"/><ellipse cx="{g.ER}" cy="{g.EY}" rx="16" ry="21"/>'
        f'<path d="M110,157 Q128,161 146,157 Q144,182 128,182 Q112,182 110,157 Z"/></g>'
        f'<g fill="#FFFFFF"><circle cx="{g.EL+5}" cy="{g.EY-8}" r="6"/><circle cx="{g.ER+5}" cy="{g.EY-8}" r="6"/></g>')
mono_defs = (f'<mask id="face" maskUnits="userSpaceOnUse" x="0" y="0" width="432" height="432">'
             f'<rect width="432" height="432" fill="#FFFFFF"/><g transform="{place(FG_SCALE)}">{face}</g></mask>')
mono = f'<g mask="url(#face)"><g transform="{place(FG_SCALE)}">{sil}</g></g>'
open(os.path.join(ICON_DIR, "ic_monochrome.svg"), "w").write(wrap(mono, mono_defs, comment=(
    "Adaptive icon monochrome layer (Android 13+ themed icons): white Mathling silhouette, face cut out.")))

# Legacy full icon: rounded square, background + larger mascot.
bd2, bi2 = bg_parts("L")
fd2, fi2 = fg_parts(LEG_SCALE, "L")
legacy = (f'<clipPath id="round"><rect width="432" height="432" rx="96"/></clipPath>')
open(os.path.join(ICON_DIR, "ic_launcher.svg"), "w").write(wrap(
    f'<g clip-path="url(#round)">{bi2}{fi2}</g>', bd2 + fd2 + legacy, comment=(
        "Legacy launcher icon + project icon: ic_background + ic_foreground composed "
        "in a rounded square, mascot enlarged. Keep in sync with the adaptive layers.")))

bd3, bi3 = bg_parts("R")
fd3, fi3 = fg_parts(LEG_SCALE, "R")
open(os.path.join(ROOT, "icon.svg"), "w").write(wrap(
    f'<g transform="scale({128/432:.6f})"><g clip-path="url(#round)">{bi3}{fi3}</g></g>', bd3 + fd3 + legacy,
    w=128, h=128, vb="0 0 128 128",
    comment="Project icon (128x128). Same artwork as assets/images/icon/ic_launcher.svg."))
# Play Store listing icon source (full-bleed square; Play applies its own mask).
open("store_icon.svg", "w").write(
    wrap(bi2 + fi2, bd2 + fd2, comment="store icon"))
print("icons ok")
