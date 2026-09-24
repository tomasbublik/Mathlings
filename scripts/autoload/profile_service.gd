extends Node
## Single source of truth for "who is playing right now".
##
## ProfileService runs against one of two backends, transparently:
##   • DB (`ProfilesDao` + the SQLite addon) when DbGuard.writable(DB) is true.
##   • Local ConfigFile fallback (`user://profiles_local.cfg`) when the
##     SQLite addon is missing — e.g. a fresh checkout where the user
##     hasn't run the addon installer yet. The fallback shares the rest of
##     the per-profile layout (user://profiles/<id>/settings.cfg), so when
##     the addon arrives later the profile dirs already exist and a manual
##     migration is straightforward.
##
## The active profile id (= "who is playing") is *always* persisted in
## `user://current_profile.cfg`, independent of the backend, so SettingsStore
## can decide which settings.cfg path to load before any backend is available.
##
## Reference: specs/P16_profiles.md, DESIGN §6.1 (profiles table).

signal active_profile_changed(profile_id: int)
signal profile_list_changed

const MAX_PROFILES: int = 5

## Active-profile pointer. Lives outside settings.cfg so SettingsStore can
## consult it at startup without loading any settings (chicken-and-egg fix).
const ACTIVE_STATE_PATH: String = "user://current_profile.cfg"

## Local-backend store of the profile list. Used only when the SQLite addon
## isn't installed; otherwise the DB is authoritative. ConfigFile sections
## are named "profile.<id>" with `name` and `created_at` keys.
const LOCAL_PROFILES_PATH: String = "user://profiles_local.cfg"

## Root for per-profile config directories. Each profile gets its own
## settings.cfg under user://profiles/<id>/settings.cfg.
const PROFILE_DIR_ROOT: String = "user://profiles"

## Path of the legacy single-profile settings file. Migration moves it
## under PROFILE_DIR_ROOT/<id>/settings.cfg the first time a profile exists.
const LEGACY_SETTINGS_PATH: String = "user://settings.cfg"


var _state: ConfigFile = ConfigFile.new()
var _local: ConfigFile = ConfigFile.new()
var _active_id: int = 0
var _migration_done: bool = false


func _ready() -> void:
	_load_active_state()
	# `load` for an absent file returns ERR_FILE_NOT_FOUND, not an error we
	# care about — the empty ConfigFile is a valid starting state.
	_local.load(LOCAL_PROFILES_PATH)


# ---------------------------------------------------------------------------
# Public surface (backend-agnostic)
# ---------------------------------------------------------------------------

## Returns the currently active profile id (0 when none is selected — caller
## should redirect to the picker).
func active_id() -> int:
	return _active_id


## Returns Array[Dictionary] of profile rows. Same shape regardless of
## backend: each row has `id`, `name`, `created_at`.
func list() -> Array:
	if _has_db():
		return ProfilesDao.get_all(DB)
	return _list_local()


## Switches the active profile. Returns false when profile_id is invalid
## or not found in the active backend. Emits `active_profile_changed` so
## SettingsStore (and other listeners) reload from the new file path.
func set_active(profile_id: int) -> bool:
	if profile_id <= 0:
		return false
	if not _profile_exists(profile_id):
		return false
	_active_id = profile_id
	_persist_active_state()
	active_profile_changed.emit(profile_id)
	return true


## Creates a new profile with the given display name, persists it, and
## creates the per-profile config directory. Returns the new profile id, or
## -1 when at the MAX_PROFILES cap.
func create(name: String) -> int:
	var trimmed := name.strip_edges()
	if trimmed == "":
		trimmed = "Hráč"

	var current_count := list().size()
	if current_count >= MAX_PROFILES:
		return -1

	var new_id: int = (_create_db(trimmed) if _has_db() else _create_local(trimmed))
	if new_id <= 0:
		return -1

	_ensure_profile_dir(new_id)
	profile_list_changed.emit()
	return new_id


