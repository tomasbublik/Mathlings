## GUT integration test for the translation CSV.
##
## Reads `assets/translations/strings.csv` directly (not via TranslationServer)
## so we can pin three contracts:
##   1. Every supported locale (LocaleCatalog) has a column.
##   2. No row is missing a value for any locale.
##   3. Format-specifier counts ("%s", "%d", …) match across locales for the
##      same key — a translator dropping a "%d" by accident silently breaks
##      runtime formatting on that one locale only.

extends GutTest


const CSV_PATH: String = "res://assets/translations/strings.csv"


# Cached parse so each test gets the same (immutable) result.
var _rows: Array = []
var _header: PackedStringArray = []


func before_all() -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		fail_test("Couldn't open %s" % CSV_PATH)
		return
	# Godot's CSV reader is overly simple (no quoted-comma support that we
	# need), but the rows we authored use plain commas + escaped quotes
	# only. Stick to the built-in parser; it matches what Godot's importer
	# actually consumes.
	_header = f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() <= 1 and row[0] == "":
			continue
		_rows.append(row)


# ---------------------------------------------------------------------------
# Column / locale coverage
# ---------------------------------------------------------------------------

func test_first_column_is_keys() -> void:
	assert_eq(_header[0], "keys",
		"first CSV column must be the translation key column")


func test_every_supported_locale_has_a_column() -> void:
	for code in LocaleCatalog.all_codes():
		assert_true(code in _header,
			"locale '%s' is in LocaleCatalog but missing from CSV header" % code)


func test_csv_has_no_extra_columns() -> void:
	# Catches the inverse: a translator added a column for a locale we
	# don't actually ship. Header should be exactly `keys` + supported codes.
	for col in _header:
		if col == "keys":
			continue
		assert_true(LocaleCatalog.is_supported(col),
			"CSV has column '%s' which isn't in LocaleCatalog" % col)


# ---------------------------------------------------------------------------
# Per-row completeness
# ---------------------------------------------------------------------------

func test_every_row_has_a_value_for_every_locale() -> void:
	for row in _rows:
		var key: String = row[0]
		for i in range(1, _header.size()):
			var locale: String = _header[i]
			var value: String = row[i] if i < row.size() else ""
			assert_ne(value.strip_edges(), "",
				"key '%s' has empty translation for '%s'" % [key, locale])


# ---------------------------------------------------------------------------
# Format specifier consistency
# ---------------------------------------------------------------------------

func test_format_specifier_counts_match_across_locales() -> void:
	# A translator dropping the "%d" from a Czech sentence won't fail the
	# build, but it will throw at runtime in the CS locale only. This test
	# catches it before release.
	for row in _rows:
		var key: String = row[0]
		var en_value: String = row[1] if row.size() > 1 else ""
		var en_count := _count_format_specifiers(en_value)
		for i in range(2, _header.size()):
			var locale: String = _header[i]
			var value: String = row[i] if i < row.size() else ""
			var count := _count_format_specifiers(value)
			assert_eq(count, en_count,
				"format specifier mismatch for key '%s' in '%s' (%d vs en's %d): '%s'"
					% [key, locale, count, en_count, value])


## Counts %d / %s / %f / %% / %02d-style specifiers in a translation value.
## Brute-force regex is fine for the ~80 strings in the CSV.
func _count_format_specifiers(text: String) -> int:
	var rx := RegEx.new()
	rx.compile("%(\\d*\\.?\\d*)?[dsfx%]")
	return rx.search_all(text).size()
