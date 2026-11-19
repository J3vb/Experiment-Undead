## Looks up content (.tres in res://content/<type>/) by id = file name.
## Content.weapon(&"rifle_ar"), Content.enemy(&"zombie_walker").
extends Node

const ROOT: String = "res://content"

var _by_type: Dictionary[StringName, Dictionary] = {}
var _loaded: Dictionary[String, Resource] = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_by_type.clear()
	_loaded.clear()
	var root: DirAccess = DirAccess.open(ROOT)
	if root == null:
		push_error("Content: missing %s" % ROOT)
		return
	for type_dir: String in root.get_directories():
		var items: Dictionary = {}
		_scan(ROOT.path_join(type_dir), items)
		_by_type[StringName(type_dir)] = items


func _scan(path: String, items: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(path.path_join(sub), items)
	for file: String in dir.get_files():
		# Exported builds rename resources to *.tres.remap
		var clean: String = file.trim_suffix(".remap")
		if clean.get_extension() != "tres":
			continue
		var id: StringName = StringName(clean.get_basename())
		if items.has(id):
			push_error("Content: duplicate id '%s' in %s" % [id, path])
			continue
		items[id] = path.path_join(clean)


func get_item(type: StringName, id: StringName) -> Resource:
	var items: Dictionary = _by_type.get(type, {})
	if not items.has(id):
		push_error("Content: no %s with id '%s'" % [type, id])
		return null
	var path: String = items[id]
	if not _loaded.has(path):
		_loaded[path] = load(path)
	return _loaded[path]


func has(type: StringName, id: StringName) -> bool:
	return _by_type.get(type, {}).has(id)


func ids(type: StringName) -> Array:
	return _by_type.get(type, {}).keys()


## Ids in name order, the same on every machine. Array.sort() on StringNames orders them by memory address.
func sorted_ids(type: StringName) -> Array[StringName]:
	var names: PackedStringArray = PackedStringArray(ids(type))
	names.sort()
	var sorted: Array[StringName] = []
	for id: String in names:
		sorted.append(StringName(id))
	return sorted


func weapon(id: StringName) -> WeaponData:
	return get_item(&"weapons", id) as WeaponData


func enemy(id: StringName) -> EnemyData:
	return get_item(&"enemies", id) as EnemyData
