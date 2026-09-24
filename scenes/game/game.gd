extends Node2D
## Game scene — owns the FallingProblem instances, HUD, answer buttons, and
## drives a `GameController` per frame. The controller stays engine-agnostic;
## this scene handles rendering, input, and navigation.
## Reference: DESIGN §9, §10.2, specs/P10_game_controller.md

const FALLING_PROBLEM_SCENE: PackedScene = preload("res://scenes/game/falling_problem.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/game/vfx/floating_text.tscn")
const RESULTS_SCENE: String = "res://scenes/results/results.tscn"

@onready var _background: TextureRect = $Background
@onready var _score_label: Label = %ScoreLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _combo_badge: Label = %ComboBadge
@onready var _countdown_label: Label = %CountdownLabel
@onready var _countdown_overlay: CanvasLayer = %CountdownOverlay
@onready var _countdown_dim: ColorRect = $CountdownOverlay/Dim
@onready var _answer_bar: HBoxContainer = $HUD/AnswerBar
@onready var _answer_buttons: Array[Button] = [
	%AnswerButton1, %AnswerButton2, %AnswerButton3
]
@onready var _play_field: Node2D = %PlayField

var _controller: GameController
var _current_entity: FallingProblem = null
var _current_entity_shown_at_ms: int = 0
var _vertical_direction: int = 1
var _last_combo_multiplier: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_apply_theme()
	get_viewport().size_changed.connect(_update_screen_layout)
	_update_screen_layout()
	AudioManager.play_music(ThemeManager.current_game_music_key())
	_controller = _build_controller()
	_wire_controller_signals()
	_wire_answer_buttons()
	_combo_badge.visible = false
	_countdown_overlay.visible = false
	_update_hud(0, 0, 0.0)

	_controller.start()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg
	# Skins (texture + splash colour) are picked per-spawn via ThemeManager;
	# we only cache the falling direction here because every entity needs it.
	_vertical_direction = ThemeManager.current_vertical_direction()


func _update_screen_layout() -> void:
	var size := get_viewport_rect().size
	_resize_fullscreen_control(_background, size)
	_resize_fullscreen_control(_countdown_dim, size)

	var portrait := size.y > size.x
	_answer_bar.offset_left = 24.0 if portrait else 64.0
	_answer_bar.offset_right = -24.0 if portrait else -64.0
	_answer_bar.offset_top = -132.0 if portrait else -150.0
	_answer_bar.offset_bottom = -24.0 if portrait else -32.0
	for button in _answer_buttons:
		button.custom_minimum_size = Vector2(180, 92) if portrait else Vector2(260, 110)
		button.add_theme_font_size_override("font_size", 44 if portrait else 56)


func _resize_fullscreen_control(control: Control, size: Vector2) -> void:
	control.position = Vector2.ZERO
	control.set_deferred("size", size)


func _process(delta: float) -> void:
	if _controller == null:
		return
	_controller.tick(delta)
	if _controller.state() == GameController.State.PLAYING:
		_update_timer_label(_controller.time_remaining_s())
	if _controller.state() == GameController.State.RESULT:
		set_process(false)
		get_tree().change_scene_to_file(RESULTS_SCENE)


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _build_controller() -> GameController:
	var profile_id: int = ProfileService.active_id()
	var config: Dictionary = _snapshot_config()
	var skill_model := SkillModel.new(profile_id, DB)
	var logger := AttemptLogger.new(-1, DB)  # real session_id set when round starts
	var diff := DifficultyController.new()
	return GameController.new(profile_id, config, DB, skill_model, logger, diff)


func _snapshot_config() -> Dictionary:
	return {
		"duration_s": int(SettingsStore.get_value("round/duration_s", 120)),
		"speed_preset": String(SettingsStore.get_value("round/speed_preset", "adaptive")),
		"enabled_skills": SettingsStore.get_value("skills/enabled", []),
	}


func _wire_controller_signals() -> void:
	_controller.spawn_requested.connect(_on_spawn_requested)
	_controller.answer_resolved.connect(_on_answer_resolved)
	_controller.score_changed.connect(_on_score_changed)
	_controller.streak_changed.connect(_on_streak_changed)
	_controller.combo_changed.connect(_on_combo_changed)
	_controller.countdown_tick.connect(_on_countdown_tick)
	_controller.state_changed.connect(_on_state_changed)
	_controller.problem_missed.connect(_on_problem_missed)


func _wire_answer_buttons() -> void:
	for i in range(_answer_buttons.size()):
		var idx := i
		_answer_buttons[i].pressed.connect(func() -> void: _on_answer_pressed(idx))
		_answer_buttons[i].disabled = true


# ---------------------------------------------------------------------------
# Controller callbacks
# ---------------------------------------------------------------------------

