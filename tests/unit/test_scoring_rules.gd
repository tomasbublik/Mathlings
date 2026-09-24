## GUT unit tests for ScoringRules.
## Pins the JSON contract, the safety-net fallbacks, and the math that
## GameController relies on. Whenever scoring_rules.json changes, the tier
## tests should be the first thing to look at.

extends GutTest


# ---------------------------------------------------------------------------
# load_default
# ---------------------------------------------------------------------------

func test_load_default_succeeds_against_bundled_json() -> void:
	var rules := ScoringRules.load_default()
	assert_eq(rules.version, ScoringRules.SUPPORTED_SCHEMA_VERSION)
	assert_eq(rules.base_points, 10)
	assert_eq(rules.combo_tiers.size(), 3,
		"bundled JSON must keep three combo tiers (3, 5, 10)")
	assert_eq(int(rules.combo_tiers[0]["min_streak"]), 3)
	assert_almost_eq(float(rules.combo_tiers[0]["multiplier"]), 1.25, 0.001)


func test_load_missing_path_returns_safe_defaults() -> void:
	var rules := ScoringRules.load_from("res://nope/does_not_exist.json")
	assert_eq(rules.base_points, ScoringRules.DEFAULT_BASE_POINTS)
	assert_eq(rules.combo_tiers.size(), ScoringRules.DEFAULT_COMBO_TIERS.size(),
		"safety-net combo tiers must be present when JSON is missing")


# ---------------------------------------------------------------------------
# combo_for_streak
# ---------------------------------------------------------------------------

func test_combo_for_streak_below_first_tier_returns_one() -> void:
	var rules := ScoringRules.load_default()
	assert_almost_eq(rules.combo_for_streak(0), 1.0, 0.001)
	assert_almost_eq(rules.combo_for_streak(2), 1.0, 0.001)


func test_combo_for_streak_at_each_threshold() -> void:
	var rules := ScoringRules.load_default()
	assert_almost_eq(rules.combo_for_streak(3), 1.25, 0.001)
	assert_almost_eq(rules.combo_for_streak(4), 1.25, 0.001)
	assert_almost_eq(rules.combo_for_streak(5), 1.5, 0.001)
	assert_almost_eq(rules.combo_for_streak(9), 1.5, 0.001)
	assert_almost_eq(rules.combo_for_streak(10), 2.0, 0.001)
	assert_almost_eq(rules.combo_for_streak(99), 2.0, 0.001,
		"highest tier persists for arbitrarily long streaks")


# ---------------------------------------------------------------------------
# points_for_correct (mirrors GameController behavior)
# ---------------------------------------------------------------------------

func test_points_for_first_correct_is_base() -> void:
	var rules := ScoringRules.load_default()
	assert_eq(rules.points_for_correct(1), 10)


func test_eleven_streak_total_matches_game_controller() -> void:
	# Same expected total as test_scoring_combo_eleven_correct in
	# test_game_controller.gd. If this drifts, the rules JSON or the
	# round() semantics changed.
	var rules := ScoringRules.load_default()
	var total: int = 0
	for s in range(1, 12):
		total += rules.points_for_correct(s)
	assert_eq(total, 161,
		"11 consecutive correct answers must total 161 with default rules")


# ---------------------------------------------------------------------------
# Schema version handling
# ---------------------------------------------------------------------------

func test_unknown_schema_version_falls_back_to_defaults() -> void:
	# Write a temp JSON with a future schema version; load_from must reject it.
	var path: String = "user://test_scoring_rules_future.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 99, "base_points": 9999}')
	f = null
	var rules := ScoringRules.load_from(path)
	assert_eq(rules.base_points, ScoringRules.DEFAULT_BASE_POINTS,
		"unknown schema_version must trigger fallback, not adopt the new value")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_malformed_json_falls_back_to_defaults() -> void:
	var path: String = "user://test_scoring_rules_malformed.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not valid json")
	f = null
	var rules := ScoringRules.load_from(path)
	assert_eq(rules.base_points, ScoringRules.DEFAULT_BASE_POINTS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------------------
# Custom-tier override (synthetic rules for tests)
# ---------------------------------------------------------------------------

func test_custom_rules_alter_combo_curve() -> void:
	# Simulate a tuned ruleset by mutating an instance directly. GameController
	# can be constructed with this custom instance for what-if testing.
	var rules := ScoringRules.new()
	rules.base_points = 20
	rules.combo_tiers = [
		{ "min_streak": 2, "multiplier": 1.5 },
		{ "min_streak": 6, "multiplier": 3.0 },
	]
	assert_eq(rules.points_for_correct(1), 20)
	assert_eq(rules.points_for_correct(2), 30)
	assert_eq(rules.points_for_correct(6), 60)
