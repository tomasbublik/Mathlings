## GUT integration tests for UnlockSystem.
## Each rule has a happy path and at least one negative case.
## Uses TestInMemoryDb so we exercise SQL counts (sessions, distinct days).

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


func _summary(score: int = 0, best_streak: int = 0) -> Dictionary:
	return {
		"score": score,
		"best_streak": best_streak,
		"accuracy": 1.0,
		"total_attempts": 1,
		"correct_attempts": 1,
	}


# ---------------------------------------------------------------------------
# Profile guard + DB guard
# ---------------------------------------------------------------------------

func test_invalid_profile_id_returns_empty_list() -> void:
	if _skip_unless_db(): return
	assert_eq(UnlockSystem.evaluate(0, _summary(), _db), [],
		"profile_id <= 0 must short-circuit with no unlocks")
	assert_eq(UnlockSystem.evaluate(-1, _summary(), _db), [])


func test_null_db_returns_only_db_independent_unlocks() -> void:
	if _skip_unless_db(): return
	# best_streak rule does not touch DB → still unlocks; DB-bound rules silently fail.
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(0, 10), null)
	var keys: Array = unlocks.map(func(u: Dictionary) -> String: return String(u["key"]))
	assert_true(keys.has("streak_10"),
		"streak_10 must unlock even without a DB (rule is pure)")


# ---------------------------------------------------------------------------
# streak_10 badge
# ---------------------------------------------------------------------------

func test_streak_10_unlocks_at_target() -> void:
	if _skip_unless_db(): return
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(0, 10), _db)
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "streak_10"))


func test_streak_10_does_not_unlock_below_target() -> void:
	if _skip_unless_db(): return
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(0, 9), _db)
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "streak_10"))


func test_unlock_persisted_only_once() -> void:
	if _skip_unless_db(): return
	# First evaluation writes the row.
	UnlockSystem.evaluate(_profile_id, _summary(0, 10), _db)
	# Second evaluation must skip already-persisted unlocks.
	var second: Array = UnlockSystem.evaluate(_profile_id, _summary(0, 10), _db)
	assert_false(_has_unlock(second, UnlockSystem.KIND_BADGE, "streak_10"),
		"streak_10 must not appear in the result list twice")
	assert_true(UnlocksDao.is_unlocked(_db, _profile_id, UnlockSystem.KIND_BADGE, "streak_10"))


# ---------------------------------------------------------------------------
# ten_games badge
# ---------------------------------------------------------------------------

func test_ten_games_unlocks_after_ten_finished_sessions() -> void:
	if _skip_unless_db(): return
	for i in range(UnlockSystem.TEN_GAMES_BADGE_TARGET):
		var sid := SessionsDao.insert(_db, _profile_id, 1700000000000 + i * 1000, "{}")
		SessionsDao.close_session(_db, sid, 1700000060000 + i * 1000, 60000, 0, 0, 0.5)

	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(), _db)
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "ten_games"))


func test_ten_games_does_not_unlock_with_nine_sessions() -> void:
	if _skip_unless_db(): return
	for i in range(9):
		var sid := SessionsDao.insert(_db, _profile_id, 1700000000000 + i * 1000, "{}")
		SessionsDao.close_session(_db, sid, 1700000060000 + i * 1000, 60000, 0, 0, 0.5)
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(), _db)
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "ten_games"))


# ---------------------------------------------------------------------------
# addition_master badge
# ---------------------------------------------------------------------------

func test_addition_master_unlocks_when_all_three_add_skills_are_above_threshold() -> void:
	if _skip_unless_db(): return
	for k in ["add_0_10", "add_0_20", "add_0_100"]:
		SkillsDao.upsert(_db, _profile_id, k, UnlockSystem.ADDITION_MASTERY_RATING + 1, 5, 5, 0)
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(), _db)
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "addition_master"))


func test_addition_master_skips_when_any_skill_is_below_threshold() -> void:
	if _skip_unless_db(): return
	SkillsDao.upsert(_db, _profile_id, "add_0_10", 1500.0, 5, 5, 0)
	SkillsDao.upsert(_db, _profile_id, "add_0_20", 1500.0, 5, 5, 0)
	SkillsDao.upsert(_db, _profile_id, "add_0_100", 1399.0, 5, 5, 0)  # one below
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(), _db)
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "addition_master"))


# ---------------------------------------------------------------------------
# space theme
# ---------------------------------------------------------------------------

func test_space_theme_unlocks_when_total_plus_round_score_reaches_threshold() -> void:
	if _skip_unless_db(): return
	# 800 from previous sessions + 200 in summary = 1000 (threshold).
	var sid := SessionsDao.insert(_db, _profile_id, 1700000000000, "{}")
	SessionsDao.close_session(_db, sid, 1700000060000, 60000, 800, 0, 1.0)
	var unlocks: Array = UnlockSystem.evaluate(
		_profile_id, _summary(UnlockSystem.SPACE_THEME_TOTAL_SCORE - 800), _db)
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_THEME, "space"))


func test_space_theme_does_not_unlock_below_threshold() -> void:
	if _skip_unless_db(): return
	var unlocks: Array = UnlockSystem.evaluate(_profile_id, _summary(500), _db)
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_THEME, "space"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _has_unlock(unlocks: Array, kind: String, key: String) -> bool:
	for u: Dictionary in unlocks:
		if String(u.get("kind", "")) == kind and String(u.get("key", "")) == key:
			return true
	return false
