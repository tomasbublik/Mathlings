extends Control
## First-run language picker.
##
## Opens automatically when SettingsStore has no `general/locale_chosen`
## flag (set on first successful pick). Renders one button per supported
## locale with its native-spelled name, so a child who only reads e.g.
## Hindi can find "हिन्दी" without help. The picker also runs in Settings
## (separate flow) but isn't blocked by the same flag — re-entry is fine.
##
## Reference: specs/P18_i18n.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const PROFILE_PICKER_SCENE: String = "res://scenes/profiles/profile_picker.tscn"

@onready var _background: TextureRect = $Background
@onready var _list_container: VBoxContainer = %LocaleList
@onready var _title: Label = %TitleLabel


func _ready() -> void:
	_apply_theme()
	_render_list()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


## Renders the catalog as one button per locale. Each button calls
## `_pick(code)` which persists the choice and forwards to the next scene
## in the boot flow (profile picker if no profiles, otherwise main menu).
func _render_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	_title.text = tr("LOCALE_PICKER_TITLE")
	for entry in LocaleCatalog.SUPPORTED:
		var btn := Button.new()
		btn.text = String(entry["native"])
		btn.custom_minimum_size = Vector2(420, 76)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_pick.bind(String(entry["code"])))
		_list_container.add_child(btn)


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
