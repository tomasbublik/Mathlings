class_name LocaleCatalog
## Single source of truth for which locales the game ships with.
##
## Keeping the list in code (rather than scanning the translation files at
## runtime) lets us:
##   1. control display order in the picker (English first, Czech second,
##      then the rest by global speaker count),
##   2. annotate each entry with its native name (so a kid who only reads
##      Hindi can still recognise their language) and an RTL flag,
##   3. unit-test every UI string against this list (see test_translations).
##
## Reference: specs/P18_i18n.md

## Default fallback locale — also what TranslationServer falls back to when
## a key is missing in the active locale.
const DEFAULT_LOCALE: String = "en"

## Ordered list of supported locales. Each entry:
##   { "code": "en", "native": "English", "rtl": false }
const SUPPORTED: Array[Dictionary] = [
	{"code": "en",  "native": "English",          "rtl": false},
	{"code": "cs",  "native": "Čeština",          "rtl": false},
	{"code": "zh",  "native": "中文",              "rtl": false},
	{"code": "hi",  "native": "हिन्दी",            "rtl": false},
	{"code": "es",  "native": "Español",          "rtl": false},
	{"code": "fr",  "native": "Français",         "rtl": false},
	{"code": "ar",  "native": "العربية",          "rtl": true },
	{"code": "bn",  "native": "বাংলা",            "rtl": false},
	{"code": "ru",  "native": "Русский",          "rtl": false},
	{"code": "pt",  "native": "Português",        "rtl": false},
	{"code": "ur",  "native": "اردو",             "rtl": true },
	{"code": "id",  "native": "Bahasa Indonesia", "rtl": false},
]


## Returns true when the given locale should render right-to-left (Arabic,
## Urdu). Mirrors the `rtl` flag on the catalog row.
static func is_rtl(code: String) -> bool:
	for entry in SUPPORTED:
		if String(entry["code"]) == code:
			return bool(entry["rtl"])
	return false


## Returns the native-spelled name for a locale code (e.g. "Čeština" for
## "cs"). Falls back to the code itself for unknown locales so the picker
## never shows a blank line.
static func native_name(code: String) -> String:
	for entry in SUPPORTED:
		if String(entry["code"]) == code:
			return String(entry["native"])
	return code


## Returns true when `code` appears in SUPPORTED. Used by LocaleService to
## reject corrupted settings values.
static func is_supported(code: String) -> bool:
	for entry in SUPPORTED:
		if String(entry["code"]) == code:
			return true
	return false


## All supported locale codes as a PackedStringArray — convenient input for
## test loops over the i18n CSV.
static func all_codes() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry in SUPPORTED:
		out.append(String(entry["code"]))
	return out
