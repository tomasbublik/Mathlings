## Problem — konstanty a helper funkce pro Problem Dictionary kontrakt.
##
## Problem Dictionary (viz DESIGN §7.1):
##   "id"             : int    — autoinkrement per session (nastavuje volající)
##   "skill_key"      : String — viz DESIGN §6.2
##   "expression"     : String — např. "7 + 5"
##   "correct_answer" : int
##   "choices"        : Array[int] — délka 3, zamícháno
##   "correct_index"  : int    — index správné odpovědi v choices
##   "difficulty"     : float  — D pro Elo dle §6.2

class_name Problem

## Povinné klíče Problem Dictionary.
const REQUIRED_KEYS: PackedStringArray = [
	"id",
	"skill_key",
	"expression",
	"correct_answer",
	"choices",
	"correct_index",
	"difficulty",
]

## Obtížnosti (D) per skill_key dle DESIGN §6.2.
const DIFFICULTY: Dictionary = {
	"add_0_10":  900.0,
	"add_0_20":  1000.0,
	"add_0_100": 1100.0,
	"sub_0_10":  950.0,
	"sub_0_20":  1050.0,
	"sub_0_100": 1150.0,
	"mul_x2":    1000.0,
	"mul_x3":    1030.0,
	"mul_x4":    1060.0,
	"mul_x5":    1090.0,
	"mul_x6":    1120.0,
	"mul_x7":    1150.0,
	"mul_x8":    1180.0,
	"mul_x9":    1210.0,
	"mul_x10":   1240.0,
	"div_0_100": 1200.0,
}

## Zkontroluje, zda Dictionary splňuje kontrakt Problem.
## Vrací true pokud dict obsahuje všechny povinné klíče a základní invarianty:
##   - choices.size() == 3
##   - correct_index ∈ [0, 2]
##   - choices[correct_index] == correct_answer
##   - žádná záporná hodnota v choices
static func is_valid(problem: Dictionary) -> bool:
	for key: String in REQUIRED_KEYS:
		if not problem.has(key):
			return false

	var choices: Array = problem["choices"]
	if choices.size() != 3:
		return false

	var correct_index: int = problem["correct_index"]
	if correct_index < 0 or correct_index > 2:
		return false

	if choices[correct_index] != problem["correct_answer"]:
		return false

	for val: int in choices:
		if val < 0:
			return false

	# Žádné duplicity v choices
	if choices[0] == choices[1] or choices[0] == choices[2] or choices[1] == choices[2]:
		return false

	return true
