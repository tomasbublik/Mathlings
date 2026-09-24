## GUT unit testy pro ProblemGenerator a Problem.
##
## Pokrývá všechny body ze sekce "Testy" v specs/P1_problem_generator.md:
## - 500 vygenerovaných problémů per skill_key: validita, choices.size()==3, žádné duplicity,
##   žádné záporné, choices[correct_index] == correct_answer.
## - Specifické invarianty per skill: add_0_20 součet ≤ 20, sub_0_100 výsledek ≥ 0,
##   mul_x7 jeden operand == 7, div_0_100 dělí beze zbytku.
## - Neznámý skill_key vrací {}.
## - Determinismus: stejný seed → stejný výsledek.

extends GutTest

# ---------------------------------------------------------------------------
# Pomocné metody
# ---------------------------------------------------------------------------

## Vytvoří RNG se zadaným seedem (pro determinismus).
func _rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

## Parsuje výraz "a OP b" a vrací Dictionary s klíči a, op, b.
func _parse_expression(expression: String) -> Dictionary:
	# Podporované operátory: +, -, ×, ÷
	var ops: Array[String] = [" + ", " - ", " × ", " ÷ "]
	for op: String in ops:
		if op in expression:
			var parts: PackedStringArray = expression.split(op)
			if parts.size() == 2:
				return {
					"a": int(parts[0].strip_edges()),
					"op": op.strip_edges(),
					"b": int(parts[1].strip_edges()),
				}
	return {}

# ---------------------------------------------------------------------------
# Testy: neznámý skill_key
# ---------------------------------------------------------------------------

func test_unknown_skill_key_returns_empty() -> void:
	var result: Dictionary = ProblemGenerator.generate("unknown_skill")
	assert_eq(result, {}, "Neznamy skill_key musi vracet {}")

func test_empty_skill_key_returns_empty() -> void:
	var result: Dictionary = ProblemGenerator.generate("")
	assert_eq(result, {}, "Prazdny skill_key musi vracet {}")

func test_null_rng_is_accepted() -> void:
	# generate() s null RNG nesmi crashnout
	var result: Dictionary = ProblemGenerator.generate("add_0_10", null)
	assert_false(result.is_empty(), "generate() s null RNG musi vracet validni problem")

# ---------------------------------------------------------------------------
# Testy: supported_skills()
# ---------------------------------------------------------------------------

func test_supported_skills_not_empty() -> void:
	var skills: PackedStringArray = ProblemGenerator.supported_skills()
	assert_gt(skills.size(), 0, "supported_skills() musi vracet neprazdny seznam")

func test_supported_skills_contains_all_design_keys() -> void:
	var skills: PackedStringArray = ProblemGenerator.supported_skills()
	var expected: Array[String] = [
		"add_0_10", "add_0_20", "add_0_100",
		"sub_0_10", "sub_0_20", "sub_0_100",
		"mul_x2", "mul_x3", "mul_x4", "mul_x5", "mul_x6",
		"mul_x7", "mul_x8", "mul_x9", "mul_x10",
		"div_0_100",
	]
	for key: String in expected:
		assert_true(key in skills, "supported_skills() musi obsahovat '%s'" % key)

# ---------------------------------------------------------------------------
# Testy: determinismus (stejný seed → stejný výsledek)
# ---------------------------------------------------------------------------

func test_determinism_same_seed_gives_same_result() -> void:
	var skill: String = "add_0_20"
	var p1: Dictionary = ProblemGenerator.generate(skill, _rng(42))
	var p2: Dictionary = ProblemGenerator.generate(skill, _rng(42))
	assert_eq(p1["expression"], p2["expression"], "Stejny seed musi dat stejny vyraz")
	assert_eq(p1["correct_answer"], p2["correct_answer"], "Stejny seed musi dat stejnou spravnou odpoved")
	assert_eq(p1["choices"], p2["choices"], "Stejny seed musi dat stejne volby")
	assert_eq(p1["correct_index"], p2["correct_index"], "Stejny seed musi dat stejny correct_index")

func test_determinism_different_seeds_give_different_results() -> void:
	# S různými seedy obvykle dostaneme různé výsledky (s drtivou pravděpodobností)
	var skill: String = "add_0_20"
	var same_count: int = 0
	var trials: int = 10
	for i: int in range(trials):
		var p1: Dictionary = ProblemGenerator.generate(skill, _rng(i * 1000))
		var p2: Dictionary = ProblemGenerator.generate(skill, _rng(i * 1000 + 500))
		if p1["expression"] == p2["expression"]:
			same_count += 1
	# Tolerance: nanejvýš polovina může náhodně splynout
	assert_lt(same_count, trials / 2 + 1,
		"Ruzne seedy musi davat prevazne ruzne vysledky")

