class_name StatsDao
## Aggregation queries backing the Parent Dashboard (stats.tscn).
## All methods are static and defensive: when DB is closed they return empty / 0.
## Reference: specs/P13_parent_dashboard.md, DESIGN §6.1


## Returns the headline stats Parent Dashboard renders. All numeric fields
## default to 0 when DB is closed or the profile has no finished sessions:
##   {
##     "sessions":            int,    # finished session count
##     "total_duration_ms":   int,    # sum of duration_ms
##     "total_score":         int,    # sum of session scores
##     "max_score":           int,    # best single-round score
##     "best_streak_overall": int,    # highest best_streak across rounds
##     "avg_error_rate":      float,  # 1 - avg(accuracy), 0..1
##   }
static func profile_totals(db: Node, profile_id: int) -> Dictionary:
	var empty := {
		"sessions": 0,
		"total_duration_ms": 0,
		"total_score": 0,
		"max_score": 0,
		"best_streak_overall": 0,
		"avg_error_rate": 0.0,
	}
	if not DbGuard.writable(db):
		return empty
	# One round trip — SQLite happily aggregates everything we want.
	var rows: Array = db.execute("""
		SELECT
			COUNT(*) AS sessions,
			COALESCE(SUM(duration_ms), 0) AS total_duration_ms,
			COALESCE(SUM(score),       0) AS total_score,
			COALESCE(MAX(score),       0) AS max_score,
			COALESCE(MAX(best_streak), 0) AS best_streak_overall,
			COALESCE(AVG(accuracy),    0.0) AS avg_accuracy
		FROM sessions
		WHERE profile_id = ? AND ended_at IS NOT NULL;
	""", [profile_id])
	if rows.is_empty():
		return empty
	var row: Dictionary = rows[0]
	var avg_accuracy: float = float(row.get("avg_accuracy", 0.0))
	# Accuracy is 0..1; error rate is its complement clamped to that range
	# (NULL accuracies on unfinished sessions are filtered by the WHERE clause).
	var error_rate := clampf(1.0 - avg_accuracy, 0.0, 1.0) if avg_accuracy > 0.0 else 0.0
	return {
		"sessions": int(row.get("sessions", 0)),
		"total_duration_ms": int(row.get("total_duration_ms", 0)),
		"total_score": int(row.get("total_score", 0)),
		"max_score": int(row.get("max_score", 0)),
		"best_streak_overall": int(row.get("best_streak_overall", 0)),
		"avg_error_rate": error_rate,
	}


## Returns an array of Dictionaries per skill, sorted by rating ASC (weakest first):
##   [{ "skill_key": String, "rating": float, "attempts": int, "correct": int,
##      "accuracy": float }]
## Accuracy falls back to 0.0 when attempts == 0.
static func skill_overview(db: Node, profile_id: int) -> Array:
	if not DbGuard.writable(db):
		return []
	var rows: Array = db.execute("""
		SELECT skill_key, rating, attempts, correct
		FROM skills
		WHERE profile_id = ?
		ORDER BY rating ASC;
	""", [profile_id])
	var result: Array = []
	for row: Dictionary in rows:
		var attempts: int = int(row.get("attempts", 0))
		var correct: int = int(row.get("correct", 0))
		var accuracy: float = 0.0 if attempts == 0 else float(correct) / float(attempts)
		result.append({
			"skill_key": String(row.get("skill_key", "")),
			"rating": float(row.get("rating", 1000.0)),
			"attempts": attempts,
			"correct": correct,
			"accuracy": accuracy,
		})
	return result


## Returns the top N skills that most need practice, ordered by accuracy ASC.
## Only considers skills with at least `min_attempts` attempts.
static func skills_needing_practice(
	db: Node,
	profile_id: int,
	limit: int = 3,
	min_attempts: int = 5
) -> Array:
	if not DbGuard.writable(db):
		return []
	var rows: Array = db.execute("""
		SELECT skill_key, rating, attempts, correct,
		       CAST(correct AS REAL) / CAST(attempts AS REAL) AS accuracy
		FROM skills
		WHERE profile_id = ? AND attempts >= ?
		ORDER BY accuracy ASC, rating ASC
		LIMIT ?;
	""", [profile_id, min_attempts, limit])
	var result: Array = []
	for row: Dictionary in rows:
		result.append({
			"skill_key": String(row.get("skill_key", "")),
			"rating": float(row.get("rating", 1000.0)),
			"attempts": int(row.get("attempts", 0)),
			"correct": int(row.get("correct", 0)),
			"accuracy": float(row.get("accuracy", 0.0)),
		})
	return result


