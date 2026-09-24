## GUT integration tests for StatsDao.
## Exercises the aggregation queries against a real (in-memory) SQLite to make
## sure the SQL is correct — pure unit tests can't catch typos in `GROUP BY` etc.

extends GutTest


var _db: TestInMemoryDb = null
var _profile_id: int = 0


func before_each() -> void:
	_db = TestInMemoryDb.new()
	if not _db.open():
		_db = null
		return
	_profile_id = ProfilesDao.insert(_db, "Hráč X", "", 1700000000000)


func after_each() -> void:
	if _db != null:
		_db.close()
		_db = null


func _skip_unless_db() -> bool:
	if _db == null:
		pending("godot-sqlite addon není dostupný")
		return true
	return false


# ---------------------------------------------------------------------------
# profile_totals
# ---------------------------------------------------------------------------

func test_profile_totals_zero_when_no_sessions() -> void:
	if _skip_unless_db(): return
	var totals: Dictionary = StatsDao.profile_totals(_db, _profile_id)
	assert_eq(int(totals["sessions"]), 0)
	assert_eq(int(totals["total_duration_ms"]), 0)
	assert_eq(int(totals["total_score"]), 0)
	assert_eq(int(totals["max_score"]), 0)
	assert_eq(int(totals["best_streak_overall"]), 0)
	assert_almost_eq(float(totals["avg_error_rate"]), 0.0, 0.0001)


func test_profile_totals_skips_unfinished_sessions() -> void:
	if _skip_unless_db(): return
	# 2 finished + 1 unfinished sessions.
	var sid1 := SessionsDao.insert(_db, _profile_id, 1700000001000, "{}")
	SessionsDao.close_session(_db, sid1, 1700000091000, 90000, 100, 5, 0.8)
	var sid2 := SessionsDao.insert(_db, _profile_id, 1700000200000, "{}")
	SessionsDao.close_session(_db, sid2, 1700000260000, 60000, 50, 3, 0.6)
	SessionsDao.insert(_db, _profile_id, 1700000300000, "{}")  # unfinished

	var totals: Dictionary = StatsDao.profile_totals(_db, _profile_id)
	assert_eq(int(totals["sessions"]), 2,
		"unfinished sessions (ended_at IS NULL) must not count")
	assert_eq(int(totals["total_duration_ms"]), 150000)
	assert_eq(int(totals["total_score"]), 150)
	assert_eq(int(totals["max_score"]), 100,
		"max_score must be the largest single-round score (here 100)")
	assert_eq(int(totals["best_streak_overall"]), 5,
		"best_streak_overall must be the highest best_streak across rounds")
	# avg_accuracy = (0.8 + 0.6) / 2 = 0.7 → error_rate = 0.3
	assert_almost_eq(float(totals["avg_error_rate"]), 0.3, 0.001)


func test_profile_totals_max_score_picks_single_best_round() -> void:
	if _skip_unless_db(): return
	# Multi-session scenario with one outlier high score.
	var rounds: Array = [40, 80, 250, 90, 60]
	for i in range(rounds.size()):
		var sid := SessionsDao.insert(_db, _profile_id, 1700000000000 + i * 1000, "{}")
		SessionsDao.close_session(_db, sid, 1700000060000 + i * 1000, 60000, rounds[i], 1, 1.0)
	var totals: Dictionary = StatsDao.profile_totals(_db, _profile_id)
	assert_eq(int(totals["max_score"]), 250)


func test_profile_totals_returns_safe_default_for_null_db() -> void:
	if _skip_unless_db(): return
	var totals: Dictionary = StatsDao.profile_totals(null, 1)
	assert_eq(int(totals["sessions"]), 0)
	assert_eq(int(totals["max_score"]), 0)
	assert_almost_eq(float(totals["avg_error_rate"]), 0.0, 0.0001)


# ---------------------------------------------------------------------------
# SessionsDao.max_score_for_profile (P16 helper)
# ---------------------------------------------------------------------------

func test_max_score_for_profile_zero_when_no_sessions() -> void:
	if _skip_unless_db(): return
	assert_eq(SessionsDao.max_score_for_profile(_db, _profile_id), 0)


func test_max_score_for_profile_returns_max() -> void:
	if _skip_unless_db(): return
	for s in [40, 80, 110, 50]:
		var sid := SessionsDao.insert(_db, _profile_id, 1700000000000, "{}")
		SessionsDao.close_session(_db, sid, 1700000060000, 60000, s, 1, 1.0)
	assert_eq(SessionsDao.max_score_for_profile(_db, _profile_id), 110)


