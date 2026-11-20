## The rename to Fenlight copies a player's files from the old "Experiment Undead" folder once.
extends GutTest

const OLD: String = "user://test_old_name/old"
const NEW: String = "user://test_old_name/new"


func before_each() -> void:
	_remove(ProjectSettings.globalize_path("user://test_old_name"))
	DirAccess.make_dir_recursive_absolute(_path(OLD + "/characters"))
	DirAccess.make_dir_recursive_absolute(_path(OLD + "/logs"))
	DirAccess.make_dir_recursive_absolute(_path(NEW + "/logs"))


func after_all() -> void:
	_remove(ProjectSettings.globalize_path("user://test_old_name"))


func test_old_folder_sits_next_to_the_user_folder() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Fenlight")
	assert_eq(OldNameData.old_dir().get_file(), "Experiment Undead")
	assert_eq(OldNameData.old_dir().get_base_dir(), OS.get_user_data_dir().get_base_dir())


func test_copies_settings_and_characters_but_not_logs() -> void:
	_write(OLD + "/settings.cfg", "settings")
	_write(OLD + "/servers.cfg", "servers")
	_write(OLD + "/characters/solo.json", "solo")
	_write(OLD + "/logs/run_1.jsonl", "log")
	_write(OLD + "/running.lock", "lock")
	assert_eq(OldNameData.copy_if_new(_path(OLD), _path(NEW)), 3)
	assert_eq(FileAccess.get_file_as_string(NEW + "/settings.cfg"), "settings")
	assert_eq(FileAccess.get_file_as_string(NEW + "/servers.cfg"), "servers")
	assert_eq(FileAccess.get_file_as_string(NEW + "/characters/solo.json"), "solo")
	assert_false(FileAccess.file_exists(NEW + "/logs/run_1.jsonl"))
	assert_false(FileAccess.file_exists(NEW + "/running.lock"))
	assert_true(FileAccess.file_exists(OLD + "/settings.cfg"), "the old folder stays as a backup")


func test_copies_only_once() -> void:
	_write(OLD + "/settings.cfg", "first")
	assert_eq(OldNameData.copy_if_new(_path(OLD), _path(NEW)), 1)
	_write(OLD + "/settings.cfg", "second")
	_write(OLD + "/characters/solo.json", "solo")
	assert_eq(OldNameData.copy_if_new(_path(OLD), _path(NEW)), 0)
	assert_eq(FileAccess.get_file_as_string(NEW + "/settings.cfg"), "first")
	assert_false(FileAccess.file_exists(NEW + "/characters/solo.json"))


func test_never_overwrites_a_player_who_already_has_new_files() -> void:
	_write(OLD + "/characters/solo.json", "old")
	DirAccess.make_dir_recursive_absolute(_path(NEW + "/characters"))
	_write(NEW + "/characters/solo.json", "new")
	assert_eq(OldNameData.copy_if_new(_path(OLD), _path(NEW)), 0)
	assert_eq(FileAccess.get_file_as_string(NEW + "/characters/solo.json"), "new")


func test_missing_old_folder_copies_nothing() -> void:
	assert_eq(OldNameData.copy_if_new(_path("user://test_old_name/none"), _path(NEW)), 0)


func _path(folder: String) -> String:
	return ProjectSettings.globalize_path(folder)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(path):
		_remove(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
