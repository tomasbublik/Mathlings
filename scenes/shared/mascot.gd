@tool
class_name Mascot
extends Control
## The Mathling — the game's little purple maths buddy.
##
## A layered, rig-free character: every part (body, eyes, mouth, arms,
## antenna, effects) is a full-canvas SVG in res://assets/images/mascot/
## drawn on the same 256×256 art board, so layers simply stack. Moods swap
## the eye/mouth/arm/effect layers; idle life (breathing, bobbing, antenna
## sway, random blinks) is computed procedurally in _process.
##
## Size-agnostic: the art is fitted into the largest centred square of the
## control's rect (aspect kept), so drop it into any container and give it a
## custom_minimum_size. The speech bubble (say()) floats ABOVE the square and
## may draw outside the control's rect — leave some headroom above it.
##
## Usage:
##   var m: Mascot = preload("res://scenes/shared/mascot.tscn").instantiate()
##   m.custom_minimum_size = Vector2(220, 220)
##   add_child(m)
##   m.set_mood(Mascot.MOOD_CHEER)
##   m.play_bounce()
##   m.say(tr("MASCOT_GREAT_JOB"), 2.5)

signal tapped

const MOOD_IDLE := &"idle"
const MOOD_HAPPY := &"happy"
const MOOD_CHEER := &"cheer"
const MOOD_THINK := &"think"
const MOOD_OOPS := &"oops"

## Layer names per mood (files: ART_DIR + name + ".svg"). "fx" may be "".
const MOODS := {
	&"idle":  {"eyes": "eyes_open",  "mouth": "mouth_smile", "arms": "arms_down",  "fx": ""},
	&"happy": {"eyes": "eyes_open",  "mouth": "mouth_grin",  "arms": "arms_open",  "fx": ""},
	&"cheer": {"eyes": "eyes_happy", "mouth": "mouth_cheer", "arms": "arms_up",    "fx": "fx_sparkles"},
	&"think": {"eyes": "eyes_think", "mouth": "mouth_think", "arms": "arms_think", "fx": "fx_think"},
	&"oops":  {"eyes": "eyes_oops",  "mouth": "mouth_oops",  "arms": "arms_down",  "fx": "fx_sweat"},
}
## Eye layers that have visible pupils and therefore blink.
const BLINKABLE_EYES := ["eyes_open", "eyes_think", "eyes_oops"]
const STATIC_LAYERS := ["shadow", "antenna", "body", "eyes_closed", "eyes_happy"]

const ART_DIR := "res://assets/images/mascot/"
const ART_SIZE := 256.0
const ANTENNA_PIVOT := Vector2(128, 76)  # art-board px: where the stalk meets the head
const SHADOW_PIVOT := Vector2(128, 234)
const BOB_PIVOT := Vector2(128, 226)     # feet — squash & stretch from the ground

const BLINK_MIN := 2.0
const BLINK_MAX := 5.0
const BLINK_TIME := 0.12
const BREATH_PERIOD := 2.8
const HOP_TIME := 0.55
const HOP_HEIGHT := 0.16   # fraction of the art square
const GIGGLE_TIME := 0.7
const TAP_COOLDOWN := 0.3

## Current mood. Unknown values fall back to idle.
@export var mood: StringName = MOOD_IDLE:
	get:
		return _mood
	set(value):
		set_mood(value)
## Breathing / bobbing / antenna sway. Blinks and hops run regardless.
@export var idle_motion := true
## Whether tapping makes the mascot giggle and hop.
@export var interactive := true:
	set(value):
		interactive = value
		mouse_filter = MOUSE_FILTER_STOP if value else MOUSE_FILTER_IGNORE

static var _tex_cache: Dictionary = {}

var _mood: StringName = MOOD_IDLE
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _blink_left := 3.0
var _blink_close := 0.0
var _hop := -1.0          # 0..1 while hopping, <0 idle
var _pop := 0.0           # 1 → 0 after a mood change
var _giggle_left := 0.0
var _tap_cooldown := 0.0
var _bubble_tween: Tween

@onready var _stage: Control = %Stage
@onready var _shadow: TextureRect = %Shadow
@onready var _bob: Control = %Bob
@onready var _antenna: TextureRect = %Antenna
@onready var _body: TextureRect = %Body
@onready var _arms: TextureRect = %Arms
@onready var _eyes: TextureRect = %Eyes
@onready var _mouth: TextureRect = %Mouth
@onready var _fx: TextureRect = %Fx
@onready var _bubble: PanelContainer = %Bubble
@onready var _bubble_label: Label = %BubbleLabel
@onready var _bubble_tail: Polygon2D = %BubbleTail


