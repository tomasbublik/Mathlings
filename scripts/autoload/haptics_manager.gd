extends Node
## Thin wrapper over Input.vibrate_handheld() with pattern presets.
## Respects SettingsStore.haptics setting and no-ops on non-mobile platforms.

enum Pattern { LIGHT, MEDIUM, HEAVY, SUCCESS, ERROR, TAP }

var _haptics_enabled: bool = true
var _is_mobile: bool = false


func _ready() -> void:
	_is_mobile = OS.has_feature("mobile")
	_haptics_enabled = SettingsStore.get_value("general/haptics", true)
	EventBus.settings_changed.connect(_on_settings_changed)


## Triggers haptic feedback with the given pattern.
## On mobile platforms: sends vibration command. On others: no-op.
func pulse(pattern: Pattern) -> void:
	if not _is_mobile or not _haptics_enabled:
		return

	match pattern:
		Pattern.TAP:
			# Barely-there tick for UI presses; soft amplitude so it never
			# feels like an error buzz.
			_vibrate(18, 0.45)
		Pattern.LIGHT:
			_vibrate(30)
		Pattern.MEDIUM:
			_vibrate(60)
		Pattern.HEAVY:
			_vibrate(120)
		Pattern.ERROR:
			_vibrate(150)
		Pattern.SUCCESS:
			_vibrate(40)
			await get_tree().create_timer(0.08).timeout
			_vibrate(30)


func _vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)


func _on_settings_changed(key: String, value: Variant) -> void:
	if key == "general/haptics":
		_haptics_enabled = bool(value)
