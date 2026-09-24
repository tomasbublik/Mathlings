extends Node
## Session-scoped ephemeral state (current score, streak, active profile, etc.).
## Persistent data lives in files (ProgressStore, SessionStatsStore, SettingsStore).

var active_profile_id: int = 0
var current_score: int = 0
var current_streak: int = 0
var current_session_id: int = 0

## Summary payload for the Results screen.
## Populated by GameController at round end; read and cleared by Results scene.
## Schema — see specs/P8c_results_screen.md "Vstup scény".
var last_result: Dictionary = {}

func reset_round() -> void:
	current_score = 0
	current_streak = 0
	current_session_id = 0
