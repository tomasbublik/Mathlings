class_name SkillModel
## Adaptive tutor: tracks per-skill Elo rating for one profile.
## - Persists to DB via SkillsDao.
## - Updates rating after each attempt.
## - Chooses the next skill from enabled set (weakness-biased with easy/hard injection).
## Reference: DESIGN §6.2, §8.1-§8.2, specs/P9_skill_model.md

const DEFAULT_RATING: float = 1000.0
const RATING_MIN: float = 600.0
const RATING_MAX: float = 1800.0

## Elo formula tuning (DESIGN §8.1).
const ELO_DIVISOR: float = 400.0    ## scale factor in expected = 1/(1+10^((D-R)/divisor))
const ACTUAL_FAST_CORRECT: float = 1.0
const ACTUAL_SLOW_CORRECT: float = 0.7
const ACTUAL_WRONG: float = 0.0
const REACTION_FAST_MS: int = 3000
const K_HIGH: int = 32
const K_LOW: int = 16
const K_THRESHOLD_ATTEMPTS: int = 20

## choose_next() bucket boundaries — see DESIGN §8.2.
const P_EASY_INJECT: float = 0.15
const P_HARDER_INJECT: float = 0.25   ## cumulative (easy + harder)
## Pivot rating used by the weakness-biased weighted sample. Skills below the
## pivot get more weight; above it they get the floor (MIN_WEIGHT).
const WEAKNESS_WEIGHT_PIVOT: float = 1500.0
const MIN_WEIGHT: float = 0.01

## Families for "harder_by_one" lookup (DESIGN §6.2, §8.2).
const FAMILIES: Dictionary = {
	"add": ["add_0_10", "add_0_20", "add_0_100"],
	"sub": ["sub_0_10", "sub_0_20", "sub_0_100"],
	"mul": ["mul_x2", "mul_x3", "mul_x4", "mul_x5", "mul_x6", "mul_x7", "mul_x8", "mul_x9", "mul_x10"],
	"div": ["div_0_100"],
}


var _profile_id: int
var _db: Node
var _cache: Dictionary = {}  ## skill_key -> {rating: float, attempts: int, correct: int}


## Loads existing ratings for `profile_id` from DB. `db` is the DB autoload (or compatible).
## When `db` is null (pure-unit tests) the model operates in-memory only.
func _init(profile_id: int, db: Node) -> void:
	_profile_id = profile_id
	_db = db
	_load_from_db()


## Returns the current rating for `skill_key`. Unknown keys default to 1000.
func rating_for(skill_key: String) -> float:
	if _cache.has(skill_key):
		return float(_cache[skill_key]["rating"])
	return DEFAULT_RATING


## Returns the current number of recorded attempts for `skill_key`.
func attempts_for(skill_key: String) -> int:
	if _cache.has(skill_key):
		return int(_cache[skill_key]["attempts"])
	return 0


## Average rating across the given enabled keys. Used by DifficultyController.
func average_rating(enabled_keys: PackedStringArray) -> float:
	if enabled_keys.is_empty():
		return DEFAULT_RATING
	var sum_r: float = 0.0
	for k: String in enabled_keys:
		sum_r += rating_for(k)
	return sum_r / float(enabled_keys.size())


## Applies the Elo update for one attempt and persists the new row.
## `reaction_ms` < 0 ⇒ the problem was missed (counted as wrong).
## Returns the new rating.
func on_attempt(skill_key: String, difficulty: float, correct: bool, reaction_ms: int) -> float:
	var entry: Dictionary = _ensure_entry(skill_key)

	var r: float = float(entry["rating"])
	var attempts: int = int(entry["attempts"])
	var correct_count: int = int(entry["correct"])

	var expected: float = 1.0 / (1.0 + pow(10.0, (difficulty - r) / ELO_DIVISOR))
	var actual: float
	if correct and reaction_ms >= 0 and reaction_ms <= REACTION_FAST_MS:
		actual = ACTUAL_FAST_CORRECT
	elif correct and reaction_ms > REACTION_FAST_MS:
		actual = ACTUAL_SLOW_CORRECT
	else:
		actual = ACTUAL_WRONG

	var k: int = K_HIGH if attempts < K_THRESHOLD_ATTEMPTS else K_LOW
	var new_rating: float = r + float(k) * (actual - expected)
	new_rating = clamp(new_rating, RATING_MIN, RATING_MAX)

	entry["rating"] = new_rating
	entry["attempts"] = attempts + 1
	if correct:
		entry["correct"] = correct_count + 1

	_persist_entry(skill_key, entry)

	# Emit only when running inside the game; unit tests construct with db = null
	# and there's nothing to broadcast to.
	if _db != null:
		EventBus.skill_rating_changed.emit(skill_key, r, new_rating)

	return new_rating