## Renames a profile in place. Returns false on invalid input or unknown id.
func rename(profile_id: int, new_name: String) -> bool:
	if profile_id <= 0:
		return false
	var trimmed := new_name.strip_edges()
	if trimmed == "":
		return false

	var ok: bool = (_rename_db(profile_id, trimmed) if _has_db()
		else _rename_local(profile_id, trimmed))
	if ok:
		profile_list_changed.emit()
	return ok


## Deletes a profile. Cascades to the per-profile config directory and (in
## the DB backend) any profile-scoped DB rows via SQL CASCADE.
##
## When the active profile is deleted, switches to the first remaining one
## (or to id=0 — caller should redirect to picker).
func delete(profile_id: int) -> bool:
	if profile_id <= 0:
		return false
	if _has_db():
		ProfilesDao.delete(DB, profile_id)
	else:
		_delete_local(profile_id)
	# Clean up the local stats file before nuking the dir. _remove_profile_dir
	# is best-effort and would silently leave a stats.cfg behind if directory
	# removal failed for any reason (locked file, permissions). Calling
	# SessionStatsStore.clear first guarantees the file is gone.
	SessionStatsStore.clear(profile_id)
	_remove_profile_dir(profile_id)
	profile_list_changed.emit()

	if profile_id == _active_id:
		var remaining := list()
		var fallback_id: int = 0 if remaining.is_empty() else int(remaining[0].get("id", 0))
		_active_id = fallback_id
		_persist_active_state()
		active_profile_changed.emit(fallback_id)
	return true


## Returns the canonical settings.cfg path for the given profile.
## profile_id <= 0 falls back to the legacy single-profile location so the
## first-run experience can boot without any backend / profile state.
func config_path_for(profile_id: int) -> String:
	if profile_id <= 0:
		return LEGACY_SETTINGS_PATH
	return "%s/%d/settings.cfg" % [PROFILE_DIR_ROOT, profile_id]


## True when a player has been chosen. Main Menu reads this to decide
## between the picker and the normal play flow.
func has_active_profile() -> bool:
	return _active_id > 0


## Idempotent migration / bootstrap. Call from Main Menu's _ready(). The
## first invocation:
##   • adopts the persisted active id when it still maps to an existing profile,
##   • migrates legacy `user://settings.cfg` into a freshly created "Hráč 1"
##     when exactly one profile exists, OR
##   • adopts the first profile in the catalog when there's no active selection
##     yet (e.g. installed-then-cleared cache).
## Subsequent calls return immediately.
##
## Returns true when an active profile is set after the call.
func ensure_ready() -> bool:
	if _migration_done:
		return _active_id > 0
	_migration_done = true

	if _active_id > 0 and _profile_exists(_active_id):
		_ensure_profile_dir(_active_id)
		return true

	var profiles := list()
	if profiles.size() == 1 and FileAccess.file_exists(LEGACY_SETTINGS_PATH):
		var first_id := int(profiles[0].get("id", 0))
		_migrate_legacy_settings(first_id)
		_active_id = first_id
		_persist_active_state()
		active_profile_changed.emit(_active_id)
		return true

	if not profiles.is_empty():
		_active_id = int(profiles[0].get("id", 0))
		_persist_active_state()
		active_profile_changed.emit(_active_id)
		return true

	# No profiles found in either backend; caller should show the picker.
	return false


# ---------------------------------------------------------------------------
# Backend selection
# ---------------------------------------------------------------------------

## True when the live DB autoload is open AND the SQLite addon is loaded.
## Centralised so the public methods stay readable.
func _has_db() -> bool:
	return DbGuard.writable(DB)


## Looks up `profile_id` in whichever backend is active.
func _profile_exists(profile_id: int) -> bool:
	if _has_db():
		return not ProfilesDao.get_by_id(DB, profile_id).is_empty()
	return _local.has_section(_local_section(profile_id))


# ---------------------------------------------------------------------------
# DB backend
# ---------------------------------------------------------------------------

func _create_db(name: String) -> int:
	if ProfilesDao.count(DB) >= MAX_PROFILES:
		return -1
	return ProfilesDao.insert(DB, name)


func _rename_db(profile_id: int, name: String) -> bool:
	return ProfilesDao.update(DB, profile_id, name)


