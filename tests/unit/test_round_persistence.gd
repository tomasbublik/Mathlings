## End-to-end persistence of rounds played through a live GameController:
## finished rounds are recorded (history, attempts, skills, totals, badges),
## aborted rounds are not (only the skill ratings they taught are kept).
## Storage goes to user://test_rounds; the test profile's stats.cfg is removed.

extends GutTest

const ROOT := "user://test_rounds"
const PID := 930001

var _saved_last_result: Dictionary = {}


func before_each() -> void:
	ProgressStore.set_root(ROOT)
	SessionStatsStore.clear(PID)
	_saved_last_result = GameState.last_result


func after_each() -> void:
	ProgressStore.delete_profile(PID)
	SessionStatsStore.clear(PID)
	DirAccess.remove_absolute(ROOT)
	DirAccess.remove_absolute("user://profiles/%d" % PID)
	ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)
	GameState.last_result = _saved_last_result
	# Live controllers play SFX; stop them so nothing is still playing at exit.
	for player: AudioStreamPlayer in AudioManager._sfx_players:
		player.stop()


func _live_controller(duration_s: int = 30) -> GameController:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var config := {
		"duration_s": duration_s,
		"speed_preset": "normal",
		"enabled_skills": ["add_0_10", "add_0_20"],
	}
	return GameController.new(PID, config, true, SkillModel.new(PID, true),
		AttemptLogger.new(), DifficultyController.new(), rng)


func _advance(c: GameController, seconds: float, step: float = 0.05) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var d: float = minf(step, remaining)
		c.tick(d)
		remaining -= d


func _answer(c: GameController, correct: bool) -> void:
	var p := c.current_problem()
	if p.is_empty():
		_advance(c, GameController.WRONG_SPAWN_DELAY_S + 0.05)
		p = c.current_problem()
	var idx: int = int(p["correct_index"])
	c.on_answer(idx if correct else (idx + 1) % 3, 800)


## Plays a full round: `correct` right answers, then `wrong` wrong ones.
## Returns the round summary.
func _play_round(correct: int, wrong: int = 0) -> Dictionary:
	var c := _live_controller(30)
	var result := [{}]
	c.round_ended.connect(func(s: Dictionary) -> void: result[0] = s)
	c.start()
	_advance(c, 3.0)
	for i in range(correct):
		_answer(c, true)
	for i in range(wrong):
		_answer(c, false)
	_advance(c, 30.0 + GameController.ENDING_GRACE_SECONDS + 0.2, 0.25)
	assert_eq(c.state(), GameController.State.RESULT)
	return result[0]


func _keys(unlocks: Array) -> Array:
	return unlocks.map(func(u: Dictionary) -> String: return String(u["key"]))


# ---------------------------------------------------------------------------

func test_finished_round_is_persisted() -> void:
	var summary := _play_round(3, 1)
	assert_eq(int(summary["session_id"]), 1)
	ProgressStore.reset_cache()  # "restart the app"

	var sessions := ProgressStore.sessions(PID)
	assert_eq(sessions.size(), 1, "one finished round in the history")
	assert_eq(int(sessions[0]["score"]), int(summary["score"]))
	assert_eq(int(sessions[0]["best_streak"]), 3)
	assert_almost_eq(float(sessions[0]["accuracy"]), 0.75, 0.0001)
	assert_eq(int(sessions[0]["duration_ms"]), 30000)

	var attempts := ProgressStore.recent_attempts(PID)
	assert_eq(attempts.size(), 4)
	assert_eq(attempts.filter(func(a: Dictionary) -> bool: return a["correct"]).size(), 3)
	for a: Dictionary in attempts:
		assert_eq(int(a["session_id"]), 1)

	var total_attempts := 0
	for row: Dictionary in ProgressStore.skill_overview(PID):
		total_attempts += int(row["attempts"])
	assert_eq(total_attempts, 4, "skill counters persisted")
	assert_eq(int(SessionStatsStore.totals_for(PID)["sessions"]), 1, "totals updated")
	assert_eq(int(GameState.last_result.get("session_id", -1)), 1)


func test_skill_model_reloads_ratings_after_restart() -> void:
	_play_round(5)
	ProgressStore.reset_cache()
	var model := SkillModel.new(PID, true)
	var trained := 0
	for key: String in ["add_0_10", "add_0_20"]:
		trained += model.attempts_for(key)
		if model.attempts_for(key) > 0:
			assert_gt(model.rating_for(key), SkillModel.DEFAULT_RATING,
				"correct answers raised the rating of %s" % key)
	assert_eq(trained, 5)


func test_aborted_round_is_not_recorded_but_ratings_stay() -> void:
	var c := _live_controller(30)
	var ended := [0]
	c.round_ended.connect(func(_s: Dictionary) -> void: ended[0] += 1)
	var last_result_before: Dictionary = GameState.last_result
	c.start()
	_advance(c, 3.0)
	for i in range(UnlockSystem.STREAK_BADGE_TARGET):
		_answer(c, true)
	c.pause()
	assert_true(c.abort_round())
	_advance(c, 40.0, 0.5)
	assert_eq(ended[0], 0)

	ProgressStore.reset_cache()
	assert_eq(ProgressStore.session_count(PID), 0, "no history entry")
	assert_eq(ProgressStore.recent_attempts(PID), [], "buffered attempts dropped")
	assert_eq(ProgressStore.unlocks(PID), [], "a 10-streak in an aborted round earns nothing")
	assert_eq(int(SessionStatsStore.totals_for(PID)["sessions"]), 0, "totals untouched")
	assert_eq(GameState.last_result, last_result_before, "no results summary")
	var answered := 0
	for row: Dictionary in ProgressStore.skill_overview(PID):
		answered += int(row["attempts"])
	assert_eq(answered, UnlockSystem.STREAK_BADGE_TARGET,
		"skill ratings from the answered problems were flushed to disk")


func test_aborted_round_does_not_consume_a_session_id() -> void:
	var c := _live_controller(30)
	c.start()
	_advance(c, 3.0)
	c.abort_round()
	var summary := _play_round(1)
	assert_eq(int(summary["session_id"]), 1)
	assert_eq(ProgressStore.session_count(PID), 1)


func test_streak_badge_from_a_real_round() -> void:
	var summary := _play_round(UnlockSystem.STREAK_BADGE_TARGET)
	assert_true("streak_10" in _keys(summary["new_unlocks"]))


func test_ten_rounds_badge_is_reachable() -> void:
	for i in range(UnlockSystem.TEN_GAMES_BADGE_TARGET - 1):
		var s := _play_round(1)
		assert_false("ten_games" in _keys(s["new_unlocks"]), "not yet after round %d" % (i + 1))
	var tenth := _play_round(1)
	assert_true("ten_games" in _keys(tenth["new_unlocks"]), "earned in the 10th round")
	ProgressStore.reset_cache()
	assert_true(ProgressStore.is_unlocked(PID, UnlockSystem.KIND_BADGE, "ten_games"))
	var again := _play_round(1)
	assert_false("ten_games" in _keys(again["new_unlocks"]), "only awarded once")
