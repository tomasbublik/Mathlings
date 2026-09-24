extends Control
## Results screen — shown after a round ends.
## Reads `GameState.last_result` (Dictionary payload) and presents a
## celebratory card: score count-up, stars popping in one by one, accuracy +
## best-streak tiles and reward cards for new unlocks, with a confetti burst.
## Reference: DESIGN §10.3, specs/P8c_results_screen.md

const GAME_SCENE: String = "res://scenes/game/game.tscn"
const STATS_SCENE: String = "res://scenes/stats/stats.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const UNLOCK_TOAST_SCENE: PackedScene = preload("res://scenes/results/unlock_toast.tscn")
const STAR_FULL: Texture2D = preload("res://scenes/results/icons/star_full.svg")

const COUNT_UP_S: float = 1.0
const STARS_START_S: float = 0.35
const STAR_STEP_S: float = 0.35
const CONFETTI_COLORS: Array[Color] = [
	Palette.SUNNY, Palette.PINK, Palette.SKY, Palette.MINT, Palette.GRAPE, Palette.CORAL,
]

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _title: Label = %TitleLabel
@onready var _card: PanelContainer = %Card
@onready var _body: BoxContainer = %Body
@onready var _buttons: BoxContainer = %Buttons
@onready var _score_label: Label = %ScoreLabel
@onready var _points_caption: Label = %PointsCaption
@onready var _stars: Array[TextureRect] = [
	$Margin/Layout/Card/Body/ScoreColumn/Stars/Star1,
	$Margin/Layout/Card/Body/ScoreColumn/Stars/Star2,
	$Margin/Layout/Card/Body/ScoreColumn/Stars/Star3,
]
@onready var _accuracy_tile: PanelContainer = %AccuracyTile
@onready var _streak_tile: PanelContainer = %StreakTile
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _unlocks_container: VBoxContainer = %UnlocksContainer
@onready var _placeholder_notice: Label = %PlaceholderNotice
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _stats_button: Button = %StatsButton
@onready var _menu_button: Button = %MenuButton
@onready var _toast: Label = %Toast


func _ready() -> void:
	_play_again_button.pressed.connect(_on_play_again)
	_stats_button.pressed.connect(_on_stats)
	_menu_button.pressed.connect(_on_menu)

	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg

	_play_again_button.text = tr("RESULTS_PLAY_AGAIN")
	_stats_button.text = tr("RESULTS_STATS_BUTTON")
	_menu_button.text = tr("RESULTS_MENU_BUTTON")
	_points_caption.text = tr("RESULTS_POINTS")
	(_accuracy_tile.get_node("Row/Text/Caption") as Label).text = tr("RESULTS_TILE_ACCURACY")
	(_streak_tile.get_node("Row/Text/Caption") as Label).text = tr("RESULTS_TILE_BEST_STREAK")

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

	var result: Dictionary = GameState.last_result
	if result.is_empty():
		_render_placeholder()
	else:
		_render_result(result)

	_animate_entrance()
	AudioManager.play_sfx("round_end")


## Landscape: score column beside the stats column, buttons in a row.
## Portrait: everything stacked, buttons full-width, and the whole layout
## scaled up — the 1280×720 "expand" stretch gives portrait phones a tall
## 1280-wide canvas on which unscaled UI looks tiny.
func _update_layout() -> void:
	var size := get_viewport_rect().size
	var portrait := size.y > size.x
	var k := HudFormat.ui_scale(size)
	# Orientation first: the margin's size is clamped to its minimum, which
	# depends on whether the body is stacked.
	_body.vertical = portrait
	_buttons.vertical = portrait
	_card.size_flags_horizontal = Control.SIZE_FILL if portrait else Control.SIZE_SHRINK_CENTER
	_margin.anchor_right = 0.0
	_margin.anchor_bottom = 0.0
	_margin.offset_left = 0.0
	_margin.offset_top = 0.0
	_margin.offset_right = size.x / k
	_margin.offset_bottom = size.y / k
	_margin.scale = Vector2(k, k)
	# Minimum sizes refresh lazily after an orientation flip; re-apply once
	# they have settled so a stale (wider) minimum doesn't clamp the rect.
	_margin.set_deferred("offset_right", size.x / k)
	_margin.set_deferred("offset_bottom", size.y / k)


func _render_placeholder() -> void:
	_placeholder_notice.visible = true
	_placeholder_notice.text = tr("RESULTS_PLACEHOLDER_NOTICE")
	_title.text = tr("RESULTS_TITLE_GOOD")
	_score_label.text = "0"
	_accuracy_label.text = "—"
	_streak_label.text = "—"


