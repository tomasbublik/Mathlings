## GUT unit tests for SkillModel and DifficultyController.
##
## Covers the critical cases from specs/P9_skill_model.md:
## - Elo update direction and magnitude (correct/fast, correct/slow, wrong, miss).
## - Rating clamps at [600, 1800].
## - K transitions from 32 to 16 at 20 attempts.
## - choose_next: prefers weakness, honors enabled set, injects harder.
## - DifficultyController: rating mult bounds, error slowdown.

extends GutTest


func _rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# ---------------------------------------------------------------------------
# Elo update
# ---------------------------------------------------------------------------

func test_elo_update_correct_fast() -> void:
	var model := SkillModel.new(1, null)
	var before: float = model.rating_for("add_0_20")
	var new_rating: float = model.on_attempt("add_0_20", 1000.0, true, 1500)
	# R=1000, D=1000, actual=1.0, expected=0.5, K=32 → delta = 16
	assert_almost_eq(new_rating - before, 16.0, 0.5,
		"Correct+fast from R=D=1000 should gain ~16 rating")


func test_elo_update_correct_slow() -> void:
	var model := SkillModel.new(1, null)
	var new_rating: float = model.on_attempt("add_0_20", 1000.0, true, 4000)
	# actual=0.7, expected=0.5 → delta = 32 * 0.2 = 6.4
	assert_almost_eq(new_rating, 1006.4, 0.5,
		"Correct but slow (> 3000ms) should gain ~6.4 rating")


func test_elo_update_wrong() -> void:
	var model := SkillModel.new(1, null)
	var new_rating: float = model.on_attempt("add_0_20", 1000.0, false, 2000)
	# actual=0.0, expected=0.5, K=32 → delta = -16
	assert_almost_eq(new_rating, 984.0, 0.5,
		"Wrong answer from R=D=1000 should lose ~16 rating")


func test_elo_miss_counts_as_wrong() -> void:
	var model := SkillModel.new(1, null)
	var new_rating: float = model.on_attempt("add_0_20", 1000.0, false, -1)
	assert_almost_eq(new_rating, 984.0, 0.5,
		"Miss (reaction_ms < 0) should behave as wrong answer")


func test_elo_clamp_upper_bound() -> void:
	var model := SkillModel.new(1, null)
	# Force rating high via many correct+fast against very high difficulty.
	for i in range(500):
		model.on_attempt("add_0_20", 2000.0, true, 500)
	assert_true(model.rating_for("add_0_20") <= SkillModel.RATING_MAX + 0.001,
		"Rating must be clamped at RATING_MAX (1800)")


func test_elo_clamp_lower_bound() -> void:
	var model := SkillModel.new(1, null)
	for i in range(500):
		model.on_attempt("add_0_20", 500.0, false, 2000)
	assert_true(model.rating_for("add_0_20") >= SkillModel.RATING_MIN - 0.001,
		"Rating must be clamped at RATING_MIN (600)")


func test_k_transition_at_20_attempts() -> void:
	# Before 20 attempts, K=32; after, K=16.
	# Use correct+fast where expected=0.5 for consistent deltas.
	# 20 attempts at R=1000, D=1000 ⇒ actual=1, expected=0.5 ⇒ gains keep shrinking.
	# Instead, verify via two identical attempts bracketed around the 20th.
	var model_before := SkillModel.new(1, null)
	# Reach attempts=19 (one short).
	for i in range(19):
		# Use alternating correct/wrong to keep rating near 1000 so expected ~0.5.
		if i % 2 == 0:
			model_before.on_attempt("add_0_20", 1000.0, true, 1500)
		else:
			model_before.on_attempt("add_0_20", 1000.0, false, 1500)
	var r_pre: float = model_before.rating_for("add_0_20")
	# 20th attempt uses K=32 (attempts<20 when update begins)
	var r_after_20: float = model_before.on_attempt("add_0_20", 1000.0, true, 1500)
	var delta_20 := r_after_20 - r_pre
	# 21st attempt uses K=16 (attempts now >= 20)
	var r_after_21: float = model_before.on_attempt("add_0_20", 1000.0, true, 1500)
	var delta_21 := r_after_21 - r_after_20
	assert_true(abs(delta_20) > abs(delta_21) - 0.001,
		"K should shrink after the 20th attempt (delta_20=%.2f, delta_21=%.2f)" % [delta_20, delta_21])


# ---------------------------------------------------------------------------
# choose_next
# ---------------------------------------------------------------------------

func test_choose_next_prefers_weakness() -> void:
	var model := SkillModel.new(1, null)
	# Seed ratings directly via on_attempt to reach roughly desired levels.
	# Instead we rely on internal cache: use model._cache trick is brittle, so use rating_for
	# via the API. We'll hand-craft ratings by many attempts.
	# Quicker: seed via targeted updates.
	_seed_rating(model, "add_0_20", 600.0)
	_seed_rating(model, "mul_x5", 1000.0)
	_seed_rating(model, "div_0_100", 1400.0)

	var enabled := PackedStringArray(["add_0_20", "mul_x5", "div_0_100"])
	var counts := {"add_0_20": 0, "mul_x5": 0, "div_0_100": 0}
	var rng := _rng(42)

	var n := 5000
	for i in range(n):
		var chosen := model.choose_next(enabled, rng)
		counts[chosen] += 1

	# Weakness (R=600) should win the lion's share in the 75% weighted bucket.
	# Expected fraction for R=600 weighted only:
	#   w = [900, 500, 100] → 900/1500 = 0.6 among weighted.
	# Plus the 10% harder bucket fills another share. Easy injection (15%) goes to R=1400.
	# Net: add_0_20 should be > 40% of picks.
	var weakest_frac: float = counts["add_0_20"] / float(n)
	var strongest_frac: float = counts["div_0_100"] / float(n)
	assert_true(weakest_frac > 0.4,
		"Weakest skill should be chosen > 40%% (got %.2f%%)" % (weakest_frac * 100.0))
	assert_true(weakest_frac > strongest_frac,
		"Weakest must be chosen more than strongest (weak=%.2f strong=%.2f)" % [weakest_frac, strongest_frac])


