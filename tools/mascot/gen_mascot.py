#!/usr/bin/env python3
"""Usage: python3 tools/mascot/gen_mascot.py assets/images/mascot <preview_dir>
Generates the Mathling mascot layer SVGs (256x256 shared canvas) plus
composite previews. Every layer uses the same viewBox so layers stack 1:1."""
import os, sys


GRAPE = "#7C4DFF"
GRAPE_LIGHT = "#A07BFF"
GRAPE_DARK = "#5B2FD9"
LINE = "#4321A8"      # outline: deep grape, never black
INK = "#2B2350"
SUNNY = "#FFC53D"
SUNNY_DARK = "#E39A00"
CORAL = "#FF6B6B"
PINK = "#FF7AC6"
PINK_DARK = "#DB4FA0"
SKY = "#38B6FF"
SKY_DARK = "#1C8FD6"
MINT = "#22C993"
SW = 6  # outline width

BODY_D = ("M128,72 C176,72 212,108 214,156 C216,198 184,224 128,224 "
          "C72,224 40,198 42,156 C44,108 80,72 128,72 Z")


def svg(inner, defs=""):
    d = f"<defs>{defs}</defs>" if defs else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" '
            f'width="256" height="256">{d}{inner}</svg>\n')


def body_parts(uid=""):
    defs = f"""
<radialGradient id="bodyGrad{uid}" cx="0.40" cy="0.32" r="0.75">
  <stop offset="0" stop-color="{GRAPE_LIGHT}"/>
  <stop offset="0.55" stop-color="{GRAPE}"/>
  <stop offset="1" stop-color="#6A3BF2"/>
</radialGradient>
<clipPath id="bodyClip{uid}"><path d="{BODY_D}"/></clipPath>"""
    inner = f"""
<g stroke="{LINE}" stroke-width="{SW}" fill="{GRAPE_DARK}">
  <ellipse cx="98" cy="222" rx="22" ry="12"/>
  <ellipse cx="158" cy="222" rx="22" ry="12"/>
</g>
<path d="{BODY_D}" fill="{GRAPE_DARK}"/>
<g clip-path="url(#bodyClip{uid})">
  <ellipse cx="128" cy="140" rx="96" ry="78" fill="url(#bodyGrad{uid})"/>
  <ellipse cx="92" cy="104" rx="26" ry="14" fill="#FFFFFF" opacity="0.35" transform="rotate(-28 92 104)"/>
  <circle cx="120" cy="88" r="5" fill="#FFFFFF" opacity="0.45"/>
</g>
<path d="{BODY_D}" fill="none" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
<g fill="{PINK}" opacity="0.6">
  <ellipse cx="74" cy="164" rx="14" ry="9"/>
  <ellipse cx="182" cy="164" rx="14" ry="9"/>
</g>"""
    return defs, inner


def shadow():
    return f'<ellipse cx="128" cy="234" rx="70" ry="10" fill="{INK}" opacity="0.16"/>'


def plus(cx, cy, arm=13, th=13, fill=SUNNY, edge=SUNNY_DARK, sw=6):
    r = th / 2
    h = f'<rect x="{cx-arm-r}" y="{cy-r}" width="{2*(arm+r)}" height="{th}" rx="{r}"/>'
    v = f'<rect x="{cx-r}" y="{cy-arm-r}" width="{th}" height="{2*(arm+r)}" rx="{r}"/>'
    return (f'<g fill="{edge}" stroke="{edge}" stroke-width="{sw}" stroke-linejoin="round">{h}{v}</g>'
            f'<g fill="{fill}">{h}{v}</g>'
            f'<circle cx="{cx-4}" cy="{cy-4}" r="2.6" fill="#FFFFFF" opacity="0.8"/>')


def antenna():
    return (f'<path d="M128,76 C126,58 132,44 144,34" fill="none" stroke="{LINE}" '
            f'stroke-width="{SW+1}" stroke-linecap="round"/>' + plus(148, 28))


