class_name UnlockSystem
## Evaluates end-of-round progression milestones and persists newly earned unlocks
## (ProgressStore). Returns the list of unlocks granted *during this call* so the
## Results screen can show toasts without reading the store again.
##
## Must run after the finished round has been recorded (GameController does
## ProgressStore.record_round + SessionStatsStore.record_session first), so
## "rounds played" / "total score" already include this round.
##
## Only stable ids (kind + key) are stored; the display name is translated at
## display time via `display_name()`, so switching language updates it.
## Reference: specs/P14_badges.md, DESIGN §7.4 (unlock SFX), §6 (storage).

const KIND_BADGE: String = "badge"
const KIND_SKIN: String = "skin"
const KIND_THEME: String = "theme"

## Threshold tuning for the rule predicates below.
const STREAK_BADGE_TARGET: int = 10
const TEN_GAMES_BADGE_TARGET: int = 10
const ADDITION_MASTERY_RATING: float = 1400.0
const ADDITION_SKILLS: Array[String] = ["add_0_10", "add_0_20", "add_0_100"]
const SPACE_THEME_TOTAL_SCORE: int = 1000
const BALLOONS_THEME_DISTINCT_DAYS: int = 5

## Translation keys of badge names (themes use UNLOCK_THEME_FORMAT + THEME_*).
const BADGE_LABEL_KEYS: Dictionary = {
	"streak_10": "UNLOCK_STREAK_10",
	"ten_games": "UNLOCK_TEN_GAMES",
	"addition_master": "UNLOCK_ADDITION_MASTER",
}


## Catalog of unlockable items: {key, kind, rule}. `rule` is a Callable that
## accepts a Dictionary context `{profile_id, summary}` and returns true when earned.
static func _rules() -> Array:
	return [
		{
			"key": "streak_10",
			"kind": KIND_BADGE,
			"rule": func(ctx: Dictionary) -> bool:
				return int(ctx["summary"].get("best_streak", 0)) >= STREAK_BADGE_TARGET,
		},
		{
			"key": "ten_games",
			"kind": KIND_BADGE,
			"rule": func(ctx: Dictionary) -> bool:
				return rounds_played(int(ctx["profile_id"])) >= TEN_GAMES_BADGE_TARGET,
		},
		{
			"key": "addition_master",
			"kind": KIND_BADGE,
			"rule": func(ctx: Dictionary) -> bool:
				var pid: int = int(ctx["profile_id"])
				for k: String in ADDITION_SKILLS:
					var row: Dictionary = ProgressStore.skill(pid, k)
					if row.is_empty() or float(row.get("rating", 0.0)) < ADDITION_MASTERY_RATING:
						return false
				return true,
		},
		{
			"key": "space",
			"kind": KIND_THEME,
			"rule": func(ctx: Dictionary) -> bool:
				return total_score(int(ctx["profile_id"])) >= SPACE_THEME_TOTAL_SCORE,
		},
		{
			"key": "balloons",
			"kind": KIND_THEME,
			"rule": func(ctx: Dictionary) -> bool:
				return ProgressStore.distinct_play_days(int(ctx["profile_id"])) \
					>= BALLOONS_THEME_DISTINCT_DAYS,
		},
	]


## Evaluates all rules for (profile_id, round summary). Persists every newly earned
## unlock and returns them as an Array[Dictionary] with keys:
##   {"kind": String, "key": String}
## (use `display_name(unlock)` for the localized name).
static func evaluate(profile_id: int, summary: Dictionary) -> Array:
	var new_unlocks: Array = []
	if profile_id <= 0:
		return new_unlocks

	var ctx := {"profile_id": profile_id, "summary": summary}

	for rule: Dictionary in _rules():
		var kind: String = String(rule["kind"])
		var key: String = String(rule["key"])
		if ProgressStore.is_unlocked(profile_id, kind, key):
			continue
		if not bool((rule["rule"] as Callable).call(ctx)):
			continue
		if ProgressStore.unlock(profile_id, kind, key):
			new_unlocks.append({"kind": kind, "key": key})

	return new_unlocks


## Localized display name of an unlock ({kind, key}) in the current locale.
static func display_name(unlock: Dictionary) -> String:
	var kind := String(unlock.get("kind", ""))
	var key := String(unlock.get("key", ""))
	if kind == KIND_THEME:
		return TranslationServer.translate("UNLOCK_THEME_FORMAT") \
			% TranslationServer.translate(ThemeManager.label_key(key))
	if BADGE_LABEL_KEYS.has(key):
		return TranslationServer.translate(BADGE_LABEL_KEYS[key])
	return key


## Finished rounds for the badge. SessionStatsStore is the running total the
## Stats screen shows (it also covers rounds played before ProgressStore
## existed); ProgressStore's history is the fallback.
static func rounds_played(profile_id: int) -> int:
	return maxi(int(SessionStatsStore.totals_for(profile_id).get("sessions", 0)),
		ProgressStore.session_count(profile_id))


static func total_score(profile_id: int) -> int:
	var from_history: int = 0
	for s: Dictionary in ProgressStore.sessions(profile_id):
		from_history += int(s.get("score", 0))
	return maxi(int(SessionStatsStore.totals_for(profile_id).get("total_score", 0)),
		from_history)
