class_name DifficultyController
## Computes the fall speed of falling problems based on the player's recent performance.
## Reference: DESIGN §8.4, specs/P9_skill_model.md

const BASE_SPEED_PX_S: float = 120.0
const STREAK_CAP: int = 10
const STREAK_STEP: float = 0.03
const RATING_MULT_MIN: float = 0.7
const RATING_MULT_MAX: float = 1.6
const RATING_REFERENCE: float = 1000.0
const RATING_SCALE: float = 1000.0
const ERROR_THRESHOLD: int = 3
const ERROR_SLOWDOWN: float = 0.8


## Returns the fall speed in px/s.
##   avg_rating     — mean rating across enabled skills (or any baseline).
##   streak         — current correct streak (≥ 0).
##   recent_errors  — count of incorrect attempts in the last 5 problems.
static func speed_for(avg_rating: float, streak: int, recent_errors: int) -> float:
	var streak_mult: float = 1.0 + float(clampi(streak, 0, STREAK_CAP)) * STREAK_STEP
	var rating_mult: float = clampf(
		1.0 + (avg_rating - RATING_REFERENCE) / RATING_SCALE,
		RATING_MULT_MIN,
		RATING_MULT_MAX
	)
	var speed: float = BASE_SPEED_PX_S * streak_mult * rating_mult
	if recent_errors >= ERROR_THRESHOLD:
		speed *= ERROR_SLOWDOWN
	return speed
