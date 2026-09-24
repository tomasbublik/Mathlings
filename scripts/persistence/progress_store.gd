class_name ProgressStore
## Per-profile learning progress persisted as one small JSON file per player:
## `user://progress/profile_<id>.json` (written via AtomicJsonFile, so there
## is always a `.bak` of the previous good version).
##
## File schema (version 1):
##   {
##     "version": 1,
##     "profile_id": 3,
##     "next_session_id": 13,
##     "skills":   { "<skill_key>": {"rating": 1034.5, "attempts": 41,
##                                   "correct": 35, "last_seen_at": <unix ms>} },
##     "unlocks":  { "<kind>/<key>": {"kind": "badge", "key": "streak_10",
##                                    "unlocked_at": <unix ms>} },
##     "sessions": [ {"id", "started_at", "ended_at", "duration_ms", "score",
##                    "best_streak", "accuracy", "config"} ]      (≤ MAX_SESSIONS)
##     "attempts": [ {"session_id", "skill_key", "expression", "correct_answer",
##                    "choices", "chosen_index", "correct", "reaction_ms",
##                    "at"} ]                                     (≤ MAX_ATTEMPTS)
##   }
## `skills` carries the per-skill aggregate counters, so stats never depend
## on the capped `attempts` log. Only finished rounds are stored in
## `sessions` / `attempts` — an aborted round never reaches this file.
##
## Write policy: data is cached in memory per profile. Skill updates during a
## round only mark the profile dirty; the file is written at round end
## (`record_round`), on unlock, and on `flush()` (round abort, app pause /
## close — see ProfileService._notification). A killed app therefore loses
## at most the round in progress.
##
## Reference: DESIGN §6.

const VERSION: int = 1
const DEFAULT_ROOT: String = "user://progress"
const MAX_ATTEMPTS: int = 500
const MAX_SESSIONS: int = 1000
const DEFAULT_RATING: float = 1000.0

## Directory holding the per-profile files. Tests point this at user://test_*.
static var root: String = DEFAULT_ROOT

static var _cache: Dictionary = {}   ## profile_id -> normalised data Dictionary
static var _dirty: Dictionary = {}   ## profile_id -> true


## Redirects storage (tests) and drops the in-memory cache.
static func set_root(path: String) -> void:
	root = path
	_cache.clear()
	_dirty.clear()


## Drops the in-memory cache without writing (tests / simulated restart).
static func reset_cache() -> void:
	_cache.clear()
	_dirty.clear()


static func path_for(profile_id: int) -> String:
	return "%s/profile_%d.json" % [root, profile_id]


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

## skill_key -> {rating, attempts, correct, last_seen_at}. Returns a copy.
static func skills(profile_id: int) -> Dictionary:
	if profile_id <= 0:
		return {}
	return (_data(profile_id)["skills"] as Dictionary).duplicate(true)


## One skill row, or {} when the profile never practised it.
static func skill(profile_id: int, skill_key: String) -> Dictionary:
	if profile_id <= 0:
		return {}
	var all: Dictionary = _data(profile_id)["skills"]
	return (all.get(skill_key, {}) as Dictionary).duplicate()


## Updates one skill in memory; persisted by the next write / flush().
static func set_skill(profile_id: int, skill_key: String, rating: float,
		attempts: int, correct: int, last_seen_at_ms: int = 0) -> void:
	if profile_id <= 0 or skill_key == "":
		return
	var all: Dictionary = _data(profile_id)["skills"]
	all[skill_key] = {
		"rating": rating,
		"attempts": attempts,
		"correct": correct,
		"last_seen_at": last_seen_at_ms if last_seen_at_ms > 0 else now_ms(),
	}
	_dirty[profile_id] = true


# ---------------------------------------------------------------------------
# Rounds (sessions + attempts)
# ---------------------------------------------------------------------------

## Id the next recorded round will get (used as the live session id).
static func peek_next_session_id(profile_id: int) -> int:
	if profile_id <= 0:
		return 0
	return int(_data(profile_id)["next_session_id"])


## Stores a finished round and its attempts, then writes the file.
## `session` keys: started_at, ended_at, duration_ms, score, best_streak,
## accuracy, config. Returns the session id.
static func record_round(profile_id: int, session: Dictionary, attempts: Array) -> int:
	if profile_id <= 0:
		return 0
	var data := _data(profile_id)
	var id: int = int(data["next_session_id"])
	data["next_session_id"] = id + 1
	var row := _clean_session(session)
	row["id"] = id
	var sessions: Array = data["sessions"]
	sessions.append(row)
	while sessions.size() > MAX_SESSIONS:
		sessions.pop_front()
	var attempt_log: Array = data["attempts"]
	for a: Variant in attempts:
		if a is Dictionary:
			var entry := _clean_attempt(a)
			entry["session_id"] = id
			attempt_log.append(entry)
	if attempt_log.size() > MAX_ATTEMPTS:
		data["attempts"] = attempt_log.slice(attempt_log.size() - MAX_ATTEMPTS)
	_dirty[profile_id] = true
	flush(profile_id)
	return id


