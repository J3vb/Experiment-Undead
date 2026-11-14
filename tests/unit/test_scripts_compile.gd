## Loads every project script so parse errors and warnings-as-errors fail CI,
## even in scripts that no scene or other test uses yet.
extends GutTest

const ROOTS: Array[String] = ["res://core", "res://systems", "res://levels", "res://tools", "res://tests"]


func test_all_scripts_compile() -> void:
	var paths: Array[String] = []
	for root: String in ROOTS:
		_collect(root, paths)
	assert_gt(paths.size(), 0, "No scripts found")
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, "Failed to load %s" % path)
		if script:
			assert_true(script.can_instantiate(), "Script does not compile: %s" % path)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
