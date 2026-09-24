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

	var parsed: Variant = JSON.parse_string(raw_text)
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


## Renders the rules as a Czech human-readable string for the Pravidla scene.
## Driven entirely from the loaded data, so editing the JSON is reflected
## here without code changes.
func to_human_readable_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Skóre se počítá podle pravidel verze %d." % version)
	lines.append("")
	lines.append("Základ je %d bodů za správnou odpověď. Za chybnou odpověď ani"
		% base_points)
	lines.append("za propadlý příklad se body neodečítají, ale vynuluje se série")
	lines.append("a kombo.")
	lines.append("")
	lines.append("Kombo podle série správných odpovědí:")
	for line in _format_combo_lines():
		lines.append(line)
	lines.append("")
	lines.append("Příklad: 11 správných odpovědí v řadě = %d bodů." % _eleven_streak_total())
	lines.append("")
	lines.append("Chybná odpověď nebo miss:")
	lines.append("  • pokus se započte do statistik,")
	lines.append("  • body se nepřičtou,")
	lines.append("  • série se vynuluje,")
	lines.append("  • kombo se vrátí na 1.0.")
	if not combo_sound_streaks.is_empty():
		lines.append("")
		lines.append("Combo SFX zazní při sérii: %s." % _join_int_list(combo_sound_streaks))
	return "\n".join(lines)


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


## Builds the bullet-list lines for to_human_readable_text(). Each tier
## gets one line summarizing the streak range and the resulting points.
func _format_combo_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	# Pre-tier baseline: streaks below the lowest tier all get the base points.
	var first_min: int = (
		int(combo_tiers[0].get("min_streak", 1)) if not combo_tiers.is_empty() else 1)
	if first_min > 1:
		out.append("  • Série 1–%d: násobič 1.0 → +%d bodů"
			% [first_min - 1, base_points])

	for i in range(combo_tiers.size()):
		var tier: Dictionary = combo_tiers[i]
		var lo: int = int(tier["min_streak"])
		var multiplier: float = float(tier["multiplier"])
		var points: int = int(round(float(base_points) * multiplier))

		var range_text: String
		if i + 1 < combo_tiers.size():
			var hi: int = int(combo_tiers[i + 1]["min_streak"]) - 1
			range_text = "Série %d–%d" % [lo, hi]
		else:
			range_text = "Série %d+" % lo

		out.append("  • %s: násobič %s → +%d bodů"
			% [range_text, _format_multiplier(multiplier), points])
	return out


## "1.5" → "1.5", "1.25" → "1.25", "2.0" → "2.0" — keeps trailing decimals
## tidy regardless of locale rounding.
static func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, round(multiplier)):
		return "%.1f" % multiplier
	return String.num(multiplier, 2)


## Computes the score for 11 consecutive correct answers — the canonical
## worked example we show readers so they can sanity-check the rules.
func _eleven_streak_total() -> int:
	var total: int = 0
	for s in range(1, 12):
		total += points_for_correct(s)
	return total


## Pretty-prints an integer list as "3, 5, 10".
static func _join_int_list(values: Array[int]) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append(str(v))
	return ", ".join(parts)
