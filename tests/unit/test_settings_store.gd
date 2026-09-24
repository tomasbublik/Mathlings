extends GutTest
## Unit tests for SettingsStore autoload.

var settings: Node
var test_config_path: String = "user://test_settings.cfg"

func before_each() -> void:
	# Create a fresh instance for each test
	settings = SettingsStore.new()
	# Override path for isolation
	settings.PATH = test_config_path
	# Clean up any previous test file
	if ResourceLoader.exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)

func after_each() -> void:
	if settings:
		settings.queue_free()
	# Clean up test file
	if ResourceLoader.exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)

## Test 1: First run creates file with defaults.
func test_first_run() -> void:
	settings._ready()

	assert_file_exists(test_config_path, "Settings file should be created on first run.")

	var locale: String = settings.get_value("general/locale")
	assert_eq(locale, "cs_CZ", "Locale should default to cs_CZ")

	var duration: int = settings.get_value("round/duration_s")
	assert_eq(duration, 120, "Duration should default to 120")

	var enabled_skills: Array = settings.get_value("skills/enabled")
	assert_eq(
		enabled_skills,
		["add_0_20", "sub_0_20", "mul_x2", "mul_x5", "mul_x10"],
		"Enabled skills should match defaults"
	)

## Test 2: Set-get roundtrip persists across save.
func test_set_get_roundtrip() -> void:
	settings._ready()

	settings.set_value("round/duration_s", 60)
	var retrieved: int = settings.get_value("round/duration_s")
	assert_eq(retrieved, 60, "Should retrieve set value immediately")

	# Verify file was saved
	assert_file_exists(test_config_path, "Settings should be saved to file after set_value")

## Test 3: set_value emits settings_changed signal.
func test_signal_emitted() -> void:
	settings._ready()

	var signal_received: bool = false
	var received_key: String = ""
	var received_value: Variant = null

	EventBus.settings_changed.connect(func(key: String, value: Variant) -> void:
		signal_received = true
		received_key = key
		received_value = value
	)

	settings.set_value("general/audio_sfx", false)

	assert_true(signal_received, "settings_changed signal should be emitted")
	assert_eq(received_key, "general/audio_sfx", "Signal should include correct key")
	assert_eq(received_value, false, "Signal should include correct value")

## Test 4: Missing key in file is populated with default on load (forward compat).
func test_migration_missing_key() -> void:
	# Create a config file missing a key
	var old_config: ConfigFile = ConfigFile.new()
	old_config.set_value("general", "locale", "cs_CZ")
	old_config.set_value("general", "audio_sfx", true)
	# Intentionally skip "audio_music" and others
	old_config.save(test_config_path)

	# Load and check
	settings._ready()

	var audio_music: bool = settings.get_value("general/audio_music")
	assert_eq(audio_music, true, "Missing key should be populated with default")

	# Verify it was saved
	var reloaded_config: ConfigFile = ConfigFile.new()
	reloaded_config.load(test_config_path)
	assert_true(
		reloaded_config.has_section_key("general", "audio_music"),
		"Missing key should be persisted after load"
	)

## Test 5: Type mismatch returns default with warning.
func test_type_mismatch() -> void:
	# Create a config with type mismatch: store string instead of int
	var bad_config: ConfigFile = ConfigFile.new()
	bad_config.set_value("round", "duration_s", "120")  # string instead of int
	bad_config.save(test_config_path)

	settings._ready()

	var duration: int = settings.get_value("round/duration_s")
	assert_eq(duration, 120, "Should return default when type mismatches")
	# Note: push_warning is called but GUT doesn't capture warnings directly
	# A log assertion or manual check would be needed for full coverage.

# Helper: Check if file exists
func assert_file_exists(path: String, message: String) -> void:
	var exists: bool = ResourceLoader.exists(path)
	assert_true(exists, message)
