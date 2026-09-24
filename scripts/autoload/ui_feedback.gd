extends Node
## Gives every button in the game a tactile, "squishy" feel with no
## per-scene wiring: on press it shrinks slightly, plays a soft pop and a
## tiny haptic tick; on release it springs back with a little overshoot.
##
## Hooks any BaseButton as it enters the tree. Opt-outs via node metadata:
##   ui_feedback_off    = true  → no feedback at all (custom-animated buttons)
##   ui_feedback_silent = true  → animation + haptics, but no tap sound
##                                (e.g. answer buttons that play correct/wrong)

const PRESS_SCALE := Vector2(0.93, 0.93)
const PRESS_TIME := 0.06
const RELEASE_TIME := 0.22

var _tweens: Dictionary = {}  # instance_id → Tween


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# Deferred so metadata set right after instantiation is respected.
		_hook.call_deferred(node)


func _hook(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.get_meta("ui_feedback_off", false):
		return
	if button.button_down.is_connected(_on_down):
		return
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


func _on_down(button: BaseButton) -> void:
	if button.disabled:
		return
	_animate(button, PRESS_SCALE, PRESS_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)
	HapticsManager.pulse(HapticsManager.Pattern.TAP)
	if not button.get_meta("ui_feedback_silent", false):
		AudioManager.play_sfx("tap")


func _on_up(button: BaseButton) -> void:
	_animate(button, Vector2.ONE, RELEASE_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)


func _animate(button: BaseButton, target: Vector2, time: float,
		trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	var id := button.get_instance_id()
	var old: Tween = _tweens.get(id)
	if old != null and old.is_valid():
		old.kill()
	button.pivot_offset = button.size / 2.0
	var tw := button.create_tween()
	tw.tween_property(button, "scale", target, time).set_trans(trans).set_ease(ease)
	_tweens[id] = tw
	tw.finished.connect(func() -> void: _tweens.erase(id))
