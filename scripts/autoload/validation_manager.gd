## Validation autoload — active only when --validate-ui is passed on CLI.
## Never runs on Android. Zero overhead in normal gameplay.
extends Node

const SCENES_TO_VISIT := [
	"res://scenes/main_menu/main_menu.tscn",
	"res://scenes/settings/settings.tscn",
	"res://scenes/profiles/profile_picker.tscn",
	"res://scenes/profiles/profile_manager.tscn",
	"res://scenes/locale/locale_picker.tscn",
	"res://scenes/stats/stats.tscn",
	"res://scenes/rules/rules.tscn",
	"res://scenes/results/results.tscn",
	"res://scenes/game/game.tscn",
]

var _output_dir: String

func _ready() -> void:
	if OS.get_name() == "Android":
		return
	var args := OS.get_cmdline_user_args()
	if "--validate-ui" not in args:
		return
	_output_dir = _get_arg(args, "--output-dir", "/tmp/mathlings-validation")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_run.call_deferred()

func _run() -> void:
	for scene_path: String in SCENES_TO_VISIT:
		var err := get_tree().change_scene_to_file(scene_path)
		if err != OK:
			printerr("[Val] cannot load: ", scene_path, " (err=", err, ")")
			continue
		# Wait for scene + layout to settle
		await get_tree().create_timer(2.0).timeout
		_snap(scene_path)
	get_tree().quit(0)

func _snap(scene_path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var sz := DisplayServer.window_get_size()
	var orient := "portrait" if sz.y > sz.x else "landscape"
	var scene_name := scene_path.get_file().get_basename()
	var out_path := "%s/%s_%s_%dx%d.png" % [_output_dir, scene_name, orient, sz.x, sz.y]
	if img.save_png(out_path) == OK:
		print("[Val] ", out_path)
	else:
		printerr("[Val] FAIL saving: ", out_path)

func _get_arg(args: PackedStringArray, key: String, dflt: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == key:
			return args[i + 1]
	return dflt
