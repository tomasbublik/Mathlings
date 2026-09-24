class_name GameController
extends RefCounted
## Orchestrates one game round. Pure logic (RefCounted) so it can be unit-tested
## without a scene tree; the scene wires inputs and renders via signals.
##
## State machine: IDLE → COUNTDOWN → PLAYING → ENDING → RESULT
## A round can also be abandoned from COUNTDOWN / PLAYING (pause menu →
## "Quit round"): abort_round() → ABORTED, with no results and no stats.
## Pausing is orthogonal to the state: while paused the state is kept but
## tick() / on_answer() / on_miss() are ignored.
## Reference: DESIGN §9, specs/P10_game_controller.md

signal state_changed(new_state: int)
signal spawn_requested(problem: Dictionary, speed_px_s: float)
signal answer_resolved(problem_id: int, correct: bool, chosen_index: int)
signal problem_missed(problem_id: int)
signal score_changed(new_score: int, delta: int)
signal streak_changed(new_streak: int)
signal combo_changed(multiplier: float)
signal countdown_tick(remaining_s: int)
signal round_started(session_id: int)
signal round_ended(summary: Dictionary)
## The round was quit before it finished. `session_id` is the (already
## discarded) session row, or ≤ 0 when none had been opened yet.
signal round_aborted(session_id: int)

enum State { IDLE, COUNTDOWN, PLAYING, ENDING, RESULT, ABORTED }

const COUNTDOWN_SECONDS: int = 3
const ENDING_GRACE_SECONDS: float = 1.5
const RECENT_WINDOW: int = 5
const WRONG_SPAWN_DELAY_S: float = 0.5
const TICK_SFX_LAST_SECONDS: int = 10

## Public alias kept for backwards compatibility (other scenes / tests still
## reference GameController.BASE_POINTS for the floating-text math).
## The authoritative value is now `_rules.base_points`, loaded from JSON.
const BASE_POINTS: int = ScoringRules.DEFAULT_BASE_POINTS

## Fall-speed multipliers for the user-visible "speed_preset" Setting.
## "adaptive" is handled separately (DifficultyController.speed_for).
const SPEED_PRESET_MULTIPLIERS: Dictionary = {
	"slow":   0.75,
	"normal": 1.0,
	"fast":   1.4,
}

var _profile_id: int
var _config: Dictionary
var _db: Node
var _skill_model: SkillModel
var _attempt_logger: AttemptLogger
var _difficulty: DifficultyController
var _rng: RandomNumberGenerator
var _rules: ScoringRules

## True when this controller may invoke the autoload services (AudioManager,
## HapticsManager, EventBus, GameState). Unit tests pass `db=null` and we treat
## that as "headless mode" — no autoload side effects.
var _emit_side_effects: bool = false

var _state: int = State.IDLE
var _session_id: int = -1
var _paused: bool = false
var _paused_at_ms: int = 0

var _countdown_remaining_s: float = 0.0
var _countdown_last_announced: int = -1
var _duration_remaining_s: float = 0.0
var _duration_total_s: int = 0
var _ending_grace_s: float = 0.0
var _spawn_delay_s: float = 0.0
var _tick_announced_seconds: Dictionary = {}

var _score: int = 0
var _streak: int = 0
var _best_streak: int = 0
var _combo_multiplier: float = 1.0
var _total_attempts: int = 0
var _correct_attempts: int = 0

var _recent_results: Array[bool] = []
var _problem_counter: int = 0
var _current_problem: Dictionary = {}
var _current_problem_shown_at_ms: int = 0


## `db` may be null for unit tests; in that case DB-bound side effects are skipped.
## `rng` is injectable for deterministic tests.
## `rules` is injectable so tests can pin GameController against synthetic rule
## sets without round-tripping through the JSON file. When `null`, loads the
## bundled `scoring_rules.json`.
func _init(
	profile_id: int,
	config: Dictionary,
	db: Node,
	skill_model: SkillModel,
	attempt_logger: AttemptLogger,
	difficulty: DifficultyController,
	rng: RandomNumberGenerator = null,
	rules: ScoringRules = null
) -> void:
	_profile_id = profile_id
	_config = config
	_db = db
	_skill_model = skill_model
	_attempt_logger = attempt_logger
	_difficulty = difficulty
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_rules = rules if rules != null else ScoringRules.load_default()

	_emit_side_effects = db != null
	_duration_total_s = int(_config.get("duration_s", 120))


func state() -> int:
	return _state


func score() -> int:
	return _score


func streak() -> int:
	return _streak


func time_remaining_s() -> float:
	return _duration_remaining_s


func current_problem() -> Dictionary:
	return _current_problem


