extends GutTest

const WORK: String = "user://test_launcher"

var installer: VersionInstaller
var versions: String = ""
var zip_path: String = ""


func before_each() -> void:
	VersionInstaller.remove_tree(ProjectSettings.globalize_path(WORK))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	versions = ProjectSettings.globalize_path(WORK.path_join("versions"))
	zip_path = ProjectSettings.globalize_path(WORK.path_join("build.zip"))
	installer = VersionInstaller.new()
	installer.versions_dir = versions
	add_child_autofree(installer)


func after_all() -> void:
	VersionInstaller.remove_tree(ProjectSettings.globalize_path(WORK))


func _make_zip(path: String) -> void:
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	packer.start_file("ExperimentUndead.x86_64")
	packer.write_file("game".to_utf8_buffer())
	packer.close_file()
	packer.start_file("ExperimentUndead.pck")
	packer.write_file("pack data".to_utf8_buffer())
	packer.close_file()
	packer.close()


func test_good_zip_lands_in_version_folder() -> void:
	_make_zip(zip_path)
	var problem: String = installer.install_zip(zip_path, FileAccess.get_sha256(zip_path), "0.1.1")
	assert_eq(problem, "")
	var folder: String = versions.path_join("0.1.1")
	assert_eq(FileAccess.get_file_as_string(folder.path_join("ExperimentUndead.pck")), "pack data")
	assert_false(DirAccess.dir_exists_absolute(folder + ".tmp"))
	if OS.get_name() == "Linux":
		var mode: int = FileAccess.get_unix_permissions(folder.path_join("ExperimentUndead.x86_64"))
		assert_eq(mode & 0x40, 0x40, "owner can run the exe")
	assert_eq(VersionInstaller.installed_versions(versions), PackedStringArray(["0.1.1"]))


func test_wrong_digest_leaves_nothing() -> void:
	_make_zip(zip_path)
	assert_ne(installer.install_zip(zip_path, "0000", "0.1.1"), "")
	assert_false(DirAccess.dir_exists_absolute(versions.path_join("0.1.1")))
	assert_false(DirAccess.dir_exists_absolute(versions.path_join("0.1.1.tmp")))


func test_half_download_leaves_no_folder() -> void:
	_make_zip(zip_path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(zip_path)
	var cut: FileAccess = FileAccess.open(zip_path, FileAccess.WRITE)
	cut.store_buffer(bytes.slice(0, bytes.size() / 2))
	cut.close()
	var digest: String = FileAccess.get_sha256(zip_path)
	assert_ne(installer.install_zip(zip_path, digest, "0.1.1"), "", "a cut zip does not unpack")
	assert_eq(VersionInstaller.installed_versions(versions), PackedStringArray())
	assert_false(DirAccess.dir_exists_absolute(versions.path_join("0.1.1.tmp")))


func test_only_two_newest_folders_stay() -> void:
	var old: PackedStringArray = ["0.1.0", "0.1.1-test.1", "0.1.1"]
	for version: String in old:
		DirAccess.make_dir_recursive_absolute(versions.path_join(version))
	DirAccess.make_dir_recursive_absolute(versions.path_join("0.0.9.tmp"))
	_make_zip(zip_path)
	assert_eq(installer.install_zip(zip_path, FileAccess.get_sha256(zip_path), "0.2.0"), "")
	assert_eq(VersionInstaller.installed_versions(versions), PackedStringArray(["0.2.0", "0.1.1"]))


func test_folder_in_use_is_kept() -> void:
	var present: PackedStringArray = ["0.1.0", "0.1.1", "0.2.0"]
	for version: String in present:
		DirAccess.make_dir_recursive_absolute(versions.path_join(version))
	installer.prune(PackedStringArray(["0.1.0"]))
	assert_eq(VersionInstaller.installed_versions(versions), PackedStringArray(["0.2.0", "0.1.1", "0.1.0"]))


func test_versions_dir_next_to_exe() -> void:
	var root: String = VersionInstaller.root_dir()
	assert_eq(VersionInstaller.default_versions_dir(), root.path_join("versions"))


func test_copy_build_replaces_root_files() -> void:
	var source: String = ProjectSettings.globalize_path(WORK.path_join("source"))
	var target: String = ProjectSettings.globalize_path(WORK.path_join("target"))
	var exe: String = VersionInstaller.exe_name()
	for folder: String in [source, target]:
		DirAccess.make_dir_recursive_absolute(folder)
	var pairs: Array = [[source, "new"], [target, "old"]]
	for pair: Array in pairs:
		for name: String in [exe, exe.get_basename() + ".pck"]:
			var file: FileAccess = FileAccess.open(str(pair[0]).path_join(name), FileAccess.WRITE)
			file.store_string(pair[1])
			# A temporary handle stays open until the function ends; Windows cannot replace an open file.
			file.close()
	assert_true(VersionInstaller.copy_build(source, target))
	assert_eq(FileAccess.get_file_as_string(target.path_join(exe)), "new")
	assert_eq(FileAccess.get_file_as_string(target.path_join(exe.get_basename() + ".pck")), "new")
	assert_false(FileAccess.file_exists(target.path_join(exe + ".new")))


func test_version_dirs() -> void:
	assert_true(VersionInstaller.is_version_dir("/games/eu/versions/0.1.0"))
	assert_true(VersionInstaller.is_version_dir("/games/eu/versions/0.2.0-test.3"))
	assert_false(VersionInstaller.is_version_dir("/games/eu"))
	assert_false(VersionInstaller.is_version_dir("/games/versions/notes"))
