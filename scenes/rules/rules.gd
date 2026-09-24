extends Control
## Scoring rules screen — read-only view of the currently loaded ScoringRules.
##
## The body text is generated at runtime from `ScoringRules.to_human_readable_text()`
## so editing `assets/rules/scoring_rules.json` immediately propagates here on
## the next scene load — no recompile, no string drift between gameplay and the
## help screen.
##
## Reference: specs/P17_external_rules.md, DESIGN §10 (UI patterns).

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

@onready var _background: TextureRect = $Background
@onready var _body_label: RichTextLabel = %BodyLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_apply_theme()
	_back_button.pressed.connect(_on_back)
	_body_label.text = ScoringRules.load_default().to_human_readable_text()


## Mirrors the theme on every scene so background art stays consistent across
## navigations.
func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
