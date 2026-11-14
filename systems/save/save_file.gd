## Versioned JSON save files. Every save carries "save_version"; older saves
## are upgraded step by step on load, newer ones are refused.
## To change the format: bump CURRENT_VERSION, add a step to _migrations()
## that turns version N-1 data into version N, and add a test with an old sample.
class_name SaveFile
extends RefCounted

const CURRENT_VERSION: int = 1
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
		push_error("Save %s is version %d, this game reads up to %d. Update the game." % [path, from_version, CURRENT_VERSION])
		return {}
	if from_version < CURRENT_VERSION:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path("%s.v%d.bak" % [path, from_version]))
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
	]

## Version 0 = saves written before versioning existed: same fields, no number.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	return data
