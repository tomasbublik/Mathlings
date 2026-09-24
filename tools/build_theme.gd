extends SceneTree
## Generates assets/theme/mathlings_theme.tres from the tokens in Palette.
##
## Run after changing Palette or this file:
##   godot --headless --path . -s res://tools/build_theme.gd
##
## Type variations available to scenes (set `theme_type_variation`):
##   Button:  PlayButton (big sunny CTA), SecondaryButton (white),
##            DangerButton (coral), ChipButton (toggle chip for option
##            groups), AnswerButton (in-game answer), GhostButton (text-only)
##   Label:   HeroLabel (app name), TitleLabel (screen title),
##            HeadingLabel, CaptionLabel, StickerLabel (white + outline,
##            for text drawn straight on busy backgrounds)
##   PanelContainer: default = white card; CardTint (grape tint card)

const OUT_PATH := "res://assets/theme/mathlings_theme.tres"
const FONT_DIR := "res://assets/fonts/"
const FALLBACK_DIR := "res://assets/fonts/fallback/"

var theme := Theme.new()


func _init() -> void:
	var fonts := _build_fonts()
	theme.default_font = fonts.body
	theme.default_font_size = Palette.FONT_BODY

	_labels(fonts)
	_buttons(fonts)
	_inputs(fonts)
	_panels(fonts)
	_scrollbars()
	_toggles()
	_extra_game()
	_extra_menus()

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var err := ResourceSaver.save(theme, OUT_PATH)
	print("build_theme: saved %s (err=%d)" % [OUT_PATH, err])
	quit(err)


# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------

## Returns { body, body_bold, display } FontVariations. Baloo 2 is the
## playful display face; Nunito covers body text plus Cyrillic that Baloo
## lacks; anything in fonts/fallback/ (CJK, Arabic, Bengali…) is chained
## behind both so every locale renders real glyphs instead of tofu.
##
## Fallback files are wrapped in a FontVariation at the same weight as the
## face they back up, so variable fallbacks (Baloo Bhaijaan 2, Baloo Da 2)
## render bold like the primary text instead of at their Regular default.
## Baloo 2 also backs up body text: Nunito has no Devanagari (Hindi).
func _build_fonts() -> Dictionary:
	var files: Array[FontFile] = []
	if DirAccess.dir_exists_absolute(FALLBACK_DIR):
		for f in DirAccess.get_files_at(FALLBACK_DIR):
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				files.append(load(FALLBACK_DIR + f) as FontFile)

	var nunito: FontFile = load(FONT_DIR + "Nunito.ttf")
	var baloo: FontFile = load(FONT_DIR + "Baloo2.ttf")

	var body := _variation(nunito, 650, _fallbacks_at(650, files, baloo))
	var body_bold := _variation(nunito, 800, _fallbacks_at(800, files, baloo))
	var display_fallbacks: Array[Font] = [body_bold]
	display_fallbacks.append_array(_fallbacks_at(700, files))
	var display := _variation(baloo, 700, display_fallbacks)
	return {"body": body, "body_bold": body_bold, "display": display}


func _fallbacks_at(weight: int, files: Array[FontFile], first: FontFile = null) -> Array[Font]:
	var out: Array[Font] = []
	if first != null:
		out.append(_variation(first, weight, []))
	for f in files:
		out.append(_variation(f, weight, []))
	return out


func _variation(base: FontFile, weight: int, fallbacks: Array[Font]) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	v.fallbacks = fallbacks
	return v


# ---------------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------------

## Candy button box: flat fill, rounded, darker bottom edge for depth.
func _candy(fill: Color, edge: Color, depth: int, radius: int = Palette.RADIUS_M) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.border_width_bottom = depth
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 12
	s.content_margin_bottom = 12 + depth
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


## Pressed variant: loses most of its depth and its top edge drops, so the
## face appears to sink into the screen.
func _candy_pressed(fill: Color, edge: Color, radius: int = Palette.RADIUS_M) -> StyleBoxFlat:
	var s := _candy(fill, edge, Palette.EDGE_PRESSED, radius)
	var sink := Palette.EDGE - Palette.EDGE_PRESSED
	s.expand_margin_top = -sink
	s.content_margin_top = 12 + sink
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
	return s


