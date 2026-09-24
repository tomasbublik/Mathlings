extends Node
## Global signal bus for loosely-coupled cross-module events.
## Any module may emit or listen. Keep signals additive - never remove, only deprecate.
## See DESIGN.md §Shared Contracts for the signal registry.

# --- Gameplay ---
signal problem_spawned(problem_id: int, skill_key: String, expression: String, choices: Array, correct_index: int)
signal answer_chosen(problem_id: int, chosen_index: int, correct: bool, reaction_ms: int)
signal problem_missed(problem_id: int)  ## dopadl na zem bez odpovedi
signal round_started(session_id: int, config: Dictionary)
signal round_ended(session_id: int, summary: Dictionary)
## The player quit the round from the pause menu. No round_ended / results
## follow; the session row (if any) has already been discarded.
signal round_aborted(session_id: int)

# --- Tutor ---
signal skill_rating_changed(skill_key: String, old_rating: float, new_rating: float)

# --- UI / Feedback ---
signal score_changed(new_score: int, delta: int)
signal streak_changed(new_streak: int)
signal combo_multiplier_changed(multiplier: float)

# --- Settings ---
signal settings_changed(key: String, value: Variant)
