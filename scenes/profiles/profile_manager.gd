extends Control
## Profile manager — CRUD over the profile list (max 5 profiles).
##
## Reached from Main Menu → "Profily" (Parent Gate-protected). Lets the
## adult set up alternate profiles for siblings, rename someone, or wipe a
## profile that's been collecting dust.
##
## Reference: specs/P16_profiles.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

@onready var _background: TextureRect = $Background
@onready var _profile_list: VBoxContainer = %ProfileList
@onready var _new_name_input: LineEdit = %NewNameInput
@onready var _add_button: Button = %AddButton
@onready var _back_button: Button = %BackButton
@onready var _toast: Label = %Toast


func _ready() -> void:
	_apply_theme()
	_back_button.pressed.connect(_on_back)
	_add_button.pressed.connect(_on_add_pressed)
	_new_name_input.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	ProfileService.profile_list_changed.connect(_render)
	ProfileService.active_profile_changed.connect(func(_id: int) -> void: _render())
	_render()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _render() -> void:
	for child in _profile_list.get_children():
		child.queue_free()

	var profiles: Array = ProfileService.list()
	for profile: Dictionary in profiles:
		_profile_list.add_child(_make_row(profile))

	# Cap at MAX_PROFILES — disable the input + add button when full.
	var at_cap := profiles.size() >= ProfileService.MAX_PROFILES
	_new_name_input.editable = not at_cap
	_add_button.disabled = at_cap
	_add_button.text = "Přidat" if not at_cap else "Plno (%d)" % ProfileService.MAX_PROFILES


## Builds one row: [Name | Vybrat | Přejmenovat | Smazat], with the active
## profile highlighted in green.
func _make_row(profile: Dictionary) -> HBoxContainer:
	var profile_id: int = int(profile.get("id", 0))
	var profile_name: String = String(profile.get("name", "Hráč"))
	var is_active: bool = profile_id == ProfileService.active_id()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = ("✓ %s" if is_active else "• %s") % profile_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if is_active else Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	if not is_active:
		var pick := Button.new()
		pick.text = "Vybrat"
		pick.custom_minimum_size = Vector2(140, 64)
		pick.pressed.connect(_on_pick.bind(profile_id))
		row.add_child(pick)

	var rename := Button.new()
	rename.text = "Přejmenovat"
	rename.custom_minimum_size = Vector2(180, 64)
	rename.pressed.connect(_on_rename.bind(profile_id, profile_name))
	row.add_child(rename)

	var delete := Button.new()
	delete.text = "Smazat"
	delete.custom_minimum_size = Vector2(140, 64)
	delete.pressed.connect(_on_delete.bind(profile_id, profile_name))
	row.add_child(delete)

	return row


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_pick(profile_id: int) -> void:
	if ProfileService.set_active(profile_id):
		_show_toast("Aktivní profil přepnut.")
	else:
		_show_toast("Profil nelze vybrat.")


func _on_add_pressed() -> void:
	var name := _new_name_input.text.strip_edges()
	if name == "":
		_show_toast("Zadej jméno.")
		return
	var new_id: int = ProfileService.create(name)
	if new_id <= 0:
		_show_toast("Profil nelze vytvořit (limit %d nebo DB nedostupná)."
			% ProfileService.MAX_PROFILES)
		return
	_new_name_input.text = ""
	# Inner quotes are escaped ASCII so GDScript can't close the string at "%s".
	_show_toast("Profil \"%s\" vytvořen." % name)


func _on_rename(profile_id: int, current_name: String) -> void:
	var dialog := _make_text_input_dialog(
		"Přejmenovat profil",
		"Nové jméno:",
		current_name,
		func(new_name: String) -> void:
			if not ProfileService.rename(profile_id, new_name):
				_show_toast("Přejmenovat se nepodařilo.")
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_delete(profile_id: int, profile_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Smazat profil"
	# Inner quotes escaped — see comment in _on_add_pressed.
	dialog.dialog_text = "Opravdu smazat profil \"%s\"?\nVšechna jeho data zmizí." % profile_name
	dialog.ok_button_text = "Smazat"
	dialog.cancel_button_text = "Zrušit"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if not ProfileService.delete(profile_id):
			_show_toast("Smazat se nepodařilo."))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_back() -> void:
	# When the user nukes the active profile while standing on this screen,
	# ProfileService falls back to id=0 and we should redirect to the picker.
	if ProfileService.active_id() <= 0:
		get_tree().change_scene_to_file("res://scenes/profiles/profile_picker.tscn")
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
	dlg.ok_button_text = "OK"
	dlg.add_cancel_button("Zrušit")

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dlg.add_child(vbox)

	var label := Label.new()
	label.text = prompt
	vbox.add_child(label)

	var input := LineEdit.new()
	input.text = initial
	input.custom_minimum_size = Vector2(280, 48)
	input.max_length = 24
	vbox.add_child(input)

	dlg.confirmed.connect(func() -> void:
		var value := input.text.strip_edges()
		if value != "":
			on_accept.call(value))
	dlg.close_requested.connect(dlg.queue_free)
	return dlg


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
