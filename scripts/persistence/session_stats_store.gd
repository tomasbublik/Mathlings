class_name SessionStatsStore
## ConfigFile-backed running totals of finished rounds per profile, in
## `user://profiles/<id>/stats.cfg`. Source of the Stats screen summary tiles
## and of the "rounds played" / "total score" unlock rules. Predates
## ProgressStore, so it also covers rounds played before per-round history
## was kept (existing installs keep their totals).
##
## Schema (one section, simple key/value):
##   [aggregates]
##   sessions             = 12
##   total_duration_ms    = 1450000
##   total_score          = 740
##   max_score            = 230
##   best_streak_overall  = 14
##   accuracy_sum         = 8.95   ; running sum so we can compute mean
##
## We keep `accuracy_sum` instead of `avg_accuracy` so subsequent records can
## update the running mean exactly with one pass — `(sum + new) / (n + 1)` —
## without losing precision over many sessions. The Stats screen converts
## back to error_rate = 1 - (sum / sessions) at read time.
##
## Reference: specs/P16_profiles.md, specs/P13_parent_dashboard.md.

const AGGREGATES_SECTION: String = "aggregates"


## Records one finished round into the local stats file. Idempotent in the
## sense that calling it twice for one round will simply double-count — the
## caller (GameController) is responsible for invoking it exactly once per
## ended round (at the same point as ProgressStore.record_round).
##
## Defensive: invalid profile_id (≤ 0) is a no-op so the call site doesn't
## have to special-case the "no profile yet" state.
static func record_session(
	profile_id: int,
	score: int,
	duration_ms: int,
	best_streak: int,
	accuracy: float
) -> void:
	if profile_id <= 0:
		return

	var path := _path_for(profile_id)
	_ensure_profile_dir(profile_id)

	var cfg := ConfigFile.new()
	cfg.load(path)  # silently ignores ERR_FILE_NOT_FOUND — we want a fresh file

	var sessions: int = int(cfg.get_value(AGGREGATES_SECTION, "sessions", 0)) + 1
	var total_duration_ms: int = int(
		cfg.get_value(AGGREGATES_SECTION, "total_duration_ms", 0)) + duration_ms
	var total_score: int = int(
		cfg.get_value(AGGREGATES_SECTION, "total_score", 0)) + score
	var max_score: int = maxi(
		int(cfg.get_value(AGGREGATES_SECTION, "max_score", 0)), score)
	var best_streak_overall: int = maxi(
		int(cfg.get_value(AGGREGATES_SECTION, "best_streak_overall", 0)), best_streak)
	var accuracy_sum: float = float(
		cfg.get_value(AGGREGATES_SECTION, "accuracy_sum", 0.0)) + clampf(accuracy, 0.0, 1.0)

	cfg.set_value(AGGREGATES_SECTION, "sessions", sessions)
	cfg.set_value(AGGREGATES_SECTION, "total_duration_ms", total_duration_ms)
	cfg.set_value(AGGREGATES_SECTION, "total_score", total_score)
	cfg.set_value(AGGREGATES_SECTION, "max_score", max_score)
	cfg.set_value(AGGREGATES_SECTION, "best_streak_overall", best_streak_overall)
	cfg.set_value(AGGREGATES_SECTION, "accuracy_sum", accuracy_sum)

	var err := cfg.save(path)
	if err != OK:
		push_error("SessionStatsStore: failed to save '%s' (%s)"
			% [path, error_string(err)])


## Returns the totals dictionary (sessions, total_duration_ms, total_score,
## max_score, best_streak_overall, avg_error_rate).
##
## When the file is missing or unreadable, every field is 0/0.0 — the
## Stats screen already handles "no data yet" by hiding the table.
static func totals_for(profile_id: int) -> Dictionary:
	var empty := {
		"sessions": 0,
		"total_duration_ms": 0,
		"total_score": 0,
		"max_score": 0,
		"best_streak_overall": 0,
		"avg_error_rate": 0.0,
	}
	if profile_id <= 0:
		return empty

	var cfg := ConfigFile.new()
	if cfg.load(_path_for(profile_id)) != OK:
		return empty

	var sessions: int = int(cfg.get_value(AGGREGATES_SECTION, "sessions", 0))
	if sessions == 0:
		return empty

	var accuracy_sum: float = float(
		cfg.get_value(AGGREGATES_SECTION, "accuracy_sum", 0.0))
	var avg_accuracy: float = accuracy_sum / float(sessions)
	var error_rate: float = clampf(1.0 - avg_accuracy, 0.0, 1.0)

	return {
		"sessions": sessions,
		"total_duration_ms": int(cfg.get_value(AGGREGATES_SECTION, "total_duration_ms", 0)),
		"total_score": int(cfg.get_value(AGGREGATES_SECTION, "total_score", 0)),
		"max_score": int(cfg.get_value(AGGREGATES_SECTION, "max_score", 0)),
		"best_streak_overall": int(cfg.get_value(AGGREGATES_SECTION, "best_streak_overall", 0)),
		"avg_error_rate": error_rate,
	}


## Wipes the local stats file for a profile. Called by ProfileService.delete
## so a fresh profile re-using the same on-disk dir starts at zero (the dir
## itself is also removed by ProfileService).
static func clear(profile_id: int) -> void:
	if profile_id <= 0:
		return
	var path := _path_for(profile_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _path_for(profile_id: int) -> String:
	return "user://profiles/%d/stats.cfg" % profile_id


## Mirrors ProfileService._ensure_profile_dir. Repeated here to avoid a
## circular dependency between the persistence and autoload layers.
static func _ensure_profile_dir(profile_id: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var rel := "profiles/%d" % profile_id
	if not dir.dir_exists(rel):
		dir.make_dir_recursive(rel)
