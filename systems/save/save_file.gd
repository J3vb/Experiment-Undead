## Versioned JSON save files. Every save carries "save_version"; older saves
## are upgraded step by step on load, newer ones are refused.
## To change the format: bump CURRENT_VERSION, add a step to _migrations()
## that turns version N-1 data into version N, and add a test with an old sample.
class_name SaveFile
extends RefCounted

const CURRENT_VERSION: int = 4
const VERSION_KEY: String = "save_version"


## Writes data with the current save_version. Writes to a temp file first so a
## crash mid-write never leaves a half-written save.
static func write(path: String, data: Dictionary) -> Error:
	var out: Dictionary = data.duplicate(true)
	out[VERSION_KEY] = CURRENT_VERSION
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## The file's save_version, or -1 when it is missing or not a JSON object.
## Lets callers tell a save from a newer game apart from a broken one.
static func saved_version(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return -1
	var data: Dictionary = json.data
	var version: Variant = data.get(VERSION_KEY, 0)
	return int(version) if version is int or version is float else -1


## Returns the upgraded data, or an empty Dictionary when the file is missing,
## unreadable or from a newer game version.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Save %s is not valid JSON" % path)
		return {}
	var data: Dictionary = json.data
	var from_version: int = int(data.get(VERSION_KEY, 0))
	if from_version > CURRENT_VERSION:
		var info: Array = [path, from_version, CURRENT_VERSION]
		push_error("Save %s is version %d, this game reads up to %d. Update the game." % info)
		return {}
	if from_version < CURRENT_VERSION:
		var backup: String = "%s.v%d.bak" % [path, from_version]
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
	return upgrade(data, _migrations())


## Runs every step from the data's version up to the newest step's target.
## Step at index i turns version i into version i + 1.
static func upgrade(data: Dictionary, steps: Array[Callable]) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var v: int = int(out.get(VERSION_KEY, 0))
	while v < steps.size():
		out = steps[v].call(out)
		v += 1
		out[VERSION_KEY] = v
	return out


static func _migrations() -> Array[Callable]:
	return [
		_v0_to_v1,
		_v1_to_v2,
		_v2_to_v3,
		_v3_to_v4,
	]


## Version 0 = saves written before versioning existed: same fields, no number.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	return data


## Version 2 adds the best run per map: {map: {"round": int, "kills": int}}.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	if not data.get("best_runs") is Dictionary:
		data["best_runs"] = {}
	return data


## Version 3 adds the headgear, gloves, backpack and boots slots. Missing slots
## load empty; the bump stops a version 2 build from dropping them on save.
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	return data


## Version 4 adds the picked field ability (an id; empty means the highest unlocked).
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	if not data.get("field_ability") is String:
		data["field_ability"] = ""
	return data
