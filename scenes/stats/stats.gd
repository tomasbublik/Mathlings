extends Control
## Parent dashboard: aggregates per-profile stats from StatsDao and renders them.
## Loads synchronously in `_ready` (MVP). Handles missing DB gracefully.
## Reference: specs/P13_parent_dashboard.md

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

@onready var _background: TextureRect = $Background
@onready var _profile_name: Label = %ProfileName
@onready var _sessions_label: Label = %SessionsLabel
@onready var _total_time_label: Label = %TotalTimeLabel
@onready var _total_score_label: Label = %TotalScoreLabel
@onready var _max_score_label: Label = %MaxScoreLabel
@onready var _best_streak_label: Label = %BestStreakLabel
@onready var _error_rate_label: Label = %ErrorRateLabel
@onready var _skills_grid: GridContainer = %SkillsGrid
@onready var _practice_list: VBoxContainer = %PracticeList
@onready var _empty_state: Label = %EmptyState
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_apply_theme()
	_back_button.pressed.connect(_on_back)
	get_viewport().size_changed.connect(_update_responsive_layout)

	var profile_id: int = ProfileService.active_id()
	_profile_name.text = _profile_name_for(profile_id)
	_load_data(profile_id)
	_update_responsive_layout()


func _apply_theme() -> void:
	var bg := ThemeManager.current_background_texture()
	if bg != null:
		_background.texture = bg


func _profile_name_for(profile_id: int) -> String:
	# DB has the authoritative name when the addon is installed; otherwise
	# fall back to ProfileService's local backend so the dashboard header
	# doesn't read "Hráč 1" for every player on a fresh checkout.
	if DB.is_open():
		var p: Dictionary = ProfilesDao.get_by_id(DB, profile_id)
		if not p.is_empty():
			return String(p.get("name", "Hráč 1"))
	for entry in ProfileService.list():
		if int(entry.get("id", 0)) == profile_id:
			return String(entry.get("name", "Hráč 1"))
	return "Hráč 1"


func _load_data(profile_id: int) -> void:
	# Prefer DB-backed totals; fall back to the local SessionStatsStore so a
	# fresh checkout (no SQLite addon) still shows aggregates after a few
	# rounds. Skill-level breakdowns remain DB-only — they need per-attempt
	# rows the local fallback doesn't track.
	var totals: Dictionary = StatsDao.profile_totals(DB, profile_id)
	if int(totals.get("sessions", 0)) == 0 and not DbGuard.writable(DB):
		totals = SessionStatsStore.totals_for(profile_id)
	var skills: Array = StatsDao.skill_overview(DB, profile_id)
	var practice: Array = StatsDao.skills_needing_practice(DB, profile_id)

	_sessions_label.text = "Sezení: %d" % int(totals.get("sessions", 0))
	_total_time_label.text = "Odehraný čas: %s" % _format_duration(int(totals.get("total_duration_ms", 0)))
	_total_score_label.text = "Celkové skóre: %d" % int(totals.get("total_score", 0))
	_max_score_label.text = "Nejlepší kolo: %d" % int(totals.get("max_score", 0))
	_best_streak_label.text = "Nejdelší série: %d 🔥" % int(totals.get("best_streak_overall", 0))
	# Render the error rate as a percentage; 0 attempts → leave a dash so the
	# user understands "not yet measurable" rather than the literal 0%.
	var sessions: int = int(totals.get("sessions", 0))
	if sessions == 0:
		_error_rate_label.text = "Chybovost: —"
	else:
		_error_rate_label.text = "Chybovost: %d %%" \
			% int(round(float(totals.get("avg_error_rate", 0.0)) * 100.0))

	_populate_skills_table(skills)
	_populate_practice_list(practice)

	var has_any_data: bool = not skills.is_empty() or int(totals.get("sessions", 0)) > 0
	_empty_state.visible = not has_any_data


func _populate_skills_table(skills: Array) -> void:
	for child in _skills_grid.get_children():
		child.queue_free()

	_add_header_cell("Dovednost")
	_add_header_cell("Rating")
	_add_header_cell("Přesnost")

	for entry: Dictionary in skills:
		var key: String = String(entry.get("skill_key", ""))
		_add_value_cell(SkillLabels.label_for(key))
		_add_value_cell("%d" % int(round(float(entry.get("rating", 1000.0)))))
		var attempts: int = int(entry.get("attempts", 0))
		if attempts == 0:
			_add_value_cell("—")
		else:
			var pct: int = int(round(float(entry.get("accuracy", 0.0)) * 100.0))
			_add_value_cell("%d %% (%d/%d)" % [pct, int(entry.get("correct", 0)), attempts])


func _populate_practice_list(practice: Array) -> void:
	for child in _practice_list.get_children():
		child.queue_free()

	if practice.is_empty():
		var placeholder := Label.new()
		placeholder.text = "— zatím málo dat —"
		_apply_readable_label(placeholder, Color(1, 1, 1), 28)
		_practice_list.add_child(placeholder)
		return

	for entry: Dictionary in practice:
		var key: String = String(entry.get("skill_key", ""))
		var pct: int = int(round(float(entry.get("accuracy", 0.0)) * 100.0))
		var line := Label.new()
		line.text = "• %s — %d %% (%d pokusů)" % [
			SkillLabels.label_for(key), pct, int(entry.get("attempts", 0))
		]
		_apply_readable_label(line, Color(1, 0.88, 0.35), 30)
		_practice_list.add_child(line)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add_header_cell(text: String) -> void:
	var l := Label.new()
	l.text = text
	_apply_readable_label(l, Color(0.85, 0.95, 1.0), 28)
	_skills_grid.add_child(l)


func _add_value_cell(text: String) -> void:
	var l := Label.new()
	l.text = text
	_apply_readable_label(l, Color(1, 1, 1), 28)
	_skills_grid.add_child(l)


func _apply_readable_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)


func _update_responsive_layout() -> void:
	var size := get_viewport_rect().size
	_skills_grid.columns = 1 if size.y > size.x else 3


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
