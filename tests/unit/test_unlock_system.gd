## GUT tests for UnlockSystem against a real ProgressStore in a temp dir.
## Each rule has a happy path and at least one negative case.

extends GutTest

const ROOT := "user://test_unlocks"
const PID := 910001

var _saved_locale: String = ""


func before_each() -> void:
	ProgressStore.set_root(ROOT)
	SessionStatsStore.clear(PID)
	_saved_locale = TranslationServer.get_locale()


func after_each() -> void:
	ProgressStore.delete_profile(PID)
	SessionStatsStore.clear(PID)
	DirAccess.remove_absolute(ROOT)
	DirAccess.remove_absolute("user://profiles/%d" % PID)
	ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)
	TranslationServer.set_locale(_saved_locale)


func _round_summary(score: int = 0, best_streak: int = 0) -> Dictionary:
	return {
		"score": score,
		"best_streak": best_streak,
		"accuracy": 1.0,
		"total_attempts": 1,
		"correct_attempts": 1,
	}


## Records a finished round the way GameController does (both stores).
func _play_round(score: int = 10, started_at_ms: int = 1700000000000) -> void:
	ProgressStore.record_round(PID, {
		"started_at": started_at_ms, "ended_at": started_at_ms + 60000,
		"duration_ms": 60000, "score": score, "best_streak": 1, "accuracy": 0.5,
	}, [])
	SessionStatsStore.record_session(PID, score, 60000, 1, 0.5)


func _has_unlock(unlocks: Array, kind: String, key: String) -> bool:
	for u: Dictionary in unlocks:
		if String(u.get("kind", "")) == kind and String(u.get("key", "")) == key:
			return true
	return false


# ---------------------------------------------------------------------------
# Guards + idempotency
# ---------------------------------------------------------------------------

func test_invalid_profile_id_returns_empty_list() -> void:
	assert_eq(UnlockSystem.evaluate(0, _round_summary(0, 10)), [])
	assert_eq(UnlockSystem.evaluate(-1, _round_summary(0, 10)), [])


func test_unlock_persisted_only_once() -> void:
	var first: Array = UnlockSystem.evaluate(PID, _round_summary(0, 10))
	assert_true(_has_unlock(first, UnlockSystem.KIND_BADGE, "streak_10"))
	var second: Array = UnlockSystem.evaluate(PID, _round_summary(0, 10))
	assert_false(_has_unlock(second, UnlockSystem.KIND_BADGE, "streak_10"),
		"an unlock is reported only the first time")
	assert_eq(ProgressStore.unlocks(PID, UnlockSystem.KIND_BADGE).size(), 1)
	ProgressStore.reset_cache()
	assert_true(ProgressStore.is_unlocked(PID, UnlockSystem.KIND_BADGE, "streak_10"),
		"the unlock survives a restart")


# ---------------------------------------------------------------------------
# streak_10
# ---------------------------------------------------------------------------

func test_streak_10_unlocks_at_target() -> void:
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary(0, UnlockSystem.STREAK_BADGE_TARGET))
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "streak_10"))


func test_streak_10_does_not_unlock_below_target() -> void:
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary(0, 9))
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "streak_10"))


# ---------------------------------------------------------------------------
# ten_games
# ---------------------------------------------------------------------------

func test_ten_games_unlocks_after_ten_finished_rounds() -> void:
	for i in range(UnlockSystem.TEN_GAMES_BADGE_TARGET):
		_play_round(10, 1700000000000 + i * 1000)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "ten_games"))


func test_ten_games_does_not_unlock_with_nine_rounds() -> void:
	for i in range(9):
		_play_round(10, 1700000000000 + i * 1000)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "ten_games"))


func test_ten_games_counts_rounds_from_legacy_totals() -> void:
	# Installs that played before ProgressStore existed only have stats.cfg.
	for i in range(UnlockSystem.TEN_GAMES_BADGE_TARGET):
		SessionStatsStore.record_session(PID, 10, 60000, 1, 0.5)
	assert_eq(ProgressStore.session_count(PID), 0)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "ten_games"))