# ---------------------------------------------------------------------------
# Testy: 500 vygenerovaných problémů per skill_key
# ---------------------------------------------------------------------------

func _run_bulk_test(skill_key: String, extra_check: Callable = Callable()) -> void:
	var count: int = 500
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 123456

	for i: int in range(count):
		var problem: Dictionary = ProblemGenerator.generate(skill_key, rng)

		# Musí vrátit neprázdný dict
		assert_false(problem.is_empty(),
			"[%s] Problem #%d nesmí být prázdný" % [skill_key, i])

		# Správné klíče
		for key: String in Problem.REQUIRED_KEYS:
			assert_true(problem.has(key),
				"[%s] Problem #%d chybi klic '%s'" % [skill_key, i, key])

		# choices.size() == 3
		var choices: Array = problem["choices"]
		assert_eq(choices.size(), 3,
			"[%s] Problem #%d: choices.size() musi byt 3" % [skill_key, i])

		# Žádné záporné hodnoty
		for val: int in choices:
			assert_gte(val, 0,
				"[%s] Problem #%d: choices nesmi obsahovat zaporne hodnoty (val=%d)" % [skill_key, i, val])

		# Žádné duplicity
		assert_ne(choices[0], choices[1],
			"[%s] Problem #%d: choices[0] == choices[1] (duplikat)" % [skill_key, i])
		assert_ne(choices[0], choices[2],
			"[%s] Problem #%d: choices[0] == choices[2] (duplikat)" % [skill_key, i])
		assert_ne(choices[1], choices[2],
			"[%s] Problem #%d: choices[1] == choices[2] (duplikat)" % [skill_key, i])

		# correct_index ukazuje na správnou odpověď
		var correct_index: int = problem["correct_index"]
		assert_true(correct_index >= 0 and correct_index <= 2,
			"[%s] Problem #%d: correct_index mimo rozsah (=%d)" % [skill_key, i, correct_index])
		assert_eq(choices[correct_index], problem["correct_answer"],
			"[%s] Problem #%d: choices[correct_index] != correct_answer" % [skill_key, i])

		# correct_answer ∉ distractors (musí být právě jednou v choices)
		var correct: int = problem["correct_answer"]
		var correct_count: int = 0
		for val: int in choices:
			if val == correct:
				correct_count += 1
		assert_eq(correct_count, 1,
			"[%s] Problem #%d: correct_answer se v choices vyskytuje %dx (musi byt 1x)" % [skill_key, i, correct_count])

		# difficulty je kladné číslo
		assert_gt(float(problem["difficulty"]), 0.0,
			"[%s] Problem #%d: difficulty musi byt kladne" % [skill_key, i])

		# skill_key odpovídá
		assert_eq(problem["skill_key"], skill_key,
			"[%s] Problem #%d: skill_key neodpovida" % [skill_key, i])

		# Ověřit správnost výpočtu z expression
		var parsed: Dictionary = _parse_expression(problem["expression"])
		assert_false(parsed.is_empty(),
			"[%s] Problem #%d: nelze parsovat expression '%s'" % [skill_key, i, problem["expression"]])

		var a: int = parsed["a"]
		var b: int = parsed["b"]
		var op: String = parsed["op"]
		var expected_answer: int = 0
		match op:
			"+":
				expected_answer = a + b
			"-":
				expected_answer = a - b
			"×":
				expected_answer = a * b
			"÷":
				if b != 0:
					expected_answer = a / b

		assert_eq(problem["correct_answer"], expected_answer,
			"[%s] Problem #%d: correct_answer=%d nesedi s expression '%s' (ocekavano %d)" % [
				skill_key, i, problem["correct_answer"], problem["expression"], expected_answer])

		# Volitelný extra check per skill
		if extra_check.is_valid():
			extra_check.call(problem, i)

# --- add_0_10 ---
func test_bulk_add_0_10() -> void:
	_run_bulk_test("add_0_10", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_lte(parsed["a"] + parsed["b"], 10,
			"add_0_10: soucet musi byt <= 10")
		assert_gte(parsed["a"], 0)
		assert_gte(parsed["b"], 0)
		assert_lte(parsed["a"], 10)
		assert_lte(parsed["b"], 10)
	)

# --- add_0_20 ---
func test_bulk_add_0_20() -> void:
	_run_bulk_test("add_0_20", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_lte(parsed["a"] + parsed["b"], 20,
			"add_0_20: soucet musi byt <= 20")
		assert_gte(parsed["a"], 0)
		assert_gte(parsed["b"], 0)
	)

# --- add_0_100 ---
func test_bulk_add_0_100() -> void:
	_run_bulk_test("add_0_100", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_lte(parsed["a"] + parsed["b"], 100,
			"add_0_100: soucet musi byt <= 100")
		assert_gte(parsed["a"], 0)
		assert_gte(parsed["b"], 0)
	)

