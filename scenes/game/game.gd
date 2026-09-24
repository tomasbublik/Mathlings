extends Node2D
## Game scene — owns the FallingProblem instances, HUD, answer buttons, and
## drives a `GameController` per frame. The controller stays engine-agnostic;
## this scene handles rendering, input, and navigation.
## Reference: DESIGN §9, §10.2, specs/P10_game_controller.md
##
## Look & feel: HUD values live in white "pill" chips (HudChip), answer
## buttons are per-slot candy buttons (AnswerButtonStyle) that flash mint /
## coral on the outcome. The controller already fires the SUCCESS / ERROR
## haptics and correct / wrong sounds, so the answer buttons opt out of the
## global UiFeedback (`ui_feedback_off`) and are animated here instead.

const FALLING_PROBLEM_SCENE: PackedScene = preload("res://scenes/game/falling_problem.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/game/vfx/floating_text.tscn")
const RESULTS_SCENE: String = "res://scenes/results/results.tscn"

## Pastel blend used for the "?" placeholder buttons before the first problem.
const PLACEHOLDER_BLEND: float = 0.45
## Combo badge colours per HudFormat.combo_tier().
const COMBO_FILLS: Array[Color] = [Palette.SUNNY, Palette.PINK, Palette.GRAPE]
const COMBO_EDGES: Array[Color] = [Palette.SUNNY_DARK, Palette.PINK_DARK, Palette.GRAPE_DARK]
const COMBO_TEXT: Array[Color] = [Palette.INK, Color.WHITE, Color.WHITE]

@onready var _background: TextureRect = $Background
@onready var _score_label: Label = %ScoreLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _score_chip: PanelContainer = %ScoreChip
@onready var _streak_chip: PanelContainer = %StreakChip
@onready var _timer_chip: PanelContainer = %TimerChip
@onready var _combo_badge: PanelContainer = %ComboBadge
@onready var _combo_label: Label = %ComboLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _countdown_overlay: CanvasLayer = %CountdownOverlay
@onready var _countdown_dim: ColorRect = $CountdownOverlay/Dim
@onready var _answer_bar: HBoxContainer = $HUD/AnswerBar
@onready var _top_bar: HBoxContainer = $HUD/TopBar
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

var _round_duration_s: int = 120
var _shown_timer_secs: int = -1
var _timer_urgent: bool = false
var _last_streak: int = 0
## Answer button → running Tween (scale / shake / flash), so a new
## animation cleanly replaces the previous one.
var _button_tweens: Dictionary = {}
## HUD control → running pop Tween.
var _pop_tweens: Dictionary = {}
var _countdown_tween: Tween
## HUD / entity scale for the current screen shape (see HudFormat.ui_scale).
var _ui_scale: float = 1.0
var _floor_y: float = 520.0


func _ready() -> void:
	_rng.randomize()
	_apply_theme()
	get_viewport().size_changed.connect(_update_screen_layout)
	_update_screen_layout()
	AudioManager.play_music(ThemeManager.current_game_music_key())
	var config := _snapshot_config()
	_round_duration_s = int(config["duration_s"])
	_controller = _build_controller(config)
	_wire_controller_signals()
	_wire_answer_buttons()
	_combo_badge.visible = false
	_countdown_overlay.visible = false
	_update_hud(0, 0, float(_round_duration_s))

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

	# The project stretches canvas_items/expand from a 1280×720 base, so a
	# portrait phone gets a very tall 1280-wide canvas where everything looks
	# tiny. Scale the HUD rows up there instead of hand-tuning every size.
	var portrait := size.y > size.x
	_ui_scale = HudFormat.ui_scale(size)
	var k := _ui_scale
	var margin := 24.0 * k

	_top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_bar.scale = Vector2(k, k)
	_top_bar.position = Vector2(margin, 18.0 * k)
	_top_bar.size = Vector2((size.x - 2.0 * margin) / k, 60.0)

	# Chunky answer bar: full width on portrait phones, capped and centred on
	# wide screens so the three buttons stay thumb-sized rather than huge.
	var bar_h := 122.0
	var bar_w: float = (size.x - 2.0 * margin) / k if portrait else minf(size.x - 128.0, 1100.0)
	var bottom_gap: float = (36.0 if portrait else 24.0) * k
	for button in _answer_buttons:
		button.custom_minimum_size = Vector2(0, bar_h)
		button.add_theme_font_size_override("font_size", 64)
	_answer_bar.add_theme_constant_override("separation", 16 if portrait else 28)
	_answer_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_answer_bar.scale = Vector2(k, k)
	_answer_bar.size = Vector2(bar_w, bar_h)
	_answer_bar.position = Vector2((size.x - bar_w * k) / 2.0, size.y - bottom_gap - bar_h * k)
	# Unanswered problems land just above the answer bar.
	_floor_y = _answer_bar.position.y - 54.0 * k
	_combo_badge.scale = Vector2(k, k)
	_position_combo_badge.call_deferred()


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