## Kicks off the round: IDLE → COUNTDOWN. Safe to call only from IDLE.
func start() -> void:
	if _state != State.IDLE:
		return
	_reset_round_state()
	_countdown_remaining_s = float(COUNTDOWN_SECONDS)
	_countdown_last_announced = -1
	_transition(State.COUNTDOWN)
	_emit_countdown(COUNTDOWN_SECONDS)
	_play_sfx("round_start")


## Driven by the scene each frame. Advances timers and handles state transitions.
## A paused round ignores ticks, so the countdown, the round timer and the
## post-wrong-answer spawn delay all keep their remaining time.
func tick(delta_s: float) -> void:
	if _paused:
		return
	match _state:
		State.COUNTDOWN:
			_countdown_remaining_s -= delta_s
			var secs_left: int = int(ceil(_countdown_remaining_s))
			if secs_left != _countdown_last_announced and secs_left >= 0:
				_emit_countdown(secs_left)
			if _countdown_remaining_s <= 0.0:
				_begin_playing()
		State.PLAYING:
			if _spawn_delay_s > 0.0:
				_spawn_delay_s -= delta_s
				if _spawn_delay_s <= 0.0:
					_spawn_next_problem()
			_duration_remaining_s -= delta_s
			_maybe_tick_sfx()
			if _duration_remaining_s <= 0.0:
				_begin_ending()
		State.ENDING:
			_ending_grace_s -= delta_s
			if _ending_grace_s <= 0.0:
				_transition(State.RESULT)
		_:
			pass


## Player pressed answer `chosen_index` after `reaction_ms` since the problem was shown.
func on_answer(chosen_index: int, reaction_ms: int) -> void:
	if _paused or _state != State.PLAYING or _current_problem.is_empty():
		return

	var problem: Dictionary = _current_problem
	var problem_id: int = int(problem.get("id", 0))
	var is_correct: bool = AnswerValidator.is_correct(problem, chosen_index)
	var resolved_at_ms: int = Time.get_ticks_msec()

	_log_and_update_skill(problem, chosen_index, reaction_ms, resolved_at_ms, is_correct)

	if is_correct:
		_apply_correct()
		# Theme-aware success chain (see ThemeManager.current_correct_sfx_chain).
		# Vesmír mixes "lightsaber" → "space_explosion"; other themes default
		# to the single in-place "correct" SFX so legacy behaviour is preserved.
		_play_sfx_chain(ThemeManager.current_correct_sfx_chain())
		_pulse_haptics(HapticsManager.Pattern.SUCCESS)
		answer_resolved.emit(problem_id, true, chosen_index)
		_current_problem = {}
		_spawn_next_problem()
	else:
		_apply_wrong()
		_play_sfx("wrong")
		_pulse_haptics(HapticsManager.Pattern.ERROR)
		answer_resolved.emit(problem_id, false, chosen_index)
		_current_problem = {}
		_spawn_delay_s = WRONG_SPAWN_DELAY_S


## Called when a falling problem crosses the floor without being answered.
func on_miss(problem_id: int) -> void:
	if _paused or _state != State.PLAYING:
		return
	if _current_problem.is_empty() or int(_current_problem.get("id", -1)) != problem_id:
		return

	var problem: Dictionary = _current_problem
	var resolved_at_ms: int = Time.get_ticks_msec()
	_log_and_update_skill(problem, -1, -1, resolved_at_ms, false)

	_apply_wrong()
	_play_sfx("miss")
	_pulse_haptics(HapticsManager.Pattern.MEDIUM)
	problem_missed.emit(problem_id)
	_current_problem = {}
	_spawn_next_problem()


## True while the round can be paused / quit: during the countdown and
## while playing. Once ENDING starts the results are already on their way.
func can_pause() -> bool:
	return not _paused and (_state == State.COUNTDOWN or _state == State.PLAYING)


func is_paused() -> bool:
	return _paused


## Freezes the round (the pause overlay is owned by the scene). Returns true
## when the round was actually paused.
func pause() -> bool:
	if not can_pause():
		return false
	_paused = true
	_paused_at_ms = Time.get_ticks_msec()
	return true


## Unfreezes a paused round. The current problem's "shown at" time is
## shifted by the pause length so the logged reaction time (and the Elo
## update that uses it) doesn't count the break.
func resume() -> void:
	if not _paused:
		return
	_paused = false
	var paused_ms: int = maxi(0, Time.get_ticks_msec() - _paused_at_ms)
	if not _current_problem.is_empty():
		_current_problem_shown_at_ms += paused_ms


