## GUT unit tests for GameController pause / resume / abort_round().
##
## Headless controllers (live = false) cover the timing and input guards.
## What an aborted round persists (nothing but skill ratings) is covered in
## test_round_persistence.gd against a real ProgressStore in a temp dir.

extends GutTest


func _make_controller(duration_s: int = 30) -> GameController:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var config := {
		"duration_s": duration_s,
		"speed_preset": "normal",
		"enabled_skills": ["add_0_10"],
	}
	return GameController.new(1, config, false, SkillModel.new(1),
		AttemptLogger.new(), DifficultyController.new(), rng)


func _advance(c: GameController, seconds: float, step: float = 0.05) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var d: float = minf(step, remaining)
		c.tick(d)
		remaining -= d


func _playing_controller(duration_s: int = 30) -> GameController:
	var c := _make_controller(duration_s)
	c.start()
	_advance(c, 3.0)
	assert_eq(c.state(), GameController.State.PLAYING)
	return c


# ---------------------------------------------------------------------------
# Pause / resume
# ---------------------------------------------------------------------------

func test_pause_freezes_round_timer_and_resume_keeps_remaining_time() -> void:
	var c := _playing_controller(30)
	_advance(c, 5.0)
	var before := c.time_remaining_s()
	assert_true(c.pause(), "pause() succeeds while PLAYING")
	assert_true(c.is_paused())
	_advance(c, 20.0)
	assert_almost_eq(c.time_remaining_s(), before, 0.0001, "Timer must not move while paused")
	assert_eq(c.state(), GameController.State.PLAYING, "Pause keeps the state")
	c.resume()
	assert_false(c.is_paused())
	_advance(c, 2.0)
	assert_almost_eq(c.time_remaining_s(), before - 2.0, 0.01, "Timer resumes from the same spot")


func test_pause_freezes_countdown() -> void:
	var c := _make_controller()
	c.start()
	_advance(c, 1.0)
	assert_true(c.pause(), "Countdown can be paused")
	_advance(c, 10.0)
	assert_eq(c.state(), GameController.State.COUNTDOWN, "Countdown must not finish while paused")
	c.resume()
	_advance(c, 2.1)
	assert_eq(c.state(), GameController.State.PLAYING)


func test_answers_and_misses_ignored_while_paused() -> void:
	var c := _playing_controller()
	var p := c.current_problem()
	var resolved := [0]
	c.answer_resolved.connect(func(_id: int, _ok: bool, _i: int) -> void: resolved[0] += 1)
	c.problem_missed.connect(func(_id: int) -> void: resolved[0] += 1)
	c.pause()
	c.on_answer(int(p["correct_index"]), 500)
	c.on_miss(int(p["id"]))
	assert_eq(resolved[0], 0, "No answer / miss may register while paused")
	assert_eq(c.score(), 0)
	assert_eq(c.current_problem(), p, "The same problem is still waiting")
	c.resume()
	c.on_answer(int(p["correct_index"]), 500)
	assert_eq(c.score(), 10, "Answers count again after resume")
	assert_eq(c.streak(), 1)


func test_pause_keeps_streak_and_combo() -> void:
	var c := _playing_controller()
	for i in range(3):
		c.on_answer(int(c.current_problem()["correct_index"]), 500)
	assert_eq(c.streak(), 3)
	c.pause()
	_advance(c, 3.0)
	c.resume()
	assert_eq(c.streak(), 3, "Pausing must not reset the streak")
	var score_before := c.score()
	c.on_answer(int(c.current_problem()["correct_index"]), 500)
	assert_eq(c.streak(), 4)
	assert_eq(c.score() - score_before, 13, "Combo multiplier (1.25x) survives a pause")


func test_no_spawn_while_paused_after_wrong_answer() -> void:
	var c := _playing_controller()
	var spawns := [0]
	c.spawn_requested.connect(func(_p: Dictionary, _s: float) -> void: spawns[0] += 1)
	var p := c.current_problem()
	c.on_answer((int(p["correct_index"]) + 1) % 3, 500)
	c.pause()
	_advance(c, 2.0)
	assert_eq(spawns[0], 0, "The post-wrong spawn delay is frozen while paused")
	c.resume()
	_advance(c, GameController.WRONG_SPAWN_DELAY_S + 0.1)
	assert_eq(spawns[0], 1)


func test_cannot_pause_twice_or_outside_round() -> void:
	var idle := _make_controller()
	assert_false(idle.pause(), "Nothing to pause before start()")
	var c := _playing_controller(1)
	assert_true(c.pause())
	assert_false(c.pause(), "Already paused")
	c.resume()
	_advance(c, 1.1)
	assert_eq(c.state(), GameController.State.ENDING)
	assert_false(c.can_pause(), "No pause once the round is ending")
	assert_false(c.pause())


# ---------------------------------------------------------------------------
# abort_round()
# ---------------------------------------------------------------------------

func test_abort_emits_no_round_ended_and_stops_the_round() -> void:
	var c := _playing_controller(5)
	var ended := [0]
	var aborted := [0]
	var spawns := [0]
	c.round_ended.connect(func(_s: Dictionary) -> void: ended[0] += 1)
	c.round_aborted.connect(func(_id: int) -> void: aborted[0] += 1)
	c.spawn_requested.connect(func(_p: Dictionary, _s: float) -> void: spawns[0] += 1)
	c.pause()
	assert_true(c.abort_round())
	assert_eq(c.state(), GameController.State.ABORTED)
	assert_false(c.is_paused())
	assert_eq(aborted[0], 1, "round_aborted fires once")
	_advance(c, 10.0)
	assert_eq(ended[0], 0, "An aborted round never emits round_ended")
	assert_eq(spawns[0], 0, "Nothing spawns after abort")
	assert_eq(c.state(), GameController.State.ABORTED)
	assert_true(c.current_problem().is_empty())


func test_abort_during_countdown() -> void:
	var c := _make_controller()
	c.start()
	_advance(c, 1.0)
	assert_true(c.abort_round())
	_advance(c, 5.0)
	assert_eq(c.state(), GameController.State.ABORTED, "Countdown doesn't restart the round")


func test_abort_not_allowed_after_round_ended() -> void:
	var c := _playing_controller(1)
	_advance(c, 1.1)
	assert_eq(c.state(), GameController.State.ENDING)
	assert_false(c.abort_round(), "Finished rounds keep their results")
	assert_eq(c.state(), GameController.State.ENDING)