func _button_set(type: String, fill: Color, edge: Color, text: Color, radius: int = Palette.RADIUS_M) -> void:
	theme.set_stylebox("normal", type, _candy(fill, edge, Palette.EDGE, radius))
	theme.set_stylebox("hover", type, _candy(fill.lightened(0.08), edge, Palette.EDGE, radius))
	theme.set_stylebox("pressed", type, _candy_pressed(fill.darkened(0.06), edge, radius))
	theme.set_stylebox("hover_pressed", type, _candy_pressed(fill.darkened(0.06), edge, radius))
	theme.set_stylebox("disabled", type, _candy(Palette.DISABLED, Palette.DISABLED_EDGE, Palette.EDGE, radius))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(c, type, text)
	theme.set_color("font_disabled_color", type, Color.WHITE)


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _labels(fonts: Dictionary) -> void:
	theme.set_color("font_color", "Label", Palette.INK)
	theme.set_font("font", "Label", fonts.body)
	theme.set_font_size("font_size", "Label", Palette.FONT_BODY)

	_sticker("HeroLabel", fonts.display, Palette.FONT_HERO, 18)
	_sticker("TitleLabel", fonts.display, Palette.FONT_TITLE, 14)
	_sticker("StickerLabel", fonts.display, Palette.FONT_HEADING, 10)

	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", fonts.display)
	theme.set_font_size("font_size", "HeadingLabel", Palette.FONT_HEADING)
	theme.set_color("font_color", "HeadingLabel", Palette.INK)

	theme.set_type_variation("CaptionLabel", "Label")
	theme.set_font_size("font_size", "CaptionLabel", Palette.FONT_CAPTION)
	theme.set_color("font_color", "CaptionLabel", Palette.INK_SOFT)

	theme.set_font("normal_font", "RichTextLabel", fonts.body)
	theme.set_font("bold_font", "RichTextLabel", fonts.body_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", Palette.FONT_BODY)
	theme.set_font_size("bold_font_size", "RichTextLabel", Palette.FONT_BODY)
	theme.set_color("default_color", "RichTextLabel", Palette.INK)


## White display text with a thick grape outline and soft drop shadow —
## readable on any background (sky, space, party).
func _sticker(type: String, font: Font, size: int, outline: int) -> void:
	theme.set_type_variation(type, "Label")
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, Color.WHITE)
	theme.set_color("font_outline_color", type, Palette.GRAPE_DARK)
	theme.set_constant("outline_size", type, outline)
	theme.set_color("font_shadow_color", type, Palette.SHADOW)
	theme.set_constant("shadow_offset_x", type, 0)
	theme.set_constant("shadow_offset_y", type, 5)
	theme.set_constant("shadow_outline_size", type, outline)


