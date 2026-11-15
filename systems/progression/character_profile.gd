## One local character. Keeps unknown save fields and refuses to replace unreadable saves.
class_name CharacterProfile
extends RefCounted

const DIRECTORY: String = "user://characters/"
const XP_RULES: XpRules = preload("res://content/progression/xp_rules.tres")

var id: StringName = &""
var display_name: String = "Survivor"
var total_xp: int = 0
var skill_ranks: Dictionary = {}
var level: int:
	get:
		return XP_RULES.level_for_total_xp(total_xp)

var _unknown: Dictionary = {}
var _can_save: bool = true


func to_dict() -> Dictionary:
	var data: Dictionary = _unknown.duplicate(true)
	data["id"] = String(id)
	data["display_name"] = display_name
	data["total_xp"] = total_xp
	data["skill_ranks"] = skill_ranks.duplicate(true)
	return data


static func from_dict(data: Dictionary) -> CharacterProfile:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = StringName(data.get("id", ""))
	profile.display_name = data.get("display_name", "Survivor")
	profile.total_xp = int(data.get("total_xp", 0))
	profile.skill_ranks = data.get("skill_ranks", {}).duplicate(true)
	profile._unknown = data.duplicate(true)
	for key: String in ["id", "display_name", "total_xp", "skill_ranks"]:
		profile._unknown.erase(key)
	return profile


static func load_or_create(profile_id: StringName) -> CharacterProfile:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = profile_id
	var path: String = DIRECTORY + String(profile_id) + ".json"
	if not FileAccess.file_exists(path):
		return profile
	var data: Dictionary = SaveFile.read(path)
	var xp: Variant = data.get("total_xp", 0)
	var valid: bool = (
		not data.is_empty()
		and data.get("id", String(profile_id)) is String
		and data.get("display_name", "Survivor") is String
		and data.get("skill_ranks", {}) is Dictionary
		and (xp is int or xp is float)
	)
	if valid:
		valid = is_finite(float(xp)) and float(xp) >= 0.0 and float(xp) == float(int(xp))
	if not valid:
		profile._can_save = false
		Log.warn(&"progression", &"profile_unreadable", {"id": String(profile_id), "path": path})
		return profile
	profile = from_dict(data)
	profile.id = profile_id
	return profile


func save() -> Error:
	if not _can_save:
		return ERR_UNAVAILABLE
	var path: String = DIRECTORY + String(id) + ".json"
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if error == OK:
		error = SaveFile.write(path, to_dict())
	if error != OK:
		Log.warn(&"progression", &"profile_save_failed", {"id": String(id), "path": path, "error": error})
	return error
