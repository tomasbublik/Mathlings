## GUT unit tests for LocaleCatalog.
## Pure-data lookup helper — tests stay focused on the contract surface so
## adding a new locale to SUPPORTED only requires adding the row, not
## rewriting these tests.

extends GutTest


func test_default_locale_is_in_catalog() -> void:
	# DEFAULT_LOCALE is the fallback when settings is missing / corrupt.
	# It must point to an actual row, otherwise LocaleService can't apply it.
	assert_true(LocaleCatalog.is_supported(LocaleCatalog.DEFAULT_LOCALE))


func test_supported_list_is_non_empty_and_typed() -> void:
	assert_true(LocaleCatalog.SUPPORTED.size() >= 1)
	for entry in LocaleCatalog.SUPPORTED:
		assert_true(entry is Dictionary)
		assert_true(entry.has("code"))
		assert_true(entry.has("native"))
		assert_true(entry.has("rtl"))


func test_native_names_are_non_empty() -> void:
	for entry in LocaleCatalog.SUPPORTED:
		var native: String = String(entry["native"]).strip_edges()
		assert_ne(native, "",
			"locale '%s' must have a non-empty native name" % entry["code"])


func test_rtl_only_arabic_and_urdu_in_current_catalog() -> void:
	# Sanity check on flag coverage. If we add another RTL language later,
	# update this list — better than silently mis-flipping a layout.
	var rtl_codes: Array[String] = []
	for entry in LocaleCatalog.SUPPORTED:
		if bool(entry["rtl"]):
			rtl_codes.append(String(entry["code"]))
	rtl_codes.sort()
	assert_eq(rtl_codes, ["ar", "ur"],
		"current catalog only declares Arabic + Urdu as RTL — review on additions")


func test_is_supported_handles_unknown() -> void:
	assert_false(LocaleCatalog.is_supported("xx"))
	assert_false(LocaleCatalog.is_supported(""))


func test_is_rtl_returns_false_for_unknown() -> void:
	# Defensive: never return true for an unknown locale (would mis-flip
	# layout for free-typed strings).
	assert_false(LocaleCatalog.is_rtl("xx"))


func test_native_name_falls_back_to_code() -> void:
	assert_eq(LocaleCatalog.native_name("xx"), "xx",
		"unknown code must echo back rather than render empty")


func test_all_codes_matches_supported() -> void:
	var codes := LocaleCatalog.all_codes()
	assert_eq(codes.size(), LocaleCatalog.SUPPORTED.size())
	for entry in LocaleCatalog.SUPPORTED:
		assert_true(String(entry["code"]) in codes)
