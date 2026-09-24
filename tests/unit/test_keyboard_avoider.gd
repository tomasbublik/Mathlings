## GUT unit tests for KeyboardAvoider.compute_shift.
## Pure function — no scene tree, no virtual keyboard required.

extends GutTest

const M: float = KeyboardAvoider.MARGIN


func test_no_shift_when_content_is_above_keyboard() -> void:
	assert_eq(KeyboardAvoider.compute_shift(100.0, 300.0, 400.0), 0.0)


func test_no_shift_when_keyboard_closed() -> void:
	# Closed keyboard ⇒ kb_top at the bottom edge of a 720-tall viewport.
	assert_eq(KeyboardAvoider.compute_shift(330.0, 520.0, 720.0), 0.0)


func test_shifts_just_enough_to_clear_keyboard() -> void:
	# Bottom at 520 must end MARGIN above kb_top 360 ⇒ move by 160 + M.
	assert_eq(KeyboardAvoider.compute_shift(330.0, 520.0, 360.0), 160.0 + M)


func test_tall_content_pins_top_to_margin() -> void:
	# 500-tall span cannot fit above a keyboard at 300: keep its top visible.
	assert_eq(KeyboardAvoider.compute_shift(200.0, 700.0, 300.0), 200.0 - M)


func test_never_returns_negative_shift() -> void:
	# Content already hugging the top edge and still overlapping.
	assert_eq(KeyboardAvoider.compute_shift(5.0, 500.0, 300.0), 0.0)