func _on_spawn_requested(problem: Dictionary, speed: float) -> void:
	var entity: FallingProblem = FALLING_PROBLEM_SCENE.instantiate()
	_play_field.add_child(entity)
	var viewport_w: float = get_viewport_rect().size.x
	var viewport_h: float = get_viewport_rect().size.y
	var margin: float = 160.0
	entity.floor_y = viewport_h - 200.0 if _vertical_direction > 0 else -120.0
	entity.position = Vector2(
		_rng.randf_range(margin, viewport_w - margin),
		-100.0 if _vertical_direction > 0 else viewport_h + 120.0)

	# Per-spawn skin lookup keeps every round visually varied and lets each
	# fruit's unique splash colour reach the explosion VFX.
	var skin := ThemeManager.random_skin_for_current(_rng)
	entity.set_splash_color(skin.get("splash", FallingProblem.DEFAULT_SPLASH_COLOR) as Color)
	entity.setup(problem, speed, skin.get("texture", null) as Texture2D, _vertical_direction)
	entity.landed.connect(_on_entity_landed)
	_current_entity = entity

	_populate_answer_buttons(problem["choices"])
	_enable_answers(true)


func _on_entity_landed(problem_id: int) -> void:
	_controller.on_miss(problem_id)


func _on_answer_pressed(index: int) -> void:
	_enable_answers(false)
	var elapsed: int = Time.get_ticks_msec() - _current_entity_shown_at_ms
	_controller.on_answer(index, elapsed)


func _on_answer_resolved(_problem_id: int, correct: bool, _chosen_index: int) -> void:
	if _current_entity == null:
		return
	if correct:
		_spawn_score_floating_text(_current_entity.global_position)
		_current_entity.explode_correct()
	else:
		_current_entity.explode_wrong()
	_current_entity = null


func _spawn_score_floating_text(pos: Vector2) -> void:
	var delta_points: int = int(round(float(GameController.BASE_POINTS) * _last_combo_multiplier))
	var text: String
	var color := Color(1, 0.95, 0.4)
	if _last_combo_multiplier > 1.0:
		text = "+%d (%.2fx)" % [delta_points, _last_combo_multiplier]
		color = Color(1, 0.6, 0.2)
	else:
		text = "+%d" % delta_points
	var ft: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	_play_field.add_child(ft)
	ft.global_position = pos
	ft.setup(text, color)


func _on_problem_missed(_problem_id: int) -> void:
	# The entity has already invoked `splash()` via its own landing logic.
	_current_entity = null


func _on_score_changed(new_score: int, _delta: int) -> void:
	_score_label.text = tr("GAME_SCORE_PREFIX") % new_score


func _on_streak_changed(new_streak: int) -> void:
	if new_streak <= 1:
		_streak_label.text = ""
	else:
		_streak_label.text = tr("GAME_STREAK_PREFIX") % new_streak


func _on_combo_changed(multiplier: float) -> void:
	_last_combo_multiplier = multiplier
	if is_equal_approx(multiplier, 1.0):
		_combo_badge.visible = false
	else:
		_combo_badge.visible = true
		_combo_badge.text = "x%.2f" % multiplier


func _on_countdown_tick(remaining_s: int) -> void:
	_countdown_overlay.visible = remaining_s > 0
	if remaining_s > 0:
		_countdown_label.text = str(remaining_s)
	else:
		_countdown_label.text = tr("GAME_COUNTDOWN_GO")
		var tween := create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(_countdown_overlay, "visible", false, 0.0)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameController.State.PLAYING:
			_countdown_overlay.visible = false
		GameController.State.ENDING:
			_enable_answers(false)
		_:
			pass


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _populate_answer_buttons(choices: Array) -> void:
	_current_entity_shown_at_ms = Time.get_ticks_msec()
	for i in range(_answer_buttons.size()):
		if i < choices.size():
			_answer_buttons[i].text = str(choices[i])
			_answer_buttons[i].visible = true
		else:
			_answer_buttons[i].visible = false


func _enable_answers(on: bool) -> void:
	for b in _answer_buttons:
		b.disabled = not on


func _update_hud(score_val: int, streak_val: int, time_s: float) -> void:
	_score_label.text = tr("GAME_SCORE_PREFIX") % score_val
	if streak_val > 1:
		_streak_label.text = tr("GAME_STREAK_PREFIX") % streak_val
	else:
		_streak_label.text = ""
	_update_timer_label(time_s)


func _update_timer_label(time_s: float) -> void:
	var secs: int = max(0, int(ceil(time_s)))
	var m: int = secs / 60
	var s: int = secs % 60
	_timer_label.text = tr("GAME_TIMER_PREFIX") % [m, s]
