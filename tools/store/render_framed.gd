extends SceneTree
## Renders "framed" marketing screenshots: a real phone screenshot on a brand
## gradient with a short caption above it (2400x1080, 24-bit PNG, no alpha).
##
##   godot --path . --script res://tools/store/render_framed.gd            # en
##   godot --path . --script res://tools/store/render_framed.gd -- --locale cs
##
## Captions live in tools/store/framed_captions.json (one block per locale).
## Sources: store/graphics/phone/ (en) or store/graphics/phone_<locale>/.
## Output:  store/graphics/phone_framed/ (en) or phone_framed_<locale>/.
## Not headless: captions are Labels drawn with Baloo 2 (sticker style).

const CAPTIONS := "res://tools/store/framed_captions.json"
const SIZE := Vector2i(2400, 1080)
const SHOT_SCALE := 0.74
const CAPTION_Y := 118.0
const CAPTION_FONT_SIZE := 104
const CAPTION_OUTLINE := 20

const ROUNDED_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size;
uniform float radius;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
"""


func _initialize() -> void:
	_render.call_deferred()


func _arg(key: String, dflt: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == key:
			return args[i + 1]
	return dflt


func _render() -> void:
	var locale := _arg("--locale", "en")
	var src_dir := "res://store/graphics/phone" + ("" if locale == "en" else "_" + locale)
	var out_dir := "res://store/graphics/phone_framed" + ("" if locale == "en" else "_" + locale)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAPTIONS))
	if not (data is Dictionary) or not (data as Dictionary).has(locale):
		printerr("no captions for locale '", locale, "' in ", CAPTIONS)
		quit(1)
		return
	var captions: Dictionary = data[locale]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/Baloo2.ttf")
	font.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): 800,
	}
	var shader := Shader.new()
	shader.code = ROUNDED_SHADER

	var files: Array = captions.keys()
	files.sort()
	for file_name: String in files:
		var shot := Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join(file_name)))
		if shot == null or shot.is_empty():
			printerr("missing screenshot ", src_dir.path_join(file_name))
			continue
		var vp := _build(shot, String(captions[file_name]), font, shader)
		root.add_child(vp)
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var out := ProjectSettings.globalize_path(out_dir.path_join(file_name))
		print("framed: ", out, " err=", img.save_png(out))
		vp.queue_free()
	quit(0)


func _build(shot: Image, caption: String, font: Font, shader: Shader) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Brand background: grape → deep grape diagonal with soft light blobs.
	var grad := Gradient.new()
	grad.set_color(0, Color("#8B63FF"))
	grad.set_color(1, Color("#5B2FD9"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	gt.width = SIZE.x
	gt.height = SIZE.y
	var bg := TextureRect.new()
	bg.texture = gt
	bg.size = Vector2(SIZE)
	vp.add_child(bg)
	for blob: Array in [[Vector2(260, 140), 260.0, 0.10], [Vector2(2180, 980), 340.0, 0.08],
			[Vector2(2240, 160), 150.0, 0.07], [Vector2(120, 940), 180.0, 0.06]]:
		var c := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in range(48):
			pts.append(blob[0] + Vector2.from_angle(TAU * k / 48.0) * float(blob[1]))
		c.polygon = pts
		c.color = Color(1, 1, 1, float(blob[2]))
		vp.add_child(c)

	var shot_size := Vector2(shot.get_size()) * SHOT_SCALE
	var shot_pos := Vector2((SIZE.x - shot_size.x) / 2.0, SIZE.y - shot_size.y - 44.0)
	var radius := 36.0

	# White "device-less" frame with a soft shadow.
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(int(radius + 12))
	sb.shadow_color = Color(0.1, 0.03, 0.3, 0.35)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 12)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = shot_pos - Vector2(12, 12)
	frame.size = shot_size + Vector2(24, 24)
	vp.add_child(frame)

	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(shot)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.position = shot_pos
	tr.size = shot_size
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("rect_size", shot_size)
	mat.set_shader_parameter("radius", radius)
	tr.material = mat
	vp.add_child(tr)

	var title := Label.new()
	title.text = caption
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Palette.GRAPE_DARK.darkened(0.25))
	title.add_theme_constant_override("outline_size", CAPTION_OUTLINE)
	title.add_theme_color_override("font_shadow_color", Color(0.08, 0.02, 0.25, 0.4))
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.add_theme_constant_override("shadow_outline_size", CAPTION_OUTLINE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(0, CAPTION_Y - 80)
	title.size = Vector2(SIZE.x, 160)
	vp.add_child(title)
	return vp