## Abandons the round ("Quit round" in the pause menu). Allowed from
## COUNTDOWN / PLAYING (paused or not); returns false otherwise.
##
## Contract (see DESIGN §9):
## - no `round_ended` signal / EventBus.round_ended, no results summary in
##   GameState, no unlock evaluation, no SessionStatsStore record;
## - the session row and its attempts are deleted, so the round never shows
##   up in "My progress" or in session-count based unlocks;
## - skill ratings already updated from real answers are kept — the child
##   did answer those problems, and the tutor should learn from them.
func abort_round() -> bool:
	if _state != State.COUNTDOWN and _state != State.PLAYING:
		return false
	_paused = false
	_current_problem = {}
	_spawn_delay_s = 0.0
	var aborted_session_id: int = _session_id
	_discard_session()
	_session_id = -1
	_transition(State.ABORTED)
	round_aborted.emit(aborted_session_id)
	if _emit_side_effects:
		EventBus.round_aborted.emit(aborted_session_id)
	return true


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func _transition(new_state: int) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)


func _reset_round_state() -> void:
	_score = 0
	_streak = 0
	_best_streak = 0
	_combo_multiplier = 1.0
	_total_attempts = 0
	_correct_attempts = 0
	_recent_results.clear()
	_problem_counter = 0
	_current_problem = {}
	_duration_remaining_s = float(_duration_total_s)
	_tick_announced_seconds.clear()


func _begin_playing() -> void:
	_session_id = _open_session()
	_duration_remaining_s = float(_duration_total_s)
	_transition(State.PLAYING)
	round_started.emit(_session_id)
	if _emit_side_effects:
		EventBus.round_started.emit(_session_id, _config)
	_spawn_next_problem()


func _begin_ending() -> void:
	_ending_grace_s = ENDING_GRACE_SECONDS
	_transition(State.ENDING)
	var summary := _build_summary()
	_close_session(summary)
	# Mirror the round into the local stats store so the Stats screen has
	# numbers to show even when the SQLite addon isn't installed. Cheap, and
	# idempotent re-running this path with a DB present is harmless (the DB
	# remains the canonical source — Stats prefers it when available).
	if _profile_id > 0:
		SessionStatsStore.record_session(
			_profile_id,
			int(summary.get("score", 0)),
			_duration_total_s * 1000,
			int(summary.get("best_streak", 0)),
			float(summary.get("accuracy", 0.0))
		)
	summary["new_unlocks"] = UnlockSystem.evaluate(_profile_id, summary, _db)
	if _emit_side_effects:
		GameState.last_result = summary
		EventBus.round_ended.emit(_session_id, summary)
	round_ended.emit(summary)
	_play_sfx("round_end")


func _build_summary() -> Dictionary:
	var accuracy: float = 0.0
	if _total_attempts > 0:
		accuracy = float(_correct_attempts) / float(_total_attempts)
	return {
		"session_id": _session_id,
		"score": _score,
		"accuracy": accuracy,
		"best_streak": _best_streak,
		"total_attempts": _total_attempts,
		"correct_attempts": _correct_attempts,
		"new_unlocks": [],  # P14 fills this once badges ship.
	}


# ---------------------------------------------------------------------------
# Scoring and streaks
# ---------------------------------------------------------------------------

func _apply_correct() -> void:
	_total_attempts += 1
	_correct_attempts += 1
	_streak += 1
	if _streak > _best_streak:
		_best_streak = _streak
	_push_recent(true)

	var new_combo: float = _rules.combo_for_streak(_streak)
	if not is_equal_approx(new_combo, _combo_multiplier):
		_combo_multiplier = new_combo
		combo_changed.emit(new_combo)
		if new_combo > 1.0 and _streak in _rules.combo_sound_streaks:
			_play_sfx("combo_up")

	var delta: int = _rules.points_for_correct(_streak)
	_score += delta
	score_changed.emit(_score, delta)
	streak_changed.emit(_streak)


func _apply_wrong() -> void:
	_total_attempts += 1
	_streak = 0
	_push_recent(false)
	if not is_equal_approx(_combo_multiplier, 1.0):
		_combo_multiplier = 1.0
		combo_changed.emit(1.0)
	streak_changed.emit(_streak)


func _push_recent(correct: bool) -> void:
	_recent_results.append(correct)
	if _recent_results.size() > RECENT_WINDOW:
		_recent_results.remove_at(0)


func _recent_errors() -> int:
	var n: int = 0
	for r in _recent_results:
		if not r:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Problem lifecycle
# ---------------------------------------------------------------------------

