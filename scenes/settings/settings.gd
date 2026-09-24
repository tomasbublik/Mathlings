extends Control
## Settings screen — reads and writes everything through SettingsStore.
## Option groups are ChipButton toggles grouped into cards; static labels
## in the .tscn are translation keys (auto-translated by Godot).
## Reference: DESIGN §6.3, specs/P8b_settings_screen.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const PROFILES_SCENE: String = "res://scenes/profiles/profile_manager.tscn"

const DURATION_OPTIONS: Array[int] = [30, 60, 120, 180, 300]
const SPEED_OPTIONS: Array[String] = ["slow", "normal", "fast", "adaptive"]
const SPEED_KEYS: Dictionary = {
	"slow": "SETTINGS_SPEED_SLOW",
	"normal": "SETTINGS_SPEED_NORMAL",
	"fast": "SETTINGS_SPEED_FAST",
	"adaptive": "SETTINGS_SPEED_ADAPTIVE",
}
const SPEED_GLYPHS: Dictionary = {
	"slow": "🐢", "normal": "🐇", "fast": "⚡", "adaptive": "✨",
}
## Skill rows: skill-key prefix → [glyph, badge variation].
const SKILL_GROUPS: Array = [
	["add_", "➕", "BadgeMint"],
	["sub_", "➖", "BadgeSky"],
	["mul_", "✖", "BadgePink"],
	["div_", "➗", "BadgeSunny"],
]

@onready var _background: TextureRect = $Background
@onready var _column: MarginContainer = %Column
@onready var _cards: VBoxContainer = %Cards
@onready var _duration_group: HFlowContainer = %DurationGroup
@onready var _speed_group: HFlowContainer = %SpeedGroup
@onready var _theme_group: HFlowContainer = %ThemeGroup
@onready var _skills_box: VBoxContainer = %SkillsBox
@onready var _language_group: HFlowContainer = %LanguageGroup
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _music_toggle: CheckButton = %MusicToggle
@onready var _haptics_toggle: CheckButton = %HapticsToggle
@onready var _sfx_preview: Button = %SfxPreviewButton
@onready var _profile_row: HBoxContainer = %Row
@onready var _profile_label: Label = %ProfileLabel
@onready var _players_button: Button = %PlayersButton
@onready var _back_button: Button = %BackButton
@onready var _reset_button: Button = %ResetButton
@onready var _validation_label: Label = %ValidationLabel

var _duration_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _theme_buttons: Dictionary = {}  ## theme_key -> Button
var _skill_buttons: Dictionary = {}  ## skill_key -> Button (toggle chip)
var _language_buttons: Dictionary = {}  ## locale code -> Button


func _ready() -> void:
	_apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed_external)
	get_viewport().size_changed.connect(_update_responsive_layout)

	_build_duration_buttons()
	_build_speed_buttons()
	_build_theme_buttons()
	_build_skill_chips()
	_build_language_buttons()
	_wire_toggles()
	_populate_profile()

	_back_button.pressed.connect(_on_back)
	_reset_button.pressed.connect(_on_reset_pressed)
	_players_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(PROFILES_SCENE))
	_sfx_preview.pressed.connect(func() -> void: AudioManager.play_sfx("correct"))
	_sfx_preview.set_meta("ui_feedback_silent", true)

	_load_from_store()
	_update_responsive_layout()
	MenuKit.stagger_in(_cards.get_children(), 0.0, 0.05)


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _on_theme_changed_external(_key: String) -> void:
	_apply_theme()


# ---------------------------------------------------------------------------
# Build dynamic UI
# ---------------------------------------------------------------------------

func _make_chip(text: String, parent: Control) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"ChipButton"
	btn.toggle_mode = true
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 64)
	parent.add_child(btn)
	return btn


func _build_duration_buttons() -> void:
	for s in DURATION_OPTIONS:
		var text := (tr("SETTINGS_DURATION_SECONDS") % s if s < 60 or s % 60 != 0
			else tr("SETTINGS_DURATION_MINUTES") % (s / 60))
		var btn := _make_chip(text, _duration_group)
		btn.custom_minimum_size.x = 112
		btn.pressed.connect(_on_duration_selected.bind(s))
		_duration_buttons.append(btn)


func _build_speed_buttons() -> void:
	for preset in SPEED_OPTIONS:
		var btn := _make_chip("%s  %s" % [SPEED_GLYPHS[preset], tr(SPEED_KEYS[preset])], _speed_group)
		btn.pressed.connect(_on_speed_selected.bind(preset))
		_speed_buttons.append(btn)


func _build_theme_buttons() -> void:
	var profile_id: int = ProfileService.active_id()
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		var label: String = tr(ThemeManager.label_key(theme_key))
		var available: bool = ThemeManager.is_available(theme_key, profile_id)
		var btn := _make_chip(label if available else "🔒 %s" % label, _theme_group)
		btn.custom_minimum_size = Vector2(0, 76)
		btn.disabled = not available
		var skins: Array = meta.get("skins", [])
		if not skins.is_empty():
			btn.icon = load(String(skins[0].get("texture", ""))) as Texture2D
			btn.expand_icon = false
			btn.add_theme_constant_override("icon_max_width", 44)
		btn.pressed.connect(_on_theme_selected.bind(theme_key))
		_theme_buttons[theme_key] = btn


