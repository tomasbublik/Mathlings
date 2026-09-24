## GUT unit tests for ResultsLogic — star thresholds, headline choice and
## accuracy rounding on the Results screen.

extends GutTest


func test_stars_thresholds() -> void:
	assert_eq(ResultsLogic.stars_for_accuracy(0.0), 0)
	assert_eq(ResultsLogic.stars_for_accuracy(0.1), 1)
	assert_eq(ResultsLogic.stars_for_accuracy(0.59), 1)
	assert_eq(ResultsLogic.stars_for_accuracy(0.6), 2)
	assert_eq(ResultsLogic.stars_for_accuracy(0.84), 2)
	assert_eq(ResultsLogic.stars_for_accuracy(0.85), 3)
	assert_eq(ResultsLogic.stars_for_accuracy(1.0), 3)


func test_title_key_celebrates_two_or_more_stars() -> void:
	assert_eq(ResultsLogic.title_key(3), "RESULTS_TITLE_GOOD")
	assert_eq(ResultsLogic.title_key(2), "RESULTS_TITLE_GOOD")
	assert_eq(ResultsLogic.title_key(1), "RESULTS_TITLE_OK")
	assert_eq(ResultsLogic.title_key(0), "RESULTS_TITLE_OK")


func test_title_keys_exist_in_translations() -> void:
	var f := FileAccess.open("res://assets/translations/strings.csv", FileAccess.READ)
	assert_not_null(f)
	var keys: Array[String] = []
	while not f.eof_reached():
		keys.append(f.get_csv_line()[0])
	for k in ["RESULTS_TITLE_GOOD", "RESULTS_TITLE_OK", "RESULTS_POINTS",
			"RESULTS_TILE_ACCURACY", "RESULTS_TILE_BEST_STREAK",
			"RESULTS_STATS_BUTTON", "RESULTS_COMING_SOON", "RESULTS_UNLOCK_NEW"]:
		assert_true(k in keys, "missing translation key %s" % k)


func test_accuracy_percent_rounds_and_clamps() -> void:
	assert_eq(ResultsLogic.accuracy_percent(0.904), 90)
	assert_eq(ResultsLogic.accuracy_percent(0.905), 91)
	assert_eq(ResultsLogic.accuracy_percent(1.2), 100)
	assert_eq(ResultsLogic.accuracy_percent(-0.1), 0)
