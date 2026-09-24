## Guards against emoji variation selector U+FE0F in user-facing sources.
## Godot's text server on Android draws it as a tofu box ("⚙FE0F"), so
## emoji must be written without it.

extends GutTest

const ROOTS: Array[String] = ["res://scenes", "res://scripts"]
const EXTRA_FILES: Array[String] = ["res://assets/translations/strings.csv"]
const EXTENSIONS: Array[String] = ["gd", "tscn"]
const VS16: String = "️"


func test_no_variation_selector_in_sources() -> void:
	var offenders: Array[String] = []
	var files: Array[String] = EXTRA_FILES.duplicate()
	for root in ROOTS:
		_collect(root, files)
	for path in files:
		if FileAccess.get_file_as_string(path).contains(VS16):
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "U+FE0F found in: %s" % [offenders])


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.get_extension() in EXTENSIONS:
			out.append(dir_path.path_join(f))
