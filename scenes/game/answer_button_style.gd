class_name AnswerButtonStyle
extends RefCounted
## Builds per-slot candy styles for the in-game answer buttons at runtime.
## Mirrors the theme's candy look (tools/build_theme.gd `_candy`): rounded,
## flat fill, darker bottom edge, and a pressed state whose face sinks.
##
## The same StyleBoxFlat instance is used for normal / hover / disabled so the
## game can tween its colours (correct / wrong flash) and a locked button never
## drops to the grey disabled look mid-round.


## Applies the look to `button` and returns the shared face StyleBoxFlat
## (tween its `bg_color` / `border_color` to animate the whole button).
static func apply(button: Button, fill: Color, edge: Color,
		text: Color = Color.WHITE, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var face := _box(fill, edge, Palette.EDGE)
	var down := _box(fill.darkened(0.06), edge, Palette.EDGE_PRESSED)
	var sink := Palette.EDGE - Palette.EDGE_PRESSED
	down.expand_margin_top = -sink
	down.content_margin_top += sink
	down.shadow_size = 2
	down.shadow_offset = Vector2(0, 1)

	for state in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, face)
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, down)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	for c in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(c, text)
	var outline_color := edge.darkened(0.3) if outline == Color.TRANSPARENT else outline
	button.add_theme_color_override("font_outline_color", outline_color)
	button.add_theme_constant_override("outline_size", 12)
	return face


static func _box(fill: Color, edge: Color, depth: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.border_width_bottom = depth
	s.set_corner_radius_all(Palette.RADIUS_L)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6 + depth
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 5)
	return s
