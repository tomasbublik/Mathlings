## GUT unit tests for SkillLabels.
##
## After P18, labels are resolved through TranslationServer instead of a
## hardcoded Czech Dictionary. Tests focus on the *contract* rather than
## any specific locale's wording — exact strings live in the CSV and
## change per locale, so pinning them here would just create churn.

extends GutTest


func test_translation_keys_cover_every_supported_skill() -> void:
	# Adding a new skill to ProblemGenerator without wiring a CSV row would
	# silently render the raw machine key in Settings. This test fails fast
	# with a clear message when that happens.
	for key in ProblemGenerator.supported_skills():
		assert_true(SkillLabels.TRANSLATION_KEYS.has(key),
			"supported skill '%s' is missing a translation key in SkillLabels" % key)


func test_label_for_known_skill_returns_translated_string() -> void:
	# We can't predict which locale the test harness will run in, but we
	# *can* assert the returned string isn't the raw translation key (i.e.
	# the CSV pipeline is wired up).
	var label := SkillLabels.label_for("add_0_20")
	var raw_key := SkillLabels.TRANSLATION_KEYS["add_0_20"]
	assert_ne(label, raw_key,
		"label_for('add_0_20') must be translated, not return the raw key '%s'" % raw_key)
	assert_ne(label, "",
		"label must never be empty for a known skill")


func test_unknown_skill_key_falls_through_to_input() -> void:
	# Contract: unknown skills return their machine key unchanged so the
	# bug is *visible* in the UI rather than silently rendering empty.
	assert_eq(SkillLabels.label_for("not_a_real_skill"), "not_a_real_skill")
	assert_eq(SkillLabels.label_for(""), "")


func test_translation_keys_use_consistent_shape() -> void:
	# Every value in TRANSLATION_KEYS must follow the SKILL_<KEY> convention
	# the CSV expects. Catches typos like "SKL_MUL_X5" before they ship.
	for skill_key in SkillLabels.TRANSLATION_KEYS.keys():
		var translation_key: String = SkillLabels.TRANSLATION_KEYS[skill_key]
		assert_true(translation_key.begins_with("SKILL_"),
			"translation key '%s' must start with SKILL_" % translation_key)
		assert_eq(translation_key.to_upper(), translation_key,
			"translation key '%s' must be UPPER_SNAKE_CASE" % translation_key)
