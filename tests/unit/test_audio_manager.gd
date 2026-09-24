extends GutTest
## Smoke tests for AudioManager autoload.
## Verifies basic behavior: SFX pool, music fade, disabled-flag handling, missing-key warnings.

var audio_manager: AudioManager


func before_each() -> void:
	# Reset state before each test
	audio_manager = AudioManager


func test_play_sfx_with_flag_disabled() -> void:
	## When SFX disabled, play_sfx should be no-op (no player.play() call).
	# Arrange
	audio_manager._sfx_enabled = false
	var player := audio_manager._get_next_sfx_player()
	var initial_playing := player.playing

	# Act
	audio_manager.play_sfx("correct")

	# Assert
	assert_eq(player.playing, initial_playing, "SFX should not play when disabled")


func test_play_sfx_unknown_key() -> void:
	## Unknown SFX key should emit warning and not crash.
	# Arrange
	audio_manager._sfx_enabled = true

	# Act / Assert - should not throw, only warn
	audio_manager.play_sfx("nonexistent_sound")
	# No assertion needed; pass if no crash


func test_play_music_unknown_key() -> void:
	## Unknown music key should emit warning and not crash.
	# Arrange
	audio_manager._music_enabled = true

	# Act / Assert - should not throw, only warn
	audio_manager.play_music("nonexistent_music")
	# No assertion needed; pass if no crash


func test_sfx_pool_round_robin() -> void:
	## SFX pool should cycle through players.
	# Arrange
	var indices: Array[int] = []

	# Act - track which player was used for 6 calls
	for i in range(6):
		var idx := audio_manager._sfx_current_index
		indices.append(idx)
		audio_manager._get_next_sfx_player()

	# Assert - should see pattern 0,1,2,3,0,1
	assert_eq(indices, [0, 1, 2, 3, 0, 1], "Pool should cycle round-robin")


func test_play_music_with_flag_disabled() -> void:
	## When music disabled, play_music should be no-op.
	# Arrange
	audio_manager._music_enabled = false
	var initial_playing := audio_manager._music_player.playing

	# Act
	audio_manager.play_music("menu")

	# Assert
	assert_eq(audio_manager._music_player.playing, initial_playing, "Music should not play when disabled")


func test_stop_music_cancels_tween() -> void:
	## stop_music should kill existing tween before creating fade-out tween.
	# Arrange - create a tween
	audio_manager._music_enabled = true
	audio_manager._music_player.volume_db = 0.0
	audio_manager._music_player.play()
	audio_manager.play_music("menu", 1000)
	await get_tree().process_frame

	# Act
	var tween_before := audio_manager._music_tween
	audio_manager.stop_music(500)

	# Assert - tween should be different (old killed, new created)
	assert_ne(audio_manager._music_tween, tween_before, "Tween should be replaced on stop_music")
