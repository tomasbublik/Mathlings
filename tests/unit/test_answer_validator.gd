## GUT unit tests for AnswerValidator.
## AnswerValidator is a thin static helper — these tests document the contract
## and guard against regressions in the few branches it exposes.

extends GutTest


func _problem(correct_index: int, choices: Array = [10, 12, 13]) -> Dictionary:
	return {
		"id": 1,
		"skill_key": "add_0_20",
		"expression": "5 + 7",
		"correct_answer": 12,
		"choices": choices,
		"correct_index": correct_index,
		"difficulty": 1000.0,
	}


func test_returns_true_for_matching_index() -> void:
	assert_true(AnswerValidator.is_correct(_problem(1), 1),
		"chosen_index equal to correct_index → true")


func test_returns_false_for_other_index() -> void:
	assert_false(AnswerValidator.is_correct(_problem(1), 0))
	assert_false(AnswerValidator.is_correct(_problem(1), 2))


func test_miss_index_minus_one_is_false() -> void:
	# A miss is encoded as chosen_index = -1; never correct.
	assert_false(AnswerValidator.is_correct(_problem(0), -1),
		"chosen_index = -1 (miss) is never correct")


func test_missing_correct_index_returns_false() -> void:
	# Defensive: if a Dictionary skips correct_index we must not crash.
	var malformed: Dictionary = {"choices": [1, 2, 3]}
	assert_false(AnswerValidator.is_correct(malformed, 0),
		"missing correct_index key returns false rather than throwing")


func test_out_of_range_index_returns_false() -> void:
	# Validator does not enforce bounds — but a wildly out-of-range index can
	# never equal a valid correct_index ∈ {0,1,2}.
	assert_false(AnswerValidator.is_correct(_problem(0), 99))
