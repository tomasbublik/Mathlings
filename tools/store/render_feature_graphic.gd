extends SceneTree
## Renders the Google Play feature graphic (1024x500, 24-bit PNG, no alpha).
##
##   python3 tools/store/gen_feature_graphic.py        # artwork SVG
##   godot --path . --script res://tools/store/render_feature_graphic.gd
##
## Not headless: the wordmark is a real Label drawn with Baloo 2 in the same
## sticker style as the in-game HeroLabel (white fill, GRAPE_DARK outline,
## soft drop shadow), so it needs a renderer. Everything is drawn at 2x in a
## SubViewport and downsampled for crisp edges.

const ART_SVG := "res://tools/store/feature_graphic_art.svg"
const OUT_PNG := "res://store/graphics/feature_graphic_1024x500.png"
const SIZE := Vector2i(1024, 500)
const SS := 2  ## supersampling factor

## Title placement in 1x canvas px: centre of the wordmark.
const TITLE_CENTER := Vector2(736, 240)
const TITLE_FONT_SIZE := 104
const TITLE_OUTLINE := 20
const TITLE_ROTATION_DEG := -4.0


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var svg := FileAccess.get_file_as_string(ART_SVG)
	if svg.is_empty():
		printerr("missing ", ART_SVG, " - run tools/store/gen_feature_graphic.py first")
		quit(1)
		return
	var art := Image.new()
	var err := art.load_svg_from_string(svg, float(SS))
	if err != OK:
		printerr("SVG render failed: ", error_string(err))
		quit(1)
		return

	var vp := SubViewport.new()
	vp.size = SIZE * SS
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(art)
	bg.size = Vector2(SIZE * SS)
	vp.add_child(bg)

	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/Baloo2.ttf")
	font.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): 800,
	}

	var title := Label.new()
	title.text = "Mathlings"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE * SS)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Palette.GRAPE_DARK)
	title.add_theme_constant_override("outline_size", TITLE_OUTLINE * SS)
	title.add_theme_color_override("font_shadow_color", Color(0.17, 0.08, 0.45, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 7 * SS)
	title.add_theme_constant_override("shadow_outline_size", TITLE_OUTLINE * SS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vp.add_child(title)
	title.reset_size()
	title.pivot_offset = title.size / 2.0
	title.position = TITLE_CENTER * SS - title.size / 2.0
	title.rotation_degrees = TITLE_ROTATION_DEG

	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PNG.get_base_dir()))
	err = img.save_png(ProjectSettings.globalize_path(OUT_PNG))
	print("feature graphic: ", OUT_PNG, " ", img.get_size(), " err=", err)
	quit(0 if err == OK else 1)
