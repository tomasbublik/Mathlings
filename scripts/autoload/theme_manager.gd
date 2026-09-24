extends Node
## Central theme registry + current selection.
##
## Each theme bundles:
##   • A background Texture2D
##   • One or more "skins" — the visual representation of a falling problem.
##     Every skin entry is a Dictionary with:
##         { "texture": String  (res:// path),
##           "splash":  Color   (per-skin explosion / splatter palette) }
##     The split lets a watermelon explode in red even though its outer
##     skin is green, etc.
##   • A `game_music` key resolved through AudioCatalog
##   • A `vertical_direction` (+1 = falls down, -1 = floats up — balloons)
##   • A `default_unlocked` flag — when false the player has to earn the
##     theme via the unlock system before it appears in Settings.
##
## Reference: specs/P12_themes.md, specs/P19_fruit_vfx.md (skins schema).

signal theme_changed(theme_key: String)

## Convenience: cream highlight used when a fruit has no specific palette
## (or callers pass an unknown skin texture path).
const FALLBACK_SPLASH := Color(1.0, 0.92, 0.6)

## Default success SFX chain — themes without a `correct_sfx_chain` key fall
## back to a single in-place "correct" sound (matches pre-P20 behaviour).
const DEFAULT_CORRECT_CHAIN: Array = [
	{"key": "correct", "delay_ms": 0},
]

## Default explosion scene used when a theme doesn't override it. Currently
## the colourful fruit explosion (which works fine for non-themed builds).
const DEFAULT_EXPLOSION_SCENE: String = "res://scenes/game/vfx/fruit_explosion.tscn"

const THEMES: Dictionary = {
	"fruit": {
		"label": "Ovoce",
		"background": "res://assets/images/backgrounds/bg_sky.svg",
		"skins": [
			# Each entry: { texture: res://, splash: Color (interior flesh hue) }.
			# The splash matches what the *inside* of the fruit would look like
			# when burst — so a green watermelon erupts in juicy red.
			{"texture": "res://assets/images/skins/skin_apple.svg",
			 "splash": Color(1.00, 0.95, 0.70)},   # apple → cream-yellow flesh
			{"texture": "res://assets/images/skins/skin_banana.svg",
			 "splash": Color(1.00, 0.92, 0.55)},   # banana → pale yellow
			{"texture": "res://assets/images/skins/skin_pear.svg",
			 "splash": Color(0.97, 0.97, 0.80)},   # pear → off-white flesh
			{"texture": "res://assets/images/skins/skin_strawberry.svg",
			 "splash": Color(0.95, 0.45, 0.55)},   # strawberry → bright pink
			{"texture": "res://assets/images/skins/skin_blueberry.svg",
			 "splash": Color(0.65, 0.45, 0.85)},   # blueberry → light purple
			{"texture": "res://assets/images/skins/skin_orange.svg",
			 "splash": Color(1.00, 0.70, 0.30)},   # orange → bright orange
			{"texture": "res://assets/images/skins/skin_lemon.svg",
			 "splash": Color(0.98, 0.92, 0.55)},   # lemon → pale yellow flesh
			{"texture": "res://assets/images/skins/skin_watermelon.svg",
			 "splash": Color(0.95, 0.25, 0.30)},   # watermelon → red flesh
			{"texture": "res://assets/images/skins/skin_grape.svg",
			 "splash": Color(0.55, 0.85, 0.45)},   # grape → green-white flesh
			{"texture": "res://assets/images/skins/skin_peach.svg",
			 "splash": Color(1.00, 0.65, 0.50)},   # peach → orange-pink flesh
		],
		"game_music": "game",
		"vertical_direction": 1,
		"default_unlocked": true,
	},
	"space": {
		"label": "Vesmír",
		"background": "res://assets/images/backgrounds/bg_space.svg",
		"skins": [
			{"texture": "res://assets/images/skins/skin_meteor.svg",
			 "splash": Color(1.00, 0.55, 0.20)},   # meteor → glowing orange
			{"texture": "res://assets/images/skins/skin_star.svg",
			 "splash": Color(1.00, 0.92, 0.50)},   # star → bright yellow
			{"texture": "res://assets/images/skins/skin_satellite.svg",
			 "splash": Color(0.85, 0.85, 0.95)},   # satellite → silver shards
			{"texture": "res://assets/images/skins/skin_spaceship.svg",
			 "splash": Color(0.95, 0.30, 0.30)},   # rocket → engine red
			{"texture": "res://assets/images/skins/skin_ufo.svg",
			 "splash": Color(0.55, 0.85, 0.65)},   # ufo → glowing green
		],
		"game_music": "game_space",
		# Star-Wars-style success: a saber swoosh kicks in on hit, an
		# explosion lands ~350 ms later as the debris scatters.
		"correct_sfx_chain": [
			{"key": "lightsaber",      "delay_ms": 0},
			{"key": "space_explosion", "delay_ms": 350},
		],
		# Custom debris particles (rotating coloured shards) instead of the
		# fruit-style juicy splash.
		"explosion_scene": "res://scenes/game/vfx/space_explosion.tscn",
		"vertical_direction": 1,
		"default_unlocked": true,
	},
	"balloons": {
		"label": "Oslava",
		"background": "res://assets/images/backgrounds/bg_party.svg",
		"skins": [
			{"texture": "res://assets/images/skins/skin_balloon.svg",
			 "splash": Color(1.00, 0.45, 0.55)},   # popped balloon → festive pink
		],
		"game_music": "game_party",
		"vertical_direction": -1,
		"default_unlocked": true,
	},
}

