class_name AtomicJsonFile
## Crash-safe JSON files in user://.
##
## write(): serialise to `<path>.tmp`, copy the current (known good) file to
##          `<path>.bak`, then rename the .tmp over `<path>`. A crash at any
##          point leaves either the old or the new file intact.
## read():  read `<path>`; when it is missing, unreadable or not a JSON
##          object, fall back to `<path>.bak`. Never crashes, never raises
##          engine errors on bad data (uses JSON.new().parse, not
##          JSON.parse_string) — just logs a warning and returns null.
##
## Reference: DESIGN §6.

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"


## Writes `data` to `path` atomically. Returns OK or the first error hit.
static func write(path: String, data: Dictionary) -> Error:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK:
			push_error("AtomicJsonFile: cannot create '%s' (%s)" % [dir_path, error_string(mk_err)])
			return mk_err

	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		var open_err := FileAccess.get_open_error()
		push_error("AtomicJsonFile: cannot write '%s' (%s)" % [tmp, error_string(open_err)])
		return open_err
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	var write_err := f.get_error()
	f.close()
	if write_err != OK:
		push_error("AtomicJsonFile: write to '%s' failed (%s)" % [tmp, error_string(write_err)])
		DirAccess.remove_absolute(tmp)
		return write_err

	# Keep the previous version as .bak — but only when it is itself valid,
	# so a corrupt main file never overwrites a good backup.
	if FileAccess.file_exists(path) and _read_dict(path) != null:
		var copy_err := DirAccess.copy_absolute(path, path + BAK_SUFFIX)
		if copy_err != OK:
			push_warning("AtomicJsonFile: could not refresh backup of '%s' (%s)"
				% [path, error_string(copy_err)])

	var rename_err := DirAccess.rename_absolute(tmp, path)
	if rename_err != OK and FileAccess.file_exists(path):
		# Some platforms refuse to rename over an existing file; the .bak
		# already holds the previous version, so replace in two steps.
		DirAccess.remove_absolute(path)
		rename_err = DirAccess.rename_absolute(tmp, path)
	if rename_err != OK:
		push_error("AtomicJsonFile: cannot move '%s' into place (%s)"
			% [tmp, error_string(rename_err)])
	return rename_err


## Returns the parsed Dictionary from `path` (or its .bak), or null when
## neither holds a valid JSON object.
static func read(path: String) -> Variant:
	var main: Variant = _read_dict(path)
	if main != null:
		return main
	var bak_path := path + BAK_SUFFIX
	if FileAccess.file_exists(path):
		push_warning("AtomicJsonFile: '%s' is corrupt; trying backup" % path)
	var bak: Variant = _read_dict(bak_path)
	if bak != null:
		if FileAccess.file_exists(path):
			push_warning("AtomicJsonFile: recovered '%s' from backup" % path)
		return bak
	if FileAccess.file_exists(bak_path):
		push_warning("AtomicJsonFile: backup '%s' is corrupt too" % bak_path)
	return null


## Removes the file together with its .bak / .tmp siblings.
static func remove(path: String) -> void:
	for p: String in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## True when the file or its backup exists.
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


static func _read_dict(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data: Variant = json.data
	if data is Dictionary:
		return data
	return null
