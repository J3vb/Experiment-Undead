## Drops lightmap entries for meshes that no longer exist in a map, so a layout
## change that removes baked nodes does not break the map until the next GPU
## re-bake (LightmapGI errors on missing baked nodes). Remaining meshes keep
## their baked light; new meshes stay unbaked until the re-bake.
##   godot --headless --path . -s res://tools/prune_lightmap_users.gd -- halcyon_labs
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var map_id: String = args[0] if not args.is_empty() else "halcyon_labs"
	var level: Node = (load("res://levels/%s/map.tscn" % map_id) as PackedScene).instantiate()
	var gi: LightmapGI = level.find_child("LightmapGI", false, false) as LightmapGI
	var data: LightmapGIData = gi.light_data
	var removed: int = prune(data, gi)
	var uid: int = _uid_in_file(data.resource_path)
	var err: Error = ResourceSaver.save(data, data.resource_path)
	if err == OK:
		_write_uid(data.resource_path, uid)
	print("removed %d missing lightmap users from %s (%s)" % [removed, data.resource_path, error_string(err)])
	level.free()
	quit(0 if err == OK else 1)


## A script save writes no uid into the binary file, but map.tscn refers to the
## bake by its uid, so it is copied from the old file. Binary header: magic,
## 5 ints, type name (length + bytes), 8-byte offset, 4-byte flags, then the uid.
static func _uid_offset(file: FileAccess) -> int:
	file.seek(24)
	return 28 + file.get_32() + 12


static func _uid_in_file(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	file.seek(_uid_offset(file))
	return file.get_64()


static func _write_uid(path: String, uid: int) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek(_uid_offset(file))
	file.store_64(uid)


## Entries are [path, uv rect, slice, sub instance], flattened. Keeps those whose path resolves from gi.
static func prune(data: LightmapGIData, gi: LightmapGI) -> int:
	var users: Array = data.get("user_data")
	var kept: Array = []
	var removed: int = 0
	for i: int in range(0, users.size(), 4):
		if gi.get_node_or_null(users[i] as NodePath) == null:
			removed += 1
			continue
		kept.append_array(users.slice(i, i + 4))
	data.set("user_data", kept)
	return removed
