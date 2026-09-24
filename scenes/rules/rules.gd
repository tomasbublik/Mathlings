extends Control
## Rules screen — a friendly, scannable explanation of how to play and how
## scoring works.
##
## Every number shown (base points, combo tiers, the worked example) is read
## from the loaded ScoringRules, so editing `assets/rules/scoring_rules.json`
## propagates here on the next scene load — no string drift between
## gameplay and the help screen. The copy itself lives in strings.csv.
##
## Reference: specs/P17_external_rules.md, DESIGN §10 (UI patterns).

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

## How many answers in a row the worked example uses.
const EXAMPLE_STREAK: int = 11

@onready var _background: TextureRect = $Background
@onready var _column: MarginContainer = %Column
@onready var _cards: VBoxContainer = %Cards
@onready var _back_button: Button = %BackButton

var _rules: ScoringRules
var _steps_row: BoxContainer


func _ready() -> void:
	_apply_theme()
	_back_button.pressed.connect(_on_back)
	_rules = ScoringRules.load_default()
	_build_how_to_card()
	_build_combo_card()
	_build_oops_card()
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	MenuKit.stagger_in(_cards.get_children(), 0.0, 0.06)


## Mirrors the theme on every scene so background art stays consistent across
## navigations.
func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _update_responsive_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	var portrait := size.y > size.x
	MenuKit.fit_column(_column, size.x, 1080.0, 24.0 if portrait else 32.0)
	if _steps_row != null:
		_steps_row.vertical = portrait


# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------

## White card with an emoji badge + heading; returns the body container.
func _add_card(glyph: String, badge_variation: String, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	_cards.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(MenuKit.badge(glyph, badge_variation, 56))
	var heading := Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(heading)
	body.add_child(head)
	return body


## Step 1-2-3: sums fall → tap the answer → collect points.
func _build_how_to_card() -> void:
	var body := _add_card("🎮", "BadgeGrape", tr("RULES_HOW_TITLE"))
	_steps_row = BoxContainer.new()
	_steps_row.add_theme_constant_override("separation", 16)
	body.add_child(_steps_row)
	_add_step(1, "🍎", "BadgeCoral", tr("RULES_STEP_FALL"), "7 + 5", Palette.INK)
	_add_step(2, "👆", "BadgeSky", tr("RULES_STEP_TAP"), "12 ✓", Palette.MINT_DARK)
	var b := _rules.base_points
	_add_step(3, "⭐", "BadgeSunny", tr("RULES_STEP_SCORE") % b,
		"%d · %d · %d" % [b, b * 2, b * 3], Palette.SUNNY_DARK)


func _add_step(number: int, glyph: String, badge_variation: String, text: String,
		example: String, example_color: Color) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"CardSoft"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_row.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	tile.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	left.add_child(MenuKit.badge(glyph, badge_variation, 68))
	var num := Label.new()
	num.theme_type_variation = &"CaptionLabel"
	num.text = "%d" % number
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(num)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)
	var ex := Label.new()
	ex.theme_type_variation = &"StatValueLabel"
	ex.add_theme_font_size_override("font_size", 38)
	ex.add_theme_color_override("font_color", example_color)
	ex.text = example
	right.add_child(ex)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 150
	right.add_child(label)


## Combo tiers as a row of tiles: "3–4 in a row · ×1.25 · +13 points".
func _build_combo_card() -> void:
	var body := _add_card("🔥", "BadgeCoral", tr("RULES_COMBO_TITLE"))
	var hint := Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr("RULES_COMBO_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	body.add_child(flow)

	var tiers := _rules.combo_tiers
	var first_min: int = int(tiers[0].get("min_streak", 1)) if not tiers.is_empty() else 1
	var flames := 0
	if first_min > 1:
		_add_tier(flow, tr("RULES_COMBO_RANGE") % [1, first_min - 1], 1.0, flames)
	for i in range(tiers.size()):
		var lo: int = int(tiers[i]["min_streak"])
		var multiplier: float = float(tiers[i]["multiplier"])
		var range_text: String
		if i + 1 < tiers.size():
			range_text = tr("RULES_COMBO_RANGE") % [lo, int(tiers[i + 1]["min_streak"]) - 1]
		else:
			range_text = tr("RULES_COMBO_FROM") % lo
		flames += 1
		_add_tier(flow, range_text, multiplier, flames)

	# Worked example so kids (and parents) can sanity-check the maths.
	var total := 0
	for s in range(1, EXAMPLE_STREAK + 1):
		total += _rules.points_for_correct(s)
	var example := PanelContainer.new()
	example.theme_type_variation = &"BadgeSunny"
	example.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ex_label := Label.new()
	ex_label.theme_type_variation = &"HeadingLabel"
	ex_label.add_theme_font_size_override("font_size", Palette.FONT_BODY)
	ex_label.text = "🎉  " + tr("RULES_EXAMPLE") % [EXAMPLE_STREAK, total]
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 4)
	pad.add_child(ex_label)
	example.add_child(pad)
	body.add_child(example)


func _add_tier(parent: Control, range_text: String, multiplier: float, flames: int) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"CardSoft"
	tile.custom_minimum_size = Vector2(200, 0)
	parent.add_child(tile)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
	var top := Label.new()
	top.theme_type_variation = &"CaptionLabel"
	top.text = ("🔥".repeat(flames) + "  " if flames > 0 else "") + range_text
	box.add_child(top)
	var mult := Label.new()
	mult.theme_type_variation = &"StatValueLabel"
	mult.add_theme_font_size_override("font_size", 40)
	mult.text = "× %s" % _format_multiplier(multiplier)
	box.add_child(mult)
	var pts := Label.new()
	pts.theme_type_variation = &"HeadingLabel"
	pts.add_theme_font_size_override("font_size", Palette.FONT_BODY)
	pts.add_theme_color_override("font_color", Palette.MINT_DARK)
	pts.text = tr("RULES_COMBO_POINTS") % int(round(float(_rules.base_points) * multiplier))
	box.add_child(pts)


func _build_oops_card() -> void:
	var body := _add_card("🙈", "BadgePink", tr("RULES_OOPS_TITLE"))
	var text := Label.new()
	text.text = tr("RULES_OOPS_TEXT")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)


## "1.25" → "1.25", "2.0" → "2" — short and friendly.
static func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, round(multiplier)):
		return "%d" % int(round(multiplier))
	return String.num(multiplier, 2)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
