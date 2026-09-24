class_name PauseOverlay
extends CanvasLayer
## Pause menu shown over a paused round: scrim + white card with the
## thinking Mathling, "Paused", a big Continue and a quieter Quit round.
##
## Runs with PROCESS_MODE_ALWAYS so its buttons (and the UiFeedback squish
## tweens they create via `button.create_tween()`), the mascot's idle
## animation and the entrance tween keep working while the SceneTree is
## paused. The Game scene owns the actual pause / resume / quit logic and
## listens to `continue_requested` / `quit_requested`.
##
## Quit is a single tap on purpose: the menu only appears after a deliberate
## tap on the pause chip (or back / leaving the app), Quit is the smaller
## white button under the big sunny Continue, and a round lasts ~2 minutes —
## a second "are you sure?" step would cost more than an accidental quit.

signal continue_requested
signal quit_requested

const ENTER_TIME := 0.28

@onready var _root: Control = $Root
@onready var _scrim: ColorRect = $Root/Scrim
@onready var _card: PanelContainer = %Card
@onready var _mascot: Mascot = %Mascot
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _continue_button: Button = %ContinueButton
@onready var _quit_button: Button = %QuitButton

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_scrim.color = Palette.SCRIM
	# The default card is 95 % white, which reads grey over the scrim.
	var card_style := (_card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	card_style.bg_color = Palette.SURFACE
	card_style.content_margin_left = 40
	card_style.content_margin_right = 40
	_card.add_theme_stylebox_override("panel", card_style)
	_title.text = tr("GAME_PAUSE_TITLE")
	_hint.text = tr("GAME_PAUSE_HINT")
	_continue_button.text = tr("GAME_PAUSE_CONTINUE")
	_quit_button.text = tr("GAME_PAUSE_QUIT")
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_quit_button.pressed.connect(_on_quit_pressed)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func is_open() -> bool:
	return visible


## Shows the menu with a soft pop-in (card) and fade (scrim).
func open() -> void:
	if visible:
		return
	visible = true
	_continue_button.disabled = false
	_quit_button.disabled = false
	_mascot.set_mood(Mascot.MOOD_THINK)
	_update_layout()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_scrim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.85, 0.85)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_scrim, "modulate:a", 1.0, ENTER_TIME * 0.7)
	_tween.tween_property(_card, "modulate:a", 1.0, ENTER_TIME * 0.6)
	_tween.tween_property(_card, "scale", Vector2.ONE, ENTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_card.scale = Vector2.ONE
	_card.modulate.a = 1.0
	_scrim.modulate.a = 1.0
	visible = false


func _on_quit_pressed() -> void:
	# One quit per round: ignore a duplicate tap while the scene changes.
	_continue_button.disabled = true
	_quit_button.disabled = true
	quit_requested.emit()


## Portrait phones get a tall 1280-wide canvas; scale the whole overlay up
## like the HUD (HudFormat.ui_scale) so the card and buttons keep their
## physical size.
func _update_layout() -> void:
	var size := _root.get_viewport_rect().size
	var k := HudFormat.ui_scale(size)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = Vector2.ZERO
	_root.scale = Vector2(k, k)
	_root.size = size / k
	_card.pivot_offset = _card.size / 2.0
