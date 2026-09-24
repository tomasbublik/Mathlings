extends Control
## Main menu scene — entry point for the app.
## - "Hrát!" → scenes/game/game.tscn (or toast "Brzy!" if missing).
## - "Statistiky" → scenes/stats/stats.tscn (or toast).
## - "Nastavení" → scenes/settings/settings.tscn.
## ParentGate is currently not used (it annoyed more than it protected);
## scenes/shared/parent_gate.* is kept for when a better guard is designed.
## - Profile badge reads SettingsStore + DB (fallback "Hráč 1").
## Reference: DESIGN §10.1, specs/P8a_main_menu.md

const GAME_SCENE: String = "res://scenes/game/game.tscn"
const STATS_SCENE: String = "res://scenes/stats/stats.tscn"
const SETTINGS_SCENE: String = "res://scenes/settings/settings.tscn"
const RULES_SCENE: String = "res://scenes/rules/rules.tscn"
const PROFILES_SCENE: String = "res://scenes/profiles/profile_manager.tscn"
const PROFILE_PICKER_SCENE: String = "res://scenes/profiles/profile_picker.tscn"
const LOCALE_PICKER_SCENE: String = "res://scenes/locale/locale_picker.tscn"

@onready var _background: TextureRect = $Background
@onready var _logo: Label = %Logo
@onready var _play_button: Button = %PlayButton
@onready var _stats_button: Button = %StatsButton
@onready var _profiles_button: Button = %ProfilesButton
@onready var _rules_button: Button = %RulesButton
@onready var _settings_button: Button = %SettingsButton
@onready var _profile_badge: Label = %ProfileBadge
@onready var _toast: Label = %Toast
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	# First-run flow: locale picker → profile picker → main menu. Each prior
	# step persists a flag, so subsequent boots skip directly here.
	if not bool(SettingsStore.get_value("general/locale_chosen", false)):
		call_deferred("_redirect_to_locale_picker")
		return

	if not ProfileService.ensure_ready():
		call_deferred("_redirect_to_profile_picker")
		return

	_play_button.pressed.connect(_on_play_pressed)
	_stats_button.pressed.connect(_on_stats_pressed)
	_profiles_button.pressed.connect(_on_profiles_pressed)
	_rules_button.pressed.connect(_on_rules_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)

	_apply_theme()
	_apply_translations()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	ProfileService.active_profile_changed.connect(func(_id: int) -> void:
		_profile_badge.text = _profile_badge_text())
	EventBus.settings_changed.connect(_on_settings_changed_relay)

	_profile_badge.text = _profile_badge_text()
	_version_label.text = VersionInfo.display_string()
	_toast.modulate.a = 0.0

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_play_intro_animation()
	AudioManager.stop_music()


func _redirect_to_locale_picker() -> void:
	get_tree().change_scene_to_file(LOCALE_PICKER_SCENE)


func _redirect_to_profile_picker() -> void:
	get_tree().change_scene_to_file(PROFILE_PICKER_SCENE)


## Pulls every visible label / button text through the translation server.
## Called on `_ready` and again whenever the locale changes mid-session.
func _apply_translations() -> void:
	_play_button.text = tr("MAIN_MENU_PLAY_BUTTON")
	_stats_button.text = tr("MAIN_MENU_STATS_BUTTON")
	_profiles_button.text = tr("MAIN_MENU_PROFILES_BUTTON")
	_rules_button.text = tr("MAIN_MENU_RULES_BUTTON")
	_settings_button.text = tr("MAIN_MENU_SETTINGS_BUTTON")


func _on_settings_changed_relay(key: String, _value: Variant) -> void:
	if key == "general/locale":
		_apply_translations()
		_profile_badge.text = _profile_badge_text()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _on_theme_changed(_key: String) -> void:
	_apply_theme()


func _update_layout() -> void:
	var size := get_viewport_rect().size
	var portrait := size.y > size.x
	var bvbox: VBoxContainer = $ButtonsVBox
	var nav_btns: Array[Button] = [_stats_button, _profiles_button, _rules_button]

	if portrait:
		var btn_w := int(size.x * 0.68)
		_play_button.custom_minimum_size.x = btn_w
		for btn in nav_btns:
			btn.custom_minimum_size.x = btn_w
		# Shift button group below logo (~200 px) instead of floating at 50 % height.
		bvbox.anchor_left = 0.5
		bvbox.anchor_right = 0.5
		bvbox.anchor_top = 0.0
		bvbox.anchor_bottom = 0.0
		bvbox.offset_left = -(btn_w * 0.5)
		bvbox.offset_right = btn_w * 0.5
		bvbox.offset_top = 260.0
		bvbox.offset_bottom = 660.0
	else:
		_play_button.custom_minimum_size.x = 384
		for btn in nav_btns:
			btn.custom_minimum_size.x = 384
		bvbox.anchor_left = 0.5
		bvbox.anchor_right = 0.5
		bvbox.anchor_top = 0.5
		bvbox.anchor_bottom = 0.5
		bvbox.offset_left = -192.0
		bvbox.offset_right = 192.0
		bvbox.offset_top = -60.0
		bvbox.offset_bottom = 180.0


func _profile_badge_text() -> String:
	var active_id: int = ProfileService.active_id()
	var name := "Hráč 1"
	if active_id > 0 and DB.is_open():
		var profile: Dictionary = ProfilesDao.get_by_id(DB, active_id)
		if not profile.is_empty():
			name = String(profile.get("name", "Hráč 1"))
	return tr("COMMON_PROFILE_PREFIX") % name


func _play_intro_animation() -> void:
	# Logo drops from top with a bounce.
	var target_y: float = _logo.position.y
	_logo.position.y = target_y - 300.0
	var tween := create_tween()
	tween.tween_property(_logo, "position:y", target_y, 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Buttons fade in with stagger.
	var buttons: Array[Control] = [
		_play_button, _stats_button, _profiles_button, _rules_button, _settings_button
	]
	for i in range(buttons.size()):
		var b := buttons[i]
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.4 + i * 0.1)
		t.tween_property(b, "modulate:a", 1.0, 0.25)


func _on_play_pressed() -> void:
	if ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_show_toast(tr("COMMON_COMING_SOON"))


func _on_stats_pressed() -> void:
	if ResourceLoader.exists(STATS_SCENE):
		get_tree().change_scene_to_file(STATS_SCENE)
	else:
		_show_toast(tr("COMMON_COMING_SOON"))


func _on_rules_pressed() -> void:
	if ResourceLoader.exists(RULES_SCENE):
		get_tree().change_scene_to_file(RULES_SCENE)
	else:
		_show_toast(tr("COMMON_COMING_SOON"))


func _on_profiles_pressed() -> void:
	if ResourceLoader.exists(PROFILES_SCENE):
		get_tree().change_scene_to_file(PROFILES_SCENE)
	else:
		_show_toast(tr("COMMON_COMING_SOON"))


func _on_settings_pressed() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE):
		get_tree().change_scene_to_file(SETTINGS_SCENE)
	else:
		_show_toast(tr("COMMON_COMING_SOON"))


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
