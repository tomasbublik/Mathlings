extends Control
## Results screen — shown after a round ends.
## Reads `GameState.last_result` (Dictionary payload) and presents:
##   score (tween 0 → value), accuracy stars, best streak, new unlocks.
## Reference: DESIGN §10.3, specs/P8c_results_screen.md

const GAME_SCENE: String = "res://scenes/game/game.tscn"
const STATS_SCENE: String = "res://scenes/stats/stats.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const UNLOCK_TOAST_SCENE: PackedScene = preload("res://scenes/results/unlock_toast.tscn")

const STAR_EMPTY: String = "☆"
const STAR_FULL: String = "★"

@onready var _title: Label = %TitleLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _stars_label: Label = %StarsLabel
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

	var result: Dictionary = GameState.last_result
	if result.is_empty():
		_render_placeholder()
	else:
		_render_result(result)

	AudioManager.play_sfx("round_end")


func _render_placeholder() -> void:
	_placeholder_notice.visible = true
	_score_label.text = "0"
	_stars_label.text = STAR_EMPTY.repeat(3)
	_accuracy_label.text = "Přesnost: —"
	_streak_label.text = "Nejdelší série: —"


func _render_result(result: Dictionary) -> void:
	_placeholder_notice.visible = false

	var score: int = int(result.get("score", 0))
	var accuracy: float = float(result.get("accuracy", 0.0))
	var best_streak: int = int(result.get("best_streak", 0))
	var unlocks: Array = result.get("new_unlocks", [])

	_accuracy_label.text = "Přesnost: %d %%" % int(round(accuracy * 100.0))
	_streak_label.text = "Nejdelší série: %d 🔥" % best_streak

	_animate_score(score)
	_animate_stars(_stars_for_accuracy(accuracy))
	_animate_unlocks(unlocks)


func _animate_score(target: int) -> void:
	_score_label.text = "0"
	if target <= 0:
		return
	var tween := create_tween()
	tween.tween_method(_set_score_text, 0.0, float(target), 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Tick sound once per ~0.1 s during count-up.
	for t in range(10):
		var tick_tween := create_tween()
		tick_tween.tween_interval(0.1 * t)
		tick_tween.tween_callback(func() -> void: AudioManager.play_sfx("tick"))


func _set_score_text(v: float) -> void:
	_score_label.text = str(int(round(v)))


func _stars_for_accuracy(accuracy: float) -> int:
	if accuracy >= 0.85:
		return 3
	if accuracy >= 0.6:
		return 2
	if accuracy > 0.0:
		return 1
	return 0


func _animate_stars(count: int) -> void:
	_stars_label.text = ""
	_stars_label.modulate.a = 1.0
	for i in range(3):
		var delay := 0.3 + i * 0.15
		var index := i
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			var glyph: String = STAR_FULL if index < count else STAR_EMPTY
			_stars_label.text += glyph)


func _animate_unlocks(unlocks: Array) -> void:
	for child in _unlocks_container.get_children():
		child.queue_free()

	for i in range(unlocks.size()):
		var unlock: Dictionary = unlocks[i]
		var toast: UnlockToast = UNLOCK_TOAST_SCENE.instantiate()
		_unlocks_container.add_child(toast)
		toast.setup(unlock)
		toast.modulate.a = 0.0

		var tween := create_tween()
		tween.tween_interval(1.2 + i * 0.4)
		tween.tween_callback(func() -> void: AudioManager.play_sfx("unlock"))
		tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.3)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _on_play_again() -> void:
	if ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_show_toast("Brzy!")


func _on_stats() -> void:
	if ResourceLoader.exists(STATS_SCENE):
		get_tree().change_scene_to_file(STATS_SCENE)
	else:
		_show_toast("Brzy!")


func _on_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