# ---------------------------------------------------------------------------
# Local (ConfigFile) backend
# ---------------------------------------------------------------------------

func _list_local() -> Array:
	var rows: Array = []
	for section in _local.get_sections():
		if not section.begins_with("profile."):
			continue
		# The id is the suffix after "profile.". Bail on any malformed key
		# rather than crashing the picker.
		var id_part := section.substr("profile.".length())
		if not id_part.is_valid_int():
			continue
		rows.append({
			"id": int(id_part),
			"name": String(_local.get_value(section, "name", "Hráč")),
			"created_at": int(_local.get_value(section, "created_at", 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"]))
	return rows


func _create_local(name: String) -> int:
	if _list_local().size() >= MAX_PROFILES:
		return -1
	var new_id := _next_local_id()
	var section := _local_section(new_id)
	_local.set_value(section, "name", name)
	_local.set_value(section, "created_at",
		int(Time.get_unix_time_from_system() * 1000.0))
	_save_local()
	return new_id


func _rename_local(profile_id: int, name: String) -> bool:
	var section := _local_section(profile_id)
	if not _local.has_section(section):
		return false
	_local.set_value(section, "name", name)
	_save_local()
	return true


func _delete_local(profile_id: int) -> void:
	var section := _local_section(profile_id)
	if _local.has_section(section):
		_local.erase_section(section)
		_save_local()


## Returns the next free profile id for the local backend. We don't reuse
## ids of deleted profiles so per-profile settings dirs (`user://profiles/<id>/`)
## from a deleted profile never accidentally bind to a new one.
func _next_local_id() -> int:
	var max_id := 0
	for section in _local.get_sections():
		if not section.begins_with("profile."):
			continue
		var id_part := section.substr("profile.".length())
		if id_part.is_valid_int():
			max_id = maxi(max_id, int(id_part))
	return max_id + 1


static func _local_section(profile_id: int) -> String:
	return "profile.%d" % profile_id


func _save_local() -> void:
	var err := _local.save(LOCAL_PROFILES_PATH)
	if err != OK:
		push_error("ProfileService: failed to persist local profiles (%s)"
			% error_string(err))


# ---------------------------------------------------------------------------
# Active-state persistence + per-profile layout
# ---------------------------------------------------------------------------

func _load_active_state() -> void:
	var err := _state.load(ACTIVE_STATE_PATH)
	if err == OK:
		_active_id = int(_state.get_value("profile", "active_id", 0))
	# ERR_FILE_NOT_FOUND is the normal first-run path — leave active_id at 0.


func _persist_active_state() -> void:
	_state.set_value("profile", "active_id", _active_id)
	var err := _state.save(ACTIVE_STATE_PATH)
	if err != OK:
		push_error("ProfileService: failed to persist active state (%s)"
			% error_string(err))


func _ensure_profile_dir(profile_id: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var rel := "profiles/%d" % profile_id
	if not dir.dir_exists(rel):
		dir.make_dir_recursive(rel)


func _remove_profile_dir(profile_id: int) -> void:
	var path := "%s/%d" % [PROFILE_DIR_ROOT, profile_id]
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	# Walk up and remove the now-empty directory.
	var parent := DirAccess.open(PROFILE_DIR_ROOT)
	if parent != null:
		parent.remove(str(profile_id))


## Moves user://settings.cfg → user://profiles/<id>/settings.cfg. Idempotent
## (no-op when destination already exists).
func _migrate_legacy_settings(profile_id: int) -> void:
	if profile_id <= 0:
		return
	var dest := config_path_for(profile_id)
	if FileAccess.file_exists(dest):
		return
	if not FileAccess.file_exists(LEGACY_SETTINGS_PATH):
		return

	_ensure_profile_dir(profile_id)
	var src := FileAccess.open(LEGACY_SETTINGS_PATH, FileAccess.READ)
	if src == null:
		return
	var contents := src.get_as_text()
	src = null

	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(contents)
	out = null

	# Remove the legacy file so we don't migrate twice on next boot.
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("settings.cfg"):
		dir.remove("settings.cfg")
