class_name SkillLabels
## Skill_key → translation lookup.
##
## Used to be a Czech-only Dictionary. Since P18 the labels live in
## assets/translations/strings.csv under SKILL_<UPPER_SKILL_KEY> keys
## (e.g. `SKILL_ADD_0_20`). We resolve them through `tr()` so a single
## edit to the CSV propagates to every locale.
##
## When a key is missing from the CSV (a brand-new skill someone added
## without a translation), `tr()` returns the key unchanged — we then
## emit the raw machine identifier so the bug is visible rather than the
## label silently rendering empty.
##
## Reference: specs/P8b_settings_screen.md, specs/P18_i18n.md


## Mirror of the CSV keys, kept here so callers (tests, settings UI) can
## iterate without parsing CSV. Should match `ProblemGenerator.supported_skills()`
## one-for-one.
const TRANSLATION_KEYS: Dictionary = {
	"add_0_10":  "SKILL_ADD_0_10",
	"add_0_20":  "SKILL_ADD_0_20",
	"add_0_100": "SKILL_ADD_0_100",
	"sub_0_10":  "SKILL_SUB_0_10",
	"sub_0_20":  "SKILL_SUB_0_20",
	"sub_0_100": "SKILL_SUB_0_100",
	"mul_x2":    "SKILL_MUL_X2",
	"mul_x3":    "SKILL_MUL_X3",
	"mul_x4":    "SKILL_MUL_X4",
	"mul_x5":    "SKILL_MUL_X5",
	"mul_x6":    "SKILL_MUL_X6",
	"mul_x7":    "SKILL_MUL_X7",
	"mul_x8":    "SKILL_MUL_X8",
	"mul_x9":    "SKILL_MUL_X9",
	"mul_x10":   "SKILL_MUL_X10",
	"div_0_100": "SKILL_DIV_0_100",
}


## Returns the translated label for `skill_key`. Unknown skills fall back to
## the raw key (visible bug rather than silent empty string).
static func label_for(skill_key: String) -> String:
	if not TRANSLATION_KEYS.has(skill_key):
		return skill_key
	# TranslationServer.translate() is a global function; we call it via
	# the standard tr-style API so it picks up the active locale.
	return TranslationServer.translate(String(TRANSLATION_KEYS[skill_key]))
