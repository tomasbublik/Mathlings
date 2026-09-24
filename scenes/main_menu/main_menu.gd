extends Control
## Main menu scene — entry point for the app.
## - Big "Play" → scenes/game/game.tscn (or toast "Coming soon" if missing).
## - Menu tiles → Stats, Profiles, Rules, Settings.
## - Profile chip (top-left) greets the active player and opens Profiles.
## - `MascotSlot` (Layout/Column/HeroRow/MascotSlot, 260×260) is an empty
##   placeholder next to Play for the shared mascot component.
## ParentGate is currently not used (it annoyed more than it protected);
## scenes/shared/parent_gate.* is kept for when a better guard is designed.
## Reference: DESIGN §10.1, specs/P8a_main_menu.md

const GAME_SCENE: String = "res://scenes/game/game.tscn"
const STATS_SCENE: String = "res://scenes/stats/stats.tscn"
const SETTINGS_SCENE: String = "res://scenes/settings/settings.tscn"
const RULES_SCENE: String = "res://scenes/rules/rules.tscn"
const PROFILES_SCENE: String = "res://scenes/profiles/profile_manager.tscn"
const PROFILE_PICKER_SCENE: String = "res://scenes/profiles/profile_picker.tscn"
const LOCALE_PICKER_SCENE: String = "res://scenes/locale/locale_picker.tscn"

## Menu tiles: node → [emoji, badge variation, title translation key].
const TILE_SPECS: Dictionary = {
	"StatsButton": ["📊", "BadgeSky", "STATS_TITLE"],
	"ProfilesButton": ["👥", "BadgePink", "PROFILE_MANAGER_TITLE"],
	"RulesButton": ["💡", "BadgeSunny", "RULES_TITLE"],
	"SettingsButton": ["⚙️", "BadgeMint", "SETTINGS_TITLE"],
}

@onready var _background: TextureRect = $Background
@onready var _logo: Label = %Logo
@onready var _hero_row: BoxContainer = %HeroRow
@onready var _mascot_slot: Control = %MascotSlot
@onready var _play_button: Button = %PlayButton
@onready var _tiles: GridContainer = %Tiles
@onready var _stats_button: Button = %StatsButton
@onready var _profiles_button: Button = %ProfilesButton
@onready var _rules_button: Button = %RulesButton
@onready var _settings_button: Button = %SettingsButton
@onready var _profile_chip: Button = %ProfileChip
@onready var _toast_panel: PanelContainer = %ToastPanel
@onready var _toast: Label = %Toast
@onready var _version_label: Label = %VersionLabel

var _tile_labels: Dictionary = {}  ## Button → Label (tile caption)


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
	_stats_button.pressed.connect(_go.bind(STATS_SCENE))
	_profiles_button.pressed.connect(_go.bind(PROFILES_SCENE))
	_rules_button.pressed.connect(_go.bind(RULES_SCENE))
	_settings_button.pressed.connect(_go.bind(SETTINGS_SCENE))
	_profile_chip.pressed.connect(_go.bind(PROFILES_SCENE))

	_build_tiles()
	_apply_theme()
	_apply_translations()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	ProfileService.active_profile_changed.connect(func(_id: int) -> void:
		_refresh_profile_chip())
	EventBus.settings_changed.connect(_on_settings_changed_relay)

	_version_label.text = VersionInfo.display_string()

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_play_intro_animation()
	AudioManager.stop_music()


func _redirect_to_locale_picker() -> void:
	get_tree().change_scene_to_file(LOCALE_PICKER_SCENE)


func _redirect_to_profile_picker() -> void:
	get_tree().change_scene_to_file(PROFILE_PICKER_SCENE)


## Fills each menu tile with an emoji badge above its caption.
func _build_tiles() -> void:
	for node_name: String in TILE_SPECS:
		var btn: Button = _tiles.get_node(node_name)
		var spec: Array = TILE_SPECS[node_name]
		var content := MenuKit.tile_content(String(spec[0]), String(spec[1]), "")
		btn.add_child(content)
		_tile_labels[btn] = content.get_child(1) as Label


## Pulls every visible label / button text through the translation server.
## Called on `_ready` and again whenever the locale changes mid-session.
func _apply_translations() -> void:
	_logo.text = tr("APP_TITLE")
	_play_button.text = tr("MAIN_MENU_PLAY_BUTTON")
	for node_name: String in TILE_SPECS:
		var btn: Button = _tiles.get_node(node_name)
		var key := String(TILE_SPECS[node_name][2])
		(_tile_labels[btn] as Label).text = tr(key)
		btn.tooltip_text = tr(key)
	_refresh_profile_chip()


func _refresh_profile_chip() -> void:
	_profile_chip.text = "👤  " + tr("MAIN_MENU_GREETING") % MenuKit.active_profile_name()


func _on_settings_changed_relay(key: String, _value: Variant) -> void:
	if key == "general/locale":
		_apply_translations()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _on_theme_changed(_key: String) -> void:
	_apply_theme()


## Landscape: mascot beside Play, four tiles in a row.
## Portrait: mascot above Play, tiles in a 2×2 grid.
func _update_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	var portrait := size.y > size.x
	_hero_row.vertical = portrait
	_tiles.columns = 2 if portrait else 4
	var tile_size := Vector2(300, 150) if portrait else Vector2(230, 136)
	for btn: Button in _tile_labels.keys():
		btn.custom_minimum_size = tile_size
	_play_button.custom_minimum_size = Vector2(460.0 if portrait else 440.0, 150.0)


func _play_intro_animation() -> void:
	var nodes: Array = [_logo, _mascot_slot, _play_button]
	nodes.append_array(_tiles.get_children())
	nodes.append(_profile_chip)
	MenuKit.stagger_in(nodes, 0.0, 0.04)
	create_tween().tween_interval(0.6).finished.connect(_start_play_pulse)


## Gentle "breathing" on the Play button draws the eye to the main action.
## Stops for good the first time the button is pressed.
func _start_play_pulse() -> void:
	var pulse := _play_button.create_tween().set_loops()
	pulse.tween_property(_play_button, "scale", Vector2(1.04, 1.04), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_play_button, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_button.button_down.connect(pulse.kill, CONNECT_ONE_SHOT)


func _on_play_pressed() -> void:
	_go(GAME_SCENE)


func _go(scene_path: String) -> void:
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		MenuKit.show_toast(_toast_panel, _toast, tr("COMMON_COMING_SOON"), 1.2)
