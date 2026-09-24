## GUT tests for the file-based progress storage: AtomicJsonFile + ProgressStore.
## Everything runs in user://test_progress (removed after each test).

extends GutTest

const ROOT := "user://test_progress"
const P1 := 920001
const P2 := 920002


func before_each() -> void:
	ProgressStore.set_root(ROOT)


func after_each() -> void:
	for pid: int in [P1, P2]:
		ProgressStore.delete_profile(pid)
	for f: String in ["raw.json", "raw.json.bak", "raw.json.tmp"]:
		DirAccess.remove_absolute("%s/%s" % [ROOT, f])
	DirAccess.remove_absolute(ROOT)
	ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Simulates an app restart: forget everything cached in memory.
func _restart() -> void:
	ProgressStore.reset_cache()


func _round(score: int, started_at: int = 1700000000000) -> Dictionary:
	return {
		"started_at": started_at, "ended_at": started_at + 120000,
		"duration_ms": 120000, "score": score, "best_streak": 4,
		"accuracy": 0.75, "config": {"duration_s": 120, "enabled_skills": ["add_0_10"]},
	}


func _attempt(skill: String, correct: bool) -> Dictionary:
	return {
		"skill_key": skill, "expression": "2 + 3", "correct_answer": 5,
		"choices": [4, 5, 6], "chosen_index": 1 if correct else 0,
		"correct": correct, "reaction_ms": 900, "at": 1700000001000,
	}


# ---------------------------------------------------------------------------
# AtomicJsonFile
# ---------------------------------------------------------------------------

func test_atomic_write_round_trip_and_backup() -> void:
	var path := ROOT + "/raw.json"
	assert_eq(AtomicJsonFile.write(path, {"version": 1, "n": 1}), OK)
	assert_false(FileAccess.file_exists(path + ".tmp"), "no .tmp left behind")
	assert_false(FileAccess.file_exists(path + ".bak"), "nothing to back up on first write")
	assert_eq(AtomicJsonFile.write(path, {"version": 1, "n": 2}), OK)
	assert_true(FileAccess.file_exists(path + ".bak"), "previous version kept as .bak")
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 2)
	var bak_json := JSON.new()
	bak_json.parse(_read_text(path + ".bak"))
	assert_eq(int(bak_json.data["n"]), 1)


func test_corrupt_main_file_falls_back_to_backup() -> void:
	var path := ROOT + "/raw.json"
	AtomicJsonFile.write(path, {"n": 1})
	AtomicJsonFile.write(path, {"n": 2})  # .bak = {"n": 1}
	_write_text(path, "{\"n\": 3, truncated")
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 1, "falls back to the .bak")
	# The next write must not replace the good .bak with the corrupt file.
	AtomicJsonFile.write(path, {"n": 4})
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 4)
	_write_text(path, "garbage")
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 1, ".bak still holds the last good version")


func test_non_object_json_and_missing_files_read_as_null() -> void:
	var path := ROOT + "/raw.json"
	assert_null(AtomicJsonFile.read(path), "missing file")
	_write_text(path, "[1, 2, 3]")
	assert_null(AtomicJsonFile.read(path), "a JSON array is not a valid document")


func test_leftover_tmp_file_is_ignored_and_replaced() -> void:
	var path := ROOT + "/raw.json"
	AtomicJsonFile.write(path, {"n": 1})
	_write_text(path + ".tmp", "{half written")  # crash mid-write
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 1)
	assert_eq(AtomicJsonFile.write(path, {"n": 2}), OK)
	assert_eq(int(AtomicJsonFile.read(path)["n"]), 2)


# ---------------------------------------------------------------------------
# Round trip
# ---------------------------------------------------------------------------

func test_everything_survives_a_restart() -> void:
	ProgressStore.set_skill(P1, "add_0_10", 1123.5, 12, 9, 1700000000500)
	var sid := ProgressStore.record_round(P1, _round(150),
		[_attempt("add_0_10", true), _attempt("add_0_10", false)])
	assert_eq(sid, 1)
	assert_true(ProgressStore.unlock(P1, "badge", "streak_10", 1700000009999))
	_restart()

	var skill := ProgressStore.skill(P1, "add_0_10")
	assert_almost_eq(float(skill["rating"]), 1123.5, 0.001)
	assert_eq(int(skill["attempts"]), 12)
	assert_eq(int(skill["correct"]), 9)
	assert_eq(int(skill["last_seen_at"]), 1700000000500)

	var sessions := ProgressStore.sessions(P1)
	assert_eq(sessions.size(), 1)
	var s: Dictionary = sessions[0]
	assert_eq(int(s["id"]), 1)
	assert_eq(int(s["score"]), 150)
	assert_eq(int(s["best_streak"]), 4)
	assert_eq(int(s["duration_ms"]), 120000)
	assert_eq(int(s["started_at"]), 1700000000000)
	assert_almost_eq(float(s["accuracy"]), 0.75, 0.0001)
	assert_eq(int(s["config"]["duration_s"]), 120)

	var attempts := ProgressStore.recent_attempts(P1)
	assert_eq(attempts.size(), 2)
	assert_eq(int(attempts[0]["session_id"]), 1)
	assert_true(attempts[0]["correct"])
	assert_false(attempts[1]["correct"])

	assert_true(ProgressStore.is_unlocked(P1, "badge", "streak_10"))
	assert_eq(int(ProgressStore.unlocks(P1)[0]["unlocked_at"]), 1700000009999)
	assert_eq(ProgressStore.peek_next_session_id(P1), 2, "session ids keep increasing")