# --- sub_0_10 ---
func test_bulk_sub_0_10() -> void:
	_run_bulk_test("sub_0_10", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_gte(parsed["a"] - parsed["b"], 0,
			"sub_0_10: vysledek musi byt >= 0")
		assert_lte(parsed["a"], 10)
		assert_gte(parsed["b"], 0)
		assert_gte(parsed["a"], 0)
	)

# --- sub_0_20 ---
func test_bulk_sub_0_20() -> void:
	_run_bulk_test("sub_0_20", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_gte(parsed["a"] - parsed["b"], 0,
			"sub_0_20: vysledek musi byt >= 0")
		assert_lte(parsed["a"], 20)
		assert_gte(parsed["b"], 0)
	)

# --- sub_0_100 ---
func test_bulk_sub_0_100() -> void:
	_run_bulk_test("sub_0_100", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_gte(parsed["a"] - parsed["b"], 0,
			"sub_0_100: vysledek musi byt >= 0")
		assert_lte(parsed["a"], 100)
		assert_gte(parsed["b"], 0)
	)

# --- mul_x2 až mul_x10 ---
func test_bulk_mul_x2() -> void:
	_run_bulk_test("mul_x2", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 2, "mul_x2: prvni operand musi byt 2")
		assert_gte(parsed["b"], 1)
		assert_lte(parsed["b"], 10)
	)

func test_bulk_mul_x3() -> void:
	_run_bulk_test("mul_x3", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 3, "mul_x3: prvni operand musi byt 3")
	)

func test_bulk_mul_x4() -> void:
	_run_bulk_test("mul_x4", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 4, "mul_x4: prvni operand musi byt 4")
	)

func test_bulk_mul_x5() -> void:
	_run_bulk_test("mul_x5", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 5, "mul_x5: prvni operand musi byt 5")
	)

func test_bulk_mul_x6() -> void:
	_run_bulk_test("mul_x6", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 6, "mul_x6: prvni operand musi byt 6")
	)

func test_bulk_mul_x7() -> void:
	# Spec: mul_x7 - jeden operand je 7
	_run_bulk_test("mul_x7", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 7, "mul_x7: prvni operand musi byt 7")
		assert_gte(parsed["b"], 1)
		assert_lte(parsed["b"], 10)
	)

func test_bulk_mul_x8() -> void:
	_run_bulk_test("mul_x8", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 8, "mul_x8: prvni operand musi byt 8")
	)

func test_bulk_mul_x9() -> void:
	_run_bulk_test("mul_x9", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 9, "mul_x9: prvni operand musi byt 9")
	)

func test_bulk_mul_x10() -> void:
	_run_bulk_test("mul_x10", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		assert_eq(parsed["a"], 10, "mul_x10: prvni operand musi byt 10")
	)

# --- div_0_100 ---
func test_bulk_div_0_100() -> void:
	_run_bulk_test("div_0_100", func(p: Dictionary, _i: int) -> void:
		var parsed := _parse_expression(p["expression"])
		var a: int = parsed["a"]
		var b: int = parsed["b"]
		# Dělí beze zbytku
		assert_eq(a % b, 0,
			"div_0_100: %d / %d musi delit beze zbytku" % [a, b])
		# b ∈ [2, 10]
		assert_gte(b, 2, "div_0_100: delitel musi byt >= 2")
		assert_lte(b, 10, "div_0_100: delitel musi byt <= 10")
		# Výsledek (kvocient) ∈ [2, 10]
		var q: int = a / b
		assert_gte(q, 2, "div_0_100: kvocient musi byt >= 2")
		assert_lte(q, 10, "div_0_100: kvocient musi byt <= 10")
		# a ≤ 100
		assert_lte(a, 100, "div_0_100: delenec musi byt <= 100")
	)

# ---------------------------------------------------------------------------
# Testy: Problem.is_valid() helper
# ---------------------------------------------------------------------------

func test_problem_is_valid_correct_dict() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "add_0_20",
		"expression": "7 + 5",
		"correct_answer": 12,
		"choices": [13, 12, 10],
		"correct_index": 1,
		"difficulty": 1000.0,
	}
	assert_true(Problem.is_valid(p), "Validni problem musi projit is_valid()")

func test_problem_is_valid_rejects_wrong_correct_index() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "add_0_20",
		"expression": "7 + 5",
		"correct_answer": 12,
		"choices": [13, 12, 10],
		"correct_index": 0,  # špatně — correct je na indexu 1
		"difficulty": 1000.0,
	}
	assert_false(Problem.is_valid(p), "Spatny correct_index musi selhat is_valid()")