# --- Pure helpers (unit-tested) ---------------------------------------------

static func is_valid_mood(value: StringName) -> bool:
	return MOODS.has(value)


## Returns `value` if it's a known mood, otherwise idle.
static func normalize_mood(value: StringName) -> StringName:
	return value if MOODS.has(value) else MOOD_IDLE


## Layer names for a mood (after normalisation).
static func layers_for(value: StringName) -> Dictionary:
	return MOODS[normalize_mood(value)]


static func layer_path(layer: String) -> String:
	return ART_DIR + layer + ".svg"


## Every layer file the component may show.
static func all_layer_names() -> PackedStringArray:
	var names := PackedStringArray(STATIC_LAYERS)
	for m: StringName in MOODS:
		for key: String in ["eyes", "mouth", "arms", "fx"]:
			var n: String = MOODS[m][key]
			if n != "" and not names.has(n):
				names.append(n)
	return names


static func can_blink(value: StringName) -> bool:
	return BLINKABLE_EYES.has(layers_for(value)["eyes"])


static func next_blink_delay(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(BLINK_MIN, BLINK_MAX)


## Largest square centred in `area` — where the art is drawn.
static func fit_square(area: Vector2) -> Rect2:
	var side := maxf(0.0, minf(area.x, area.y))
	return Rect2((area - Vector2(side, side)) * 0.5, Vector2(side, side))


# --- Public API ----------------------------------------------------------------

func set_mood(value: StringName) -> void:
	var m := normalize_mood(value)
	if m != value and not Engine.is_editor_hint():
		push_warning("Mascot: unknown mood '%s', using idle" % value)
	var changed := m != _mood
	_mood = m
	if is_node_ready():
		_apply_mood()
		if changed and not Engine.is_editor_hint():
			_pop = 1.0


## One-shot hop with anticipation squash and a soft landing.
func play_bounce() -> void:
	_hop = 0.0


## Shows a speech bubble above the head. duration <= 0 keeps it until
## hide_bubble() is called.
func say(text: String, duration: float = 2.5) -> void:
	if not is_node_ready():
		return
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.size = Vector2.ZERO  # shrink to fit the new text
	_layout_bubble()
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble.scale = Vector2(0.3, 0.3)
	_bubble.modulate.a = 0.0
	_bubble_tween = create_tween()
	_bubble_tween.set_parallel(true)
	_bubble_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)
	if duration > 0.0:
		_bubble_tween.chain().tween_interval(duration)
		_bubble_tween.chain().tween_callback(hide_bubble)


func hide_bubble() -> void:
	if not is_node_ready() or not _bubble.visible:
		return
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.set_parallel(true)
	_bubble_tween.tween_property(_bubble, "scale", Vector2(0.6, 0.6), 0.15)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.15)
	_bubble_tween.chain().tween_callback(func() -> void: _bubble.visible = false)


# --- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_rng.randomize()
	_blink_left = next_blink_delay(_rng)
	mouse_filter = MOUSE_FILTER_STOP if interactive else MOUSE_FILTER_IGNORE
	_shadow.texture = _tex("shadow")
	_antenna.texture = _tex("antenna")
	_body.texture = _tex("body")
	_bubble.visible = false
	_apply_mood()
	_layout()
	resized.connect(_layout)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_tap_cooldown = maxf(0.0, _tap_cooldown - delta)
	_update_eyes(delta)
	_animate(delta)
	if _bubble.visible:
		_layout_bubble()


func _gui_input(event: InputEvent) -> void:
	if not interactive or Engine.is_editor_hint():
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not fit_square(size).has_point(mb.position):
		return
	accept_event()
	if _tap_cooldown > 0.0:
		return
	_tap_cooldown = TAP_COOLDOWN
	_giggle_left = GIGGLE_TIME
	_update_eyes(0.0)
	play_bounce()
	HapticsManager.pulse(HapticsManager.Pattern.LIGHT)
	AudioManager.play_sfx("giggle")
	tapped.emit()


# --- Internals ---------------------------------------------------------------

static func _tex(layer: String) -> Texture2D:
	if not _tex_cache.has(layer):
		_tex_cache[layer] = load(layer_path(layer))
	return _tex_cache[layer]


func _apply_mood() -> void:
	var l := layers_for(mood)
	_arms.texture = _tex(l["arms"])
	_mouth.texture = _tex(l["mouth"])
	_fx.texture = _tex(l["fx"]) if l["fx"] != "" else null
	_fx.visible = l["fx"] != ""
	_blink_close = 0.0
	_update_eyes(0.0)


