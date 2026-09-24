extends Control
## First-run / on-launch profile picker.
##
## Two presentations rolled into one scene to keep the navigation surface
## small:
##   • If at least one profile exists, render a list of "Pick player"
##     buttons; on selection set active and continue to Main Menu.
##   • If no profiles exist (truly first run), render a single "Vytvoř
##     prvního hráče" button that prompts for a name and creates the
##     profile inline.
##
## We never enter this scene with a valid active profile already set —
## Main Menu's _ready does that bypass.
##
## Reference: specs/P16_profiles.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

@onready var _background: TextureRect = $Background
@onready var _title_label: Label = %TitleLabel
@onready var _list_container: VBoxContainer = %ProfileList
@onready var _empty_box: VBoxContainer = %EmptyState
@onready var _empty_input: LineEdit = %EmptyNameInput
@onready var _empty_create_button: Button = %EmptyCreateButton
@onready var _toast: Label = %Toast


func _ready() -> void:
	_apply_theme()
	_empty_create_button.pressed.connect(_on_empty_create_pressed)
	_empty_input.text_submitted.connect(func(_t: String) -> void: _on_empty_create_pressed())
	get_viewport().size_changed.connect(_on_size_changed)
	_render()


func _on_size_changed() -> void:
	var btn_w := _responsive_button_width()
	_empty_input.custom_minimum_size.x = btn_w
	_empty_create_button.custom_minimum_size.x = btn_w
	for child in _list_container.get_children():
		(child as Button).custom_minimum_size.x = btn_w


func _responsive_button_width() -> int:
	var size := get_viewport_rect().size
	return int(size.x * 0.68) if size.y > size.x else 420


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

## Repaints the picker UI from the current ProfileService state. Cheap
## enough to call after every mutation; no incremental diffing required.
func _render() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	var btn_w := _responsive_button_width()
	_empty_input.custom_minimum_size.x = btn_w
	_empty_create_button.custom_minimum_size.x = btn_w

	var profiles: Array = ProfileService.list()
	if profiles.is_empty():
		_title_label.text = "Pojď, založ si svůj profil"
		_list_container.visible = false
		_empty_box.visible = true
		_empty_input.grab_focus()
		return

	_title_label.text = "Vyber svého hráče"
	_list_container.visible = true
	_empty_box.visible = false

	for profile: Dictionary in profiles:
		_list_container.add_child(_make_profile_button(profile))


## Builds a single big "pick me" button for the given profile row.
func _make_profile_button(profile: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = "👤  %s" % String(profile.get("name", "Hráč"))
	btn.custom_minimum_size = Vector2(_responsive_button_width(), 92)
	btn.add_theme_font_size_override("font_size", 32)
	btn.pressed.connect(_on_profile_chosen.bind(int(profile.get("id", 0))))
	return btn


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_profile_chosen(profile_id: int) -> void:
	if not ProfileService.set_active(profile_id):
		_show_toast("Profil nelze vybrat.")
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_empty_create_pressed() -> void:
	var name := _empty_input.text.strip_edges()
	if name == "":
		_show_toast("Zadej jméno.")
		return
	var new_id: int = ProfileService.create(name)
	if new_id <= 0:
		_show_toast("Profil nelze vytvořit.")
		return
	if not ProfileService.set_active(new_id):
		_show_toast("Profil vytvořen, ale nešel aktivovat.")
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ---------------------------------------------------------------------------
# Toast helper (mirrors main_menu's pattern so users see consistent feedback)
# ---------------------------------------------------------------------------

func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
