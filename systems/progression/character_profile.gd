## One local character. Keeps unknown save fields and refuses to replace unreadable saves.
class_name CharacterProfile
extends RefCounted

const DIRECTORY: String = "user://characters/"
const STASH_SIZE: int = 60
const XP_RULES: XpRules = preload("res://content/progression/xp_rules.tres")

var id: StringName = &""
var display_name: String = "Survivor"
var total_xp: int = 0
var skill_ranks: Dictionary = {}
var stash: Array[Dictionary] = []
var loadout: Dictionary = {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}}
## Best run per map (the level folder name): {"round": int, "kills": int}.
var best_runs: Dictionary = {}
var level: int:
	get:
		return XP_RULES.level_for_total_xp(total_xp)

var _unknown: Dictionary = {}
var _can_save: bool = true


func _init() -> void:
	for _slot: int in STASH_SIZE:
		stash.append({})


func to_dict() -> Dictionary:
	var data: Dictionary = _unknown.duplicate(true)
	data["id"] = String(id)
	data["display_name"] = display_name
	data["total_xp"] = total_xp
	data["skill_ranks"] = skill_ranks.duplicate(true)
	data["stash"] = stash.duplicate(true)
	data["loadout"] = loadout.duplicate(true)
	data["best_runs"] = best_runs.duplicate(true)
	return data


static func from_dict(data: Dictionary) -> CharacterProfile:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = StringName(data.get("id", ""))
	profile.display_name = data.get("display_name", "Survivor")
	profile.total_xp = int(data.get("total_xp", 0))
	profile.skill_ranks = data.get("skill_ranks", {}).duplicate(true)
	var saved_stash: Array = data.get("stash", [])
	for slot: int in mini(saved_stash.size(), STASH_SIZE):
		if saved_stash[slot] is Dictionary:
			profile.stash[slot] = saved_stash[slot].duplicate(true)
	var saved_loadout: Variant = data.get("loadout", {})
	if saved_loadout is Dictionary:
		for slot: String in profile.loadout:
			if saved_loadout.get(slot) is Dictionary:
				profile.loadout[slot] = saved_loadout[slot].duplicate(true)
	var saved_best: Variant = data.get("best_runs", {})
	if saved_best is Dictionary:
		profile.best_runs = saved_best.duplicate(true)
	profile._unknown = data.duplicate(true)
	for key: String in ["id", "display_name", "total_xp", "skill_ranks", "stash", "loadout", "best_runs"]:
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
		and _valid_inventory(data)
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


static func _valid_inventory(data: Dictionary) -> bool:
	var saved_stash: Variant = data.get("stash", [])
	var saved_loadout: Variant = data.get("loadout", {})
	if saved_loadout is Array and saved_loadout.is_empty():
		saved_loadout = {}
	if not saved_stash is Array or not saved_loadout is Dictionary:
		return false
	if saved_stash.size() > STASH_SIZE:
		return false
	for item: Variant in saved_stash:
		if item != null and not item is Dictionary:
			return false
	for slot: String in ["primary", "sidearm", "vest", "charm", "implant"]:
		var item: Variant = saved_loadout.get(slot)
		if item != null and not item is Dictionary:
			return false
	return true


## Keeps the highest round per map (more kills breaks a tie). Saves and
## returns true when this run is a new best.
func record_run(map: String, stats: Dictionary) -> bool:
	var run_round: int = int(stats.get("round", 0))
	var run_kills: int = int(stats.get("kills", 0))
	var best: Variant = best_runs.get(map, {})
	var best_round: int = int(best.get("round", 0)) if best is Dictionary else 0
	var best_kills: int = int(best.get("kills", 0)) if best is Dictionary else 0
	if run_round < best_round or (run_round == best_round and run_kills <= best_kills):
		return false
	best_runs[map] = {"round": run_round, "kills": run_kills}
	save()
	return true


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
