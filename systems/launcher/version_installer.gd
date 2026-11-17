## Downloads a release zip, checks its SHA-256 and unpacks it into versions/<version>/ next to
## the game, complete or not at all. Keeps the newest few version folders.
class_name VersionInstaller
extends Node

signal finished(ok: bool, message: String)

const KEEP: int = 2
const DOWNLOAD_DIR: String = "user://launcher"
const USER_AGENT: String = "User-Agent: ExperimentUndead-launcher"
const CONFIG: String = "user://launcher.cfg"
const REFRESH_TRIES: int = 30

## Absolute folder that holds one folder per installed version.
var versions_dir: String = ""
var _http: HTTPRequest
var _release: Dictionary = {}
var _zip_path: String = ""


func _ready() -> void:
	if versions_dir.is_empty():
		versions_dir = default_versions_dir()


## versions/ next to the install root's exe. A copy started from versions/<v>/ points two levels up.
static func default_versions_dir() -> String:
	return root_dir().path_join("versions")


static func root_dir() -> String:
	var here: String = OS.get_executable_path().get_base_dir()
	return here.get_base_dir().get_base_dir() if is_version_dir(here) else here


## True for a versions/<version>/ folder: a copy the launcher installed and started.
static func is_version_dir(folder: String) -> bool:
	return folder.get_base_dir().get_file() == "versions" and ReleaseFeed.is_release_version(folder.get_file())


static func launcher_value(key: StringName, default: Variant) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG)
	return config.get_value("launcher", key, default)


static func save_launcher_value(key: StringName, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG)
	config.set_value("launcher", key, value)
	config.save(CONFIG)


## The game's exe name, the same in every version folder.
static func exe_name() -> String:
	return OS.get_executable_path().get_file()


## Complete version folders (a .tmp folder is a failed install), newest first.
static func installed_versions(folder: String) -> PackedStringArray:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return PackedStringArray()
	for name: String in DirAccess.get_directories_at(folder):
		if not name.ends_with(".tmp") and ReleaseFeed.is_release_version(name):
			found.append(name)
	found.sort_custom(func(a: String, b: String) -> bool: return Build.compare_versions(a, b) > 0)
	return PackedStringArray(found)


func is_busy() -> bool:
	return _http != null


## 0..1 while downloading.
func progress() -> float:
	if _http == null or _release.get("size", 0) <= 0:
		return 0.0
	return clampf(float(_http.get_downloaded_bytes()) / float(_release["size"]), 0.0, 1.0)


## Starts the download of a ReleaseFeed.newest() entry; finished fires when it is installed or failed.
func download(release: Dictionary) -> void:
	if is_busy():
		return
	_release = release
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOWNLOAD_DIR))
	_zip_path = ProjectSettings.globalize_path(DOWNLOAD_DIR.path_join("%s.zip" % release["version"]))
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_file = _zip_path
	_http.request_completed.connect(_on_downloaded)
	add_child(_http)
	var err: Error = _http.request(str(release["url"]), PackedStringArray([USER_AGENT]))
	if err != OK:
		_end(false, "Could not start the download (%s)." % error_string(err))


func cancel() -> void:
	if _http:
		_http.cancel_request()
		_end(false, "Download cancelled.")


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Log.warn(&"launcher", &"download_failed", {"version": _release["version"], "result": result, "code": code})
		_end(false, "The download failed. Check your connection and try again.")
		return
	await get_tree().process_frame
	var problem: String = install_zip(_zip_path, str(_release["digest"]), str(_release["version"]))
	_end(problem.is_empty(), problem)


func _end(ok: bool, message: String) -> void:
	if _http:
		_http.queue_free()
		_http = null
	if FileAccess.file_exists(_zip_path):
		DirAccess.remove_absolute(_zip_path)
	finished.emit(ok, message)


