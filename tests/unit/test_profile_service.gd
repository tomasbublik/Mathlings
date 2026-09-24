## GUT unit tests for ProfileService.
##
## ProfileService is an autoload backed by user:// state, so DB-bound CRUD
## paths can't be tested cleanly without a refactor (TestInMemoryDb is a
## separate connection; ProfileService consults the global DB autoload).
## What we *can* pin in pure unit tests:
##   • config_path_for: deterministic path derivation (no I/O).
##   • MAX_PROFILES contract.
##   • Constants used by tests / docs that mustn't drift.
##
## End-to-end CRUD is exercised manually via the picker / manager scenes
## (verified by the smoke check listed in DoD #2 of P16).

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
# Behavioral checks against the live autoload (no DB writes)
# ---------------------------------------------------------------------------

func test_set_active_rejects_non_positive_ids() -> void:
	# The live autoload exists; passing 0 / -1 must not mutate state.
	var before := ProfileService.active_id()
	assert_false(ProfileService.set_active(0))
	assert_false(ProfileService.set_active(-5))
	assert_eq(ProfileService.active_id(), before,
		"invalid set_active calls must not mutate the active id")


func test_create_uses_local_backend_when_db_is_closed() -> void:
	# DB autoload is open only when the SQLite addon is installed. Without
	# it, ProfileService falls back to a ConfigFile store — create() must
	# still succeed so the picker / first-run flow works on a fresh checkout.
	if DB.is_open():
		pending("DB is open; this test only exercises the local-backend branch")
		return
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
