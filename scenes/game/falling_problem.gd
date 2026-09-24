class_name FallingProblem
extends Node2D
## Visual entity for one falling math problem.
## Displays skin texture + expression label. Falls downward at configured speed.
## Emits `landed(problem_id)` when it reaches `floor_y` without being resolved.
## Explode / splash animations call queue_free() after the tween finishes.
##
## Input handling lives outside this node — GameController decides via explode_*/splash.
## Reference: DESIGN.md §7.1, specs/P7_falling_problem.md

signal landed(problem_id: int)

## Generic dark-particle burst played on a wrong answer.
const WRONG_VFX: PackedScene = preload("res://scenes/game/vfx/wrong_particles.tscn")
## Soft dust cloud played when the entity hits the floor unanswered.
const MISS_VFX: PackedScene = preload("res://scenes/game/vfx/miss_particles.tscn")

## Default explosion colour used when nobody calls `set_splash_color()` —
## kept in sync with ThemeManager.FALLBACK_SPLASH so non-fruit themes still
## look reasonable until they ship their own VFX.
const DEFAULT_SPLASH_COLOR := Color(1.0, 0.92, 0.6)
## Last-resort explosion scene if a theme misconfigures `explosion_scene`
## to a path that no longer exists. Mirrors ThemeManager.DEFAULT_EXPLOSION_SCENE.
const FALLBACK_EXPLOSION_SCENE: PackedScene = preload("res://scenes/game/vfx/fruit_explosion.tscn")

@export var floor_y: float = 700.0

var _speed_px_s: float = 0.0
var _vertical_direction: int = 1
var _problem_id: int = 0
var _resolved: bool = false
var _splash_color: Color = DEFAULT_SPLASH_COLOR

@onready var _skin: Sprite2D = $Skin
@onready var _expression: Label = $Expression
@onready var _fx_layer: Node2D = $FxLayer


## Sets the colour used by the success-explosion particles. Caller (the Game
## scene) reads it from `ThemeManager.random_skin_for_current().splash` so
## every fruit pops in its own juice colour.
func set_splash_color(color: Color) -> void:
	_splash_color = color


## Initializes the entity. `problem` is a Problem Dictionary (DESIGN §7.1).
## `skin_texture` is used for the Sprite2D; may be null (fallback to colored square).
func setup(problem: Dictionary, speed_px_s: float, skin_texture: Texture2D, vertical_direction: int = 1) -> void:
	_problem_id = int(problem.get("id", 0))
	_speed_px_s = speed_px_s
	_vertical_direction = 1 if vertical_direction >= 0 else -1
	_resolved = false

	if not is_node_ready():
		await ready

	if skin_texture != null:
		_skin.texture = skin_texture
	_expression.text = String(problem.get("expression", ""))

	set_process(true)


func _process(delta: float) -> void:
	if _resolved:
		return

	position.y += _speed_px_s * float(_vertical_direction) * delta

	if (_vertical_direction > 0 and position.y >= floor_y) or (_vertical_direction < 0 and position.y <= floor_y):
		_resolved = true
		set_process(false)
		landed.emit(_problem_id)
		splash()


## Plays a celebratory pop+scale+fade animation with particles, then queue_free().
func explode_correct() -> void:
	if _resolved:
		return
	_resolved = true
	set_process(false)
	_spawn_explosion_for_current_theme(_splash_color)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Plays a shrink+fast-drop animation with dark particles, then queue_free().
func explode_wrong() -> void:
	if _resolved:
		return
	_resolved = true
	set_process(false)
	_spawn_vfx_in_parent(WRONG_VFX)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 200.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


## Plays a flatten+fade splash animation with dust particles, then queue_free().
func splash() -> void:
	_spawn_vfx_in_parent(MISS_VFX)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 0.25), 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)


## Attaches a one-shot particle instance to our parent at our global position so the
## effect outlives this entity (we queue_free ourselves shortly after).
func _spawn_vfx_in_parent(scene: PackedScene) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var vfx: Node2D = scene.instantiate()
	parent.add_child(vfx)
	vfx.global_position = global_position


## Spawns the active theme's correct-answer explosion at our position,
## tinted to `splash_color`. Each registered explosion scene exposes a
## `setup(color: Color)` method (FruitExplosion, SpaceExplosion, …) so we
## treat them polymorphically through a duck-type call.
##
## Falls back to the bundled fruit explosion when the theme references a
## scene that no longer exists — same defensive posture as ThemeManager.
func _spawn_explosion_for_current_theme(splash_color: Color) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var scene: PackedScene = _resolve_explosion_scene()
	var vfx: Node2D = scene.instantiate()
	parent.add_child(vfx)
	vfx.global_position = global_position
	if vfx.has_method("setup"):
		vfx.call("setup", splash_color)


static func _resolve_explosion_scene() -> PackedScene:
	var path := ThemeManager.current_explosion_scene_path()
	var loaded: Resource = load(path)
	if loaded is PackedScene:
		return loaded
	push_warning("FallingProblem: explosion scene '%s' missing or invalid; using fallback." % path)
	return FALLBACK_EXPLOSION_SCENE
