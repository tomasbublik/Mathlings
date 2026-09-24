extends Label
class_name FloatingText

func setup(display_text: String, color: Color) -> void:
	text = display_text
	add_theme_color_override("font_color", color)

	if not is_node_ready():
		await ready

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 60.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
