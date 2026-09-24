extends Label
class_name FloatingText
## "+10" sticker that pops up over a solved problem, floats upwards and fades.
## Callers set `global_position` to the problem's centre, then `setup()`.

func setup(display_text: String, color: Color, display_scale: float = 1.0) -> void:
	text = display_text
	add_theme_color_override("font_color", color)

	if not is_node_ready():
		await ready

	# Centre the label on the anchor point we were placed at.
	reset_size()
	position -= size / 2.0
	pivot_offset = size / 2.0
	scale = Vector2(0.4, 0.4) * display_scale

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * display_scale, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", position.y - 90.0 * display_scale, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.45) \
		.set_delay(0.45)
	tween.tween_callback(queue_free)