func _buttons(fonts: Dictionary) -> void:
	theme.set_font("font", "Button", fonts.display)
	theme.set_font_size("font_size", "Button", Palette.FONT_BUTTON)
	theme.set_constant("h_separation", "Button", 10)
	_button_set("Button", Palette.GRAPE, Palette.GRAPE_DARK, Color.WHITE)

	for v in ["PlayButton", "SecondaryButton", "DangerButton", "ChipButton", "AnswerButton", "GhostButton"]:
		theme.set_type_variation(v, "Button")

	_button_set("PlayButton", Palette.SUNNY, Palette.SUNNY_DARK, Palette.INK, Palette.RADIUS_L)
	theme.set_font_size("font_size", "PlayButton", 48)

	_button_set("SecondaryButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.GRAPE)
	_button_set("DangerButton", Palette.CORAL, Palette.CORAL_DARK, Color.WHITE)

	# Chips: white when idle, grape when toggled on (Button.toggle_mode).
	_button_set("ChipButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.INK, Palette.RADIUS_S)
	theme.set_stylebox("pressed", "ChipButton", _candy_pressed(Palette.GRAPE, Palette.GRAPE_DARK, Palette.RADIUS_S))
	theme.set_stylebox("hover_pressed", "ChipButton", _candy_pressed(Palette.GRAPE, Palette.GRAPE_DARK, Palette.RADIUS_S))
	theme.set_color("font_pressed_color", "ChipButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "ChipButton", Color.WHITE)
	theme.set_font_size("font_size", "ChipButton", Palette.FONT_BODY)

	# Answer buttons: neutral white base; the game recolours each slot from
	# Palette.ANSWER_COLORS via style overrides.
	_button_set("AnswerButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.INK, Palette.RADIUS_L)
	theme.set_font_size("font_size", "AnswerButton", Palette.FONT_ANSWER)

	var ghost := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(st, "GhostButton", ghost)
	theme.set_color("font_color", "GhostButton", Palette.GRAPE)
	theme.set_color("font_hover_color", "GhostButton", Palette.GRAPE_DARK)
	theme.set_color("font_pressed_color", "GhostButton", Palette.GRAPE_DARK)
	theme.set_font_size("font_size", "GhostButton", Palette.FONT_BODY)


func _inputs(fonts: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.SURFACE
	normal.border_color = Palette.SURFACE_EDGE
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(Palette.RADIUS_M)
	normal.corner_detail = 10
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Palette.GRAPE
	focus.draw_center = false
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", normal)
	theme.set_font("font", "LineEdit", fonts.body_bold)
	theme.set_font_size("font_size", "LineEdit", Palette.FONT_BUTTON)
	theme.set_color("font_color", "LineEdit", Palette.INK)
	theme.set_color("font_placeholder_color", "LineEdit", Palette.INK_FAINT)
	theme.set_color("caret_color", "LineEdit", Palette.GRAPE)
	theme.set_color("selection_color", "LineEdit", Palette.GRAPE_LIGHT)
	theme.set_constant("caret_width", "LineEdit", 3)


func _card(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(Palette.RADIUS_L)
	s.corner_detail = 10
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	s.set_content_margin_all(24)
	return s


func _panels(fonts: Dictionary) -> void:
	theme.set_stylebox("panel", "PanelContainer", _card(Color(1, 1, 1, 0.95)))
	theme.set_type_variation("CardTint", "PanelContainer")
	theme.set_stylebox("panel", "CardTint", _card(Palette.GRAPE_LIGHT))

	# Dialogs (AcceptDialog / ConfirmationDialog are embedded Windows).
	var win := _card(Palette.SURFACE)
	win.expand_margin_top = 48  # room for the title bar
	win.set_content_margin_all(0)
	theme.set_stylebox("embedded_border", "Window", win)
	theme.set_stylebox("embedded_unfocused_border", "Window", win)
	theme.set_font("title_font", "Window", fonts.display)
	theme.set_font_size("title_font_size", "Window", Palette.FONT_HEADING)
	theme.set_color("title_color", "Window", Palette.INK)
	theme.set_constant("title_height", "Window", 48)
	var dlg_panel := StyleBoxFlat.new()
	dlg_panel.bg_color = Palette.SURFACE
	dlg_panel.set_content_margin_all(24)
	dlg_panel.set_corner_radius_all(Palette.RADIUS_L)
	theme.set_stylebox("panel", "AcceptDialog", dlg_panel)


func _scrollbars() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.35)
	track.set_corner_radius_all(8)
	track.content_margin_left = 6
	track.content_margin_right = 6
	var grab := StyleBoxFlat.new()
	grab.bg_color = Palette.GRAPE
	grab.set_corner_radius_all(8)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = Palette.GRAPE_DARK
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("grabber", bar, grab)
		theme.set_stylebox("grabber_highlight", bar, grab_hi)
		theme.set_stylebox("grabber_pressed", bar, grab_hi)


func _toggles() -> void:
	var on: Texture2D = load("res://assets/theme/toggle_on.svg")
	var off: Texture2D = load("res://assets/theme/toggle_off.svg")
	for t in ["CheckButton", "CheckBox"]:
		theme.set_icon("checked", t, on)
		theme.set_icon("unchecked", t, off)
		theme.set_icon("checked_disabled", t, on)
		theme.set_icon("unchecked_disabled", t, off)
		theme.set_color("font_color", t, Palette.INK)
		theme.set_color("font_hover_color", t, Palette.INK)
		theme.set_color("font_pressed_color", t, Palette.INK)
		theme.set_color("font_hover_pressed_color", t, Palette.INK)
		theme.set_color("font_focus_color", t, Palette.INK)
		theme.set_constant("h_separation", t, 16)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			theme.set_stylebox(st, t, StyleBoxEmpty.new())


# ---------------------------------------------------------------------------
# Game + results extras
# ---------------------------------------------------------------------------

## Variations used by the in-game HUD, falling problems and results screen:
##   PanelContainer: HudChip (white pill), RewardCard (white card with a
##                   sunny rim, for unlock toasts)
##   Label: HudValueLabel (bold number inside a HudChip), CountdownLabel
##          (giant 3-2-1 sticker), ProblemLabel (expression on a falling
##          skin), ScoreValueLabel (results count-up), StatValueLabel
func _extra_game() -> void:
	var display: Font = theme.get_font("font", "HeroLabel")

	var chip := StyleBoxFlat.new()
	chip.bg_color = Palette.SURFACE
	chip.border_color = Palette.SURFACE_EDGE
	chip.border_width_bottom = 5
	chip.set_corner_radius_all(40)
	chip.corner_detail = 10
	chip.anti_aliasing = true
	chip.content_margin_left = 12
	chip.content_margin_right = 22
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4 + 5
	chip.shadow_color = Palette.SHADOW
	chip.shadow_size = 8
	chip.shadow_offset = Vector2(0, 4)
	theme.set_type_variation("HudChip", "PanelContainer")
	theme.set_stylebox("panel", "HudChip", chip)

	var reward := _card(Palette.SURFACE)
	reward.border_color = Palette.SUNNY
	reward.set_border_width_all(4)
	reward.border_width_bottom = 8
	reward.content_margin_top = 12
	reward.content_margin_bottom = 14
	reward.content_margin_left = 16
	reward.content_margin_right = 24
	theme.set_type_variation("RewardCard", "PanelContainer")
	theme.set_stylebox("panel", "RewardCard", reward)

	theme.set_type_variation("HudValueLabel", "Label")
	theme.set_font("font", "HudValueLabel", display)
	theme.set_font_size("font_size", "HudValueLabel", 34)
	theme.set_color("font_color", "HudValueLabel", Palette.INK)

	_sticker("CountdownLabel", display, 200, 30)
	_sticker("ProblemLabel", display, 68, 16)

	theme.set_type_variation("ScoreValueLabel", "Label")
	theme.set_font("font", "ScoreValueLabel", display)
	theme.set_font_size("font_size", "ScoreValueLabel", 110)
	theme.set_color("font_color", "ScoreValueLabel", Palette.GRAPE)

	# StatValueLabel is defined in _extra_menus() (shared with Stats/Rules).
# Menu screens (main menu, settings, stats, rules, profiles, locale)
# ---------------------------------------------------------------------------
##   Button:         PillButton (small white pill — profile chip, links),
##                   IconButton (square white candy for a single glyph),
##                   TileButton (white menu tile, icon above text)
##   PanelContainer: ToastPanel (dark pill for toasts), Badge<Colour>
##                   (round tinted bubble behind an emoji / initial:
##                   BadgeGrape, BadgeSunny, BadgeCoral, BadgeMint,
##                   BadgeSky, BadgePink), CardSoft (flat tinted inner card)
##   Label:          ToastLabel, StatValueLabel (big number on stat tiles),
##                   BadgeLabel (glyph inside a badge), AvatarLabel (white
##                   initial on a coloured avatar)
##   ProgressBar:    Meter (grape) + MeterMint, MeterSunny, MeterCoral
func _extra_menus() -> void:
	var display: Font = theme.get_font("font", "Button")
	var bold: Font = theme.get_font("font", "LineEdit")

	# --- Buttons -----------------------------------------------------------
	for v in ["PillButton", "IconButton", "TileButton"]:
		theme.set_type_variation(v, "Button")
	_button_set("PillButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.GRAPE, 36)
	theme.set_font_size("font_size", "PillButton", Palette.FONT_BODY)
	_set_side_margins("PillButton", 22)

	_button_set("IconButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.GRAPE)
	theme.set_font_size("font_size", "IconButton", Palette.FONT_HEADING)
	_set_side_margins("IconButton", 12)

	_button_set("TileButton", Palette.SURFACE, Palette.SURFACE_EDGE, Palette.INK, Palette.RADIUS_L)
	theme.set_font_size("font_size", "TileButton", Palette.FONT_BODY)

	# --- Panels ------------------------------------------------------------
	var toast := StyleBoxFlat.new()
	toast.bg_color = Color(Palette.INK, 0.92)
	toast.set_corner_radius_all(40)
	toast.corner_detail = 10
	toast.content_margin_left = 32
	toast.content_margin_right = 32
	toast.content_margin_top = 14
	toast.content_margin_bottom = 16
	toast.shadow_color = Palette.SHADOW
	toast.shadow_size = 10
	toast.shadow_offset = Vector2(0, 4)
	theme.set_type_variation("ToastPanel", "PanelContainer")
	theme.set_stylebox("panel", "ToastPanel", toast)

	var badges := {
		"BadgeGrape": Palette.GRAPE_LIGHT,
		"BadgeSunny": Palette.SUNNY.lerp(Color.WHITE, 0.72),
		"BadgeCoral": Palette.CORAL.lerp(Color.WHITE, 0.75),
		"BadgeMint": Palette.MINT.lerp(Color.WHITE, 0.75),
		"BadgeSky": Palette.SKY.lerp(Color.WHITE, 0.75),
		"BadgePink": Palette.PINK.lerp(Color.WHITE, 0.72),
	}
	for badge_name: String in badges:
		var b := StyleBoxFlat.new()
		b.bg_color = badges[badge_name]
		b.set_corner_radius_all(200)
		b.corner_detail = 16
		b.set_content_margin_all(8)
		theme.set_type_variation(badge_name, "PanelContainer")
		theme.set_stylebox("panel", badge_name, b)

	var soft := StyleBoxFlat.new()
	soft.bg_color = Palette.GRAPE_LIGHT.lerp(Color.WHITE, 0.35)
	soft.set_corner_radius_all(Palette.RADIUS_M)
	soft.corner_detail = 10
	soft.set_content_margin_all(18)
	theme.set_type_variation("CardSoft", "PanelContainer")
	theme.set_stylebox("panel", "CardSoft", soft)

	# --- Labels ------------------------------------------------------------
	theme.set_type_variation("ToastLabel", "Label")
	theme.set_font("font", "ToastLabel", bold)
	theme.set_font_size("font_size", "ToastLabel", Palette.FONT_BODY)
	theme.set_color("font_color", "ToastLabel", Color.WHITE)

	theme.set_type_variation("StatValueLabel", "Label")
	theme.set_font("font", "StatValueLabel", display)
	theme.set_font_size("font_size", "StatValueLabel", 46)
	theme.set_color("font_color", "StatValueLabel", Palette.INK)

	theme.set_type_variation("BadgeLabel", "Label")
	theme.set_font_size("font_size", "BadgeLabel", 28)

	theme.set_type_variation("AvatarLabel", "Label")
	theme.set_font("font", "AvatarLabel", display)
	theme.set_font_size("font_size", "AvatarLabel", 64)
	theme.set_color("font_color", "AvatarLabel", Color.WHITE)
	theme.set_color("font_shadow_color", "AvatarLabel", Color(0, 0, 0, 0.18))
	theme.set_constant("shadow_offset_x", "AvatarLabel", 0)
	theme.set_constant("shadow_offset_y", "AvatarLabel", 4)

	# --- Meters ------------------------------------------------------------
	var fills := {
		"Meter": Palette.GRAPE,
		"MeterMint": Palette.MINT,
		"MeterSunny": Palette.SUNNY,
		"MeterCoral": Palette.CORAL,
	}
	for meter_name: String in fills:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Palette.GRAPE_LIGHT
		bg.set_corner_radius_all(12)
		bg.corner_detail = 8
		var fg := bg.duplicate() as StyleBoxFlat
		fg.bg_color = fills[meter_name]
		theme.set_type_variation(meter_name, "ProgressBar")
		theme.set_stylebox("background", meter_name, bg)
		theme.set_stylebox("fill", meter_name, fg)
		theme.set_font_size("font_size", meter_name, Palette.FONT_CAPTION)
		theme.set_color("font_color", meter_name, Palette.INK)


## Narrows the left/right content margins of every state of a button type.
func _set_side_margins(type: String, margin: int) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := theme.get_stylebox(st, type) as StyleBoxFlat
		sb.content_margin_left = margin
		sb.content_margin_right = margin