def eye_oval(cx, cy, dx=0, dy=0):
    return (f'<ellipse cx="{cx+dx}" cy="{cy+dy}" rx="16" ry="21" fill="{INK}"/>'
            f'<circle cx="{cx+dx+5}" cy="{cy+dy-8}" r="6" fill="#FFFFFF"/>'
            f'<circle cx="{cx+dx-5}" cy="{cy+dy+8}" r="2.8" fill="#FFFFFF" opacity="0.9"/>')

EL, ER, EY = 101, 155, 130


def eyes_open():
    return eye_oval(EL, EY) + eye_oval(ER, EY)


def arc(cx, cy, w, h, sw=7, color=INK):
    # h>0: U shape (closed, relaxed); h<0: ^ shape (happy)
    return (f'<path d="M{cx-w},{cy} Q{cx},{cy+h*2} {cx+w},{cy}" fill="none" '
            f'stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>')


def eyes_closed():
    return arc(EL, EY + 2, 14, 7) + arc(ER, EY + 2, 14, 7)


def eyes_happy():
    return arc(EL, EY + 8, 15, -12) + arc(ER, EY + 8, 15, -12)


def brow(x1, y1, x2, y2, qx, qy):
    return (f'<path d="M{x1},{y1} Q{qx},{qy} {x2},{y2}" fill="none" stroke="{INK}" '
            f'stroke-width="6" stroke-linecap="round"/>')


def eyes_think():
    # glancing up and to the side, one curious raised brow
    return (eye_oval(EL, EY, 4, -4) + eye_oval(ER, EY, 4, -4)
            + brow(86, 104, 112, 104, 99, 101) + brow(146, 95, 172, 97, 159, 85))


def eyes_oops():
    # "oh no!" — inner brow ends lifted: sympathetic, not sad
    return (eye_oval(EL, EY + 2) + eye_oval(ER, EY + 2)
            + brow(84, 103, 112, 96, 98, 96) + brow(144, 96, 172, 103, 158, 96))


def open_mouth(pts, uid, tongue_cy, tongue_rx):
    x1, y1, x2, bottom = pts
    d = f"M{x1},{y1} Q128,{y1+4} {x2},{y1} Q{x2-2},{bottom} 128,{bottom} Q{x1+2},{bottom} {x1},{y1} Z"
    defs = f'<clipPath id="mClip{uid}"><path d="{d}"/></clipPath>'
    inner = (f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
             f'<g clip-path="url(#mClip{uid})"><ellipse cx="128" cy="{tongue_cy}" rx="{tongue_rx}" ry="10" fill="{CORAL}"/></g>')
    return defs, inner


def mouth_smile():
    return "", arc(128, 160, 14, 6, sw=6)


def mouth_grin(uid=""):
    return open_mouth((110, 157, 146, 182), "g" + uid, 184, 13)


def mouth_cheer(uid=""):
    return open_mouth((104, 155, 152, 194), "c" + uid, 196, 17)


def mouth_think():
    return "", f'<ellipse cx="140" cy="166" rx="6" ry="5.5" fill="{INK}"/>'


def mouth_oops():
    return "", (f'<path d="M112,168 Q117,161 122,166 Q128,172 134,166 Q139,161 144,168" '
                f'fill="none" stroke="{INK}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>')


def arm(cx, cy, rot, rx=13, ry=22):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" '
            f'fill="{GRAPE}" stroke="{LINE}" stroke-width="{SW}"/>')


def arms_down():
    return arm(48, 184, 24, 12, 19) + arm(208, 184, -24, 12, 19)


def arms_open():
    return arm(36, 160, 55) + arm(220, 160, -55)


def arms_up():
    return arm(26, 128, -48, 12, 23) + arm(230, 128, 48, 12, 23)


def arms_think():
    # left arm resting, right paw raised to the chin
    return arm(48, 184, 24, 12, 19) + arm(182, 192, -52, 11, 21)


