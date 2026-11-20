## Copies a player's files from the folder the game used before its rename
## ("Experiment Undead") into today's user:// folder, once, so the rename keeps
## characters, settings and saved servers. The old folder stays as a backup.
class_name OldNameData
extends RefCounted

const OLD_FOLDER_NAME: String = "Experiment Undead"
## What the game keeps in user://. Logs, lock and stop files are left behind.
const ENTRIES: PackedStringArray = ["settings.cfg", "servers.cfg", "launcher.cfg", "characters", "characters-test"]


## The old folder next to today's one: app_userdata/Experiment Undead.
static func old_dir() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join(OLD_FOLDER_NAME)


## Copies ENTRIES from old_path into new_path when new_path has none of them yet.
## Returns how many files were copied.
static func copy_if_new(old_path: String, new_path: String) -> int:
	if old_path == new_path or not DirAccess.dir_exists_absolute(old_path):
		return 0
	for entry: String in ENTRIES:
		if _exists(new_path.path_join(entry)):
			return 0
	var copied: int = 0
	for entry: String in ENTRIES:
		var source: String = old_path.path_join(entry)
		if DirAccess.dir_exists_absolute(source):
			copied += _copy_dir(source, new_path.path_join(entry))
		elif FileAccess.file_exists(source):
			copied += _copy_file(source, new_path.path_join(entry))
	return copied


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _copy_dir(source: String, target: String) -> int:
	DirAccess.make_dir_recursive_absolute(target)
	var copied: int = 0
	for file_name: String in DirAccess.get_files_at(source):
		copied += _copy_file(source.path_join(file_name), target.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(source):
		copied += _copy_dir(source.path_join(dir_name), target.path_join(dir_name))
	return copied


static func _copy_file(source: String, target: String) -> int:
	var result: Error = DirAccess.copy_absolute(source, target)
	if result != OK:
		Log.warn(&"save", &"old_name_copy_failed", {"path": source, "error": result})
		return 0
	return 1
