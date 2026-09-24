extends Node
## Persistence layer for per-profile user settings via ConfigFile.
##
## Each profile gets its own settings.cfg under user://profiles/<id>/. The
## active profile id is owned by ProfileService — this autoload subscribes
## to active_profile_changed and reloads its in-memory ConfigFile from the
## new path on every switch (emitting settings_changed for every key so UI
## can repaint without bespoke wiring).
##
## When ProfileService reports active_id == 0 (first run or fresh install)
## this store reads/writes the legacy single-profile path so the picker /
## migration flow can boot before any profile exists.
##
## Reference: DESIGN §6.3, specs/P5_settings_store.md, specs/P16_profiles.md.

const DEFAULTS := {
	# Default locale is English so the first-run experience reads for the
	# widest possible audience; LocaleService runs the picker on first boot
	# anyway so the value is rarely surfaced. See specs/P18_i18n.md.
	"general/locale": "en",
	"general/audio_sfx": true,
	"general/audio_music": true,
	"general/haptics": true,

	"round/duration_s": 120,
	"round/speed_preset": "adaptive",

	"skills/enabled": ["add_0_20", "sub_0_20", "mul_x2", "mul_x5", "mul_x10"],

	"appearance/theme": "fruit",
}


var _config: ConfigFile = ConfigFile.new()
## Path of the file currently held in memory. Recomputed every time the
## active profile changes; cached so save() always writes back to the file
## that load() actually parsed.
var _current_path: String = ""


func _ready() -> void:
	ProfileService.active_profile_changed.connect(_on_active_profile_changed)
	_reload_for_active_profile()


# ---------------------------------------------------------------------------
# Public API (unchanged surface from P5)
# ---------------------------------------------------------------------------

## Retrieves a setting value, with type validation and defaults.
## Parses key as "section/name", validates type against DEFAULTS, falls back
## to the default on type mismatch.
func get_value(key: String, default: Variant = null) -> Variant:
	var actual_default: Variant = DEFAULTS.get(key, default)

	var parts := key.split("/")
	if parts.size() != 2:
		push_warning("SettingsStore: invalid key format '%s' (expected 'section/name')" % key)
		return actual_default

	var section: String = parts[0]
	var name: String = parts[1]

	if not _config.has_section_key(section, name):
		return actual_default

	var stored_value: Variant = _config.get_value(section, name)

	# Defensive type check — protects against a corrupted .cfg from an older
	# build silently flipping a bool to an int and breaking downstream code.
	if actual_default != null and typeof(stored_value) != typeof(actual_default):
		push_warning(
			"SettingsStore: type mismatch for '%s' (expected %s, got %s); using default."
			% [key, typeof(actual_default), typeof(stored_value)]
		)
		return actual_default

	return stored_value


## Stores a value, persists immediately, and emits EventBus.settings_changed.
func set_value(key: String, value: Variant) -> void:
	var parts := key.split("/")
	if parts.size() != 2:
		push_warning("SettingsStore: invalid key format '%s' (expected 'section/name')" % key)
		return

	_config.set_value(parts[0], parts[1], value)
	save()
	EventBus.settings_changed.emit(key, value)


## Persists current config to the active profile's settings.cfg.
func save() -> void:
	if _current_path == "":
		_current_path = ProfileService.config_path_for(ProfileService.active_id())
	var err := _config.save(_current_path)
	if err != OK:
		push_error("SettingsStore: failed to save '%s' (%s)"
			% [_current_path, error_string(err)])


## Resets all settings to DEFAULTS, persists, and emits one settings_changed
## per default key so subscribers can refresh in a single batch.
func reset_to_defaults() -> void:
	_config.clear()
	_initialize_defaults()
	save()

	for key: String in DEFAULTS.keys():
		EventBus.settings_changed.emit(key, DEFAULTS[key])


# ---------------------------------------------------------------------------
# Profile-switch plumbing
# ---------------------------------------------------------------------------

func _on_active_profile_changed(_profile_id: int) -> void:
	_reload_for_active_profile()
	# Notify subscribers that *every* known setting may have changed.
	for key: String in DEFAULTS.keys():
		EventBus.settings_changed.emit(key, get_value(key))


## Loads (or creates with defaults) the settings.cfg for the currently
## active profile. Called at boot AND on every profile switch.
func _reload_for_active_profile() -> void:
	_load_path(ProfileService.config_path_for(ProfileService.active_id()))


## Loads (or creates with defaults) the settings file at `path` and makes it
## the file save() writes to. Split out so tests can use an isolated file.
func _load_path(path: String) -> void:
	_current_path = path
	_config = ConfigFile.new()
	var err: int = _config.load(_current_path)

	if err == ERR_FILE_NOT_FOUND:
		_initialize_defaults()
		save()
		return

	if err != OK:
		push_error("SettingsStore: failed to load '%s' (%s); reverting to defaults."
			% [_current_path, error_string(err)])
		_initialize_defaults()
		return

	# Forward-compatibility: a profile created on an older build is missing
	# any keys this build added (e.g. appearance/theme). Backfill silently.
	_ensure_all_keys_exist()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _initialize_defaults() -> void:
	for key: String in DEFAULTS.keys():
		var parts := key.split("/")
		_config.set_value(parts[0], parts[1], DEFAULTS[key])


func _ensure_all_keys_exist() -> void:
	var dirty := false
	for key: String in DEFAULTS.keys():
		var parts := key.split("/")
		if not _config.has_section_key(parts[0], parts[1]):
			_config.set_value(parts[0], parts[1], DEFAULTS[key])
			dirty = true
	if dirty:
		save()