func test_file_has_version_and_lives_under_root() -> void:
	ProgressStore.record_round(P1, _round(10), [])
	var path := ProgressStore.path_for(P1)
	assert_true(path.begins_with(ROOT + "/"))
	var data: Variant = AtomicJsonFile.read(path)
	assert_eq(int(data["version"]), ProgressStore.VERSION)
	assert_eq(int(data["profile_id"]), P1)


func test_skill_updates_are_buffered_until_flush() -> void:
	ProgressStore.set_skill(P1, "mul_x3", 1050.0, 1, 1)
	assert_false(FileAccess.file_exists(ProgressStore.path_for(P1)),
		"a single answer must not hit the disk")
	ProgressStore.flush()
	_restart()
	assert_almost_eq(float(ProgressStore.skill(P1, "mul_x3")["rating"]), 1050.0, 0.001)


func test_unflushed_skill_updates_are_lost_on_kill() -> void:
	ProgressStore.set_skill(P1, "mul_x3", 1050.0, 1, 1)
	_restart()  # app killed without pause / round end
	assert_true(ProgressStore.skill(P1, "mul_x3").is_empty())


func test_corrupt_progress_file_recovers_from_backup() -> void:
	ProgressStore.record_round(P1, _round(10), [])
	ProgressStore.record_round(P1, _round(20), [])  # .bak holds the 1-round state
	_write_text(ProgressStore.path_for(P1), "{ not json")
	_restart()
	assert_eq(ProgressStore.session_count(P1), 1, "recovered from .bak")


func test_corrupt_file_without_backup_starts_empty() -> void:
	_write_text(ProgressStore.path_for(P1), "\u0001\u0002 nonsense")
	_restart()
	assert_eq(ProgressStore.session_count(P1), 0)
	assert_eq(ProgressStore.skills(P1), {})
	assert_eq(ProgressStore.record_round(P1, _round(5), []), 1, "and keeps working")


func test_bad_field_types_are_sanitised() -> void:
	_write_text(ProgressStore.path_for(P1), JSON.stringify({
		"version": 1,
		"next_session_id": "lots",
		"skills": {
			"add_0_10": {"rating": "1200", "attempts": 4, "correct": true},
			"sub_0_10": "not a dict",
			"": {"rating": 1},
		},
		"unlocks": {"x": {"kind": "badge"}, "y": 5,
			"badge/ten_games": {"kind": "badge", "key": "ten_games", "unlocked_at": "?"}},
		"sessions": [{"id": 7, "score": -5, "accuracy": 3.0}, "junk", null],
		"attempts": {"not": "a list"},
	}))
	_restart()
	var skills := ProgressStore.skills(P1)
	assert_eq(skills.keys(), ["add_0_10"])
	assert_almost_eq(float(skills["add_0_10"]["rating"]), 1200.0, 0.001)
	assert_eq(int(skills["add_0_10"]["correct"]), 1)
	assert_eq(ProgressStore.unlocks(P1).size(), 1)
	var s: Dictionary = ProgressStore.sessions(P1)[0]
	assert_eq(int(s["score"]), 0)
	assert_almost_eq(float(s["accuracy"]), 1.0, 0.0001)
	assert_eq(ProgressStore.recent_attempts(P1), [])
	assert_eq(ProgressStore.peek_next_session_id(P1), 8, "never reuses a stored id")


# ---------------------------------------------------------------------------
# Caps, isolation, deletion
# ---------------------------------------------------------------------------

func test_attempts_log_is_capped_but_skill_counters_are_not() -> void:
	var batch: Array = []
	for i in range(300):
		batch.append(_attempt("add_0_10", i % 2 == 0))
	ProgressStore.record_round(P1, _round(1), batch)
	ProgressStore.record_round(P1, _round(2), batch)
	ProgressStore.set_skill(P1, "add_0_10", 1000.0, 600, 300)
	ProgressStore.flush()
	_restart()
	var recent := ProgressStore.recent_attempts(P1)
	assert_eq(recent.size(), ProgressStore.MAX_ATTEMPTS)
	assert_eq(int(recent[recent.size() - 1]["session_id"]), 2, "newest attempts are kept")
	assert_eq(int(ProgressStore.skill(P1, "add_0_10")["attempts"]), 600,
		"aggregates don't depend on the capped log")