# ---------------------------------------------------------------------------
# addition_master
# ---------------------------------------------------------------------------

func test_addition_master_unlocks_when_all_add_skills_are_above_threshold() -> void:
	for k: String in UnlockSystem.ADDITION_SKILLS:
		ProgressStore.set_skill(PID, k, UnlockSystem.ADDITION_MASTERY_RATING + 1.0, 30, 28)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "addition_master"))


func test_addition_master_skips_when_any_skill_is_below_threshold() -> void:
	ProgressStore.set_skill(PID, "add_0_10", 1500.0, 30, 28)
	ProgressStore.set_skill(PID, "add_0_20", 1500.0, 30, 28)
	ProgressStore.set_skill(PID, "add_0_100", 1399.0, 30, 28)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "addition_master"))


func test_addition_master_skips_when_a_skill_was_never_practised() -> void:
	ProgressStore.set_skill(PID, "add_0_10", 1500.0, 30, 28)
	ProgressStore.set_skill(PID, "add_0_20", 1500.0, 30, 28)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_BADGE, "addition_master"))


# ---------------------------------------------------------------------------
# Themes
# ---------------------------------------------------------------------------

func test_space_theme_unlocks_when_total_score_reaches_threshold() -> void:
	_play_round(800)
	_play_round(UnlockSystem.SPACE_THEME_TOTAL_SCORE - 800)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary())
	assert_true(_has_unlock(unlocks, UnlockSystem.KIND_THEME, "space"))


func test_space_theme_does_not_unlock_below_threshold() -> void:
	_play_round(500)
	var unlocks: Array = UnlockSystem.evaluate(PID, _round_summary(500))
	assert_false(_has_unlock(unlocks, UnlockSystem.KIND_THEME, "space"),
		"the round score is already in the totals — no double counting")


func test_balloons_theme_needs_distinct_play_days() -> void:
	var day_ms := 24 * 3600 * 1000
	for i in range(UnlockSystem.BALLOONS_THEME_DISTINCT_DAYS - 1):
		_play_round(10, 1700000000000 + i * day_ms)
	_play_round(10, 1700000000000 + 1000)  # same day as the first one
	assert_false(_has_unlock(UnlockSystem.evaluate(PID, _round_summary()),
		UnlockSystem.KIND_THEME, "balloons"))
	_play_round(10, 1700000000000 + 10 * day_ms)
	assert_true(_has_unlock(UnlockSystem.evaluate(PID, _round_summary()),
		UnlockSystem.KIND_THEME, "balloons"))


# ---------------------------------------------------------------------------
# Display names are translated at display time
# ---------------------------------------------------------------------------

func test_display_name_follows_the_current_locale() -> void:
	var streak := {"kind": UnlockSystem.KIND_BADGE, "key": "streak_10"}
	var space := {"kind": UnlockSystem.KIND_THEME, "key": "space"}
	TranslationServer.set_locale("en")
	assert_eq(UnlockSystem.display_name(streak), "10 in a row, no mistakes!")
	assert_eq(UnlockSystem.display_name(space), "Theme: Space")
	assert_eq(UnlockSystem.display_name({"kind": "badge", "key": "ten_games"}),
		"10 rounds played")
	assert_eq(UnlockSystem.display_name({"kind": "badge", "key": "addition_master"}),
		"Addition master")
	TranslationServer.set_locale("cs")
	assert_eq(UnlockSystem.display_name(streak), "10 v řadě bez chyby!")
	assert_eq(UnlockSystem.display_name(space), "Téma: Vesmír")


func test_every_unlock_has_a_translated_name() -> void:
	TranslationServer.set_locale("en")
	for rule: Dictionary in UnlockSystem._rules():
		var name := UnlockSystem.display_name(rule)
		assert_false(name.begins_with("UNLOCK_") or name.contains("THEME_"),
			"'%s' must resolve to a translated name, got '%s'" % [rule["key"], name])
		assert_ne(name, String(rule["key"]))