func _build_controller(config: Dictionary) -> GameController:
	var profile_id: int = ProfileService.active_id()
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
		var b := _answer_buttons[i]
		# Animation lives here and haptics/sounds in the controller; the global
		# squish + tap would double up with the correct/wrong feedback.
		b.set_meta("ui_feedback_off", true)
		# Register on touch-down: snappier for a timed game.
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _on_answer_pressed(idx))
		b.disabled = true
		b.text = "?"
		_style_answer_placeholder(i)


# ---------------------------------------------------------------------------
# Controller callbacks
# ---------------------------------------------------------------------------

func _on_spawn_requested(problem: Dictionary, speed: float) -> void:
	var entity: FallingProblem = FALLING_PROBLEM_SCENE.instantiate()
	_play_field.add_child(entity)
	var viewport_w: float = get_viewport_rect().size.x
	var viewport_h: float = get_viewport_rect().size.y
	var margin: float = 160.0
	entity.floor_y = _floor_y if _vertical_direction > 0 else -120.0 * _ui_scale
	entity.position = Vector2(
		_rng.randf_range(margin, viewport_w - margin),
		-100.0 * _ui_scale if _vertical_direction > 0 else viewport_h + 120.0 * _ui_scale)
	entity.set_display_scale(_ui_scale)

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
	_squish_button(_answer_buttons[index])
	var elapsed: int = Time.get_ticks_msec() - _current_entity_shown_at_ms
	_controller.on_answer(index, elapsed)


func _on_answer_resolved(_problem_id: int, correct: bool, chosen_index: int) -> void:
	if chosen_index >= 0 and chosen_index < _answer_buttons.size():
		_play_answer_feedback(chosen_index, correct)
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
	var boosted := _last_combo_multiplier > 1.0
	var ft: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	_play_field.add_child(ft)
	ft.global_position = pos + Vector2(0, -70.0 * _ui_scale)
	ft.setup(HudFormat.points_text(delta_points, _last_combo_multiplier),
		Palette.SUNNY if boosted else Color.WHITE, _ui_scale)


func _on_problem_missed(_problem_id: int) -> void:
	# The entity has already invoked `splash()` via its own landing logic.
	_current_entity = null


func _on_score_changed(new_score: int, _delta: int) -> void:
	_score_label.text = str(new_score)
	_pop(_score_chip, 1.12)


func _on_streak_changed(new_streak: int) -> void:
	_streak_label.text = str(new_streak)
	if new_streak > _last_streak and new_streak >= 2:
		_pop(_streak_chip, 1.15)
	elif new_streak == 0 and _last_streak > 0:
		_pop(_streak_chip, 0.88)
	_last_streak = new_streak
	_position_combo_badge.call_deferred()


