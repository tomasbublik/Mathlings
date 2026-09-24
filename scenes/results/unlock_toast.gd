class_name UnlockToast
extends PanelContainer
## Single-card visualization of a newly earned unlock on the Results screen.
## Animates in (slide + fade) on `_ready`, then remains until the scene exits.
## Reference: specs/P14_badges.md

const KIND_ICON: Dictionary = {
	"badge": "🏅",
	"skin":  "🎨",
	"theme": "🌄",
}


func setup(unlock: Dictionary) -> void:
	if not is_node_ready():
		await ready
	var kind: String = String(unlock.get("kind", ""))
	var label: String = String(unlock.get("label", unlock.get("key", "?")))
	$HBox/Icon.text = String(KIND_ICON.get(kind, "🏆"))
	$HBox/Label.text = "Odemkl jsi: %s" % label


func _ready() -> void:
	# Entry animation: slide up + fade in.
	modulate.a = 0.0
	var start_offset: float = position.y + 40.0
	position.y = start_offset
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(self, "position:y", start_offset - 40.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
