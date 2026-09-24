class_name AnswerValidator
## Thin helper: checks whether the chosen index matches a Problem's correct_index.
## Reference: DESIGN §7.1, specs/P10_game_controller.md

## Returns true if `chosen_index` equals `problem["correct_index"]`.
## Guards against out-of-range indices and missing keys.
static func is_correct(problem: Dictionary, chosen_index: int) -> bool:
	if not problem.has("correct_index"):
		return false
	var correct_index: int = int(problem["correct_index"])
	return chosen_index == correct_index