func _on_combo_changed(multiplier: float) -> void:
	_last_combo_multiplier = multiplier
	if multiplier <= 1.0 or is_equal_approx(multiplier, 1.0):
		_hide_combo_badge()
		return
	var tier := HudFormat.combo_tier(multiplier)
	var style := (_combo_badge.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = COMBO_FILLS[tier]
	style.border_color = COMBO_EDGES[tier]
	_combo_badge.add_theme_stylebox_override("panel", style)
	_combo_label.add_theme_color_override("font_color", COMBO_TEXT[tier])
	_combo_label.text = HudFormat.combo_text(multiplier)
	_combo_badge.visible = true
	_combo_badge.reset_size()
	_position_combo_badge()
	_combo_badge.pivot_offset = _combo_badge.size / 2.0
	_combo_badge.scale = Vector2(0.2, 0.2) * _ui_scale
	_combo_badge.rotation_degrees = -30.0
	var tw := _replace_pop_tween(_combo_badge)
	tw.set_parallel(true)
	tw.tween_property(_combo_badge, "scale", Vector2.ONE * _ui_scale, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_combo_badge, "rotation_degrees", -8.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop(_streak_chip, 1.2)


func _hide_combo_badge() -> void:
	if not _combo_badge.visible:
		return
	var tw := _replace_pop_tween(_combo_badge)
	tw.tween_property(_combo_badge, "scale", Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _combo_badge.visible = false)


## Tucks the combo badge under the right edge of the streak chip like a
## sticker. Called whenever the chip may have moved or resized.
func _position_combo_badge() -> void:
	if not is_instance_valid(_combo_badge) or not _combo_badge.visible:
		return
	# Layout-space position (ignores the chip's own pop scale).
	var k := _ui_scale
	var chip_pos: Vector2 = _top_bar.position \
		+ (_streak_chip.get_parent() as Control).position * k + _streak_chip.position * k
	_combo_badge.position = Vector2(
		chip_pos.x + (_streak_chip.size.x - _combo_badge.size.x * 0.45) * k,
		chip_pos.y + (_streak_chip.size.y - 10.0) * k)


func _on_countdown_tick(remaining_s: int) -> void:
	_countdown_overlay.visible = true
	var label := _countdown_label
	label.pivot_offset = label.size / 2.0
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	label.modulate.a = 1.0
	if remaining_s > 0:
		label.text = str(remaining_s)
		label.remove_theme_color_override("font_color")
		label.scale = Vector2(0.2, 0.2)
		label.rotation_degrees = -12.0 if remaining_s % 2 == 1 else 12.0
		_countdown_tween.set_parallel(true)
		_countdown_tween.tween_property(label, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_countdown_tween.tween_property(label, "rotation_degrees", 0.0, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		HapticsManager.pulse(HapticsManager.Pattern.LIGHT)
	else:
		label.text = tr("GAME_COUNTDOWN_GO")
		label.add_theme_color_override("font_color", Palette.SUNNY)
		label.scale = Vector2(0.3, 0.3)
		label.rotation_degrees = -6.0
		_countdown_tween.tween_property(label, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_countdown_tween.tween_interval(0.25)
		_countdown_tween.tween_property(label, "scale", Vector2(1.6, 1.6), 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_countdown_tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25)
		_countdown_tween.tween_callback(func() -> void: _countdown_overlay.visible = false)
		HapticsManager.pulse(HapticsManager.Pattern.MEDIUM)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameController.State.ENDING:
			_enable_answers(false)
			_set_timer_urgent(false)
		_:
			pass


# ---------------------------------------------------------------------------
# Answer buttons
# ---------------------------------------------------------------------------

func _style_answer_slot(i: int) -> StyleBoxFlat:
	var n := Palette.ANSWER_COLORS.size()
	return AnswerButtonStyle.apply(_answer_buttons[i],
		Palette.ANSWER_COLORS[i % n], Palette.ANSWER_EDGES[i % n])


## Soft pastel version of the slot colour with a white "?" — reads as
## "get ready", not as a broken grey button.
func _style_answer_placeholder(i: int) -> void:
	var n := Palette.ANSWER_COLORS.size()
	var fill := Palette.ANSWER_COLORS[i % n].lerp(Color.WHITE, PLACEHOLDER_BLEND)
	var edge := Palette.ANSWER_EDGES[i % n].lerp(Color.WHITE, PLACEHOLDER_BLEND * 0.6)
	AnswerButtonStyle.apply(_answer_buttons[i], fill, edge, Color.WHITE, edge)
	_answer_buttons[i].set_meta("placeholder", true)


func _populate_answer_buttons(choices: Array) -> void:
	_current_entity_shown_at_ms = Time.get_ticks_msec()
	for i in range(_answer_buttons.size()):
		var b := _answer_buttons[i]
		if i < choices.size():
			b.text = str(choices[i])
			b.visible = true
			if b.get_meta("placeholder", false):
				b.set_meta("placeholder", false)
				_style_answer_slot(i)
				_pop_button_in(b, i)
		else:
			b.visible = false


func _enable_answers(on: bool) -> void:
	for b in _answer_buttons:
		b.disabled = not on


func _replace_button_tween(b: Button) -> Tween:
	var old: Tween = _button_tweens.get(b)
	if old != null and old.is_valid():
		old.kill()
	# An interrupted mint/coral flash must not leave the button recoloured
	# or shaken off its slot.
	if b.has_meta("flash_slot"):
		if b.has_meta("shake_base_x"):
			b.position.x = float(b.get_meta("shake_base_x"))
			b.remove_meta("shake_base_x")
		var slot := int(b.get_meta("flash_slot"))
		b.remove_meta("flash_slot")
		_style_answer_slot(slot)
	b.pivot_offset = b.size / 2.0
	var tw := b.create_tween()
	_button_tweens[b] = tw
	return tw


func _squish_button(b: Button) -> void:
	var tw := _replace_button_tween(b)
	tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_button_in(b: Button, i: int) -> void:
	var tw := _replace_button_tween(b)
	b.scale = Vector2(0.6, 0.6)
	tw.tween_interval(0.06 * i)
	tw.tween_property(b, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Correct → mint flash + bouncy pop. Wrong → coral flash + head-shake.
## The slot colour fades back in afterwards.
func _play_answer_feedback(i: int, correct: bool) -> void:
	var b := _answer_buttons[i]
	var n := Palette.ANSWER_COLORS.size()
	var tw := _replace_button_tween(b)
	var face := AnswerButtonStyle.apply(b,
		Palette.MINT if correct else Palette.CORAL,
		Palette.MINT_DARK if correct else Palette.CORAL_DARK)
	b.set_meta("flash_slot", i)
	if correct:
		b.scale = Vector2(0.9, 0.9)
		tw.tween_property(b, "scale", Vector2(1.14, 1.14), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b.scale = Vector2.ONE
		var base_x := b.position.x
		b.set_meta("shake_base_x", base_x)
		tw.tween_method(func(t: float) -> void:
			b.position.x = base_x + sin(t * TAU * 3.0) * 16.0 * (1.0 - t), 0.0, 1.0, 0.4)
		tw.tween_callback(func() -> void:
			b.position.x = base_x
			b.remove_meta("shake_base_x"))
	# Fade the flash back to the slot colour.
	tw.tween_property(face, "bg_color", Palette.ANSWER_COLORS[i % n], 0.25)
	tw.parallel().tween_property(face, "border_color", Palette.ANSWER_EDGES[i % n], 0.25)
	tw.tween_callback(func() -> void:
		b.remove_meta("flash_slot")
		_style_answer_slot(i))


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _replace_pop_tween(c: Control) -> Tween:
	var old: Tween = _pop_tweens.get(c)
	if old != null and old.is_valid():
		old.kill()
	var tw := c.create_tween()
	_pop_tweens[c] = tw
	return tw


## Quick scale bounce on a HUD chip (peak > 1 = celebrate, < 1 = deflate).
func _pop(c: Control, peak: float) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := _replace_pop_tween(c)
	tw.tween_property(c, "scale", Vector2(peak, peak), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_hud(score_val: int, streak_val: int, time_s: float) -> void:
	_score_label.text = str(score_val)
	_streak_label.text = str(streak_val)
	_last_streak = streak_val
	_update_timer_label(time_s)


func _update_timer_label(time_s: float) -> void:
	var secs := HudFormat.timer_seconds(time_s)
	if secs == _shown_timer_secs:
		return
	_shown_timer_secs = secs
	_timer_label.text = HudFormat.timer_text(secs)
	var urgent := HudFormat.is_urgent(secs) \
		and _controller != null and _controller.state() == GameController.State.PLAYING
	_set_timer_urgent(urgent)
	if urgent:
		_pop(_timer_chip, 1.15)


## Final seconds: the timer chip turns coral with white text and pulses once
## per second (see `_update_timer_label`).
func _set_timer_urgent(on: bool) -> void:
	if on == _timer_urgent:
		return
	_timer_urgent = on
	if on:
		var style := (_timer_chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.bg_color = Palette.CORAL
		style.border_color = Palette.CORAL_DARK
		_timer_chip.add_theme_stylebox_override("panel", style)
		_timer_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_timer_chip.remove_theme_stylebox_override("panel")
		_timer_label.remove_theme_color_override("font_color")