## Chooses the next skill from `enabled_keys`.
## - 15 % → easy injection (highest-rated enabled skill).
## - 10 % → harder-by-one from a weighted sample.
## - 75 % → weighted sample (weakness-biased).
func choose_next(enabled_keys: PackedStringArray, rng: RandomNumberGenerator = null) -> String:
	assert(enabled_keys.size() > 0, "SkillModel.choose_next requires at least one enabled skill")
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	if enabled_keys.size() == 1:
		return enabled_keys[0]

	var p: float = rng.randf()

	if p < P_EASY_INJECT:
		return _argmax_rating(enabled_keys)

	var weighted: String = _weighted_sample(enabled_keys, rng)

	if p < P_HARDER_INJECT:
		var harder: String = _harder_by_one(weighted, enabled_keys)
		if harder != "":
			return harder

	return weighted


# ---------------------------------------------------------------------------
# DB <-> cache
# ---------------------------------------------------------------------------

func _load_from_db() -> void:
	if not DbGuard.writable(_db):
		return
	var rows: Array = SkillsDao.get_for_profile(_db, _profile_id)
	for row: Dictionary in rows:
		var key: String = String(row.get("skill_key", ""))
		if key == "":
			continue
		_cache[key] = {
			"rating": float(row.get("rating", DEFAULT_RATING)),
			"attempts": int(row.get("attempts", 0)),
			"correct": int(row.get("correct", 0)),
		}


func _ensure_entry(skill_key: String) -> Dictionary:
	if not _cache.has(skill_key):
		_cache[skill_key] = {
			"rating": DEFAULT_RATING,
			"attempts": 0,
			"correct": 0,
		}
	return _cache[skill_key]


func _persist_entry(skill_key: String, entry: Dictionary) -> void:
	if not DbGuard.writable(_db):
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	SkillsDao.upsert(
		_db,
		_profile_id,
		skill_key,
		float(entry["rating"]),
		int(entry["attempts"]),
		int(entry["correct"]),
		now_ms
	)


# ---------------------------------------------------------------------------
# Selection helpers
# ---------------------------------------------------------------------------

func _argmax_rating(keys: PackedStringArray) -> String:
	var best_key: String = keys[0]
	var best_rating: float = rating_for(best_key)
	for i: int in range(1, keys.size()):
		var r: float = rating_for(keys[i])
		if r > best_rating:
			best_rating = r
			best_key = keys[i]
	return best_key


func _weighted_sample(keys: PackedStringArray, rng: RandomNumberGenerator) -> String:
	var weights: Array[float] = []
	var total: float = 0.0
	for k: String in keys:
		var w: float = maxf(MIN_WEIGHT, WEAKNESS_WEIGHT_PIVOT - rating_for(k))
		weights.append(w)
		total += w

	var pick: float = rng.randf() * total
	var acc: float = 0.0
	for i: int in range(keys.size()):
		acc += weights[i]
		if pick <= acc:
			return keys[i]
	return keys[keys.size() - 1]


## Returns a skill_key that is the "next step up" within the family of `key`,
## constrained to `enabled_keys`. Returns "" if nothing matches.
func _harder_by_one(key: String, enabled_keys: PackedStringArray) -> String:
	var family: Array = _family_for(key)
	if family.is_empty():
		return ""
	var idx: int = family.find(key)
	if idx < 0 or idx >= family.size() - 1:
		return ""
	var enabled_set: Dictionary = {}
	for e: String in enabled_keys:
		enabled_set[e] = true
	# Walk forward until we find an enabled member.
	for j: int in range(idx + 1, family.size()):
		var candidate: String = family[j]
		if enabled_set.has(candidate):
			return candidate
	return ""


static func _family_for(key: String) -> Array:
	for fam_key: String in FAMILIES.keys():
		var members: Array = FAMILIES[fam_key]
		if members.has(key):
			return members
	return []