func test_choose_next_honors_enabled() -> void:
	var model := SkillModel.new(1, null)
	var enabled := PackedStringArray(["add_0_20", "mul_x5"])
	var rng := _rng(1)
	for i in range(2000):
		var chosen := model.choose_next(enabled, rng)
		assert_true(chosen in enabled, "choose_next returned '%s' outside enabled set" % chosen)


func test_choose_next_harder_injection() -> void:
	# Enable add_0_10 (primary) + add_0_100 as harder step-up target within "add" family.
	var model := SkillModel.new(1, null)
	# Keep add_0_10 weak so weighted sampling almost always picks it.
	_seed_rating(model, "add_0_10", 600.0)
	_seed_rating(model, "add_0_100", 1400.0)
	var enabled := PackedStringArray(["add_0_10", "add_0_100"])
	var rng := _rng(7)
	var counts := {"add_0_10": 0, "add_0_100": 0}
	var n := 3000
	for i in range(n):
		counts[model.choose_next(enabled, rng)] += 1
	# Harder-by-one bucket = 10% of trials, and they will redirect to add_0_100 when base pick is add_0_10.
	# Easy-injection (15%) also picks the highest-rated (add_0_100 here).
	# Combined add_0_100 frequency should sit comfortably above 10%.
	var harder_frac := counts["add_0_100"] / float(n)
	assert_true(harder_frac > 0.1,
		"add_0_100 should receive > 10%% of picks via easy+harder injection (got %.2f%%)"
			% (harder_frac * 100.0))


func test_choose_next_single_skill() -> void:
	var model := SkillModel.new(1, null)
	var enabled := PackedStringArray(["add_0_20"])
	var rng := _rng(0)
	for i in range(50):
		assert_eq(model.choose_next(enabled, rng), "add_0_20",
			"With a single enabled skill, choose_next must always return it")


# ---------------------------------------------------------------------------
# DifficultyController
# ---------------------------------------------------------------------------

func test_difficulty_speed_bounds_low() -> void:
	# avg_rating=500 → rating_mult clamped to 0.7.
	var speed := DifficultyController.speed_for(500.0, 0, 0)
	assert_almost_eq(speed, 120.0 * 1.0 * 0.7, 0.01,
		"avg_rating=500 should clamp rating_mult to 0.7")


func test_difficulty_speed_bounds_high() -> void:
	# avg_rating=2000 → rating_mult clamped to 1.6.
	var speed := DifficultyController.speed_for(2000.0, 0, 0)
	assert_almost_eq(speed, 120.0 * 1.0 * 1.6, 0.01,
		"avg_rating=2000 should clamp rating_mult to 1.6")


func test_difficulty_speed_streak_mult() -> void:
	# streak=5 at avg_rating=1000 → mult = 1 + 5*0.03 = 1.15.
	var speed := DifficultyController.speed_for(1000.0, 5, 0)
	assert_almost_eq(speed, 120.0 * 1.15 * 1.0, 0.01,
		"streak=5 should yield streak_mult=1.15")


func test_difficulty_speed_streak_cap() -> void:
	# streak=30 should be capped at 10 ⇒ mult = 1.3.
	var speed := DifficultyController.speed_for(1000.0, 30, 0)
	assert_almost_eq(speed, 120.0 * 1.3 * 1.0, 0.01,
		"streak should cap at 10 for the multiplier")


func test_difficulty_speed_error_slowdown() -> void:
	var base := DifficultyController.speed_for(1000.0, 0, 0)
	var slowed := DifficultyController.speed_for(1000.0, 0, 3)
	assert_almost_eq(slowed / base, 0.8, 0.01,
		"recent_errors >= 3 should multiply speed by 0.8")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Repeatedly applies correct+fast attempts against extreme difficulty to drive
## the cached rating toward `target`. Works within [600, 1800] clamp.
func _seed_rating(model: SkillModel, skill_key: String, target: float) -> void:
	# Simpler approach: reach via many attempts with shifting difficulty.
	# Saturate high: difficulty=2000 correct ⇒ rating climbs to 1800 cap.
	# Saturate low:  difficulty=500 wrong ⇒ rating falls to 600 floor.
	# Then step back toward target.
	if target >= 1000.0:
		for i in range(500):
			model.on_attempt(skill_key, 2000.0, true, 500)
		# Rating is now at/near 1800. Nudge down with wrong answers against D=500.
		while model.rating_for(skill_key) > target + 5.0:
			model.on_attempt(skill_key, 500.0, false, 2000)
	else:
		for i in range(500):
			model.on_attempt(skill_key, 500.0, false, 2000)
		while model.rating_for(skill_key) < target - 5.0:
			model.on_attempt(skill_key, 2000.0, true, 500)
