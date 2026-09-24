extends Control
## Player stats: summary tiles, "needs practice" list and a per-skill table
## with accuracy meters. Totals come from SessionStatsStore, per-skill data
## from ProgressStore (see DESIGN §6).
## Loads synchronously in `_ready` (MVP). Handles "no data yet" gracefully.
## Reference: specs/P13_parent_dashboard.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const GAME_SCENE: String = "res://scenes/game/game.tscn"

@onready var _background: TextureRect = $Background
@onready var _column: MarginContainer = %Column
@onready var _vbox: VBoxContainer = %VBox
@onready var _player_row: HBoxContainer = %PlayerRow
@onready var _profile_name: Label = %ProfileName
@onready var _tiles_grid: GridContainer = %TilesGrid
@onready var _practice_card: PanelContainer = %PracticeCard
@onready var _practice_list: VBoxContainer = %PracticeList
@onready var _skills_card: PanelContainer = %SkillsCard
@onready var _skills_grid: GridContainer = %SkillsGrid
@onready var _skills_empty: Label = %SkillsEmpty
@onready var _empty_state: PanelContainer = %EmptyState
@onready var _empty_play_button: Button = %EmptyPlayButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_apply_theme()
	_back_button.pressed.connect(_on_back)
	_empty_play_button.pressed.connect(func() -> void:
		if ResourceLoader.exists(GAME_SCENE):
			get_tree().change_scene_to_file(GAME_SCENE))
	get_viewport().size_changed.connect(_update_responsive_layout)

	var profile_id: int = ProfileService.active_id()
	var player_name := _profile_name_for(profile_id)
	_profile_name.text = player_name
	var avatar := MenuKit.avatar(player_name, profile_id, 68)
	_player_row.add_child(avatar)
	_player_row.move_child(avatar, 0)

	_load_data(profile_id)
	_update_responsive_layout()
	var animated: Array = [_player_row]
	animated.append_array(_tiles_grid.get_children())
	animated.append_array([_practice_card, _skills_card, _empty_state])
	MenuKit.stagger_in(animated, 0.0, 0.04)


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _profile_name_for(profile_id: int) -> String:
	for p: Dictionary in ProfileService.list():
		if int(p.get("id", 0)) == profile_id:
			return String(p.get("name", tr("COMMON_DEFAULT_PLAYER")))
	return tr("COMMON_DEFAULT_PLAYER")


func _load_data(profile_id: int) -> void:
	# Round totals: SessionStatsStore (running aggregates, incl. rounds played
	# before ProgressStore existed). Per-skill data: ProgressStore aggregates.
	var totals: Dictionary = SessionStatsStore.totals_for(profile_id)
	var skills: Array = ProgressStore.skill_overview(profile_id)
	var practice: Array = ProgressStore.skills_needing_practice(profile_id)

	var sessions: int = int(totals.get("sessions", 0))
	var has_any_data: bool = not skills.is_empty() or sessions > 0

	_empty_state.visible = not has_any_data
	_tiles_grid.visible = has_any_data
	_skills_card.visible = has_any_data
	_practice_card.visible = has_any_data and not practice.is_empty()
	if not has_any_data:
		return

	_populate_tiles(totals)
	_populate_skills_table(skills)
	_populate_practice_list(practice)


# ---------------------------------------------------------------------------
# Summary tiles
# ---------------------------------------------------------------------------

func _populate_tiles(totals: Dictionary) -> void:
	for child in _tiles_grid.get_children():
		child.queue_free()
	var sessions: int = int(totals.get("sessions", 0))
	var accuracy_text := "—"
	if sessions > 0:
		var err := float(totals.get("avg_error_rate", 0.0))
		accuracy_text = "%d %%" % int(round((1.0 - err) * 100.0))

	_add_tile("🎮", "BadgeGrape", str(sessions), "STATS_TILE_SESSIONS")
	_add_tile("⏱", "BadgeSky",
		_format_duration(int(totals.get("total_duration_ms", 0))), "STATS_TILE_TIME")
	_add_tile("⭐", "BadgeSunny", str(int(totals.get("total_score", 0))), "STATS_TILE_TOTAL")
	_add_tile("🏆", "BadgeMint", str(int(totals.get("max_score", 0))), "STATS_TILE_BEST")
	_add_tile("🔥", "BadgeCoral", str(int(totals.get("best_streak_overall", 0))), "STATS_TILE_STREAK")
	_add_tile("🎯", "BadgePink", accuracy_text, "STATS_TILE_ACCURACY")


