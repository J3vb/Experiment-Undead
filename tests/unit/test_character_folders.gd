## Save folders per channel: non-stable builds use the test folder, copied once from stable.
extends GutTest

const ID: StringName = &"test_character_folders"


func after_each() -> void:
	for folder: String in [CharacterProfile.TEST_DIRECTORY, CharacterProfile.STABLE_DIRECTORY]:
		var path: String = folder + String(ID) + ".json"
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_non_stable_build_saves_only_in_the_test_folder() -> void:
	assert_false(Build.is_stable(), "tests and the editor are never stable")
	assert_eq(CharacterProfile.directory(), CharacterProfile.TEST_DIRECTORY)
	assert_true(CharacterProfile.load_or_create(ID).id == ID)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.save(), OK)
	assert_true(FileAccess.file_exists(CharacterProfile.TEST_DIRECTORY + String(ID) + ".json"))
	assert_false(FileAccess.file_exists(CharacterProfile.STABLE_DIRECTORY + String(ID) + ".json"))


func test_test_folder_is_copied_from_stable_once() -> void:
	var stable: String = "user://test_profile_stable/"
	var test: String = "user://test_profile_channel/"
	_remove_folder(stable)
	_remove_folder(test)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stable))
	_write_file(stable + "solo.json", "first")
	CharacterProfile.prepare_test_directory(stable, test)
	assert_eq(FileAccess.get_file_as_string(test + "solo.json"), "first")
	_write_file(stable + "solo.json", "second")
	_write_file(stable + "other.json", "new")
	CharacterProfile.prepare_test_directory(stable, test)
	assert_eq(FileAccess.get_file_as_string(test + "solo.json"), "first", "copied only once")
	assert_false(FileAccess.file_exists(test + "other.json"))
	assert_eq(FileAccess.get_file_as_string(stable + "solo.json"), "second", "stable is never changed")
	_remove_folder(stable)
	_remove_folder(test)


func test_missing_stable_folder_still_creates_an_empty_test_folder() -> void:
	var test: String = "user://test_profile_channel_empty/"
	_remove_folder(test)
	CharacterProfile.prepare_test_directory("user://test_profile_no_stable/", test)
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test)))
	assert_eq(DirAccess.get_files_at(ProjectSettings.globalize_path(test)).size(), 0)
	_remove_folder(test)


func _write_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_folder(folder: String) -> void:
	var path: String = ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