const DEFAULT_THEME: String = "fruit"


func _ready() -> void:
	EventBus.settings_changed.connect(_on_settings_changed)


## Returns the currently selected theme key from settings (defaults to "fruit").
func current_key() -> String:
	var key := String(SettingsStore.get_value("appearance/theme", DEFAULT_THEME))
	return key if THEMES.has(key) else DEFAULT_THEME


## Full theme metadata Dictionary (see `THEMES` schema).
func current_theme() -> Dictionary:
	return THEMES[current_key()]


## Loads and returns the background Texture2D for the active theme.
func current_background_texture() -> Texture2D:
	return _load_texture(String(current_theme().get("background", "")))


## Loads and returns the *first* skin texture in the active theme. Mostly
## used for static previews (Settings, scene backdrops). For gameplay use
## `random_skin_for_current()` so different rounds show different fruit.
func current_skin_texture() -> Texture2D:
	var entries := current_skin_entries()
	if entries.is_empty():
		return null
	return _load_texture(String(entries[0].get("texture", "")))


## Returns every skin entry in the active theme as the raw Dictionary the
## catalog stores. Useful for tests and for callers that need both texture
## and splash color in one go.
func current_skin_entries() -> Array:
	var raw: Variant = current_theme().get("skins", [])
	if raw is Array:
		return raw
	return []


## Loaded Texture2Ds for every skin in the active theme. Keeps the order
## of `current_skin_entries()` for stable indexing in tests.
func current_skin_textures() -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for entry in current_skin_entries():
		if not (entry is Dictionary):
			continue
		var texture := _load_texture(String(entry.get("texture", "")))
		if texture != null:
			result.append(texture)
	return result


## Picks a random skin from the active theme and returns it as
##   { "texture": Texture2D, "splash": Color }
## When the theme catalog is somehow empty, returns the default fallback so
## callers (gameplay) never need to null-check.
##
## `rng` is injectable for deterministic tests.
func random_skin_for_current(rng: RandomNumberGenerator = null) -> Dictionary:
	var entries := current_skin_entries()
	if entries.is_empty():
		return {"texture": null, "splash": FALLBACK_SPLASH}

	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()

	var index: int = picker.randi_range(0, entries.size() - 1)
	var entry: Dictionary = entries[index]
	return {
		"texture": _load_texture(String(entry.get("texture", ""))),
		"splash": entry.get("splash", FALLBACK_SPLASH) as Color,
	}


func current_vertical_direction() -> int:
	return int(current_theme().get("vertical_direction", 1))


func current_game_music_key() -> String:
	return String(current_theme().get("game_music", "game"))


## Sequence of SFX to play on a correct answer. Each element is a Dictionary
## of the form `{"key": String, "delay_ms": int}`, where `delay_ms` is the
## offset from the start of the chain (not cumulative — see AudioManager.play_sfx_chain).
## Themes without an override fall back to a single instant "correct" sound.
func current_correct_sfx_chain() -> Array:
	var raw: Variant = current_theme().get("correct_sfx_chain", DEFAULT_CORRECT_CHAIN)
	if raw is Array:
		return raw
	return DEFAULT_CORRECT_CHAIN


## res:// path of the PackedScene to instantiate at the entity's position
## when an answer is correct. Themes can override per-style (Vesmír uses
## space_explosion.tscn with rotating shards).
func current_explosion_scene_path() -> String:
	return String(current_theme().get("explosion_scene", DEFAULT_EXPLOSION_SCENE))


## Persists the chosen theme via SettingsStore. Emits `theme_changed` on success.
func set_theme(theme_key: String) -> void:
	if not THEMES.has(theme_key):
		push_warning("ThemeManager.set_theme: unknown key '%s'" % theme_key)
		return
	SettingsStore.set_value("appearance/theme", theme_key)
	# settings_changed → _on_settings_changed → theme_changed emitted there.


## Returns theme keys available to the given profile. A theme is available when it
## is default-unlocked OR its key exists in `unlocks` (kind='theme') for the profile.
func available_keys(profile_id: int) -> PackedStringArray:
	var result: PackedStringArray = []
	var unlocked_set: Dictionary = {}
	if profile_id > 0 and DB.is_open():
		for row: Dictionary in UnlocksDao.get_by_kind(DB, profile_id, "theme"):
			unlocked_set[String(row.get("key", ""))] = true
	for key: String in THEMES.keys():
		var t: Dictionary = THEMES[key]
		if bool(t.get("default_unlocked", false)) or unlocked_set.has(key):
			result.append(key)
	return result


## Returns true if the profile may select this theme.
func is_available(theme_key: String, profile_id: int) -> bool:
	if not THEMES.has(theme_key):
		return false
	if bool(THEMES[theme_key].get("default_unlocked", false)):
		return true
	if profile_id <= 0 or not DB.is_open():
		return false
	return UnlocksDao.is_unlocked(DB, profile_id, "theme", theme_key)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_settings_changed(key: String, _value: Variant) -> void:
	if key == "appearance/theme":
		theme_changed.emit(current_key())


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D
