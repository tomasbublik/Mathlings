extends Control
## Profile manager — CRUD over the profile list (max 5 profiles).
##
## Reached from Main Menu → "Profiles" (or the greeting chip). Lets the
## adult set up alternate profiles for siblings, rename someone, or wipe a
## profile that's been collecting dust. Each player is a card with a
## coloured avatar; the active one is outlined and badged "Playing now".
##
## Reference: specs/P16_profiles.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const PROFILE_PICKER_SCENE: String = "res://scenes/profiles/profile_picker.tscn"
const CARD_WIDTH: float = 300.0

@onready var _background: TextureRect = $Background
@onready var _column: MarginContainer = %Column
@onready var _profile_list: HFlowContainer = %ProfileList
@onready var _add_card: PanelContainer = %AddCard
@onready var _new_name_input: LineEdit = %NewNameInput
@onready var _add_button: Button = %AddButton
@onready var _back_button: Button = %BackButton
@onready var _toast_panel: PanelContainer = %ToastPanel
@onready var _toast: Label = %Toast


func _ready() -> void:
	_apply_theme()
	_new_name_input.placeholder_text = tr("PROFILE_MANAGER_NEW_PLACEHOLDER")
	_back_button.pressed.connect(_on_back)
	_add_button.pressed.connect(_on_add_pressed)
	_new_name_input.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	ProfileService.profile_list_changed.connect(_render)
	ProfileService.active_profile_changed.connect(func(_id: int) -> void: _render())
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	_render()
	var animated: Array = _profile_list.get_children()
	animated.append(_add_card)
	MenuKit.stagger_in(animated, 0.0, 0.05)


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _update_responsive_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	MenuKit.fit_column(_column, size.x, 1040.0, 24.0 if size.y > size.x else 32.0)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _render() -> void:
	for child in _profile_list.get_children():
		_profile_list.remove_child(child)
		child.queue_free()

	var profiles: Array = ProfileService.list()
	for profile: Dictionary in profiles:
		_profile_list.add_child(_make_card(profile))

	# Cap at MAX_PROFILES — disable the input + add button when full.
	var at_cap := profiles.size() >= ProfileService.MAX_PROFILES
	_new_name_input.editable = not at_cap
	_add_button.disabled = at_cap
	_add_button.text = (tr("PROFILE_MANAGER_ADD_BUTTON") if not at_cap
		else tr("PROFILE_MANAGER_ADD_FULL_FORMAT") % ProfileService.MAX_PROFILES)


## Builds one player card: avatar, name, "Playing now" / Select, and
## rename + delete actions.
func _make_card(profile: Dictionary) -> PanelContainer:
	var profile_id: int = int(profile.get("id", 0))
	var profile_name: String = String(profile.get("name", tr("COMMON_DEFAULT_PLAYER")))
	var is_active: bool = profile_id == ProfileService.active_id()

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	if is_active:
		var style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
		style.border_color = Palette.GRAPE
		style.set_border_width_all(5)
		card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	box.add_child(MenuKit.avatar(profile_name, profile_id, 104))

	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.text = profile_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = CARD_WIDTH - 64
	box.add_child(label)

	if is_active:
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"BadgeMint"
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.custom_minimum_size = Vector2(0, 64)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 14)
		pad.add_theme_constant_override("margin_right", 14)
		var badge_label := Label.new()
		badge_label.text = "✓  " + tr("PROFILE_MANAGER_ACTIVE_BADGE")
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_color_override("font_color", Palette.MINT_DARK)
		pad.add_child(badge_label)
		badge.add_child(pad)
		box.add_child(badge)
	else:
		var pick := Button.new()
		pick.theme_type_variation = &"SecondaryButton"
		pick.text = tr("PROFILE_MANAGER_PICK_BUTTON")
		pick.custom_minimum_size = Vector2(0, 64)
		pick.pressed.connect(_on_pick.bind(profile_id))
		box.add_child(pick)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)

	var rename := Button.new()
	rename.theme_type_variation = &"IconButton"
	rename.text = "✏️"
	rename.tooltip_text = tr("PROFILE_MANAGER_RENAME_BUTTON")
	rename.custom_minimum_size = Vector2(72, 64)
	rename.add_theme_font_size_override("font_size", Palette.FONT_BODY)
	rename.pressed.connect(_on_rename.bind(profile_id, profile_name))
	actions.add_child(rename)

	var delete := Button.new()
	delete.theme_type_variation = &"DangerButton"
	delete.text = "🗑️"
	delete.tooltip_text = tr("PROFILE_MANAGER_DELETE_BUTTON")
	delete.custom_minimum_size = Vector2(72, 64)
	delete.add_theme_font_size_override("font_size", Palette.FONT_BODY)
	delete.pressed.connect(_on_delete.bind(profile_id, profile_name))
	actions.add_child(delete)

	return card


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_pick(profile_id: int) -> void:
	if ProfileService.set_active(profile_id):
		_show_toast(tr("PROFILE_MANAGER_TOAST_ACTIVE_SWITCHED"))
	else:
		_show_toast(tr("PROFILE_MANAGER_TOAST_PICK_FAILED"))