## Finished rounds, oldest first.
static func sessions(profile_id: int) -> Array:
	if profile_id <= 0:
		return []
	return (_data(profile_id)["sessions"] as Array).duplicate(true)


static func session_count(profile_id: int) -> int:
	if profile_id <= 0:
		return 0
	return (_data(profile_id)["sessions"] as Array).size()


## Number of distinct UTC calendar days with a finished round.
static func distinct_play_days(profile_id: int) -> int:
	var days: Dictionary = {}
	for s: Dictionary in sessions(profile_id):
		var ms: int = int(s.get("started_at", 0))
		if ms > 0:
			days[Time.get_date_string_from_unix_time(int(ms / 1000.0))] = true
	return days.size()


## Recent attempts (capped log), oldest first.
static func recent_attempts(profile_id: int) -> Array:
	if profile_id <= 0:
		return []
	return (_data(profile_id)["attempts"] as Array).duplicate(true)


# ---------------------------------------------------------------------------
# Unlocks
# ---------------------------------------------------------------------------

static func is_unlocked(profile_id: int, kind: String, key: String) -> bool:
	if profile_id <= 0:
		return false
	return (_data(profile_id)["unlocks"] as Dictionary).has(_unlock_id(kind, key))


## Records an unlock and writes the file. Idempotent: returns true only the
## first time (the original unlocked_at is kept).
static func unlock(profile_id: int, kind: String, key: String, unlocked_at_ms: int = 0) -> bool:
	if profile_id <= 0 or kind == "" or key == "":
		return false
	var all: Dictionary = _data(profile_id)["unlocks"]
	var uid := _unlock_id(kind, key)
	if all.has(uid):
		return false
	all[uid] = {
		"kind": kind,
		"key": key,
		"unlocked_at": unlocked_at_ms if unlocked_at_ms > 0 else now_ms(),
	}
	_dirty[profile_id] = true
	flush(profile_id)
	return true


## [{kind, key, unlocked_at}] sorted by unlocked_at; `kind` "" = all kinds.
static func unlocks(profile_id: int, kind: String = "") -> Array:
	if profile_id <= 0:
		return []
	var out: Array = []
	for row: Dictionary in (_data(profile_id)["unlocks"] as Dictionary).values():
		if kind == "" or String(row["kind"]) == kind:
			out.append(row.duplicate())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["unlocked_at"]) < int(b["unlocked_at"]))
	return out


# ---------------------------------------------------------------------------
# Stats (derived from the per-skill aggregates)
# ---------------------------------------------------------------------------

## [{skill_key, rating, attempts, correct, accuracy}] sorted by rating ASC
## (weakest first).
static func skill_overview(profile_id: int) -> Array:
	var out: Array = []
	var all := skills(profile_id)
	for key: String in all.keys():
		var row: Dictionary = all[key]
		var attempts: int = int(row["attempts"])
		var correct: int = int(row["correct"])
		out.append({
			"skill_key": key,
			"rating": float(row["rating"]),
			"attempts": attempts,
			"correct": correct,
			"accuracy": 0.0 if attempts == 0 else float(correct) / float(attempts),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["rating"]), float(b["rating"])):
			return float(a["rating"]) < float(b["rating"])
		return String(a["skill_key"]) < String(b["skill_key"]))
	return out


## Up to `limit` skills with ≥ `min_attempts` attempts, lowest accuracy first
## (ties: lower rating first).
static func skills_needing_practice(profile_id: int, limit: int = 3,
		min_attempts: int = 5) -> Array:
	var rows: Array = skill_overview(profile_id).filter(func(r: Dictionary) -> bool:
		return int(r["attempts"]) >= min_attempts)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["accuracy"]), float(b["accuracy"])):
			return float(a["accuracy"]) < float(b["accuracy"])
		return float(a["rating"]) < float(b["rating"]))
	return rows.slice(0, maxi(0, limit))


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Writes dirty profiles to disk. `profile_id` ≤ 0 flushes every dirty one.
static func flush(profile_id: int = 0) -> void:
	var ids: Array = [profile_id] if profile_id > 0 else _dirty.keys()
	for pid: int in ids:
		if not _dirty.has(pid) or not _cache.has(pid):
			continue
		if AtomicJsonFile.write(path_for(pid), _cache[pid]) == OK:
			_dirty.erase(pid)


## Removes every trace of a profile's progress (file, .bak, .tmp, cache).
static func delete_profile(profile_id: int) -> void:
	if profile_id <= 0:
		return
	_cache.erase(profile_id)
	_dirty.erase(profile_id)
	AtomicJsonFile.remove(path_for(profile_id))


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Loading + defensive normalisation
# ---------------------------------------------------------------------------

static func _data(profile_id: int) -> Dictionary:
	if not _cache.has(profile_id):
		_cache[profile_id] = _load(profile_id)
	return _cache[profile_id]


