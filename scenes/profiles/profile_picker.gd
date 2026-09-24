extends Control
## First-run / on-launch profile picker.
##
## Two presentations rolled into one scene to keep the navigation surface
## small:
##   • If at least one profile exists, render a row of avatar tiles; on
##     selection set active and continue to Main Menu. A "New player" tile
##     opens the profile manager.
##   • If no profiles exist (truly first run), render a friendly card that
##     asks for a name and creates the profile inline.
##
## We never enter this scene with a valid active profile already set —
## Main Menu's _ready does that bypass.
##
## Reference: specs/P16_profiles.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const PROFILES_SCENE: String = "res://scenes/profiles/profile_manager.tscn"
const TILE_SIZE := Vector2(220, 236)

@onready var _background: TextureRect = $Background
@onready var _title_label: Label = %TitleLabel
@onready var _list_container: HFlowContainer = %ProfileList
@onready var _empty_box: PanelContainer = %EmptyState
@onready var _empty_input: LineEdit = %EmptyNameInput
@onready var _empty_create_button: Button = %EmptyCreateButton
@onready var _toast_panel: PanelContainer = %ToastPanel
@onready var _toast: Label = %Toast


func _ready() -> void:
	_apply_theme()
	_empty_input.placeholder_text = tr("PROFILE_PICKER_NAME_PLACEHOLDER")
	_empty_create_button.pressed.connect(_on_empty_create_pressed)
	_empty_input.text_submitted.connect(func(_t: String) -> void: _on_empty_create_pressed())
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()
	_render()


func _on_size_changed() -> void:
	MenuKit.fit_portrait(self)


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

	var profiles: Array = ProfileService.list()
	if profiles.is_empty():
		_title_label.text = tr("PROFILE_PICKER_EMPTY_TITLE")
		_list_container.visible = false
		_empty_box.visible = true
		_empty_input.grab_focus()
		MenuKit.stagger_in([_title_label, _empty_box], 0.0, 0.08)
		return

	_title_label.text = tr("PROFILE_PICKER_TITLE")
	_list_container.visible = true
	_empty_box.visible = false

	for profile: Dictionary in profiles:
		_list_container.add_child(_make_profile_tile(profile))
	if profiles.size() < ProfileService.MAX_PROFILES:
		_list_container.add_child(_make_add_tile())
	var animated: Array = [_title_label]
	animated.append_array(_list_container.get_children())
	MenuKit.stagger_in(animated, 0.0, 0.05)


## Builds one big "pick me" tile: coloured avatar with the initial + name.
func _make_profile_tile(profile: Dictionary) -> Button:
	var profile_id := int(profile.get("id", 0))
	var player_name := String(profile.get("name", tr("COMMON_DEFAULT_PLAYER")))
	var btn := _make_tile()
	var box := btn.get_child(0) as VBoxContainer
	box.add_child(MenuKit.avatar(player_name, profile_id, 116))
	box.add_child(_tile_caption(player_name))
	btn.pressed.connect(_on_profile_chosen.bind(profile_id))
	return btn


## "+ New player" tile — opens the profile manager to add someone.
func _make_add_tile() -> Button:
	var btn := _make_tile()
	var box := btn.get_child(0) as VBoxContainer
	var plus := MenuKit.badge("+", "BadgeGrape", 116)
	var plus_label := plus.get_child(0) as Label
	plus_label.theme_type_variation = &"HeadingLabel"
	plus_label.add_theme_font_size_override("font_size", 64)
	plus_label.add_theme_color_override("font_color", Palette.GRAPE)
	box.add_child(plus)
	var caption := _tile_caption(tr("PROFILE_PICKER_ADD_TILE"))
	caption.add_theme_color_override("font_color", Palette.GRAPE)
	box.add_child(caption)
	btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(PROFILES_SCENE))
	return btn


func _make_tile() -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"TileButton"
	btn.custom_minimum_size = TILE_SIZE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -Palette.EDGE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)
	return btn


func _tile_caption(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.add_theme_font_size_override("font_size", Palette.FONT_BUTTON)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = TILE_SIZE.x - 24
	return label


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_profile_chosen(profile_id: int) -> void:
	if not ProfileService.set_active(profile_id):
		_show_toast(tr("PROFILE_PICKER_TOAST_PICK_FAILED"))
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_empty_create_pressed() -> void:
	var player_name := _empty_input.text.strip_edges()
	if player_name == "":
		_show_toast(tr("PROFILE_PICKER_TOAST_NAME_REQUIRED"))
		return
	var new_id: int = ProfileService.create(player_name)
	if new_id <= 0:
		_show_toast(tr("PROFILE_PICKER_TOAST_CREATE_FAILED"))
		return
	if not ProfileService.set_active(new_id):
		_show_toast(tr("PROFILE_PICKER_TOAST_ACTIVATE_FAILED"))
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _show_toast(message: String) -> void:
	MenuKit.show_toast(_toast_panel, _toast, message)