func _update_eyes(delta: float) -> void:
	var l := layers_for(mood)
	var eyes: String = l["eyes"]
	if _giggle_left > 0.0:
		_giggle_left -= delta
		eyes = "eyes_happy"
	elif can_blink(mood):
		if _blink_close > 0.0:
			_blink_close -= delta
			eyes = "eyes_closed"
		else:
			_blink_left -= delta
			if _blink_left <= 0.0:
				_blink_close = BLINK_TIME
				eyes = "eyes_closed"
				# Now and then a quick double blink.
				_blink_left = 0.25 if _rng.randf() < 0.15 else next_blink_delay(_rng)
	_eyes.texture = _tex(eyes)


func _animate(delta: float) -> void:
	var s := _stage.size.x
	var breath := sin(_t * TAU / BREATH_PERIOD) if idle_motion else 0.0
	var sx := 1.0 - 0.012 * breath
	var sy := 1.0 + 0.018 * breath
	var y := -0.012 * s * (0.5 + 0.5 * sin(_t * TAU / BREATH_PERIOD + 0.8)) if idle_motion else 0.0
	var air := 0.0
	var antenna_rot := 0.05 * sin(_t * 1.7) if idle_motion else 0.0

	if _hop >= 0.0:
		_hop += delta / HOP_TIME
		var p := _hop
		if p < 0.15:                       # anticipation squash
			var k := sin(PI * p / 0.15)
			sx += 0.10 * k
			sy -= 0.12 * k
		elif p < 0.85:                     # airborne
			var q := (p - 0.15) / 0.7
			air = sin(PI * q)
			y -= HOP_HEIGHT * s * air
			sy += 0.08 * (1.0 - q) * air
			sx -= 0.05 * (1.0 - q) * air
			antenna_rot += 0.22 * sin(TAU * q)
		elif p < 1.0:                      # landing squash
			var k := sin(PI * (p - 0.85) / 0.15)
			sx += 0.08 * k
			sy -= 0.09 * k
		else:
			_hop = -1.0

	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta / 0.35)
		var w := sin(PI * (1.0 - _pop)) * _pop
		sx += 0.08 * w
		sy += 0.08 * w

	_bob.position = Vector2(0.0, y)
	_bob.scale = Vector2(sx, sy)
	_antenna.rotation = antenna_rot
	_shadow.scale = Vector2.ONE * (1.0 - 0.35 * air)
	_shadow.modulate.a = 1.0 - 0.5 * air
	if _fx.visible:
		_fx.modulate.a = 0.8 + 0.2 * sin(_t * 5.0)
		var f := 1.0 + 0.03 * sin(_t * 3.0)
		_fx.scale = Vector2(f, f)


func _layout() -> void:
	var r := fit_square(size)
	_stage.position = r.position
	_stage.size = r.size
	var k := r.size.x / ART_SIZE
	_bob.pivot_offset = BOB_PIVOT * k
	_antenna.pivot_offset = ANTENNA_PIVOT * k
	_shadow.pivot_offset = SHADOW_PIVOT * k
	_fx.pivot_offset = r.size * 0.5
	_bubble_label.add_theme_font_size_override("font_size",
		int(clampf(roundf(r.size.x * 0.1), 16.0, float(Palette.FONT_BODY))))
	if _bubble.visible:
		_layout_bubble()


func _layout_bubble() -> void:
	var r := fit_square(size)
	var width := clampf(r.size.x * 1.5, 140.0, 460.0)
	var font := _bubble_label.get_theme_font("font")
	var fs := _bubble_label.get_theme_font_size("font_size")
	var text_w := font.get_string_size(_bubble_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_bubble_label.custom_minimum_size.x = minf(ceilf(text_w) + 2.0, width - 32.0)
	var bsize := _bubble.get_combined_minimum_size()
	_bubble.size = bsize
	var tail := clampf(r.size.x * 0.06, 8.0, 18.0)
	# Bottom of the bubble sits just above the antenna tip.
	var top := r.position.y - r.size.y * 0.02
	_bubble.position = Vector2(r.position.x + (r.size.x - bsize.x) * 0.5, top - tail - bsize.y)
	_bubble.pivot_offset = Vector2(bsize.x * 0.5, bsize.y + tail)
	var cx := bsize.x * 0.5
	_bubble_tail.polygon = PackedVector2Array([
		Vector2(cx - tail, bsize.y - 2.0),
		Vector2(cx + tail, bsize.y - 2.0),
		Vector2(cx + tail * 0.2, bsize.y + tail),
	])
