class_name ScoringRules
## Runtime-loaded scoring rules.
##
## The "what player gets for an answer" knobs (base points, combo tiers,
## penalties) live in `res://assets/rules/scoring_rules.json` so they can be
## tuned without recompiling. The Pravidla screen renders the same data as
## human-readable text; the GameController consumes it programmatically.
##
## Two reasons this is a class instead of free-floating constants:
##   1. The JSON load is fallible (missing file, schema bump). Wrapping the
##      rules in a value object lets every caller treat it the same way:
##      one helper to load, one default fallback, no scattered guards.
##   2. Tests can construct synthetic rules (different tiers, different base
##      points) and re-pin GameController behavior against them.
##
## Reference: specs/P17_external_rules.md, DESIGN §9 (game loop).


## Schema version this code understands. Bumping this in the JSON forces
## a fallback to the in-code defaults with a push_warning() so we don't
## silently misinterpret tiers from a future schema.
const SUPPORTED_SCHEMA_VERSION: int = 1

const DEFAULT_PATH: String = "res://assets/rules/scoring_rules.json"

## Safety-net defaults — used when the JSON is missing, malformed, or
## tagged with an unknown schema_version. Mirrors the hard-coded values
## that lived in GameController before this class existed.
const DEFAULT_BASE_POINTS: int = 10
const DEFAULT_COMBO_TIERS: Array = [
	{ "min_streak":  3, "multiplier": 1.25 },
	{ "min_streak":  5, "multiplier": 1.5 },
	{ "min_streak": 10, "multiplier": 2.0 },
]
const DEFAULT_COMBO_SOUND_STREAKS: Array[int] = [3, 5, 10]


var version: int = SUPPORTED_SCHEMA_VERSION
var base_points: int = DEFAULT_BASE_POINTS
var combo_tiers: Array = DEFAULT_COMBO_TIERS.duplicate(true)
var wrong_answer_penalty: int = 0
var miss_penalty: int = 0
var combo_sound_streaks: Array[int] = DEFAULT_COMBO_SOUND_STREAKS.duplicate()


# ---------------------------------------------------------------------------
# Construction helpers
# ---------------------------------------------------------------------------

## Returns a `ScoringRules` populated from `DEFAULT_PATH`. Falls back to
## hardcoded safety-net defaults on any error (missing file, malformed JSON,
## unsupported schema version).
static func load_default() -> ScoringRules:
	return load_from(DEFAULT_PATH)


## Returns a `ScoringRules` loaded from `path`. Same fallback semantics as
## `load_default()` — never raises, never returns null.
static func load_from(path: String) -> ScoringRules:
	var rules := ScoringRules.new()
	if not FileAccess.file_exists(path):
		push_warning("ScoringRules: '%s' not found, using built-in defaults." % path)
		return rules

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ScoringRules: could not open '%s' (%s); using defaults."
			% [path, error_string(FileAccess.get_open_error())])
		return rules

	var raw_text: String = file.get_as_text()
	file = null

	# JSON.new().parse() reports malformed input via its return value;
	# JSON.parse_string() would also raise an engine error for it.
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_warning("ScoringRules: '%s' is malformed (line %d: %s); using defaults."
			% [path, json.get_error_line(), json.get_error_message()])
		return rules
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		push_warning("ScoringRules: '%s' is not a JSON object; using defaults." % path)
		return rules

	var data: Dictionary = parsed
	var detected_version: int = int(data.get("version", SUPPORTED_SCHEMA_VERSION))
	if detected_version != SUPPORTED_SCHEMA_VERSION:
		push_warning(
			"ScoringRules: '%s' has schema version %d; this build supports %d. "
			% [path, detected_version, SUPPORTED_SCHEMA_VERSION]
			+ "Falling back to built-in defaults."
		)
		return rules

	rules._populate_from_dict(data)
	return rules


# ---------------------------------------------------------------------------
# Public API consumed by GameController
# ---------------------------------------------------------------------------

## Returns the score multiplier earned at the given correct-answer streak.
## Mirrors the prior in-code `_combo_for_streak` so existing tests stay valid.
func combo_for_streak(streak: int) -> float:
	var multiplier: float = 1.0
	for tier: Dictionary in combo_tiers:
		if streak >= int(tier.get("min_streak", 0)):
			multiplier = float(tier.get("multiplier", 1.0))
	return multiplier


## Returns the integer points awarded for a correct answer that closes the
## given streak. `streak` must be ≥ 1 (the answer that just landed).
func points_for_correct(streak: int) -> int:
	return int(round(float(base_points) * combo_for_streak(streak)))


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Copies the validated data into self. Caller has already verified the
## schema version. Anything missing keeps its default value.
func _populate_from_dict(data: Dictionary) -> void:
	version = int(data.get("version", version))
	base_points = int(data.get("base_points", base_points))

	if data.has("combo_tiers") and data["combo_tiers"] is Array:
		combo_tiers = _normalize_tiers(data["combo_tiers"])

	wrong_answer_penalty = int(data.get("wrong_answer_penalty", wrong_answer_penalty))
	miss_penalty = int(data.get("miss_penalty", miss_penalty))

	if data.has("combo_sound_streaks") and data["combo_sound_streaks"] is Array:
		var streaks: Array[int] = []
		for v in data["combo_sound_streaks"]:
			streaks.append(int(v))
		combo_sound_streaks = streaks


## Sorts tiers by min_streak ascending and discards malformed entries so
## `combo_for_streak` can iterate without re-checking the contract.
static func _normalize_tiers(raw: Array) -> Array:
	var clean: Array = []
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		if not (d.has("min_streak") and d.has("multiplier")):
			continue
		clean.append({
			"min_streak": int(d["min_streak"]),
			"multiplier": float(d["multiplier"]),
		})
	clean.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["min_streak"]) < int(b["min_streak"]))
	return clean
