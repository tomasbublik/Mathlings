## GUT unit tests for the Problem Dictionary contract (DESIGN §7.1).
## Problem.is_valid() is the single source of truth for what a "good" Problem looks
## like — so these tests pin down both the happy path and every reject branch.

extends GutTest


func _good_problem() -> Dictionary:
	return {
		"id": 1,
		"skill_key": "add_0_20",
		"expression": "7 + 5",
		"correct_answer": 12,
		"choices": [12, 13, 10],
		"correct_index": 0,
		"difficulty": 1000.0,
	}


func test_well_formed_problem_is_valid() -> void:
	assert_true(Problem.is_valid(_good_problem()))


func test_missing_required_key_is_invalid() -> void:
	for key in Problem.REQUIRED_KEYS:
		var p: Dictionary = _good_problem()
		p.erase(key)
		assert_false(Problem.is_valid(p),
			"missing required key '%s' must invalidate the Problem" % key)


func test_choices_must_have_size_three() -> void:
	var p: Dictionary = _good_problem()
	p["choices"] = [12, 13]
	assert_false(Problem.is_valid(p), "fewer than 3 choices must be invalid")
	p["choices"] = [12, 13, 10, 11]
	assert_false(Problem.is_valid(p), "more than 3 choices must be invalid")


func test_correct_index_out_of_range_is_invalid() -> void:
	var p: Dictionary = _good_problem()
	p["correct_index"] = 3
	assert_false(Problem.is_valid(p), "correct_index >= 3 must be invalid")
	p["correct_index"] = -1
	assert_false(Problem.is_valid(p), "correct_index < 0 must be invalid")


func test_correct_index_must_point_to_correct_answer() -> void:
	# choices = [12, 13, 10], correct_index = 1 → choices[1] = 13 ≠ correct_answer (12).
	var p: Dictionary = _good_problem()
	p["correct_index"] = 1
	assert_false(Problem.is_valid(p),
		"correct_index must point to the slot whose value equals correct_answer")


func test_negative_choice_is_invalid() -> void:
	var p: Dictionary = _good_problem()
	p["choices"] = [12, -1, 10]
	assert_false(Problem.is_valid(p), "negative numbers in choices are invalid")


func test_duplicate_choices_are_invalid() -> void:
	var p: Dictionary = _good_problem()
	p["choices"] = [12, 12, 10]
	p["correct_index"] = 0
	assert_false(Problem.is_valid(p), "duplicate values in choices must be rejected")


func test_difficulty_table_covers_all_supported_skills() -> void:
	for key in ProblemGenerator.supported_skills():
		assert_true(Problem.DIFFICULTY.has(key),
			"DIFFICULTY map must contain every supported skill, missing '%s'" % key)
