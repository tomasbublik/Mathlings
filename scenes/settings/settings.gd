extends Control
## Settings screen — reads and writes everything through SettingsStore.
## Reference: DESIGN §6.3, specs/P8b_settings_screen.md

const DURATION_OPTIONS: Array[int] = [30, 60, 120, 180, 300]
const SPEED_OPTIONS: Array[String] = ["slow", "normal", "fast", "adaptive"]
const SPEED_LABELS: Dictionary = {
	"slow": "Pomalu",
	"normal": "Normálně",
	"fast": "Rychle",
	"adaptive": "Adaptivní",
}

@onready var _background: TextureRect = $Background
@onready var _duration_group: HFlowContainer = %DurationGroup
@onready var _speed_group: HFlowContainer = %SpeedGroup
@onready var _theme_group: HFlowContainer = %ThemeGroup
@onready var _skills_grid: GridContainer = %SkillsGrid
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _music_toggle: CheckButton = %MusicToggle
@onready var _haptics_toggle: CheckButton = %HapticsToggle
@onready var _sfx_preview: Button = %SfxPreviewButton
@onready var _profile_label: Label = %ProfileLabel
@onready var _back_button: Button = %BackButton
@onready var _reset_button: Button = %ResetButton
@onready var _validation_label: Label = %ValidationLabel

var _duration_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _theme_buttons: Dictionary = {}  ## theme_key -> Button
var _skill_checkboxes: Dictionary = {}  ## skill_key -> CheckBox


func _ready() -> void:
	_apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed_external)
	get_viewport().size_changed.connect(_update_responsive_layout)

	_build_duration_buttons()
	_build_speed_buttons()
	_build_theme_buttons()
	_build_skills_grid()
	_wire_toggles()
	_populate_profile()

	_back_button.pressed.connect(_on_back)
	_reset_button.pressed.connect(_on_reset_pressed)
	_sfx_preview.pressed.connect(func() -> void: AudioManager.play_sfx("correct"))

	_load_from_store()
	_update_responsive_layout()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _on_theme_changed_external(_key: String) -> void:
	_apply_theme()


# ---------------------------------------------------------------------------
# Build dynamic UI
# ---------------------------------------------------------------------------

func _build_duration_buttons() -> void:
	for s in DURATION_OPTIONS:
		var btn := Button.new()
		btn.text = "%d s" % s
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(132, 76)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_duration_selected.bind(s))
		_duration_group.add_child(btn)
		_duration_buttons.append(btn)


func _build_speed_buttons() -> void:
	for preset in SPEED_OPTIONS:
		var btn := Button.new()
		btn.text = String(SPEED_LABELS[preset])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(180, 76)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_speed_selected.bind(preset))
		_speed_group.add_child(btn)
		_speed_buttons.append(btn)


func _build_theme_buttons() -> void:
	var profile_id: int = ProfileService.active_id()
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		var label: String = String(meta.get("label", theme_key))
		var available: bool = ThemeManager.is_available(theme_key, profile_id)
		var btn := Button.new()
		btn.text = label if available else "🔒 %s" % label
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(190, 78)
		btn.add_theme_font_size_override("font_size", 28)
		btn.disabled = not available
		btn.pressed.connect(_on_theme_selected.bind(theme_key))
		_theme_group.add_child(btn)
		_theme_buttons[theme_key] = btn


func _build_skills_grid() -> void:
	for key in ProblemGenerator.supported_skills():
		var cb := CheckBox.new()
		cb.text = SkillLabels.label_for(key)
		cb.custom_minimum_size = Vector2(0, 78)
		cb.add_theme_font_size_override("font_size", 28)
		cb.add_theme_color_override("font_color", Color(1, 1, 1))
		cb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cb.add_theme_constant_override("outline_size", 4)
		cb.toggled.connect(_on_skill_toggled.bind(key))
		_skills_grid.add_child(cb)
		_skill_checkboxes[key] = cb


