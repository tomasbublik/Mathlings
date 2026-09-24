class_name AttemptLogger
## Buffers the attempts of the round in progress in memory. GameController
## hands the buffer to ProgressStore.record_round() when the round ends and
## drops it when the round is aborted, so only finished rounds are stored.
## Reference: DESIGN §6, specs/P9_skill_model.md

var _buffer: Array = []


## Records one attempt. `chosen_index` = -1 and `reaction_ms` = -1 mean a miss.
func log_attempt(
	problem: Dictionary,
	chosen_index: int,
	reaction_ms: int,
	_shown_at_ms: int = 0,
	_resolved_at_ms: int = 0
) -> void:
	var was_correct: bool = chosen_index >= 0 \
		and chosen_index == int(problem.get("correct_index", -1))
	_buffer.append({
		"skill_key": String(problem.get("skill_key", "")),
		"expression": String(problem.get("expression", "")),
		"correct_answer": int(problem.get("correct_answer", 0)),
		"choices": Array(problem.get("choices", [])),
		"chosen_index": chosen_index,
		"correct": was_correct,
		"reaction_ms": reaction_ms,
		"at": ProgressStore.now_ms(),
	})


## Attempts buffered so far (not a copy — callers must not mutate).
func pending() -> Array:
	return _buffer


## Returns the buffered attempts and empties the buffer.
func take() -> Array:
	var out := _buffer
	_buffer = []
	return out


func clear() -> void:
	_buffer = []
