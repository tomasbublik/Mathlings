extends Node
## Central audio playback manager for SFX and music.
## Manages a pool of AudioStreamPlayers for SFX with round-robin allocation.
## Music uses dedicated player with fade-in/out via tween.
## Reference: DESIGN.md §7.3 Autoload API, specs/P3_audio_manager.md

const AudioCatalog := preload("res://scripts/autoload/audio_catalog.gd")

const SFX_POOL_SIZE := 4

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_current_index: int = 0
var _music_player: AudioStreamPlayer
var _music_tween: Tween

var _sfx_enabled: bool = true
var _music_enabled: bool = true
var _last_requested_music_key: String = ""
var _current_music_key: String = ""
var _target_music_volume_db: float = 0.0


func _ready() -> void:
	_init_sfx_pool()
	_init_music_player()
	_load_audio_flags()
	EventBus.settings_changed.connect(_on_settings_changed)


## Initialize SFX player pool (4 × AudioStreamPlayer for round-robin playback).
func _init_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)


## Initialize dedicated music player.
##
## We hook the `finished` signal so we can re-trigger play() if the stream
## ever ends despite its loop_mode being LOOP_FORWARD. AudioStreamWAV import
## flags should already make the stream loop natively, but a stale
## .godot/imported cache or a sub-stream whose loop flag got dropped during
## duplication has burned us before — the manual replay is a cheap belt
## and braces against silent silence.
func _init_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = 0.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


## Restarts the music when the stream ends naturally and a track is still
## meant to be playing. Explicit stop_music() clears `_current_music_key`
## *before* calling stop(), so this hook stays quiet on user-driven stops.
func _on_music_finished() -> void:
	if _current_music_key != "" and _music_enabled:
		_music_player.play()


## Load audio enable flags from SettingsStore at startup.
func _load_audio_flags() -> void:
	_sfx_enabled = SettingsStore.get_value("general/audio_sfx", true)
	_music_enabled = SettingsStore.get_value("general/audio_music", true)


## Listen for settings changes and re-cache audio flags.
func _on_settings_changed(key: String, value: Variant) -> void:
	if key == "general/audio_sfx":
		_sfx_enabled = value as bool
	elif key == "general/audio_music":
		_music_enabled = value as bool
		if _music_enabled and _last_requested_music_key != "":
			play_music(_last_requested_music_key)
		elif not _music_enabled:
			_stop_music_immediately()


## Play a sound effect from the catalog.
## Key must exist in AudioCatalog.SFX; missing keys emit a warning.
## When the catalog points at a path that doesn't exist on disk (typical for
## work-in-progress SFX like `lightsaber.wav`), we silently no-op — the
## player would otherwise see a flood of "Resource file not found" errors.
func play_sfx(key: String) -> void:
	if not _sfx_enabled:
		return

	if not AudioCatalog.SFX.has(key):
		push_warning("AudioManager: Unknown SFX key '%s'" % key)
		return

	var path: String = AudioCatalog.SFX[key]
	var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as AudioStream
	if stream == null:
		push_warning("AudioManager: Failed to load SFX '%s' at '%s'" % [key, path])
		return

	var player := _get_next_sfx_player()
	player.stream = stream
	player.play()


## Plays an ordered sequence of SFX with per-element offsets.
##
## `chain` must be an Array of Dictionaries with shape:
##     {"key": String, "delay_ms": int}
##
## `delay_ms` is measured **from the start of the chain** (NOT cumulative),
## which makes it trivial to reason about an audio storyboard:
## { lightsaber@0ms, explosion@350ms } reads as "explosion lands 350 ms
## after lightsaber begins".
##
## Empty chains, missing keys, and SFX-disabled state are no-ops. Each
## scheduled play uses an awaitable `SceneTreeTimer` so cancelling the
## scene cancels the chain too — no orphan timers fire after navigation.
func play_sfx_chain(chain: Array) -> void:
	if not _sfx_enabled:
		return
	for entry in chain:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var key: String = String(d.get("key", ""))
		if key == "":
			continue
		var delay_ms: int = int(d.get("delay_ms", 0))
		_play_sfx_after(key, delay_ms)


## Schedules a single SFX play `delay_ms` from now. Pulled out so the chain
## helper stays tiny and so a future caller can use it directly.
func _play_sfx_after(key: String, delay_ms: int) -> void:
	if delay_ms <= 0:
		play_sfx(key)
		return
	get_tree().create_timer(delay_ms / 1000.0).timeout.connect(
		func() -> void: play_sfx(key))


## Get next available SFX player from pool (round-robin).
func _get_next_sfx_player() -> AudioStreamPlayer:
	var player := _sfx_players[_sfx_current_index]
	_sfx_current_index = (_sfx_current_index + 1) % SFX_POOL_SIZE
	return player


## Play music from the catalog with fade-in.
## Key must exist in AudioCatalog.MUSIC; missing keys emit warning and no-op.
## Fade-in duration controlled by fade_ms parameter.
func play_music(key: String, fade_ms: int = 500) -> void:
	_last_requested_music_key = key
	if not _music_enabled:
		return

	if not AudioCatalog.MUSIC.has(key):
		push_warning("AudioManager: Unknown music key '%s'" % key)
		return

	var path: String = AudioCatalog.MUSIC[key]
	var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as AudioStream
	if stream == null:
		push_warning("AudioManager: Failed to load music '%s' at '%s'" % [key, path])
		return

	if _music_player.playing and _music_player.stream != null and _music_player.stream.resource_path == path:
		_current_music_key = key
		# Ensure volume is correct if we are already playing this track
		if _music_tween and _music_tween.is_valid():
			_music_tween.kill()
		_music_player.volume_db = _target_music_volume_db
		return

	_current_music_key = key
	_music_player.stream = stream
	_music_player.stream_paused = false
	_music_player.volume_db = -80.0
	_music_player.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if fade_ms <= 0:
		_music_player.volume_db = _target_music_volume_db
	else:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", _target_music_volume_db, fade_ms / 1000.0)


## Stop music with fade-out.
## Fade-out duration controlled by fade_ms parameter.
##
## Clears `_current_music_key` *now*, before the fade tween fires the
## callback that actually stops the player, so `_on_music_finished` can't
## misinterpret an in-progress fade-out as "track ended naturally" and
## restart it.
func stop_music(fade_ms: int = 500) -> void:
	if not _music_player.playing:
		_current_music_key = ""
		return

	_current_music_key = ""

	# Cancel existing tween and fade out
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_ms / 1000.0)
	_music_tween.tween_callback(func() -> void:
		_music_player.stop()
	)


func _stop_music_immediately() -> void:
	# Clear key first so _on_music_finished doesn't restart playback.
	_current_music_key = ""
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_player.stop()
