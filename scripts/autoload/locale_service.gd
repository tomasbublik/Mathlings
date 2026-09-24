extends Node
## Glue between SettingsStore and Godot's TranslationServer.
##
## Responsibilities:
##   1. On startup, read `general/locale` and apply it to TranslationServer
##      (and the root Control's `layout_direction` for RTL languages).
##   2. Watch `EventBus.settings_changed` so changing the language in
##      Settings takes effect without restarting the app.
##   3. Expose helpers (`current()`, `apply_to_root()`) used by scenes that
##      need to repaint after a switch (e.g. the Settings scene).
##
## Translations themselves are bundled .translation files compiled from
## `assets/translations/strings.csv` (registered in project.godot under
## internationalization/locale/translations).
##
## Reference: specs/P18_i18n.md, DESIGN.md §6.3 (settings keys).

const LOCALE_KEY: String = "general/locale"


func _ready() -> void:
	# Apply the persisted locale before any scene loads its UI strings, so
	# the very first frame already shows the correct language.
	apply_to_root(_resolved_locale())
	EventBus.settings_changed.connect(_on_settings_changed)


## Returns the locale code currently in effect (matches the persisted value
## OR the LocaleCatalog default if the persisted value is missing/invalid).
func current() -> String:
	return _resolved_locale()


## Applies `code` everywhere that matters: TranslationServer, the root
## Control's layout direction (LTR / RTL), and Godot's Tree-wide auto
## translate. Doesn't persist — call SettingsStore.set_value separately
## when the change should outlive the session.
func apply_to_root(code: String) -> void:
	if not LocaleCatalog.is_supported(code):
		code = LocaleCatalog.DEFAULT_LOCALE
	TranslationServer.set_locale(code)

	# Set RTL on the running scene's root if there is one. During autoload
	# bootstrap the scene tree exists but the user-facing scene hasn't been
	# pushed yet — the same call runs again from _on_settings_changed once
	# the user navigates further, so first-frame timing isn't a concern.
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	if root == null:
		return
	var direction := (Control.LAYOUT_DIRECTION_RTL if LocaleCatalog.is_rtl(code)
		else Control.LAYOUT_DIRECTION_LTR)
	# Walk every Control descendant of the active scene so existing UI
	# updates without scene reload. Cheap (a few dozen nodes total).
	for control in _all_controls(root):
		control.layout_direction = direction


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_settings_changed(key: String, value: Variant) -> void:
	if key != LOCALE_KEY:
		return
	apply_to_root(String(value))


## Reads the locale from settings, validating against the catalog. Falls
## back to LocaleCatalog.DEFAULT_LOCALE for unknown codes so a corrupted
## settings.cfg never lands the player on an unsupported language.
func _resolved_locale() -> String:
	var raw := String(SettingsStore.get_value(LOCALE_KEY, LocaleCatalog.DEFAULT_LOCALE))
	if LocaleCatalog.is_supported(raw):
		return raw
	# `cs_CZ` was the legacy DEFAULT — accept it as plain "cs" so existing
	# installations don't get silently flipped to English on upgrade.
	if raw.begins_with("cs"):
		return "cs"
	return LocaleCatalog.DEFAULT_LOCALE


## Recursive collector of every Control under `node` (so `apply_to_root`
## doesn't have to know about the scene structure).
func _all_controls(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	for child in node.get_children():
		if child is Control:
			out.append(child)
		out.append_array(_all_controls(child))
	return out