func _wire_toggles() -> void:
	_sfx_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/audio_sfx", on))
	_music_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/audio_music", on))
	_haptics_toggle.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value("general/haptics", on))


func _populate_profile() -> void:
	if DB.is_open():
		var active_id: int = ProfileService.active_id()
		var p: Dictionary = ProfilesDao.get_by_id(DB, active_id)
		_profile_label.text = String(p.get("name", "Hráč 1"))
	else:
		_profile_label.text = "Hráč 1"


func _update_responsive_layout() -> void:
	var size := get_viewport_rect().size
	var portrait := size.y > size.x
	_skills_grid.columns = 1 if portrait else 2
	for cb: CheckBox in _skill_checkboxes.values():
		cb.custom_minimum_size = Vector2(size.x - 96.0 if portrait else 420.0, 82.0)


# ---------------------------------------------------------------------------
# Load state from SettingsStore
# ---------------------------------------------------------------------------

func _load_from_store() -> void:
	var duration: int = int(SettingsStore.get_value("round/duration_s", 120))
	for i in range(DURATION_OPTIONS.size()):
		_duration_buttons[i].button_pressed = DURATION_OPTIONS[i] == duration

	var speed: String = String(SettingsStore.get_value("round/speed_preset", "adaptive"))
	for i in range(SPEED_OPTIONS.size()):
		_speed_buttons[i].button_pressed = SPEED_OPTIONS[i] == speed

	var theme_key: String = ThemeManager.current_key()
	for key: String in _theme_buttons.keys():
		(_theme_buttons[key] as Button).set_pressed_no_signal(key == theme_key)

	var enabled: Array = SettingsStore.get_value("skills/enabled", [])
	for key in _skill_checkboxes.keys():
		(_skill_checkboxes[key] as CheckBox).set_pressed_no_signal(enabled.has(key))

	_sfx_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/audio_sfx", true)))
	_music_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/audio_music", true)))
	_haptics_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("general/haptics", true)))


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_duration_selected(seconds: int) -> void:
	for btn in _duration_buttons:
		btn.button_pressed = btn.text == "%d s" % seconds
	SettingsStore.set_value("round/duration_s", seconds)


func _on_speed_selected(preset: String) -> void:
	for i in range(SPEED_OPTIONS.size()):
		_speed_buttons[i].button_pressed = SPEED_OPTIONS[i] == preset
	SettingsStore.set_value("round/speed_preset", preset)


func _on_theme_selected(theme_key: String) -> void:
	for key: String in _theme_buttons.keys():
		(_theme_buttons[key] as Button).set_pressed_no_signal(key == theme_key)
	ThemeManager.set_theme(theme_key)


func _on_skill_toggled(on: bool, skill_key: String) -> void:
	var enabled: Array = (SettingsStore.get_value("skills/enabled", []) as Array).duplicate()
	if on:
		if not enabled.has(skill_key):
			enabled.append(skill_key)
	else:
		# Prevent disabling the last enabled skill.
		if enabled.size() <= 1 and enabled.has(skill_key):
			(_skill_checkboxes[skill_key] as CheckBox).set_pressed_no_signal(true)
			_flash_validation("Alespoň jedna dovednost musí být zapnutá.")
			return
		enabled.erase(skill_key)
	SettingsStore.set_value("skills/enabled", enabled)


func _flash_validation(msg: String) -> void:
	_validation_label.text = msg
	_validation_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_validation_label, "modulate:a", 0.0, 0.4)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_reset_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Obnovit výchozí?"
	dlg.dialog_text = "Všechna nastavení se vrátí na výchozí hodnoty."
	dlg.ok_button_text = "Obnovit"
	dlg.cancel_button_text = "Zrušit"
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		SettingsStore.reset_to_defaults()
		_load_from_store())
	dlg.close_requested.connect(dlg.queue_free)
	dlg.popup_centered()
