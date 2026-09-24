class_name UnlockSystem
## Evaluates end-of-round progression milestones and persists newly earned unlocks.
## Returns the list of unlocks granted *during this call* so the Results screen can
## show toasts without querying the DB again.
## Reference: specs/P14_badges.md, DESIGN §7.4 (unlock SFX), §6.1 (unlocks table).

## Kinds used in the unlocks table.
const KIND_BADGE: String = "badge"
const KIND_SKIN: String = "skin"
const KIND_THEME: String = "theme"

## Threshold tuning for the rule predicates below.
const STREAK_BADGE_TARGET: int = 10
const TEN_GAMES_BADGE_TARGET: int = 10
const ADDITION_MASTERY_RATING: float = 1400.0
const SPACE_THEME_TOTAL_SCORE: int = 1000
const BALLOONS_THEME_DISTINCT_DAYS: int = 5

## Catalog of unlockable items: key → {kind, label, rule}. `rule` is a Callable that
## accepts a Dictionary context `{profile_id, summary, db}` and returns true when earned.
static func _rules() -> Array:
	return [
		{
			"key": "streak_10",
			"kind": KIND_BADGE,
			"label": "Série 10 bez chyby!",
			"rule": func(ctx: Dictionary) -> bool:
				return int(ctx["summary"].get("best_streak", 0)) >= STREAK_BADGE_TARGET,
		},
		{
			"key": "ten_games",
			"kind": KIND_BADGE,
			"label": "10 odehraných her",
			"rule": func(ctx: Dictionary) -> bool:
				if not DbGuard.writable(ctx["db"]):
					return false
				return SessionsDao.count_for_profile(ctx["db"], int(ctx["profile_id"])) \
					>= TEN_GAMES_BADGE_TARGET,
		},
		{
			"key": "addition_master",
			"kind": KIND_BADGE,
			"label": "Mistr sčítání",
			"rule": func(ctx: Dictionary) -> bool:
				if not DbGuard.writable(ctx["db"]):
					return false
				var keys: Array[String] = ["add_0_10", "add_0_20", "add_0_100"]
				for k in keys:
					var row: Dictionary = SkillsDao.get_skill(
						ctx["db"], int(ctx["profile_id"]), k)
					if row.is_empty() or float(row.get("rating", 0.0)) < ADDITION_MASTERY_RATING:
						return false
				return true,
		},
		{
			"key": "space",
			"kind": KIND_THEME,
			"label": "Téma Vesmír",
			"rule": func(ctx: Dictionary) -> bool:
				if not DbGuard.writable(ctx["db"]):
					return false
				var total_score: int = _total_score(ctx["db"], int(ctx["profile_id"]))
				return total_score + int(ctx["summary"].get("score", 0)) \
					>= SPACE_THEME_TOTAL_SCORE,
		},
		{
			"key": "balloons",
			"kind": KIND_THEME,
			"label": "Téma Balónky",
			"rule": func(ctx: Dictionary) -> bool:
				if not DbGuard.writable(ctx["db"]):
					return false
				return _played_on_distinct_days(ctx["db"], int(ctx["profile_id"])) \
					>= BALLOONS_THEME_DISTINCT_DAYS,
		},
	]


## Evaluates all rules for (profile_id, round summary). Persists every newly earned
## unlock to the DB and returns them as an Array[Dictionary] with keys:
##   {"kind": String, "key": String, "label": String}
static func evaluate(profile_id: int, summary: Dictionary, db: Node) -> Array:
	var new_unlocks: Array = []
	if profile_id <= 0:
		return new_unlocks

	var ctx := {"profile_id": profile_id, "summary": summary, "db": db}

	for rule: Dictionary in _rules():
		var kind: String = String(rule["kind"])
		var key: String = String(rule["key"])
		# Skip already-unlocked entries.
		if DbGuard.writable(db) and UnlocksDao.is_unlocked(db, profile_id, kind, key):
			continue
		var earned: bool = bool((rule["rule"] as Callable).call(ctx))
		if not earned:
			continue
		if DbGuard.writable(db):
			UnlocksDao.unlock(db, profile_id, kind, key)
		new_unlocks.append({
			"kind": kind,
			"key": key,
			"label": String(rule["label"]),
		})

	return new_unlocks


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _total_score(db: Node, profile_id: int) -> int:
	var rows: Array = db.execute(
		"SELECT COALESCE(SUM(score), 0) AS total FROM sessions WHERE profile_id = ?;",
		[profile_id]
	)
	if rows.is_empty():
		return 0
	return int(rows[0].get("total", 0))


static func _played_on_distinct_days(db: Node, profile_id: int) -> int:
	# Count distinct calendar days (UTC) the profile has started a session on.
	var rows: Array = db.execute("""
		SELECT COUNT(DISTINCT DATE(started_at / 1000, 'unixepoch')) AS days
		FROM sessions WHERE profile_id = ?;
	""", [profile_id])
	if rows.is_empty():
		return 0
	return int(rows[0].get("days", 0))