def star4(cx, cy, s, fill, edge):
    d = (f"M{cx},{cy-s} Q{cx+s*0.18},{cy-s*0.18} {cx+s},{cy} Q{cx+s*0.18},{cy+s*0.18} {cx},{cy+s} "
         f"Q{cx-s*0.18},{cy+s*0.18} {cx-s},{cy} Q{cx-s*0.18},{cy-s*0.18} {cx},{cy-s} Z")
    return f'<path d="{d}" fill="{fill}" stroke="{edge}" stroke-width="3" stroke-linejoin="round"/>'


def sparkles():
    return (star4(26, 54, 15, SUNNY, SUNNY_DARK) + star4(226, 48, 13, PINK, PINK_DARK)
            + star4(236, 200, 9, SKY, SKY_DARK) + star4(20, 202, 8, MINT, "#14A176")
            + star4(196, 20, 7, SUNNY, SUNNY_DARK))


def sweat():
    return (f'<path d="M204,78 C210,88 216,96 216,103 A12,12 0 0 1 192,103 C192,96 198,88 204,78 Z" '
            f'fill="#9EDCFF" stroke="{SKY_DARK}" stroke-width="3.5" stroke-linejoin="round"/>'
            f'<ellipse cx="199" cy="101" rx="2.5" ry="4" fill="#FFFFFF"/>')


def think_dots():
    return (f'<g fill="#FFFFFF" stroke="{GRAPE_DARK}" stroke-width="3">'
            f'<circle cx="206" cy="92" r="5"/><circle cx="220" cy="74" r="7"/><circle cx="238" cy="50" r="10"/></g>')


LAYERS = {
    "shadow": ("", shadow()),
    "antenna": ("", antenna()),
    "body": body_parts(),
    "eyes_open": ("", eyes_open()),
    "eyes_closed": ("", eyes_closed()),
    "eyes_happy": ("", eyes_happy()),
    "eyes_think": ("", eyes_think()),
    "eyes_oops": ("", eyes_oops()),
    "mouth_smile": mouth_smile(),
    "mouth_grin": mouth_grin(),
    "mouth_cheer": mouth_cheer(),
    "mouth_think": mouth_think(),
    "mouth_oops": mouth_oops(),
    "arms_down": ("", arms_down()),
    "arms_open": ("", arms_open()),
    "arms_up": ("", arms_up()),
    "arms_think": ("", arms_think()),
    "fx_sparkles": ("", sparkles()),
    "fx_sweat": ("", sweat()),
    "fx_think": ("", think_dots()),
}

# Must mirror Mascot.MOODS in scenes/shared/mascot.gd
MOODS = {
    "idle":  ["eyes_open", "mouth_smile", "arms_down", None],
    "happy": ["eyes_open", "mouth_grin", "arms_open", None],
    "cheer": ["eyes_happy", "mouth_cheer", "arms_up", "fx_sparkles"],
    "think": ["eyes_think", "mouth_think", "arms_think", "fx_think"],
    "oops":  ["eyes_oops", "mouth_oops", "arms_down", "fx_sweat"],
}

def main():
    OUT, PREV = sys.argv[1], sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREV, exist_ok=True)
    for name, (defs, inner) in LAYERS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg(inner, defs))


    def composite(mood, blink=False):
        e, m, a, fx = MOODS[mood]
        if blink:
            e = "eyes_closed"
        order = ["shadow", "antenna", "body", a, e, m] + ([fx] if fx else [])
        defs = "".join(LAYERS[k][0] for k in order)
        inner = "".join(LAYERS[k][1] for k in order)
        return defs, inner

    for mood in MOODS:
        d, i = composite(mood)
        open(os.path.join(PREV, f"mood_{mood}.svg"), "w").write(svg(i, d))
    d, i = composite("idle", True)
    open(os.path.join(PREV, "mood_idle_blink.svg"), "w").write(svg(i, d))
    print("ok")


if __name__ == "__main__":
    main()