func test_max_score_ignores_unfinished_sessions() -> void:
	if _skip_unless_db(): return
	# Finished round at 50 + unfinished session that *would have* scored
	# higher but never closed → max_score must still be 50.
	var finished_sid := SessionsDao.insert(_db, _profile_id, 1700000000000, "{}")
	SessionsDao.close_session(_db, finished_sid, 1700000060000, 60000, 50, 0, 1.0)
	SessionsDao.insert(_db, _profile_id, 1700000200000, "{}")  # unfinished
	assert_eq(SessionsDao.max_score_for_profile(_db, _profile_id), 50)


# ---------------------------------------------------------------------------
# skill_overview
# ---------------------------------------------------------------------------

func test_skill_overview_sorts_by_rating_ascending() -> void:
	if _skip_unless_db(): return
	SkillsDao.upsert(_db, _profile_id, "add_0_20", 1200.0, 10, 8, 0)
	SkillsDao.upsert(_db, _profile_id, "sub_0_20", 800.0, 5, 2, 0)
	SkillsDao.upsert(_db, _profile_id, "mul_x5", 1000.0, 6, 4, 0)

	var rows: Array = StatsDao.skill_overview(_db, _profile_id)
	assert_eq(rows.size(), 3)
	assert_eq(String(rows[0]["skill_key"]), "sub_0_20", "weakest skill (rating 800) first")
	assert_eq(String(rows[1]["skill_key"]), "mul_x5")
	assert_eq(String(rows[2]["skill_key"]), "add_0_20")


func test_skill_overview_accuracy_is_zero_when_no_attempts() -> void:
	if _skip_unless_db(): return
	SkillsDao.upsert(_db, _profile_id, "add_0_10", 1000.0, 0, 0, 0)
	var rows: Array = StatsDao.skill_overview(_db, _profile_id)
	assert_eq(float(rows[0]["accuracy"]), 0.0,
		"accuracy must default to 0.0 when attempts=0 (no division by zero)")


func test_skill_overview_accuracy_is_correct_over_attempts() -> void:
	if _skip_unless_db(): return
	SkillsDao.upsert(_db, _profile_id, "add_0_10", 1000.0, 10, 7, 0)
	var rows: Array = StatsDao.skill_overview(_db, _profile_id)
	assert_almost_eq(float(rows[0]["accuracy"]), 0.7, 0.001)


# ---------------------------------------------------------------------------
# skills_needing_practice
# ---------------------------------------------------------------------------

func test_skills_needing_practice_orders_by_lowest_accuracy() -> void:
	if _skip_unless_db(): return
	SkillsDao.upsert(_db, _profile_id, "add_0_10", 1000.0, 10, 9, 0)  # 90%
	SkillsDao.upsert(_db, _profile_id, "sub_0_10", 1000.0, 10, 4, 0)  # 40%
	SkillsDao.upsert(_db, _profile_id, "mul_x5",   1000.0, 10, 7, 0)  # 70%

	var rows: Array = StatsDao.skills_needing_practice(_db, _profile_id)
	assert_eq(rows.size(), 3)
	assert_eq(String(rows[0]["skill_key"]), "sub_0_10",
		"lowest accuracy (40%%) must come first")
	assert_eq(String(rows[1]["skill_key"]), "mul_x5")
	assert_eq(String(rows[2]["skill_key"]), "add_0_10")


func test_skills_needing_practice_skips_skills_below_min_attempts() -> void:
	if _skip_unless_db(): return
	# default min_attempts = 5
	SkillsDao.upsert(_db, _profile_id, "add_0_10", 1000.0, 4, 0, 0)  # only 4 attempts
	SkillsDao.upsert(_db, _profile_id, "sub_0_10", 1000.0, 10, 5, 0) # 10 attempts

	var rows: Array = StatsDao.skills_needing_practice(_db, _profile_id)
	assert_eq(rows.size(), 1)
	assert_eq(String(rows[0]["skill_key"]), "sub_0_10",
		"add_0_10 must be filtered out (< 5 attempts)")


func test_skills_needing_practice_honors_limit() -> void:
	if _skip_unless_db(): return
	for i in range(5):
		SkillsDao.upsert(_db, _profile_id, "skill_%d" % i, 1000.0, 10, i, 0)
	var rows: Array = StatsDao.skills_needing_practice(_db, _profile_id, 2)
	assert_eq(rows.size(), 2, "limit=2 must cap the result list")
