## GUT unit tests for HudFormat — the in-game HUD's pure formatting and
## threshold helpers (timer text, urgency window, combo badge text/tier,
## portrait UI scale).

extends GutTest


func test_timer_seconds_rounds_up_and_clamps() -> void:
	assert_eq(HudFormat.timer_seconds(9.2), 10)
	assert_eq(HudFormat.timer_seconds(10.0), 10)
	assert_eq(HudFormat.timer_seconds(0.0), 0)
	assert_eq(HudFormat.timer_seconds(-3.0), 0)


func test_timer_text_formats_minutes_and_padded_seconds() -> void:
	assert_eq(HudFormat.timer_text(120), "2:00")
	assert_eq(HudFormat.timer_text(75), "1:15")
	assert_eq(HudFormat.timer_text(9), "0:09")
	assert_eq(HudFormat.timer_text(-1), "0:00")


func test_urgent_only_in_final_ten_seconds() -> void:
	assert_false(HudFormat.is_urgent(11))
	assert_true(HudFormat.is_urgent(10))
	assert_true(HudFormat.is_urgent(1))
	assert_false(HudFormat.is_urgent(0), "time's up is not 'urgent' any more")


func test_combo_text_strips_trailing_zeros() -> void:
	assert_eq(HudFormat.combo_text(1.5), "×1.5")
	assert_eq(HudFormat.combo_text(2.0), "×2")
	assert_eq(HudFormat.combo_text(1.25), "×1.25")


func test_points_text_shows_multiplier_only_when_boosted() -> void:
	assert_eq(HudFormat.points_text(10, 1.0), "+10")
	assert_eq(HudFormat.points_text(15, 1.5), "+15 ×1.5")


func test_combo_tier_grows_with_multiplier() -> void:
	assert_eq(HudFormat.combo_tier(1.25), 0)
	assert_eq(HudFormat.combo_tier(1.5), 1)
	assert_eq(HudFormat.combo_tier(2.0), 2)
	assert_eq(HudFormat.combo_tier(3.0), 2)


func test_ui_scale_is_one_in_landscape() -> void:
	assert_eq(HudFormat.ui_scale(Vector2(1280, 720)), 1.0)
	assert_eq(HudFormat.ui_scale(Vector2(1600, 720)), 1.0)
	assert_eq(HudFormat.ui_scale(Vector2(1280, 800)), 1.0)


func test_ui_scale_grows_in_portrait_but_is_capped() -> void:
	assert_almost_eq(HudFormat.ui_scale(Vector2(1280, 1600)), 1.25, 0.001)
	assert_eq(HudFormat.ui_scale(Vector2(1280, 2276)), 1.7)
	assert_eq(HudFormat.ui_scale(Vector2(0, 0)), 1.0)