func _render_result(result: Dictionary) -> void:
	_placeholder_notice.visible = false

	var score: int = int(result.get("score", 0))
	var accuracy: float = float(result.get("accuracy", 0.0))
	var best_streak: int = int(result.get("best_streak", 0))
	var unlocks: Array = result.get("new_unlocks", [])
	var stars := ResultsLogic.stars_for_accuracy(accuracy)

	_title.text = tr(ResultsLogic.title_key(stars))
	_accuracy_label.text = "%d %%" % ResultsLogic.accuracy_percent(accuracy)
	_streak_label.text = str(best_streak)

	_animate_score(score)
	_animate_stars(stars)
	_animate_unlocks(unlocks, STARS_START_S + STAR_STEP_S * 3.0 + 0.3)
	if stars >= 2:
		_burst_confetti.call_deferred()


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

## Title drops in, card and buttons rise + fade in, staggered.
func _animate_entrance() -> void:
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2(0.5, 0.5)
	_title.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.15)
	var delay := 0.08
	for c: Control in [_card, _buttons]:
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(delay)
		delay += 0.12
	var tiles: Array[Control] = [_accuracy_tile, _streak_tile]
	for i in range(tiles.size()):
		var t := tiles[i]
		t.modulate.a = 0.0
		tw.tween_property(t, "modulate:a", 1.0, 0.25).set_delay(0.5 + 0.12 * i)


func _animate_score(target: int) -> void:
	_score_label.text = "0"
	if target <= 0:
		return
	var tween := create_tween()
	tween.tween_method(_set_score_text, 0.0, float(target), COUNT_UP_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Landing bounce once the count-up finishes.
	tween.tween_callback(func() -> void:
		_score_label.pivot_offset = _score_label.size / 2.0)
	tween.tween_property(_score_label, "scale", Vector2(1.18, 1.18), 0.08)
	tween.tween_property(_score_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Tick sound once per ~0.1 s during count-up.
	for t in range(10):
		var tick_tween := create_tween()
		tick_tween.tween_interval(0.1 * t)
		tick_tween.tween_callback(func() -> void: AudioManager.play_sfx("tick"))


func _set_score_text(v: float) -> void:
	_score_label.text = str(int(round(v)))


## Empty star outlines are visible from the start; earned stars pop in one
## by one (swap to the gold texture + elastic scale, sound, haptic).
func _animate_stars(count: int) -> void:
	for i in range(mini(count, _stars.size())):
		var star := _stars[i]
		var last := i == count - 1
		var tween := create_tween()
		tween.tween_interval(STARS_START_S + STAR_STEP_S * i)
		tween.tween_callback(func() -> void:
			star.texture = STAR_FULL
			star.pivot_offset = star.size / 2.0
			star.scale = Vector2(0.2, 0.2)
			star.rotation_degrees = -25.0
			AudioManager.play_sfx("combo_up" if last else "correct")
			HapticsManager.pulse(
				HapticsManager.Pattern.MEDIUM if last else HapticsManager.Pattern.LIGHT))
		tween.tween_property(star, "scale", Vector2.ONE, 0.55) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(star, "rotation_degrees", 0.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_unlocks(unlocks: Array, start_delay: float) -> void:
	for child in _unlocks_container.get_children():
		child.queue_free()

	for i in range(unlocks.size()):
		var unlock: Dictionary = unlocks[i]
		var toast: UnlockToast = UNLOCK_TOAST_SCENE.instantiate()
		_unlocks_container.add_child(toast)
		toast.setup(unlock)
		toast.play_in(start_delay + i * 0.45)


## One-shot confetti rain from the top edge for good rounds.
func _burst_confetti() -> void:
	var size := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.z_index = 20
	p.position = Vector2(size.x / 2.0, -20.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0, 10.0)
	p.amount = 90
	p.lifetime = 3.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 14.0
	# Constant interpolation → each flake gets one solid palette colour.
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in range(CONFETTI_COLORS.size()):
		offsets.append(float(i) / CONFETTI_COLORS.size())
		colors.append(CONFETTI_COLORS[i])
	ramp.offsets = offsets
	ramp.colors = colors
	p.color_initial_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _on_play_again() -> void:
	if ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_show_toast(tr("RESULTS_COMING_SOON"))


func _on_stats() -> void:
	if ResourceLoader.exists(STATS_SCENE):
		get_tree().change_scene_to_file(STATS_SCENE)
	else:
		_show_toast(tr("RESULTS_COMING_SOON"))


func _on_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
