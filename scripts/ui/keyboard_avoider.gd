class_name KeyboardAvoider
extends Node
## Slides `target` upwards while the on-screen keyboard is open so that
## `keep_visible` (typically the input + its confirm button) stays above it.
##
## Godot on Android does not resize the window when the soft keyboard
## appears, so in landscape the keyboard covers the lower ~half of the
## screen — including any centred text field. Drop this node into a scene,
## point it at the content container and the controls that must stay
## readable, and it handles the rest.
##
## The offset maths lives in the pure `compute_shift` so it can be
## unit-tested without a device.

## Gap (canvas units) kept between the keyboard / screen top and the content.
const MARGIN: float = 16.0

## How quickly the content follows the keyboard (higher = snappier).
const FOLLOW_SPEED: float = 14.0

## Control that gets moved up. Must not be a child of a Container, or the
## container would immediately undo the offset.
@export var target: Control

## Control whose rect must end up above the keyboard. Defaults to `target`.
@export var keep_visible: Control

var _base_y: float = 0.0
var _shift: float = 0.0


func _ready() -> void:
	if keep_visible == null:
		keep_visible = target
	if target != null:
		_base_y = target.position.y


func _process(delta: float) -> void:
	if target == null or not keep_visible.is_visible_in_tree():
		return
	var desired := _desired_shift()
	if is_zero_approx(desired) and is_zero_approx(_shift):
		# Keyboard closed and at rest — re-sync with any layout change
		# (e.g. rotation re-evaluating anchors).
		_base_y = target.position.y
		return
	_shift = lerpf(_shift, desired, minf(1.0, delta * FOLLOW_SPEED))
	if absf(_shift - desired) < 0.5:
		_shift = desired
	target.position.y = _base_y - _shift


func _desired_shift() -> float:
	var kb_px: int = DisplayServer.virtual_keyboard_get_height()
	if kb_px <= 0:
		return 0.0
	var view_h: float = get_viewport().get_visible_rect().size.y
	var window_h: float = float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	# Keyboard height is reported in physical pixels; the UI lives in
	# stretched canvas units.
	var kb_top: float = view_h - kb_px * (view_h / window_h)
	# Rect as it would be without our current shift applied.
	var rect := keep_visible.get_global_rect()
	return compute_shift(rect.position.y + _shift, rect.end.y + _shift, kb_top)


## Returns how far (canvas units, >= 0) content must move up so the span
## [rect_top, rect_bottom] sits above `kb_top`. If the span is taller than
## the space left, its top is pinned to MARGIN instead — the first field
## stays readable and the rest tucks under the keyboard.
static func compute_shift(rect_top: float, rect_bottom: float, kb_top: float) -> float:
	var needed := rect_bottom + MARGIN - kb_top
	if needed <= 0.0:
		return 0.0
	var max_allowed := maxf(0.0, rect_top - MARGIN)
	return minf(needed, max_allowed)