func test_profiles_are_isolated() -> void:
	ProgressStore.set_skill(P1, "add_0_10", 1300.0, 5, 5)
	ProgressStore.record_round(P1, _round(99), [_attempt("add_0_10", true)])
	ProgressStore.unlock(P1, "badge", "streak_10")
	_restart()
	assert_eq(ProgressStore.skills(P2), {})
	assert_eq(ProgressStore.session_count(P2), 0)
	assert_eq(ProgressStore.recent_attempts(P2), [])
	assert_false(ProgressStore.is_unlocked(P2, "badge", "streak_10"))
	assert_ne(ProgressStore.path_for(P1), ProgressStore.path_for(P2))


func test_delete_profile_removes_file_backup_and_cache() -> void:
	ProgressStore.record_round(P1, _round(10), [])
	ProgressStore.record_round(P1, _round(20), [])
	ProgressStore.record_round(P2, _round(30), [])
	var path := ProgressStore.path_for(P1)
	_write_text(path + ".tmp", "{}")
	assert_true(FileAccess.file_exists(path + ".bak"))
	ProgressStore.delete_profile(P1)
	for suffix: String in ["", ".bak", ".tmp"]:
		assert_false(FileAccess.file_exists(path + suffix), "%s removed" % (path + suffix))
	assert_eq(ProgressStore.session_count(P1), 0, "cache dropped too")
	assert_eq(ProgressStore.session_count(P2), 1, "other profiles untouched")


func test_invalid_profile_ids_are_no_ops() -> void:
	ProgressStore.set_skill(0, "add_0_10", 1.0, 1, 1)
	assert_eq(ProgressStore.record_round(-1, _round(1), []), 0)
	assert_false(ProgressStore.unlock(0, "badge", "x"))
	ProgressStore.flush()
	assert_false(FileAccess.file_exists(ProgressStore.path_for(0)))


# ---------------------------------------------------------------------------
# Unlocks + stats
# ---------------------------------------------------------------------------

func test_unlock_is_idempotent() -> void:
	assert_true(ProgressStore.unlock(P1, "theme", "space", 1000))
	assert_false(ProgressStore.unlock(P1, "theme", "space", 2000))
	var rows := ProgressStore.unlocks(P1, "theme")
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0]["unlocked_at"]), 1000, "first unlock time is kept")
	assert_eq(ProgressStore.unlocks(P1, "badge"), [])


func test_skill_overview_sorted_weakest_first_with_accuracy() -> void:
	ProgressStore.set_skill(P1, "add_0_10", 1200.0, 10, 9)
	ProgressStore.set_skill(P1, "mul_x7", 900.0, 8, 2)
	ProgressStore.set_skill(P1, "sub_0_20", 1000.0, 0, 0)
	var rows := ProgressStore.skill_overview(P1)
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["skill_key"]),
		["mul_x7", "sub_0_20", "add_0_10"])
	assert_almost_eq(float(rows[0]["accuracy"]), 0.25, 0.0001)
	assert_almost_eq(float(rows[1]["accuracy"]), 0.0, 0.0001, "0 attempts → 0 accuracy")
	assert_almost_eq(float(rows[2]["accuracy"]), 0.9, 0.0001)


func test_skills_needing_practice() -> void:
	ProgressStore.set_skill(P1, "add_0_10", 1200.0, 10, 9)   # 90 %
	ProgressStore.set_skill(P1, "mul_x7", 900.0, 8, 2)       # 25 %
	ProgressStore.set_skill(P1, "sub_0_20", 1000.0, 10, 5)   # 50 %
	ProgressStore.set_skill(P1, "div_0_100", 800.0, 4, 0)    # too few attempts
	ProgressStore.set_skill(P1, "mul_x3", 950.0, 6, 3)       # 50 %, lower rating
	var rows := ProgressStore.skills_needing_practice(P1)
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["skill_key"]),
		["mul_x7", "mul_x3", "sub_0_20"])
	assert_eq(ProgressStore.skills_needing_practice(P1, 1).size(), 1)
	assert_eq(ProgressStore.skills_needing_practice(P1, 3, 50), [])


func test_distinct_play_days() -> void:
	var day := 24 * 3600 * 1000
	ProgressStore.record_round(P1, _round(1, 1700000000000), [])
	ProgressStore.record_round(P1, _round(1, 1700000000000 + 60000), [])
	ProgressStore.record_round(P1, _round(1, 1700000000000 + day), [])
	assert_eq(ProgressStore.distinct_play_days(P1), 2)