## Checks the zip against the digest and unpacks it into versions/<version>/. Returns "" or what went wrong.
func install_zip(zip_path: String, digest: String, version: String) -> String:
	if FileAccess.get_sha256(zip_path) != digest:
		Log.warn(&"launcher", &"digest_mismatch", {"version": version})
		return "The download was damaged. Try again."
	var final_dir: String = versions_dir.path_join(version)
	var temp_dir: String = final_dir + ".tmp"
	remove_tree(temp_dir)
	if DirAccess.make_dir_recursive_absolute(temp_dir) != OK or not _unzip(zip_path, temp_dir):
		remove_tree(temp_dir)
		Log.warn(&"launcher", &"install_failed", {"version": version, "folder": versions_dir})
		return (
			"Could not write to %s. Move the game to a folder you own, or download it from the release page."
			% (versions_dir)
		)
	remove_tree(final_dir)
	if DirAccess.rename_absolute(temp_dir, final_dir) != OK:
		remove_tree(temp_dir)
		return "Could not finish installing %s." % version
	Log.info(&"launcher", &"version_installed", {"version": version})
	prune(PackedStringArray([OS.get_executable_path().get_base_dir().get_file()]))
	return ""


## Deletes all but the KEEP newest version folders. Folders named in in_use, or that
## cannot be deleted yet (a running game), stay and are tried again next time.
func prune(in_use: PackedStringArray) -> void:
	var versions: PackedStringArray = installed_versions(versions_dir)
	for index: int in range(KEEP, versions.size()):
		if versions[index] not in in_use:
			remove_tree(versions_dir.path_join(versions[index]))


func _unzip(zip_path: String, target: String) -> bool:
	var zip: ZIPReader = ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	var ok: bool = true
	for name: String in zip.get_files():
		var path: String = target.path_join(name).simplify_path()
		if not path.begins_with(target):
			ok = false
			break
		if name.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			ok = false
			break
		file.store_buffer(zip.read_file(name))
		file.close()
		if name.ends_with(".x86_64"):
			FileAccess.set_unix_permissions(path, 493)  # rwxr-xr-x
	zip.close()
	return ok


## Deletes a folder and everything in it. False when something could not be removed.
static func remove_tree(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	var ok: bool = true
	for name: String in DirAccess.get_files_at(path):
		ok = DirAccess.remove_absolute(path.path_join(name)) == OK and ok
	for name: String in DirAccess.get_directories_at(path):
		ok = remove_tree(path.path_join(name)) and ok
	return DirAccess.remove_absolute(path) == OK and ok


## A copy started from versions/<v>/ copies its exe and pck over the root copy when the root is
## older, through a temp name so a failed copy never breaks the root. Retries while the root closes.
func refresh_root() -> void:
	var here: String = OS.get_executable_path().get_base_dir()
	var root_version: String = str(launcher_value(&"root_version", ""))
	if not is_version_dir(here) or Build.compare_versions(here.get_file(), root_version) <= 0:
		return
	for attempt: int in range(REFRESH_TRIES):
		if copy_build(here, root_dir()):
			save_launcher_value(&"root_version", here.get_file())
			Log.info(&"launcher", &"root_refreshed", {"version": here.get_file(), "tries": attempt + 1})
			return
		await get_tree().create_timer(0.5).timeout
	Log.warn(&"launcher", &"root_refresh_failed", {"version": here.get_file(), "root": root_dir()})


## Copies the exe, then its pck, from one folder to another. False when the exe is still locked.
static func copy_build(from: String, to: String) -> bool:
	var exe: String = exe_name()
	for name: String in [exe, exe.get_basename() + ".pck"]:
		var temp: String = to.path_join(name + ".new")
		if DirAccess.copy_absolute(from.path_join(name), temp) != OK:
			return false
		if DirAccess.rename_absolute(temp, to.path_join(name)) != OK:
			DirAccess.remove_absolute(temp)
			return false
		if name.ends_with(".x86_64"):
			FileAccess.set_unix_permissions(to.path_join(name), 493)  # rwxr-xr-x
	return true