static func _load(profile_id: int) -> Dictionary:
	var raw: Variant = AtomicJsonFile.read(path_for(profile_id))
	if raw == null:
		return _empty(profile_id)
	var version: int = int(_num(raw.get("version", 0), 0))
	if version > VERSION:
		# Written by a newer build — read what we understand; unknown keys
		# are dropped on the next write.
		push_warning("ProgressStore: profile %d file has version %d (> %d)"
			% [profile_id, version, VERSION])
	return _normalise(profile_id, raw)


static func _empty(profile_id: int) -> Dictionary:
	return {
		"version": VERSION,
		"profile_id": profile_id,
		"next_session_id": 1,
		"skills": {},
		"unlocks": {},
		"sessions": [],
		"attempts": [],
	}


## Coerces every field to the expected type; bad entries are dropped.
static func _normalise(profile_id: int, raw: Dictionary) -> Dictionary:
	var data := _empty(profile_id)

	var skills_raw: Variant = raw.get("skills", {})
	if skills_raw is Dictionary:
		for key: Variant in skills_raw.keys():
			var row: Variant = skills_raw[key]
			if not (key is String) or String(key) == "" or not (row is Dictionary):
				continue
			data["skills"][key] = {
				"rating": clampf(_num(row.get("rating"), DEFAULT_RATING), 0.0, 10000.0),
				"attempts": maxi(0, int(_num(row.get("attempts"), 0))),
				"correct": maxi(0, int(_num(row.get("correct"), 0))),
				"last_seen_at": int(_num(row.get("last_seen_at"), 0)),
			}

	var unlocks_raw: Variant = raw.get("unlocks", {})
	if unlocks_raw is Dictionary:
		for row: Variant in unlocks_raw.values():
			if not (row is Dictionary):
				continue
			var kind := str(row.get("kind", ""))
			var key := str(row.get("key", ""))
			if kind == "" or key == "":
				continue
			data["unlocks"][_unlock_id(kind, key)] = {
				"kind": kind,
				"key": key,
				"unlocked_at": int(_num(row.get("unlocked_at"), 0)),
			}

	var max_id := 0
	var sessions_raw: Variant = raw.get("sessions", [])
	if sessions_raw is Array:
		for row: Variant in sessions_raw:
			if row is Dictionary:
				var s := _clean_session(row)
				s["id"] = int(_num(row.get("id"), 0))
				max_id = maxi(max_id, int(s["id"]))
				data["sessions"].append(s)
	var sessions_arr: Array = data["sessions"]
	if sessions_arr.size() > MAX_SESSIONS:
		data["sessions"] = sessions_arr.slice(sessions_arr.size() - MAX_SESSIONS)

	var attempts_raw: Variant = raw.get("attempts", [])
	if attempts_raw is Array:
		for row: Variant in attempts_raw:
			if row is Dictionary:
				var a := _clean_attempt(row)
				a["session_id"] = int(_num(row.get("session_id"), 0))
				data["attempts"].append(a)
	var attempts_arr: Array = data["attempts"]
	if attempts_arr.size() > MAX_ATTEMPTS:
		data["attempts"] = attempts_arr.slice(attempts_arr.size() - MAX_ATTEMPTS)

	data["next_session_id"] = maxi(max_id + 1,
		int(_num(raw.get("next_session_id"), 1)))
	return data


static func _clean_session(row: Dictionary) -> Dictionary:
	var config: Variant = row.get("config", {})
	return {
		"id": 0,
		"started_at": int(_num(row.get("started_at"), 0)),
		"ended_at": int(_num(row.get("ended_at"), 0)),
		"duration_ms": maxi(0, int(_num(row.get("duration_ms"), 0))),
		"score": maxi(0, int(_num(row.get("score"), 0))),
		"best_streak": maxi(0, int(_num(row.get("best_streak"), 0))),
		"accuracy": clampf(_num(row.get("accuracy"), 0.0), 0.0, 1.0),
		"config": config if config is Dictionary else {},
	}


static func _clean_attempt(row: Dictionary) -> Dictionary:
	var choices: Variant = row.get("choices", [])
	return {
		"session_id": 0,
		"skill_key": str(row.get("skill_key", "")),
		"expression": str(row.get("expression", "")),
		"correct_answer": int(_num(row.get("correct_answer"), 0)),
		"choices": choices if choices is Array else [],
		"chosen_index": int(_num(row.get("chosen_index"), -1)),
		"correct": _num(row.get("correct"), 0.0) != 0.0,
		"reaction_ms": int(_num(row.get("reaction_ms"), -1)),
		"at": int(_num(row.get("at"), 0)),
	}


static func _unlock_id(kind: String, key: String) -> String:
	return "%s/%s" % [kind, key]


## Numeric coercion that tolerates strings / nulls / garbage.
static func _num(v: Variant, fallback: float) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			var f := float(v)
			return fallback if is_nan(f) or is_inf(f) else f
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_STRING:
			return float(v) if String(v).is_valid_float() else fallback
	return fallback