## One row per operation (➕ ➖ ✖ ➗): a badge followed by the chips.
func _build_skill_chips() -> void:
	var skills := ProblemGenerator.supported_skills()
	for group: Array in SKILL_GROUPS:
		var prefix := String(group[0])
		var keys: Array[String] = []
		for key in skills:
			if key.begins_with(prefix):
				keys.append(key)
		if keys.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var badge := MenuKit.badge(String(group[1]), String(group[2]), 56)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		row.add_child(flow)
		_skills_box.add_child(row)
		for key in keys:
			# Times tables get compact "× 7" chips — the row badge already
			# says what they are; the full name stays in the tooltip.
			var text := SkillLabels.label_for(key)
			if prefix == "mul_":
				text = "× " + key.trim_prefix("mul_x")
			var chip := _make_chip(text, flow)
			chip.tooltip_text = SkillLabels.label_for(key)
			chip.custom_minimum_size = Vector2(88 if prefix == "mul_" else 0, 58)
			chip.toggled.connect(_on_skill_toggled.bind(key))
			_skill_buttons[key] = chip


func _build_language_buttons() -> void:
	for entry in LocaleCatalog.SUPPORTED:
		var code := String(entry["code"])
		var btn := _make_chip(String(entry["native"]), _language_group)
		btn.custom_minimum_size = Vector2(0, 58)
		btn.pressed.connect(_on_language_selected.bind(code))
		_language_buttons[code] = btn


func _wire_toggles() -> void:
	_sfx_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/audio_sfx", on))
	_music_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/audio_music", on))
	_haptics_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/haptics", on))


func _populate_profile() -> void:
	var player_name := MenuKit.active_profile_name()
	_profile_label.text = player_name
	var avatar := MenuKit.avatar(player_name, ProfileService.active_id(), 72)
	_profile_row.add_child(avatar)
	_profile_row.move_child(avatar, 0)


func _update_responsive_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	MenuKit.fit_column(_column, size.x, 1040.0, 24.0 if size.y > size.x else 32.0)


# ---------------------------------------------------------------------------
# Load state from SettingsStore
# ---------------------------------------------------------------------------

func _load_from_store() -> void:
	var duration: int = int(SettingsStore.get_value("round/duration_s", 120))
	for i in range(DURATION_OPTIONS.size()):
		_duration_buttons[i].set_pressed_no_signal(DURATION_OPTIONS[i] == duration)

	var speed: String = String(SettingsStore.get_value("round/speed_preset", "adaptive"))
	for i in range(SPEED_OPTIONS.size()):
		_speed_buttons[i].set_pressed_no_signal(SPEED_OPTIONS[i] == speed)

	var theme_key: String = ThemeManager.current_key()
	for key: String in _theme_buttons.keys():
		(_theme_buttons[key] as Button).set_pressed_no_signal(key == theme_key)

	var enabled: Array = SettingsStore.get_value("skills/enabled", [])
	for key: String in _skill_buttons.keys():
		(_skill_buttons[key] as Button).set_pressed_no_signal(enabled.has(key))

	var locale := LocaleService.current()
	for code: String in _language_buttons.keys():
		(_language_buttons[code] as Button).set_pressed_no_signal(code == locale)

	_sfx_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/audio_sfx", true)))
	_music_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/audio_music", true)))
	_haptics_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/haptics", true)))


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_duration_selected(seconds: int) -> void:
	for i in range(DURATION_OPTIONS.size()):
		_duration_buttons[i].set_pressed_no_signal(DURATION_OPTIONS[i] == seconds)
	SettingsStore.set_value("round/duration_s", seconds)


func _on_speed_selected(preset: String) -> void:
	for i in range(SPEED_OPTIONS.size()):
		_speed_buttons[i].set_pressed_no_signal(SPEED_OPTIONS[i] == preset)
	SettingsStore.set_value("round/speed_preset", preset)


func _on_theme_selected(theme_key: String) -> void:
	for key: String in _theme_buttons.keys():
		(_theme_buttons[key] as Button).set_pressed_no_signal(key == theme_key)
	ThemeManager.set_theme(theme_key)


func _on_language_selected(code: String) -> void:
	if code == LocaleService.current():
		(_language_buttons[code] as Button).set_pressed_no_signal(true)
		return
	# LocaleService listens for this key and swaps the TranslationServer
	# locale; reloading repaints every string built in code.
	SettingsStore.set_value("general/locale", code)
	get_tree().reload_current_scene.call_deferred()


func _on_skill_toggled(on: bool, skill_key: String) -> void:
	var enabled: Array = (SettingsStore.get_value("skills/enabled", []) as Array).duplicate()
	if on:
		if not enabled.has(skill_key):
			enabled.append(skill_key)
	else:
		# Prevent disabling the last enabled skill.
		if enabled.size() <= 1 and enabled.has(skill_key):
			(_skill_buttons[skill_key] as Button).set_pressed_no_signal(true)
			_flash_validation(tr("SETTINGS_SKILL_AT_LEAST_ONE"))
			return
		enabled.erase(skill_key)
	SettingsStore.set_value("skills/enabled", enabled)


func _flash_validation(msg: String) -> void:
	_validation_label.text = "⚠ " + msg
	_validation_label.add_theme_color_override("font_color", Palette.CORAL_DARK)
	_validation_label.modulate.a = 1.0
	_validation_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_validation_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _validation_label.visible = false)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_reset_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("SETTINGS_RESET_DIALOG_TITLE")
	dlg.dialog_text = tr("SETTINGS_RESET_DIALOG_TEXT")
	dlg.ok_button_text = tr("SETTINGS_RESET_DIALOG_OK")
	dlg.cancel_button_text = tr("COMMON_CANCEL")
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		SettingsStore.reset_to_defaults()
		_load_from_store())
	dlg.close_requested.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.popup_centered()
