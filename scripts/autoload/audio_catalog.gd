extends Node
## Audio asset registry mapping SFX and music keys to resource paths.
## Reference: DESIGN.md §7.4 Audio SFX klíče
class_name AudioCatalog

const SFX := {
	"correct":         "res://assets/audio/sfx/correct.wav",
	"wrong":           "res://assets/audio/sfx/wrong.wav",
	"miss":            "res://assets/audio/sfx/miss.wav",
	"tick":            "res://assets/audio/sfx/tick.wav",
	"round_start":     "res://assets/audio/sfx/round_start.wav",
	"round_end":       "res://assets/audio/sfx/round_end.wav",
	"combo_up":        "res://assets/audio/sfx/combo_up.wav",
	"unlock":          "res://assets/audio/sfx/unlock.wav",
	"tap":             "res://assets/audio/sfx/tap.wav",
	# Theme-specific success sounds. The catalog references the files; if
	# they're missing on disk AudioManager logs a warning and no-ops, so
	# missing assets degrade gracefully.
	"lightsaber":      "res://assets/audio/sfx/lightsaber.wav",
	"space_explosion": "res://assets/audio/sfx/space_explosion.wav",
}

const MUSIC := {
	"menu":   "res://assets/audio/music/background_music.wav",
	"game":   "res://assets/audio/music/background_music.wav",
	"game_space": "res://assets/audio/music/game_music_space.wav",
	"game_party": "res://assets/audio/music/game_music_party.wav",
}
