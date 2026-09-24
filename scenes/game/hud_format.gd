class_name HudFormat
extends RefCounted
## Pure formatting / threshold helpers for the in-game HUD. Kept free of
## scene state so they can be unit-tested (tests/unit/test_hud_format.gd).

## Seconds left at which the timer chip turns coral and starts pulsing.
const URGENT_SECONDS: int = 10


## Whole seconds shown on the timer for a remaining time (rounded up, never
## negative) — the same rounding the controller uses for its tick SFX.
static func timer_seconds(time_s: float) -> int:
	return maxi(0, int(ceil(time_s)))


## "m:ss" timer text, e.g. 75 → "1:15".
static func timer_text(secs: int) -> String:
	secs = maxi(0, secs)
	return "%d:%02d" % [secs / 60, secs % 60]


## True while the round is in its final stretch (1‥URGENT_SECONDS).
static func is_urgent(secs: int) -> bool:
	return secs > 0 and secs <= URGENT_SECONDS


## "×1.5", "×2", "×1.25" — combo multiplier without trailing zeros.
static func combo_text(multiplier: float) -> String:
	var s := "%.2f" % multiplier
	s = s.rstrip("0").rstrip(".")
	return "×" + s


## Floating "+points" text shown over a solved problem.
static func points_text(points: int, multiplier: float) -> String:
	if multiplier > 1.0 and not is_equal_approx(multiplier, 1.0):
		return "+%d %s" % [points, combo_text(multiplier)]
	return "+%d" % points


## Combo tier 0‥2 used to pick the badge colour (bigger combo, hotter colour).
static func combo_tier(multiplier: float) -> int:
	if multiplier >= 2.0 - 0.001:
		return 2
	if multiplier >= 1.5 - 0.001:
		return 1
	return 0


## Scale for HUD rows and falling entities. The project stretches from a
## 1280×720 base with aspect "expand", so portrait screens get a tall canvas
## that is still 1280 wide — scale up there (capped) so things stay chunky.
static func ui_scale(canvas_size: Vector2) -> float:
	if canvas_size.x <= 0.0 or canvas_size.y <= canvas_size.x:
		return 1.0
	return clampf(canvas_size.y / canvas_size.x, 1.0, 1.7)
