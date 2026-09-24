## GUT unit tests for ProfileService.
##
## ProfileService is an autoload backed by user:// state. Pure checks pin
## path derivation and constants; the CRUD tests create a throw-away profile,
## point ProgressStore at user://test_profiles_progress and delete the
## profile again, restoring the previously active one.

extends GutTest


# ---------------------------------------------------------------------------
# config_path_for (pure)
# ---------------------------------------------------------------------------

func test_config_path_for_zero_returns_legacy_path() -> void:
	# profile_id <= 0 means "no profile chosen"; SettingsStore needs a stable
	# fallback so the picker can boot before any profile exists.
	assert_eq(ProfileService.config_path_for(0), ProfileService.LEGACY_SETTINGS_PATH,
		"id=0 must map to the legacy single-profile settings.cfg")
	assert_eq(ProfileService.config_path_for(-1), ProfileService.LEGACY_SETTINGS_PATH,
		"negative ids must also fall back to the legacy path")


func test_config_path_for_positive_id_uses_profile_directory() -> void:
	var path := ProfileService.config_path_for(3)
	assert_eq(path, "%s/3/settings.cfg" % ProfileService.PROFILE_DIR_ROOT)


func test_config_path_for_distinct_profiles_returns_distinct_paths() -> void:
	var p1 := ProfileService.config_path_for(1)
	var p2 := ProfileService.config_path_for(2)
	assert_ne(p1, p2,
		"each profile must map to its own settings file (no cross-contamination)")


# ---------------------------------------------------------------------------
# Contract constants
# ---------------------------------------------------------------------------

func test_max_profiles_matches_design_spec() -> void:
	# DESIGN says "support up to 5 profiles". Bumping this value should be
	# a deliberate decision, not a silent edit — pin it here.
	assert_eq(ProfileService.MAX_PROFILES, 5)


func test_path_constants_live_under_user_scope() -> void:
	# Per-profile data must stay inside user:// so it survives APK reinstall
	# the same way settings.cfg does.
	assert_true(ProfileService.ACTIVE_STATE_PATH.begins_with("user://"))
	assert_true(ProfileService.PROFILE_DIR_ROOT.begins_with("user://"))
	assert_true(ProfileService.LEGACY_SETTINGS_PATH.begins_with("user://"))


# ---------------------------------------------------------------------------
# Behavioral checks against the live autoload
# ---------------------------------------------------------------------------

func test_set_active_rejects_non_positive_ids() -> void:
	# The live autoload exists; passing 0 / -1 must not mutate state.
	var before := ProfileService.active_id()
	assert_false(ProfileService.set_active(0))
	assert_false(ProfileService.set_active(-5))
	assert_eq(ProfileService.active_id(), before,
		"invalid set_active calls must not mutate the active id")


func test_create_returns_a_fresh_id() -> void:
	# Snapshot the existing list so we can roll back without polluting state.
	var snapshot_ids: Array = []
	for p in ProfileService.list():
		snapshot_ids.append(int(p.get("id", 0)))

	var new_id := ProfileService.create("Test profile (autotest)")
	assert_true(new_id > 0,
		"create() must return a positive id when running against the local backend")
	assert_true(int(new_id) not in snapshot_ids,
		"local backend must hand out a fresh id, not reuse an existing one")

	# Clean up so re-running the test suite stays idempotent.
	ProfileService.delete(new_id)


# ---------------------------------------------------------------------------
# Deleting a player removes all of their data
# ---------------------------------------------------------------------------

const TEST_PROGRESS_ROOT := "user://test_profiles_progress"


func _fill_with_data(profile_id: int) -> void:
	ProgressStore.set_skill(profile_id, "add_0_10", 1111.0, 3, 2)
	ProgressStore.record_round(profile_id, {"started_at": 1700000000000, "score": 40}, [
		{"skill_key": "add_0_10", "correct": true}])
	ProgressStore.record_round(profile_id, {"started_at": 1700000100000, "score": 50}, [])
	ProgressStore.unlock(profile_id, "badge", "streak_10")
	SessionStatsStore.record_session(profile_id, 50, 60000, 3, 0.5)


func _assert_no_data_left(profile_id: int) -> void:
	var progress := ProgressStore.path_for(profile_id)
	for p: String in [progress, progress + ".bak", progress + ".tmp",
			ProfileService.config_path_for(profile_id),
			"%s/%d/stats.cfg" % [ProfileService.PROFILE_DIR_ROOT, profile_id]]:
		assert_false(FileAccess.file_exists(p), "%s must be deleted" % p)
	assert_false(DirAccess.dir_exists_absolute(
		"%s/%d" % [ProfileService.PROFILE_DIR_ROOT, profile_id]), "profile dir removed")
	assert_false(ProfileService.list().any(func(p: Dictionary) -> bool:
		return int(p["id"]) == profile_id), "gone from the profile list")
	ProgressStore.reset_cache()
	assert_eq(ProgressStore.session_count(profile_id), 0)
	assert_eq(int(SessionStatsStore.totals_for(profile_id)["sessions"]), 0)


func test_delete_removes_all_player_data() -> void:
	ProgressStore.set_root(TEST_PROGRESS_ROOT)
	var new_id := ProfileService.create("Delete me (autotest)")
	if new_id <= 0:
		ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)
		pending("profile cap reached on this machine")
		return
	_fill_with_data(new_id)
	assert_true(FileAccess.file_exists(ProgressStore.path_for(new_id) + ".bak"))
	assert_true(ProfileService.delete(new_id))
	_assert_no_data_left(new_id)
	DirAccess.remove_absolute(TEST_PROGRESS_ROOT)
	ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)


func test_deleting_the_active_player_falls_back_sanely() -> void:
	ProgressStore.set_root(TEST_PROGRESS_ROOT)
	var before := ProfileService.active_id()
	var new_id := ProfileService.create("")
	if new_id <= 0:
		ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)
		pending("profile cap reached on this machine")
		return
	var created: Array = ProfileService.list().filter(func(p: Dictionary) -> bool:
		return int(p["id"]) == new_id)
	assert_eq(String(created[0]["name"]), tr("COMMON_DEFAULT_PLAYER"),
		"an empty name becomes the translated default player name")
	assert_true(ProfileService.set_active(new_id))
	_fill_with_data(new_id)
	assert_true(ProfileService.delete(new_id))
	_assert_no_data_left(new_id)
	var now := ProfileService.active_id()
	assert_ne(now, new_id, "the deleted player is no longer active")
	if now > 0:
		assert_true(ProfileService.list().any(func(p: Dictionary) -> bool:
			return int(p["id"]) == now), "falls back to an existing player")
	else:
		assert_true(ProfileService.list().is_empty(), "id 0 only when nobody is left")
	if before > 0:
		ProfileService.set_active(before)
	DirAccess.remove_absolute(TEST_PROGRESS_ROOT)
	ProgressStore.set_root(ProgressStore.DEFAULT_ROOT)


func test_deleted_ids_are_not_reused() -> void:
	var a := ProfileService.create("Id A (autotest)")
	if a <= 0:
		pending("profile cap reached on this machine")
		return
	ProfileService.delete(a)
	var b := ProfileService.create("Id B (autotest)")
	assert_gt(b, a, "a new player never inherits a deleted player's id")
	ProfileService.delete(b)
