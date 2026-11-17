## Build info: version, commit, network protocol, and the crash marker.
## CI writes res://version.json before export; the editor has none and shows "dev".
extends Node

## Bump when client/server messages change. Mismatched peers are refused.
const PROTOCOL_VERSION: int = 16
const VERSION_FILE: String = "res://version.json"
const CRASH_MARKER: String = "user://running.lock"

var version: String = "dev"
var commit: String = "editor"
var built_at: String = ""
## Sorted Content ids, cached once after Content loads at startup.
var content_hash: String = ""
## True when the previous run did not quit cleanly.
var crashed_last_run: bool = false


func _ready() -> void:
	content_hash = calculate_content_hash()
	load_version_file(VERSION_FILE)
	ProjectSettings.set_setting("application/config/version", version)
	_log_header()
	crashed_last_run = begin_run(CRASH_MARKER)
	if crashed_last_run:
		push_warning("Previous session did not exit cleanly. Logs: %s" % logs_dir())


func _exit_tree() -> void:
	end_run(CRASH_MARKER)


func load_version_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Unreadable %s" % path)
		return
	var info: Dictionary = json.data
	version = str(info.get("version", version))
	commit = str(info.get("commit", commit))
	built_at = str(info.get("built_at", built_at))


func display_version() -> String:
	if commit == "editor":
		return "dev (editor)"
	return "v%s" % version


## True only for plain X.Y.Z release versions. Test tags, main builds and the editor are not stable.
func is_stable() -> bool:
	return is_stable_version(version)


func is_stable_version(text: String) -> bool:
	return RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(text) != null


func is_server() -> bool:
	return OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args()


func is_protocol_compatible(remote_protocol: int) -> bool:
	return remote_protocol == PROTOCOL_VERSION


func calculate_content_hash() -> String:
	var ids: PackedStringArray = []
	var root: DirAccess = DirAccess.open(Content.ROOT)
	if root:
		for category: String in root.get_directories():
			for id: StringName in Content.ids(StringName(category)):
				ids.append(category + "/" + String(id))
	return hash_content_ids(ids)


static func hash_content_ids(ids: PackedStringArray) -> String:
	var sorted: PackedStringArray = ids.duplicate()
	sorted.sort()
	return "\n".join(sorted).sha256_text()


func logs_dir() -> String:
	return ProjectSettings.globalize_path("user://logs")


## Returns true when the marker from an earlier run is still there.
func begin_run(marker: String) -> bool:
	var leftover: bool = FileAccess.file_exists(marker)
	var file: FileAccess = FileAccess.open(marker, FileAccess.WRITE)
	if file:
		file.store_string(Time.get_datetime_string_from_system(true))
	return leftover


func end_run(marker: String) -> void:
	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))


func _log_header() -> void:
	print("Experiment Undead %s (commit %s, built %s, protocol %d)" % [version, commit, built_at, PROTOCOL_VERSION])
	print("OS: %s %s | CPU: %s" % [OS.get_name(), OS.get_version(), OS.get_processor_name()])
	if DisplayServer.get_name() != "headless":
		var gpu: String = RenderingServer.get_video_adapter_name()
		var vendor: String = RenderingServer.get_video_adapter_vendor()
		print("GPU: %s (%s) | driver: %s" % [gpu, vendor, RenderingServer.get_video_adapter_api_version()])


## Compare gameplay resource values, so editor and exported resource formats agree.
func content_fingerprint() -> String:
	var rows: Array[String] = []
	var categories: PackedStringArray = DirAccess.get_directories_at(Content.ROOT)
	categories.sort()
	for category: String in categories:
		var ids: PackedStringArray = PackedStringArray(Content.ids(StringName(category)))
		ids.sort()
		for id: String in ids:
			rows.append(
				"%s/%s:%s" % [category, id, _content_value(Content.get_item(StringName(category), StringName(id)))]
			)
	return "\n".join(rows).sha256_text()


func _content_value(value: Variant) -> String:
	if value is Resource:
		var resource: Resource = value
		if resource.get_script() == null:
			return resource.resource_path
		var fields: Array[String] = []
		for property: Dictionary in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
				fields.append("%s=%s" % [property.name, _content_value(resource.get(property.name))])
		return ";".join(fields)
	if value is Array:
		var entries: Array[String] = []
		for entry: Variant in value:
			entries.append(_content_value(entry))
		return "[%s]" % ",".join(entries)
	if value is Dictionary:
		var fields: Array[String] = []
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys:
			fields.append("%s=%s" % [key, _content_value(value[key])])
		return "{%s}" % ",".join(fields)
	return var_to_str(value)
