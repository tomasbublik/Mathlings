extends GutTest
## Unit tests for the SettingsStore script, run on a private instance bound
## to user://test_settings.cfg (never the live autoload / a real profile).

const SettingsStoreScript := preload("res://scripts/autoload/settings_store.gd")
const TEST_PATH := "user://test_settings.cfg"

var settings: Node


func before_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	settings = autofree(SettingsStoreScript.new())


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)


## First run creates the file with defaults.
func test_first_run() -> void:
	settings._load_path(TEST_PATH)
	assert_true(FileAccess.file_exists(TEST_PATH), "Settings file should be created on first run.")
	for key: String in SettingsStoreScript.DEFAULTS.keys():
		assert_eq(settings.get_value(key), SettingsStoreScript.DEFAULTS[key],
			"'%s' should start at its default" % key)


## Set-get roundtrip persists across a reload.
func test_set_get_roundtrip() -> void:
	settings._load_path(TEST_PATH)
	settings.set_value("round/duration_s", 60)
	assert_eq(settings.get_value("round/duration_s"), 60, "Should retrieve set value immediately")
	var reloaded: Node = autofree(SettingsStoreScript.new())
	reloaded._load_path(TEST_PATH)
	assert_eq(reloaded.get_value("round/duration_s"), 60, "Value survives a reload")
	settings.set_value("round/duration_s", SettingsStoreScript.DEFAULTS["round/duration_s"])


## set_value emits EventBus.settings_changed.
func test_signal_emitted() -> void:
	settings._load_path(TEST_PATH)
	var received := {}
	var on_changed := func(key: String, value: Variant) -> void:
		received[key] = value
	EventBus.settings_changed.connect(on_changed)
	settings.set_value("round/speed_preset", "slow")
	EventBus.settings_changed.disconnect(on_changed)
	assert_eq(received.get("round/speed_preset"), "slow")


## A file from an older build missing keys is back-filled and re-saved.
func test_migration_missing_key() -> void:
	var old_config := ConfigFile.new()
	old_config.set_value("general", "locale", "cs")
	old_config.set_value("general", "audio_sfx", true)
	old_config.save(TEST_PATH)

	settings._load_path(TEST_PATH)
	assert_eq(settings.get_value("general/locale"), "cs", "Existing values are kept")
	assert_eq(settings.get_value("general/audio_music"), true,
		"Missing key should be populated with default")
	var reloaded_config := ConfigFile.new()
	reloaded_config.load(TEST_PATH)
	assert_true(reloaded_config.has_section_key("general", "audio_music"),
		"Missing key should be persisted after load")


## A value of the wrong type falls back to the default.
func test_type_mismatch() -> void:
	var bad_config := ConfigFile.new()
	bad_config.set_value("round", "duration_s", "120")  # string instead of int
	bad_config.save(TEST_PATH)
	settings._load_path(TEST_PATH)
	assert_eq(settings.get_value("round/duration_s"), 120,
		"Should return default when type mismatches")
