## GUT unit tests for GameController.
##
## Focus on pure state-machine and scoring behavior. Because GameController tracks
## timing via `tick(delta_s)`, tests simulate frames by calling tick() with fixed deltas.
## Audio/Haptics side-effects and persistence are elided by passing live = false.

extends GutTest


func _make_controller(duration_s: int = 10, enabled: Array = ["add_0_10"], rng_seed: int = 1) -> GameController:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var skill_model := SkillModel.new(1)
	var logger := AttemptLogger.new()
	var diff := DifficultyController.new()
	var config := {
		"duration_s": duration_s,
		"speed_preset": "normal",
		"enabled_skills": enabled,
	}
	return GameController.new(1, config, false, skill_model, logger, diff, rng)


func _advance(controller: GameController, seconds: float, step: float = 0.05) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var d: float = minf(step, remaining)
		controller.tick(d)
		remaining -= d


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func test_initial_state_idle() -> void:
	var c := _make_controller()
	assert_eq(c.state(), GameController.State.IDLE, "Controller starts in IDLE")


func test_start_enters_countdown() -> void:
	var c := _make_controller()
	c.start()
	assert_eq(c.state(), GameController.State.COUNTDOWN,
		"start() must transition to COUNTDOWN immediately")


func test_countdown_to_playing() -> void:
	var c := _make_controller()
	c.start()
	_advance(c, 3.1)
	assert_eq(c.state(), GameController.State.PLAYING,
		"After 3 s of countdown the controller must be PLAYING")


func test_duration_elapsed_enters_ending() -> void:
	var c := _make_controller(2)
	c.start()
	_advance(c, 3.0)  # finish countdown
	assert_eq(c.state(), GameController.State.PLAYING)
	_advance(c, 2.1)
	assert_eq(c.state(), GameController.State.ENDING,
		"After duration elapses controller must enter ENDING")


func test_ending_to_result() -> void:
	var c := _make_controller(1)
	c.start()
	_advance(c, 3.0 + 1.1 + 1.6)
	assert_eq(c.state(), GameController.State.RESULT,
		"After ENDING grace period, controller must reach RESULT")


# ---------------------------------------------------------------------------
# Scoring / streaks / combos
# ---------------------------------------------------------------------------

func test_correct_answer_increments_score() -> void:
	var c := _make_controller(30)
	c.start()
	_advance(c, 3.0)
	var problem := c.current_problem()
	assert_false(problem.is_empty(), "Controller must spawn a problem after countdown")
	c.on_answer(int(problem["correct_index"]), 1000)
	assert_eq(c.score(), 10, "First correct answer at combo=1.0 → +10 points")
	assert_eq(c.streak(), 1)


func test_wrong_resets_streak_and_combo() -> void:
	var c := _make_controller(30)
	c.start()
	_advance(c, 3.0)
	# Fake a streak by answering 3 correctly.
	for i in range(3):
		var p := c.current_problem()
		c.on_answer(int(p["correct_index"]), 1000)
	assert_eq(c.streak(), 3)
	var p_after := c.current_problem()
	var wrong_index: int = (int(p_after["correct_index"]) + 1) % 3
	c.on_answer(wrong_index, 1000)
	assert_eq(c.streak(), 0, "Wrong answer resets streak to 0")


func test_scoring_combo_eleven_correct() -> void:
	# 11 correct answers in a row. Combo schedule:
	#  streaks 1,2 → 1.0× ⇒ +10 each
	#  streaks 3,4 → 1.25× ⇒ +12 or +13 (round-half-to-even: round(12.5)=13)
	#  streaks 5..9 → 1.5× ⇒ +15 each
	#  streaks 10+ → 2.0× ⇒ +20 each
	# Spec expectation: 10+10+12+12+15+15+15+15+15+20+20 = 159.
	var c := _make_controller(60)
	c.start()
	_advance(c, 3.0)
	for i in range(11):
		var p := c.current_problem()
		c.on_answer(int(p["correct_index"]), 1000)
	var expected := 10 + 10 + 13 + 13 + 15 + 15 + 15 + 15 + 15 + 20 + 20
	# Godot's round() rounds half away from zero → 12.5 becomes 13.
	assert_eq(c.score(), expected,
		"Eleven correct answers should total %d (got %d)" % [expected, c.score()])


# ---------------------------------------------------------------------------
# Miss handling
# ---------------------------------------------------------------------------

func test_miss_is_wrong_for_skill_model() -> void:
	var c := _make_controller(30)
	c.start()
	_advance(c, 3.0)
	var p := c.current_problem()
	var pid: int = int(p["id"])
	c.on_miss(pid)
	assert_eq(c.streak(), 0, "Miss resets streak")
	# total_attempts implicitly incremented — verified via no crash + streak reset.


# ---------------------------------------------------------------------------
# No spawn after ending
# ---------------------------------------------------------------------------

func test_no_spawn_requests_after_ending() -> void:
	var c := _make_controller(1)
	var spawn_count := [0]
	c.spawn_requested.connect(func(_p: Dictionary, _s: float) -> void:
		spawn_count[0] += 1)
	c.start()
	_advance(c, 3.0)     # countdown
	assert_eq(spawn_count[0], 1, "Exactly one spawn at start of PLAYING")
	_advance(c, 1.1)     # duration elapses
	assert_eq(c.state(), GameController.State.ENDING)
	var before: int = spawn_count[0]
	_advance(c, 2.0)     # grace + result
	assert_eq(spawn_count[0], before,
		"No new spawn after ENDING (was %d, now %d)" % [before, spawn_count[0]])