func test_problem_is_valid_rejects_negative_choices() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "sub_0_10",
		"expression": "3 - 5",
		"correct_answer": -2,
		"choices": [-2, 1, 2],
		"correct_index": 0,
		"difficulty": 950.0,
	}
	assert_false(Problem.is_valid(p), "Zaporne hodnoty v choices musi selhat is_valid()")

func test_problem_is_valid_rejects_duplicates() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "add_0_10",
		"expression": "3 + 3",
		"correct_answer": 6,
		"choices": [6, 6, 7],
		"correct_index": 0,
		"difficulty": 900.0,
	}
	assert_false(Problem.is_valid(p), "Duplicity v choices musi selhat is_valid()")

func test_problem_is_valid_rejects_wrong_size() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "add_0_10",
		"expression": "3 + 3",
		"correct_answer": 6,
		"choices": [6, 7],  # jen 2 položky
		"correct_index": 0,
		"difficulty": 900.0,
	}
	assert_false(Problem.is_valid(p), "choices.size() != 3 musi selhat is_valid()")

func test_problem_is_valid_rejects_missing_key() -> void:
	var p: Dictionary = {
		"id": 0,
		"skill_key": "add_0_10",
		# chybí expression, correct_answer, choices, correct_index, difficulty
	}
	assert_false(Problem.is_valid(p), "Chybejici klic musi selhat is_valid()")

# ---------------------------------------------------------------------------
# Testy: správnost difficulty dle DESIGN §6.2
# ---------------------------------------------------------------------------

func test_difficulty_add_0_10() -> void:
	var p: Dictionary = ProblemGenerator.generate("add_0_10", _rng(1))
	assert_eq(p["difficulty"], 900.0, "add_0_10 difficulty musi byt 900.0")

func test_difficulty_add_0_20() -> void:
	var p: Dictionary = ProblemGenerator.generate("add_0_20", _rng(1))
	assert_eq(p["difficulty"], 1000.0, "add_0_20 difficulty musi byt 1000.0")

func test_difficulty_add_0_100() -> void:
	var p: Dictionary = ProblemGenerator.generate("add_0_100", _rng(1))
	assert_eq(p["difficulty"], 1100.0, "add_0_100 difficulty musi byt 1100.0")

func test_difficulty_sub_0_10() -> void:
	var p: Dictionary = ProblemGenerator.generate("sub_0_10", _rng(1))
	assert_eq(p["difficulty"], 950.0, "sub_0_10 difficulty musi byt 950.0")

func test_difficulty_mul_x7() -> void:
	var p: Dictionary = ProblemGenerator.generate("mul_x7", _rng(1))
	assert_eq(p["difficulty"], 1150.0, "mul_x7 difficulty musi byt 1150.0")

func test_difficulty_div_0_100() -> void:
	var p: Dictionary = ProblemGenerator.generate("div_0_100", _rng(1))
	assert_eq(p["difficulty"], 1200.0, "div_0_100 difficulty musi byt 1200.0")

# ---------------------------------------------------------------------------
# Testy: Problem.DIFFICULTY konstanta
# ---------------------------------------------------------------------------

func test_difficulty_constant_mul_formula() -> void:
	# DESIGN §6.2: mul_xk difficulty = 1000 + (k-2)*30
	for k: int in range(2, 11):
		var key: String = "mul_x%d" % k
		var expected: float = 1000.0 + float(k - 2) * 30.0
		assert_eq(Problem.DIFFICULTY[key], expected,
			"%s difficulty musi byt %.1f (DESIGN formula)" % [key, expected])

# ---------------------------------------------------------------------------
# Testy: id je 0 (nastavuje volající)
# ---------------------------------------------------------------------------

func test_id_is_zero() -> void:
	var p: Dictionary = ProblemGenerator.generate("add_0_20", _rng(77))
	assert_eq(p["id"], 0, "id musi byt 0 — nastavuje volajici")

# ---------------------------------------------------------------------------
# Testy: distribuce — choices nejsou vždy ve stejném pořadí
# ---------------------------------------------------------------------------

func test_choices_shuffled() -> void:
	# Ověří, že correct_index není vždy 0 (tj. dochází k míchání)
	var skill: String = "add_0_20"
	var index_counts: Dictionary = {0: 0, 1: 0, 2: 0}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 999
	for i: int in range(300):
		var p: Dictionary = ProblemGenerator.generate(skill, rng)
		var ci: int = p["correct_index"]
		index_counts[ci] = index_counts[ci] + 1
	# Každý index by měl být zastoupen alespoň 5% z 300 = 15×
	for idx: int in [0, 1, 2]:
		assert_gte(index_counts[idx], 15,
			"correct_index=%d se vyskytl jen %dx — choices pravdepodobne nejsou michane" % [idx, index_counts[idx]])
