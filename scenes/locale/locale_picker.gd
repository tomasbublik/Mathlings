extends Control
## First-run language picker.
##
## Opens automatically when SettingsStore has no `general/locale_chosen`
## flag (set on first successful pick). Renders one card per supported
## locale with its native-spelled name plus a "Hello!" in that language
## (LOCALE_PICKER_HELLO read from that locale's translation), so a child who
## only reads e.g. Hindi can find "हिन्दी" without help. The language can
## also be changed later in Settings.
##
## Reference: specs/P18_i18n.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const PROFILE_PICKER_SCENE: String = "res://scenes/profiles/profile_picker.tscn"

@onready var _background: TextureRect = $Background
@onready var _center: CenterContainer = %Center
@onready var _vbox: VBoxContainer = %VBox
@onready var _top: BoxContainer = %Top
@onready var _list_container: GridContainer = %LocaleList
@onready var _title: Label = %TitleLabel


func _ready() -> void:
	_apply_theme()
	_render_list()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	var animated: Array = [_top]
	animated.append_array(_list_container.get_children())
	MenuKit.stagger_in(animated, 0.0, 0.03)


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _update_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	var portrait := size.y > size.x
	_list_container.columns = 2 if portrait else 4
	_top.vertical = portrait
	var card_w := (size.x - 48.0 - 16.0) / 2.0 if portrait else 276.0
	for child in _list_container.get_children():
		(child as Control).custom_minimum_size = Vector2(minf(card_w, 300.0), 104)
	# Keep the block vertically centred but never glued to the edges.
	_center.custom_minimum_size = Vector2(size.x, size.y)
	_vbox.add_theme_constant_override("separation", 28 if portrait else 20)


## Renders the catalog as one card per locale. Each card calls
## `_pick(code)` which persists the choice and forwards to the next scene
## in the boot flow (profile picker if no profiles, otherwise main menu).
func _render_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	_title.text = tr("LOCALE_PICKER_TITLE")
	var current := LocaleService.current()
	for entry in LocaleCatalog.SUPPORTED:
		var code := String(entry["code"])
		var btn := Button.new()
		btn.theme_type_variation = &"TileButton"
		btn.custom_minimum_size = Vector2(250, 104)
		btn.pressed.connect(_pick.bind(code))

		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_bottom = -Palette.EDGE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(box)

		var name_label := Label.new()
		name_label.theme_type_variation = &"HeadingLabel"
		name_label.add_theme_font_size_override("font_size", Palette.FONT_BUTTON)
		name_label.text = String(entry["native"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if code == current:
			name_label.add_theme_color_override("font_color", Palette.GRAPE)
		box.add_child(name_label)

		var hello := Label.new()
		hello.theme_type_variation = &"CaptionLabel"
		hello.text = "👋 " + _hello_in(code)
		hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hello.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(hello)

		_list_container.add_child(btn)


## "Hello!" in the given locale, straight from that locale's translation.
func _hello_in(code: String) -> String:
	var t := TranslationServer.get_translation_object(code)
	if t == null:
		return ""
	return String(t.get_message("LOCALE_PICKER_HELLO"))


func _pick(code: String) -> void:
	# Persist *both* the locale and the "we've asked once" flag so we don't
	# re-prompt every cold start.
	SettingsStore.set_value("general/locale", code)
	SettingsStore.set_value("general/locale_chosen", true)
	LocaleService.apply_to_root(code)

	# Decide where to go next: if the player already has profiles, jump
	# straight to the main menu; otherwise let the profile picker run.
	if ProfileService.has_active_profile():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(PROFILE_PICKER_SCENE)
