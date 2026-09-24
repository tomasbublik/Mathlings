class_name Palette
## Mathlings design tokens — the single source of truth for colours, radii
## and font sizes. The project theme (assets/theme/mathlings_theme.tres) is
## generated from these by tools/build_theme.gd; scripts that colour things
## at runtime (answer feedback, stats bars, …) read them directly.
##
## Visual direction: "candy sticker" — saturated, friendly colours, chunky
## rounded shapes, a darker bottom edge that makes buttons look pressable.

# --- Brand ------------------------------------------------------------------
const GRAPE := Color("#7C4DFF")        ## primary — buttons, selection, links
const GRAPE_DARK := Color("#5B2FD9")   ## primary edge / title outline
const GRAPE_LIGHT := Color("#EDE6FF")  ## subtle primary tint (chips, bars bg)
const SUNNY := Color("#FFC53D")        ## hero CTA (Play), stars, rewards
const SUNNY_DARK := Color("#E39A00")
const CORAL := Color("#FF6B6B")        ## wrong answers, destructive actions
const CORAL_DARK := Color("#D94646")
const MINT := Color("#22C993")         ## correct answers, success
const MINT_DARK := Color("#14A176")
const SKY := Color("#38B6FF")          ## secondary accent, info
const SKY_DARK := Color("#1C8FD6")
const PINK := Color("#FF7AC6")         ## extra accent for variety
const PINK_DARK := Color("#DB4FA0")

# --- Neutrals -----------------------------------------------------------------
const INK := Color("#2B2350")          ## main text on light surfaces
const INK_SOFT := Color("#6B6490")     ## secondary text, captions
const INK_FAINT := Color("#A39DC0")    ## placeholders, disabled text
const SURFACE := Color("#FFFFFF")      ## cards, inputs, secondary buttons
const SURFACE_EDGE := Color("#DAD3F2") ## bottom edge of white buttons/cards
const DISABLED := Color("#CFC9E3")
const DISABLED_EDGE := Color("#B0A9CC")
const SHADOW := Color(0.12, 0.07, 0.3, 0.22)
const SCRIM := Color(0.10, 0.06, 0.25, 0.55) ## dim layer behind modals

## Answer buttons cycle through these so the three choices are easy to tell
## apart. Colour never encodes correctness.
const ANSWER_COLORS: Array[Color] = [SKY, PINK, SUNNY]
const ANSWER_EDGES: Array[Color] = [SKY_DARK, PINK_DARK, SUNNY_DARK]

# --- Shape ----------------------------------------------------------------------
const RADIUS_S := 14
const RADIUS_M := 22
const RADIUS_L := 30
const EDGE := 7          ## bottom "depth" of candy buttons, px
const EDGE_PRESSED := 2  ## depth left while held down

# --- Type scale (canvas px at the 1280×720 base resolution) ------------------
const FONT_HERO := 96    ## app name on the main menu
const FONT_TITLE := 60   ## screen titles
const FONT_HEADING := 36 ## section headings
const FONT_BUTTON := 32
const FONT_BODY := 26
const FONT_CAPTION := 20
const FONT_ANSWER := 52  ## numbers on answer buttons
