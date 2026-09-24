class_name UnlockToast
extends PanelContainer
## Reward card for a newly earned unlock on the Results screen: gift icon,
## "New reward!" caption and the unlock's name on a white card with a sunny
## rim. Hidden until `play_in()` pops it in with a wiggle, sound and haptic.
## Reference: specs/P14_badges.md


func setup(unlock: Dictionary) -> void:
	if not is_node_ready():
		await ready
	$HBox/Text/Caption.text = tr("RESULTS_UNLOCK_NEW")
	$HBox/Text/Label.text = UnlockSystem.display_name(unlock)


func _ready() -> void:
	modulate.a = 0.0


## Pops the card in after `delay` seconds.
func play_in(delay: float) -> void:
	var icon: Control = $HBox/Icon
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		pivot_offset = size / 2.0
		scale = Vector2(0.6, 0.6)
		icon.pivot_offset = icon.size / 2.0
		AudioManager.play_sfx("unlock")
		HapticsManager.pulse(HapticsManager.Pattern.SUCCESS))
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "rotation_degrees", -14.0, 0.1)
	tw.tween_property(icon, "rotation_degrees", 12.0, 0.12)
	tw.tween_property(icon, "rotation_degrees", 0.0, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
