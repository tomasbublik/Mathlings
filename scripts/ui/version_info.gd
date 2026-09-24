class_name VersionInfo
## Reads `application/config/version` from project settings and formats it
## for display in the Main Menu (and anywhere else we want to surface the
## running build).
##
## Two reasons this lives in its own class:
##   1. Bug reports become trivially actionable when the user can read off
##      the exact build they ran.
##   2. Pure-function `format_for_display` is easy to unit-test, unlike the
##      scene-bound Label that consumes it.
## Reference: specs/P21_version_display.md


## ProjectSettings key holding the canonical version string.
## Source of truth lives in project.godot::application/config/version.
const PROJECT_VERSION_KEY: String = "application/config/version"

## Fallback when the project setting is missing or blank — keeps the UI
## from rendering an empty "v" prefix in malformed builds.
const UNKNOWN_VERSION: String = "0.0.0"

## Marker appended to debug builds so testers don't confuse them with
## release APKs in screenshots.
const DEBUG_SUFFIX: String = "+debug"


## Returns the version configured in project.godot. `default` is returned
## when the setting is missing or set to an empty string.
static func current_version(default: String = UNKNOWN_VERSION) -> String:
	var raw: Variant = ProjectSettings.get_setting(PROJECT_VERSION_KEY, default)
	var version: String = String(raw).strip_edges()
	return version if version != "" else default


## Formats `version` for display, prefixing "v" and appending DEBUG_SUFFIX
## when running in a debug build. Pure function so tests can pin behavior
## without touching `OS.is_debug_build()`.
static func format_for_display(version: String, is_debug: bool) -> String:
	return "v%s%s" % [version, (DEBUG_SUFFIX if is_debug else "")]


## Convenience wrapper combining the two functions above. The Main Menu
## scene calls this once on `_ready`.
static func display_string() -> String:
	return format_for_display(current_version(), OS.is_debug_build())
