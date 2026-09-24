class_name SpaceExplosion
extends Node2D
## Themed explosion for the Vesmír motif: rotating coloured shards + dust.
##
## Distinct from `FruitExplosion` so each theme can keep its own visual
## language even though the spawn lifecycle is identical (one-shot
## particles, parent free-frees when both layers finish).
##
## Shape of the colour input is the same `splash_color: Color` as the fruit
## variant — we use it as the *primary* shard tint and pad the secondary
## shards with a chrome / dust grey so the palette never reads as
## monochrome even when only one base hue is supplied.
##
## Reference: specs/P20_space_theme_polish.md

@onready var _shards: CPUParticles2D = $Shards
@onready var _dust: CPUParticles2D = $Dust

var _layers_pending: int = 2


## Sets the dominant shard hue. The Dust layer keeps its baked colour so we
## always get a touch of grey debris regardless of theme tint.
func setup(splash_color: Color) -> void:
	if not is_node_ready():
		await ready
	_shards.color = splash_color
	_shards.emitting = true
	_dust.emitting = true


func _ready() -> void:
	_shards.finished.connect(_on_layer_finished)
	_dust.finished.connect(_on_layer_finished)


func _on_layer_finished() -> void:
	_layers_pending -= 1
	if _layers_pending <= 0:
		queue_free()
