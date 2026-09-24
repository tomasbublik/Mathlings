## GUT unit tests for the Mascot component: mood validation/fallback, layer
## table integrity (every referenced SVG exists) and the aspect-fit helper.

extends GutTest

const MASCOT_SCENE := "res://scenes/shared/mascot.tscn"


func test_required_moods_are_valid() -> void:
	for m: StringName in [&"idle", &"happy", &"cheer", &"think", &"oops"]:
		assert_true(Mascot.is_valid_mood(m), "mood '%s' must exist" % m)


func test_unknown_mood_falls_back_to_idle() -> void:
	assert_eq(Mascot.normalize_mood(&"furious"), Mascot.MOOD_IDLE)
	assert_eq(Mascot.normalize_mood(&""), Mascot.MOOD_IDLE)
	assert_eq(Mascot.normalize_mood(&"cheer"), Mascot.MOOD_CHEER)
	assert_eq(Mascot.layers_for(&"nope"), Mascot.MOODS[Mascot.MOOD_IDLE])


func test_every_mood_defines_all_layer_slots() -> void:
	for m: StringName in Mascot.MOODS:
		var l: Dictionary = Mascot.MOODS[m]
		for key: String in ["eyes", "mouth", "arms", "fx"]:
			assert_true(l.has(key), "mood '%s' is missing '%s'" % [m, key])
		assert_ne(l["eyes"], "", "mood '%s' needs eyes" % m)
		assert_ne(l["mouth"], "", "mood '%s' needs a mouth" % m)
		assert_ne(l["arms"], "", "mood '%s' needs arms" % m)


func test_every_layer_file_exists() -> void:
	var names := Mascot.all_layer_names()
	assert_true(names.has("eyes_closed"), "blink layer must be part of the set")
	for n: String in names:
		assert_true(ResourceLoader.exists(Mascot.layer_path(n)),
			"missing mascot layer %s" % Mascot.layer_path(n))


func test_blinking_only_for_moods_with_open_eyes() -> void:
	assert_true(Mascot.can_blink(&"idle"))
	assert_true(Mascot.can_blink(&"oops"))
	assert_false(Mascot.can_blink(&"cheer"), "^^ eyes are already closed")


func test_blink_delay_within_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var d := Mascot.next_blink_delay(rng)
		assert_between(d, Mascot.BLINK_MIN, Mascot.BLINK_MAX)


func test_fit_square_keeps_aspect_and_centres() -> void:
	assert_eq(Mascot.fit_square(Vector2(300, 100)), Rect2(100, 0, 100, 100))
	assert_eq(Mascot.fit_square(Vector2(80, 200)), Rect2(0, 60, 80, 80))
	assert_eq(Mascot.fit_square(Vector2(64, 64)), Rect2(0, 0, 64, 64))


func test_scene_set_mood_normalises_invalid_values() -> void:
	var m: Mascot = load(MASCOT_SCENE).instantiate()
	add_child_autofree(m)
	m.set_mood(&"cheer")
	assert_eq(m.mood, &"cheer")
	m.set_mood(&"sleepy")
	assert_eq(m.mood, Mascot.MOOD_IDLE, "unknown mood must fall back to idle")
	m.mood = &"think"
	assert_eq(m.mood, &"think", "exported property routes through set_mood")
