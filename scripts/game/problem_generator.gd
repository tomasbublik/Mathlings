## ProblemGenerator — generuje matematické příklady dle DESIGN §6.2, §7.1, §8.3.
##
## Čistá bezstavová knihovna bez UI závislostí.
## Výběr dovednosti provádí SkillModel (P9), tento modul pouze generuje
## konkrétní příklad a distraktory pro daný skill_key.

class_name ProblemGenerator

# ---------------------------------------------------------------------------
# Veřejné API
# ---------------------------------------------------------------------------

## Vytvoří Problem pro zadaný skill_key. RNG je injectable pro testovatelnost.
## Vrací Dictionary dle DESIGN §7.1. Pokud je skill_key neznámý, vrací {}.
## Pole "id" je nastaveno na 0 — volající musí nastavit správnou hodnotu.
static func generate(skill_key: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	if not Problem.DIFFICULTY.has(skill_key):
		return {}

	var result: Dictionary = _generate_expression(skill_key, rng)
	if result.is_empty():
		return {}

	var correct: int = result["correct_answer"]
	var expression: String = result["expression"]

	var choices: Array[int] = _build_choices(skill_key, correct, rng)

	# Zamíchej choices; zaznamenej correct_index
	_shuffle_array(choices, rng)
	var correct_index: int = choices.find(correct)

	return {
		"id": 0,
		"skill_key": skill_key,
		"expression": expression,
		"correct_answer": correct,
		"choices": choices,
		"correct_index": correct_index,
		"difficulty": Problem.DIFFICULTY[skill_key],
	}

## Vrací aktuální schema-compatible seznam podporovaných skill klíčů (dle DESIGN §6.2).
static func supported_skills() -> PackedStringArray:
	return PackedStringArray(Problem.DIFFICULTY.keys())

# ---------------------------------------------------------------------------
# Generování výrazů per operace
# ---------------------------------------------------------------------------

static func _generate_expression(skill_key: String, rng: RandomNumberGenerator) -> Dictionary:
	if skill_key == "add_0_10":
		return _gen_addition(rng, 0, 10, 10)
	elif skill_key == "add_0_20":
		return _gen_addition(rng, 0, 19, 20)
	elif skill_key == "add_0_100":
		return _gen_addition(rng, 0, 99, 100)
	elif skill_key == "sub_0_10":
		return _gen_subtraction(rng, 0, 10)
	elif skill_key == "sub_0_20":
		return _gen_subtraction(rng, 0, 20)
	elif skill_key == "sub_0_100":
		return _gen_subtraction(rng, 0, 100)
	elif skill_key == "div_0_100":
		return _gen_division(rng)
	elif skill_key.begins_with("mul_x"):
		var k: int = int(skill_key.substr(5))
		return _gen_multiplication(rng, k)
	return {}

## Generuje sčítání: a ∈ [0, max_operand], b ∈ [0, max_operand], a+b ≤ max_sum.
static func _gen_addition(rng: RandomNumberGenerator, min_op: int, max_op: int, max_sum: int) -> Dictionary:
	var a: int = rng.randi_range(min_op, max_op)
	var b_max: int = mini(max_op, max_sum - a)
	if b_max < min_op:
		b_max = min_op
	var b: int = rng.randi_range(min_op, b_max)
	return {
		"expression": "%d + %d" % [a, b],
		"correct_answer": a + b,
		"operand_a": a,
		"operand_b": b,
	}

## Generuje odčítání: a ∈ [b, max_a], b ∈ [0, max_a], a ≥ b (žádné záporné výsledky).
static func _gen_subtraction(rng: RandomNumberGenerator, min_val: int, max_a: int) -> Dictionary:
	var a: int = rng.randi_range(min_val, max_a)
	var b: int = rng.randi_range(min_val, a)
	return {
		"expression": "%d - %d" % [a, b],
		"correct_answer": a - b,
		"operand_a": a,
		"operand_b": b,
	}

## Generuje násobilku: a = k (pevné), b ∈ [1, 10].
static func _gen_multiplication(rng: RandomNumberGenerator, k: int) -> Dictionary:
	var b: int = rng.randi_range(1, 10)
	return {
		"expression": "%d × %d" % [k, b],
		"correct_answer": k * b,
		"operand_a": k,
		"operand_b": b,
	}

## Generuje dělení z násobilky: b ∈ [2,10], q ∈ [2,10], a = b*q — dělí beze zbytku.
static func _gen_division(rng: RandomNumberGenerator) -> Dictionary:
	var b: int = rng.randi_range(2, 10)
	var q: int = rng.randi_range(2, 10)
	var a: int = b * q
	return {
		"expression": "%d ÷ %d" % [a, b],
		"correct_answer": q,
		"operand_a": a,
		"operand_b": b,
	}

# ---------------------------------------------------------------------------
# Generování distraktorů (DESIGN §8.3)
# ---------------------------------------------------------------------------

## Sestaví Array[int] tří voleb: [correct, distractor1, distractor2].
## Pořadí zde není zamícháno — zamíchání provádí volající.
static func _build_choices(skill_key: String, correct: int, rng: RandomNumberGenerator) -> Array[int]:
	var distractors: Array[int] = _generate_distractors(skill_key, correct, rng)
	var choices: Array[int] = []
	choices.append(correct)
	choices.append(distractors[0])
	choices.append(distractors[1])
	return choices

## Generuje 2 plausibilní distraktory dle operace (DESIGN §8.3).
## Garantuje: žádné duplikáty, žádné záporné, liší se od correct.
static func _generate_distractors(skill_key: String, correct: int, rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = _get_distractor_candidates(skill_key, correct, rng)

	# Filtruj: ne záporné, ne correct
	var filtered: Array[int] = []
	for c: int in candidates:
		if c >= 0 and c != correct and not filtered.has(c):
			filtered.append(c)

	# Pokud nemáme dost, fallback
	var attempts: int = 0
	while filtered.size() < 2 and attempts < 20:
		attempts += 1
		var delta: int = rng.randi_range(1, 5)
		var sign: int = 1 if rng.randi_range(0, 1) == 0 else -1
		var candidate: int = correct + sign * delta
		if candidate >= 0 and candidate != correct and not filtered.has(candidate):
			filtered.append(candidate)

	# Pokud stále nemáme 2 (extrémní případ), doplníme deterministicky
	var fallback_delta: int = 1
	while filtered.size() < 2:
		var candidate: int = correct + fallback_delta
		if candidate != correct and not filtered.has(candidate) and candidate >= 0:
			filtered.append(candidate)
		fallback_delta += 1

	var result: Array[int] = []
	result.append(filtered[0])
	result.append(filtered[1])
	return result

## Vrací seznam kandidátů distraktorů dle heuristik per operace (DESIGN §8.3).
static func _get_distractor_candidates(skill_key: String, correct: int, rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = []

	if skill_key.begins_with("add"):
		# Sčítání: ±1, ±2, cifrová chyba (±10), správný výsledek ±10
		candidates.append(correct + 1)
		candidates.append(correct - 1)
		candidates.append(correct + 2)
		candidates.append(correct - 2)
		candidates.append(correct + 10)
		if correct >= 10:
			candidates.append(correct - 10)

	elif skill_key.begins_with("sub"):
		# Odčítání: prohození operandů (a-b vs b-a), ±1, zapomenutá výpůjčka (±10)
		candidates.append(correct + 1)
		candidates.append(correct - 1)
		candidates.append(correct + 10)
		if correct >= 10:
			candidates.append(correct - 10)
		# Prohození operandů — správná odpověď pro prohozené operandy bývá jiná hodnota;
		# simulujeme jako ±(rozdíl), což pokryje typické chyby "prohozených číslic"
		if correct > 0:
			candidates.append(correct + 2 * correct)  # b - a kdyby b < a, fallback

	elif skill_key.begins_with("mul"):
		# Násobilka: sousední násobek (a*(b±1)), nebo a+b (typická chyba záměny + za ×)
		# correct = k * b; sousední: k*(b+1) a k*(b-1)
		# Odhadneme k z skill_key
		var k: int = int(skill_key.substr(5))  # "mul_x7" → 7
		candidates.append(correct + k)   # k*(b+1) = k*b + k
		candidates.append(correct - k)   # k*(b-1) = k*b - k
		# "a+b" chyba: pro příklad "k × b", chyba je k+b
		# b = correct / k; pokud dělí beze zbytku
		if k > 0 and correct % k == 0:
			var b_val: int = correct / k
			candidates.append(k + b_val)  # typická chyba: sčítání místo násobení
		candidates.append(correct + 1)
		candidates.append(correct - 1)

	elif skill_key == "div_0_100":
		# Dělení: sousední kvocient (±1), a-b
		candidates.append(correct + 1)
		candidates.append(correct - 1)
		candidates.append(correct + 2)
		candidates.append(correct - 2)

	else:
		# Fallback pro neznámou operaci
		candidates.append(correct + rng.randi_range(1, 5))
		candidates.append(correct - rng.randi_range(1, 5))

	return candidates

# ---------------------------------------------------------------------------
# Pomocné funkce
# ---------------------------------------------------------------------------

## Zamíchá pole in-place pomocí Fisher-Yates algoritmu s daným RNG.
static func _shuffle_array(arr: Array[int], rng: RandomNumberGenerator) -> void:
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