func _spawn_next_problem() -> void:
	if _state != State.PLAYING:
		return
	_spawn_delay_s = 0.0

	var enabled_keys: PackedStringArray = _enabled_skills()
	if enabled_keys.is_empty():
		push_warning("GameController: no enabled skills; cannot spawn.")
		return

	var skill_key: String = _skill_model.choose_next(enabled_keys, _rng)
	var problem: Dictionary = ProblemGenerator.generate(skill_key, _rng)
	if problem.is_empty():
		push_warning("GameController: generator returned empty problem for '%s'" % skill_key)
		return

	_problem_counter += 1
	problem["id"] = _problem_counter
	_current_problem = problem
	_current_problem_shown_at_ms = Time.get_ticks_msec()

	var speed: float = _speed_for_current_state(enabled_keys)
	spawn_requested.emit(problem, speed)

	if _emit_side_effects:
		EventBus.problem_spawned.emit(
			int(problem["id"]),
			String(problem["skill_key"]),
			String(problem["expression"]),
			problem["choices"],
			int(problem["correct_index"])
		)


func _speed_for_current_state(enabled_keys: PackedStringArray) -> float:
	var preset: String = String(_config.get("speed_preset", "adaptive"))
	if SPEED_PRESET_MULTIPLIERS.has(preset):
		return DifficultyController.BASE_SPEED_PX_S * float(SPEED_PRESET_MULTIPLIERS[preset])
	# "adaptive" (or unknown preset) → use the rating/streak/error-aware controller.
	var avg_rating: float = _skill_model.average_rating(enabled_keys)
	return DifficultyController.speed_for(avg_rating, _streak, _recent_errors())


func _enabled_skills() -> PackedStringArray:
	var raw: Variant = _config.get("enabled_skills", [])
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		return PackedStringArray(raw)
	return PackedStringArray()


func _log_and_update_skill(
	problem: Dictionary,
	chosen_index: int,
	reaction_ms: int,
	resolved_at_ms: int,
	is_correct: bool
) -> void:
	if _attempt_logger != null:
		_attempt_logger.log_attempt(
			problem, chosen_index, reaction_ms,
			_current_problem_shown_at_ms, resolved_at_ms
		)
	_skill_model.on_attempt(
		String(problem.get("skill_key", "")),
		float(problem.get("difficulty", 1000.0)),
		is_correct,
		reaction_ms
	)
	if _emit_side_effects:
		EventBus.answer_chosen.emit(
			int(problem.get("id", 0)), chosen_index, is_correct, reaction_ms
		)


# ---------------------------------------------------------------------------
# DB
# ---------------------------------------------------------------------------

func _open_session() -> int:
	if not DbGuard.writable(_db):
		return 0
	var started_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var config_json: String = JSON.stringify(_config)
	var id: int = SessionsDao.insert(_db, _profile_id, started_ms, config_json)
	if _attempt_logger != null:
		_attempt_logger = AttemptLogger.new(id, _db)
	return id


func _close_session(summary: Dictionary) -> void:
	if _session_id <= 0 or not DbGuard.writable(_db):
		return
	var ended_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var duration_ms: int = _duration_total_s * 1000
	SessionsDao.close_session(
		_db, _session_id,
		ended_ms, duration_ms,
		int(summary.get("score", 0)),
		int(summary.get("best_streak", 0)),
		float(summary.get("accuracy", 0.0))
	)


## Deletes the open session row and its attempts (abort path).
func _discard_session() -> void:
	if _session_id <= 0 or not DbGuard.writable(_db):
		return
	AttemptsDao.delete_for_session(_db, _session_id)
	SessionsDao.delete(_db, _session_id)


# ---------------------------------------------------------------------------
# Feedback helpers
# ---------------------------------------------------------------------------

func _emit_countdown(remaining: int) -> void:
	_countdown_last_announced = remaining
	countdown_tick.emit(remaining)


func _maybe_tick_sfx() -> void:
	var secs_left: int = int(ceil(_duration_remaining_s))
	if secs_left <= 0 or secs_left > TICK_SFX_LAST_SECONDS:
		return
	if _tick_announced_seconds.has(secs_left):
		return
	_tick_announced_seconds[secs_left] = true
	_play_sfx("tick")


func _play_sfx(key: String) -> void:
	if not _emit_side_effects:
		return
	AudioManager.play_sfx(key)


## Theme-aware multi-SFX delegate used by `_apply_correct`. Skips when
## headless (no DB) so unit tests don't need AudioManager.
func _play_sfx_chain(chain: Array) -> void:
	if not _emit_side_effects:
		return
	AudioManager.play_sfx_chain(chain)


func _pulse_haptics(pattern: int) -> void:
	if not _emit_side_effects:
		return
	HapticsManager.pulse(pattern)
