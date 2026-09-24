class_name AttemptLogger
## Persists a single Problem attempt row to the `attempts` table.
## Reference: DESIGN §6.1, specs/P9_skill_model.md

var _session_id: int
var _db: Node


## `db` may be null in unit tests — `log` becomes a no-op then.
func _init(session_id: int, db: Node) -> void:
	_session_id = session_id
	_db = db


## Writes the attempt row. `chosen_index` = -1 and `reaction_ms` = -1 indicate a miss.
func log_attempt(
	problem: Dictionary,
	chosen_index: int,
	reaction_ms: int,
	shown_at_ms: int,
	resolved_at_ms: int
) -> void:
	if not DbGuard.writable(_db):
		return

	var correct_answer: int = int(problem.get("correct_answer", 0))
	var was_correct: bool = chosen_index >= 0 and chosen_index == int(problem.get("correct_index", -1))

	AttemptsDao.insert(
		_db,
		_session_id,
		String(problem.get("skill_key", "")),
		String(problem.get("expression", "")),
		correct_answer,
		problem.get("choices", []),
		chosen_index,
		was_correct,
		reaction_ms,
		shown_at_ms,
		resolved_at_ms
	)
