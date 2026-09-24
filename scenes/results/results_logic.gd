class_name ResultsLogic
extends RefCounted
## Pure helpers for the Results screen (unit-tested in
## tests/unit/test_results_logic.gd).


## 0‥3 stars from round accuracy (0.0‥1.0).
static func stars_for_accuracy(accuracy: float) -> int:
	if accuracy >= 0.85:
		return 3
	if accuracy >= 0.6:
		return 2
	if accuracy > 0.0:
		return 1
	return 0


## Translation key for the headline: celebrate good rounds, encourage the rest.
static func title_key(stars: int) -> String:
	return "RESULTS_TITLE_GOOD" if stars >= 2 else "RESULTS_TITLE_OK"


## Whole-percent accuracy, clamped to 0‥100.
static func accuracy_percent(accuracy: float) -> int:
	return clampi(int(round(accuracy * 100.0)), 0, 100)
