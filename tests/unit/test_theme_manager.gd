## GUT unit tests for ThemeManager.
## Avoids mutating global SettingsStore state — only reads metadata that's
## independent of the persisted "appearance/theme" key.

extends GutTest


func test_themes_dictionary_is_non_empty() -> void:
	assert_true(ThemeManager.THEMES.size() >= 1,
		"at least one theme must be registered")


func test_default_theme_key_is_in_catalog() -> void:
	assert_true(ThemeManager.THEMES.has(ThemeManager.DEFAULT_THEME),
		"DEFAULT_THEME must point to a key registered in THEMES")


func test_each_theme_has_required_metadata() -> void:
	# Contract: every theme exposes the keys consumed by callers.
	var required: Array[String] = [
		"label", "background", "skins", "game_music",
		"vertical_direction", "default_unlocked",
	]
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		for key in required:
			assert_true(meta.has(key),
				"theme '%s' is missing required key '%s'" % [theme_key, key])


func test_default_unlocked_themes_are_always_available() -> void:
	# Profile id 0 is sentinel for "no profile / no DB"; default_unlocked themes
	# must still be reachable.
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		if bool(meta.get("default_unlocked", false)):
			assert_true(ThemeManager.is_available(theme_key, 0),
				"default-unlocked theme '%s' must be available without DB" % theme_key)


func test_is_available_rejects_unknown_themes() -> void:
	assert_false(ThemeManager.is_available("nope_not_real", 1))


func test_available_keys_includes_all_default_unlocked() -> void:
	# Without a real DB, only default_unlocked entries are reported.
	var available := ThemeManager.available_keys(0)
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		if bool(meta.get("default_unlocked", false)):
			assert_true(theme_key in available,
				"available_keys must include default-unlocked theme '%s'" % theme_key)


func test_current_skin_textures_returns_existing_assets() -> void:
	# All bundled skin paths in THEMES should be loadable from res://. We don't
	# check pixel content — only that load() doesn't return null.
	var textures := ThemeManager.current_skin_textures()
	assert_true(textures.size() >= 1,
		"current theme must yield at least one valid skin texture")


func test_current_skin_entries_have_texture_and_splash() -> void:
	# Schema contract introduced in P19: every skin row must be a Dictionary
	# with `texture` (path) and `splash` (Color). Tests would silently miss
	# typos in the catalog without this guard.
	for theme_key: String in ThemeManager.THEMES.keys():
		var entries: Array = ThemeManager.THEMES[theme_key].get("skins", [])
		assert_true(entries.size() >= 1,
			"theme '%s' must declare at least one skin" % theme_key)
		for entry in entries:
			assert_true(entry is Dictionary,
				"every skin entry must be a Dictionary in theme '%s'" % theme_key)
			var d: Dictionary = entry
			assert_true(d.has("texture"),
				"skin entry in '%s' missing 'texture'" % theme_key)
			assert_true(d.has("splash"),
				"skin entry in '%s' missing 'splash'" % theme_key)
			assert_true(d["splash"] is Color,
				"splash for '%s' must be a Color, got %s"
					% [theme_key, typeof(d["splash"])])


func test_random_skin_for_current_returns_valid_entry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var skin := ThemeManager.random_skin_for_current(rng)
	assert_true(skin.has("texture"))
	assert_true(skin.has("splash"))
	assert_true(skin["splash"] is Color)


func test_random_skin_is_stable_for_seeded_rng() -> void:
	# Determinism check — same seed must yield the same picks (essential for
	# regression-test reproducibility in higher-level scenes).
	var a := RandomNumberGenerator.new(); a.seed = 42
	var b := RandomNumberGenerator.new(); b.seed = 42
	for _i in range(5):
		var pa := ThemeManager.random_skin_for_current(a)
		var pb := ThemeManager.random_skin_for_current(b)
		assert_eq(pa.get("splash"), pb.get("splash"),
			"identical RNG seeds must produce identical skin picks")


func test_current_vertical_direction_is_plus_or_minus_one() -> void:
	var dir := ThemeManager.current_vertical_direction()
	assert_true(dir == 1 or dir == -1,
		"vertical_direction must be ±1 (got %d)" % dir)


func test_current_game_music_key_resolves_in_audio_catalog() -> void:
	var music_key := ThemeManager.current_game_music_key()
	assert_true(AudioCatalog.MUSIC.has(music_key),
		"theme's game_music key '%s' must exist in AudioCatalog.MUSIC" % music_key)


# ---------------------------------------------------------------------------
# P20: theme-aware SFX chain + explosion scene
# ---------------------------------------------------------------------------

func test_correct_sfx_chain_keys_resolve_in_audio_catalog() -> void:
	# Each chain entry points at an SFX file we actually ship — catches typos
	# in the catalog ("space_xplosion" → silence on hit) without needing a
	# real Android device.
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		var chain: Array = meta.get("correct_sfx_chain",
			ThemeManager.DEFAULT_CORRECT_CHAIN)
		for entry in chain:
			var key: String = String(entry.get("key", ""))
			assert_true(AudioCatalog.SFX.has(key),
				"theme '%s' chain references SFX key '%s' that AudioCatalog doesn't expose"
					% [theme_key, key])


func test_default_chain_is_single_correct() -> void:
	# Themes without an override fall back to the legacy single "correct"
	# beep — pinning this prevents accidentally dragging space-only chain
	# behaviour onto fruit / balloons.
	var meta: Dictionary = ThemeManager.THEMES["fruit"]
	var chain: Array = meta.get("correct_sfx_chain", ThemeManager.DEFAULT_CORRECT_CHAIN)
	assert_eq(chain.size(), 1)
	assert_eq(String(chain[0].get("key", "")), "correct")


func test_space_chain_is_lightsaber_then_explosion() -> void:
	var chain: Array = ThemeManager.THEMES["space"]["correct_sfx_chain"]
	assert_eq(chain.size(), 2, "space theme must mix two SFX")
	assert_eq(String(chain[0].get("key", "")), "lightsaber")
	assert_eq(int(chain[0].get("delay_ms", -1)), 0,
		"lightsaber must hit on the answer (delay 0)")
	assert_eq(String(chain[1].get("key", "")), "space_explosion")
	assert_true(int(chain[1].get("delay_ms", 0)) > 0,
		"space_explosion must come after lightsaber, not at the same instant")


func test_explosion_scene_paths_exist() -> void:
	# Every theme-overridden scene must actually be loadable from res://.
	for theme_key: String in ThemeManager.THEMES.keys():
		var meta: Dictionary = ThemeManager.THEMES[theme_key]
		if not meta.has("explosion_scene"):
			continue
		var path: String = String(meta["explosion_scene"])
		assert_true(ResourceLoader.exists(path),
			"theme '%s' references non-existent explosion scene '%s'"
				% [theme_key, path])


func test_default_explosion_scene_exists() -> void:
	assert_true(ResourceLoader.exists(ThemeManager.DEFAULT_EXPLOSION_SCENE))