func _on_add_pressed() -> void:
	var player_name := _new_name_input.text.strip_edges()
	if player_name == "":
		_show_toast(tr("PROFILE_MANAGER_TOAST_NAME_REQUIRED"))
		return
	var new_id: int = ProfileService.create(player_name)
	if new_id <= 0:
		_show_toast(tr("PROFILE_MANAGER_TOAST_CREATE_FAILED") % ProfileService.MAX_PROFILES)
		return
	_new_name_input.text = ""
	_new_name_input.release_focus()
	_show_toast(tr("PROFILE_MANAGER_TOAST_CREATED_FORMAT") % player_name)


func _on_rename(profile_id: int, current_name: String) -> void:
	var dialog := _make_text_input_dialog(
		tr("PROFILE_MANAGER_RENAME_TITLE"),
		tr("PROFILE_MANAGER_RENAME_PROMPT"),
		current_name,
		func(new_name: String) -> void:
			if not ProfileService.rename(profile_id, new_name):
				_show_toast(tr("PROFILE_MANAGER_TOAST_RENAME_FAILED"))
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_delete(profile_id: int, profile_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("PROFILE_MANAGER_DELETE_TITLE")
	dialog.dialog_text = tr("PROFILE_MANAGER_DELETE_TEXT_FORMAT") % profile_name
	dialog.ok_button_text = tr("PROFILE_MANAGER_DELETE_BUTTON")
	dialog.cancel_button_text = tr("COMMON_CANCEL")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if not ProfileService.delete(profile_id):
			_show_toast(tr("PROFILE_MANAGER_TOAST_DELETE_FAILED")))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_back() -> void:
	# When the user nukes the active profile while standing on this screen,
	# ProfileService falls back to id=0 and we should redirect to the picker.
	if ProfileService.active_id() <= 0:
		get_tree().change_scene_to_file(PROFILE_PICKER_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds an AcceptDialog with a LineEdit; calls `on_accept(text)` when the
## user confirms a non-empty input. Auto-frees on close.
func _make_text_input_dialog(
	title: String, prompt: String, initial: String, on_accept: Callable
) -> AcceptDialog:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.ok_button_text = tr("COMMON_OK")
	dlg.add_cancel_button(tr("COMMON_CANCEL"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	dlg.add_child(vbox)

	var label := Label.new()
	label.text = prompt
	vbox.add_child(label)

	var input := LineEdit.new()
	input.text = initial
	input.custom_minimum_size = Vector2(360, 72)
	input.max_length = 24
	vbox.add_child(input)

	dlg.confirmed.connect(func() -> void:
		var value := input.text.strip_edges()
		if value != "":
			on_accept.call(value))
	dlg.close_requested.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.confirmed.connect(dlg.queue_free)
	return dlg


func _show_toast(message: String) -> void:
	MenuKit.show_toast(_toast_panel, _toast, message, 1.2)
