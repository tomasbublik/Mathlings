class_name FruitExplosion
extends Node2D
## "Splash" effect for a correctly answered falling fruit.
##
## Two stacked CPUParticles2D layers:
##   • Pulp:   coloured chunks the same hue as the fruit's flesh — driven
##             by `setup(splash_color)`. Heavy, fast spread, gravity = drop.
##   • Splash: tiny water-droplet sprites (assets/images/particles/drop.svg)
##             tinted to the SAME hue as the pulp so a watermelon throws red
##             droplets, a banana pale-yellow, etc. (Earlier revisions had a
##             fixed blue tint; that read as "rain" instead of "juice".)
##
## When both layers finish emitting, the parent node frees itself. We track
## that via a small counter so we don't queue_free() while one of the
## layers is still alive (CPUParticles' `finished` fires per-layer).
##
## Reference: specs/P19_fruit_vfx.md, specs/P11_vfx.md (one-shot pattern).

@onready var _pulp: CPUParticles2D = $Pulp
@onready var _splash: CPUParticles2D = $Splash

## Counts how many child layers still need to emit `finished`. We start at 2
## (both layers) and tick down; when it hits zero, the explosion is done.
var _layers_pending: int = 2


## Applies the per-fruit color to BOTH layers and starts emission.
##
## Caller must add the FruitExplosion to the scene tree first (otherwise the
## @onready nodes are not yet wired up).
##
## We preserve the splash layer's *alpha* from the .tscn so the droplets stay
## a touch translucent even after the hue swap — full opacity on a tiny
## drop-shaped sprite reads as a pebble, not a juice droplet.
func setup(splash_color: Color) -> void:
	if not is_node_ready():
		await ready
	_pulp.color = splash_color
	var splash_alpha := _splash.color.a
	_splash.color = Color(splash_color.r, splash_color.g, splash_color.b, splash_alpha)
	# Restart emission in case the scene was instantiated and reused.
	_pulp.emitting = true
	_splash.emitting = true


func _ready() -> void:
	_pulp.finished.connect(_on_layer_finished)
	_splash.finished.connect(_on_layer_finished)


func _on_layer_finished() -> void:
	_layers_pending -= 1
	if _layers_pending <= 0:
		queue_free()