func _add_tile(glyph: String, badge_variation: String, value: String, caption_key: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(MenuKit.badge(glyph, badge_variation, 72))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", -6)
	row.add_child(text_box)
	var value_label := Label.new()
	value_label.theme_type_variation = &"StatValueLabel"
	value_label.text = value
	text_box.add_child(value_label)
	var caption := Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr(caption_key)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(caption)
	_tiles_grid.add_child(card)


# ---------------------------------------------------------------------------
# Skills table + practice list
# ---------------------------------------------------------------------------

func _populate_skills_table(skills: Array) -> void:
	for child in _skills_grid.get_children():
		child.queue_free()
	_skills_empty.visible = skills.is_empty()
	_skills_grid.visible = not skills.is_empty()
	if skills.is_empty():
		return

	# One tidy block per skill: name + accuracy on top, a colour-coded
	# meter underneath. The grid shows two blocks per row in landscape.
	for entry: Dictionary in skills:
		var key: String = String(entry.get("skill_key", ""))
		var attempts: int = int(entry.get("attempts", 0))
		var accuracy: float = float(entry.get("accuracy", 0.0))

		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_theme_constant_override("separation", 6)
		block.tooltip_text = "%s: %d" % [tr("STATS_COL_RATING"),
			int(round(float(entry.get("rating", 1000.0))))]

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		block.add_child(top)
		var name_label := Label.new()
		name_label.text = SkillLabels.label_for(key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(name_label)
		var detail := Label.new()
		detail.theme_type_variation = &"CaptionLabel"
		detail.size_flags_vertical = Control.SIZE_SHRINK_END
		detail.text = ("—" if attempts == 0 else "%d %%  ·  %s" % [
			int(round(accuracy * 100.0)),
			tr("STATS_CORRECT_OF_FORMAT") % [int(entry.get("correct", 0)), attempts]])
		top.add_child(detail)

		var meter := _make_meter(accuracy if attempts > 0 else 0.0)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_child(meter)
		_skills_grid.add_child(block)


func _populate_practice_list(practice: Array) -> void:
	for child in _practice_list.get_children():
		child.queue_free()

	if practice.is_empty():
		var placeholder := Label.new()
		placeholder.theme_type_variation = &"CaptionLabel"
		placeholder.text = tr("STATS_PRACTICE_PLACEHOLDER")
		_practice_list.add_child(placeholder)
		return

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	_practice_list.add_child(flow)
	for entry: Dictionary in practice:
		var key: String = String(entry.get("skill_key", ""))
		var pct: int = int(round(float(entry.get("accuracy", 0.0)) * 100.0))
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"CardSoft"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		chip.add_child(row)
		var name_label := Label.new()
		name_label.text = SkillLabels.label_for(key)
		row.add_child(name_label)
		var pct_label := Label.new()
		pct_label.theme_type_variation = &"HeadingLabel"
		pct_label.add_theme_font_size_override("font_size", Palette.FONT_BODY)
		pct_label.add_theme_color_override("font_color", _accuracy_color(pct / 100.0))
		pct_label.text = "%d %%" % pct
		row.add_child(pct_label)
		flow.add_child(chip)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_meter(ratio: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = ratio
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ratio >= 0.8:
		bar.theme_type_variation = &"MeterMint"
	elif ratio >= 0.5:
		bar.theme_type_variation = &"MeterSunny"
	else:
		bar.theme_type_variation = &"MeterCoral"
	return bar


func _accuracy_color(ratio: float) -> Color:
	if ratio >= 0.8:
		return Palette.MINT_DARK
	if ratio >= 0.5:
		return Palette.SUNNY_DARK
	return Palette.CORAL_DARK


func _update_responsive_layout() -> void:
	var size := MenuKit.fit_portrait(self)
	var portrait := size.y > size.x
	MenuKit.fit_column(_column, size.x, 1080.0, 24.0 if portrait else 32.0)
	_tiles_grid.columns = 2 if portrait else 3
	_skills_grid.columns = 1 if portrait else 2


func _format_duration(ms: int) -> String:
	var total_s: int = ms / 1000
	var h: int = total_s / 3600
	var m: int = (total_s % 3600) / 60
	var s: int = total_s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
