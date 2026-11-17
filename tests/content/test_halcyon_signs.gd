## Checks the painted Halcyon Labs signs (plan F-68 step 1): every area has its name
## sign, every sign sits on a wall or floor of its room, and wall signs miss the doorways.
extends GutTest

const SIGNS: String = "res://levels/halcyon_labs/signs.tscn"
const MAP: String = "res://levels/halcyon_labs/map.tscn"
const LAYOUT: String = "res://levels/halcyon_labs/layout.json"
const SIGN_TEXTURES: String = "res://assets/textures/signs/"
const HAZARD: String = "res://assets/textures/halcyon/decal_hazard.png"
## The eight areas of docs/design/maps.md, by layout room id.
const AREAS: Array[String] = [
	"loading_dock",
	"guard_post",
	"mess_hall",
	"main_corridor",
	"generator_hall",
	"labs",
	"coolant_tunnel",
	"containment_wing",
]
const WALL_GAP: float = 0.2

var _layout: Dictionary
var _signs: Node


func before_all() -> void:
	_layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary


func before_each() -> void:
	_signs = (load(SIGNS) as PackedScene).instantiate()


func after_each() -> void:
	_signs.free()


func test_every_area_has_its_name_sign() -> void:
	for area: String in AREAS:
		var node_name: String = "Sign" + area.to_pascal_case()
		var name_sign: Decal = _signs.get_node_or_null(node_name) as Decal
		assert_not_null(name_sign, "%s has a name sign" % area)
		if name_sign != null:
			var expected: String = SIGN_TEXTURES + "sign_%s.png" % area
			assert_eq(name_sign.texture_albedo.resource_path, expected, node_name)
			assert_not_null(_room_at(name_sign.position), "%s hangs inside its room" % node_name)


func test_signs_use_sign_textures_and_fade_like_story_decals() -> void:
	assert_gt(_signs.get_child_count(), AREAS.size(), "name signs plus logos, lane lines and stripes")
	for decal: Decal in _signs.get_children():
		var path: String = decal.texture_albedo.resource_path
		assert_true(path.begins_with(SIGN_TEXTURES) or path == HAZARD, "%s texture %s" % [decal.name, path])
		if path.begins_with(SIGN_TEXTURES):
			assert_true(decal.distance_fade_enabled, "%s fades out with distance" % decal.name)
			assert_almost_eq(decal.distance_fade_begin, 25.0, 0.01, decal.name)


func test_signs_lie_on_a_wall_or_floor_of_their_room() -> void:
	for decal: Decal in _signs.get_children():
		var room: Dictionary = _room_at(decal.position)
		assert_false(room.is_empty(), "%s is inside a room" % decal.name)
		if room.is_empty():
			continue
		var floor_y: float = float(room["floor"])
		var top: float = floor_y + float(room.get("height", 3.5))
		var projects: Vector3 = decal.transform.basis.y
		if projects.is_equal_approx(Vector3.UP):
			assert_lt(absf(decal.position.y - floor_y), decal.size.y * 0.5, "%s reaches the floor" % decal.name)
			continue
		assert_lt(_wall_distance(room, decal.position), WALL_GAP, "%s sits on a wall" % decal.name)
		assert_gt(decal.position.y - decal.size.z * 0.5, floor_y + 0.3, "%s is above the floor" % decal.name)
		assert_lt(decal.position.y + decal.size.z * 0.5, top, "%s is below the ceiling" % decal.name)


func test_name_signs_and_logos_miss_the_doorways() -> void:
	for decal: Decal in _signs.get_children():
		if decal.texture_albedo.resource_path == HAZARD or decal.transform.basis.y.is_equal_approx(Vector3.UP):
			continue
		var along: Vector3 = decal.transform.basis.x
		for opening: Dictionary in _layout["openings"]:
			var at: Array = opening["at"]
			var door: Vector3 = Vector3(float(at[0]), decal.position.y, float(at[1]))
			var offset: Vector3 = door - decal.position
			if absf(offset.dot(decal.transform.basis.y)) > 0.5:
				continue
			var gap: float = absf(offset.dot(along)) - decal.size.x * 0.5 - float(opening["width"]) * 0.5
			assert_gt(gap, 0.0, "%s is clear of the opening at %s" % [decal.name, at])


func test_map_instances_the_signs() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	assert_true(map.has_node("Signs"), "map.tscn instances signs.tscn")
	map.free()


func _room_at(at: Vector3) -> Dictionary:
	for room: Dictionary in _layout["rooms"]:
		if not AREAS.has(room["id"]):
			continue
		var r: Array = room["rect"]
		var inside: bool = at.x >= float(r[0]) and at.x <= float(r[2]) and at.z >= float(r[1]) and at.z <= float(r[3])
		var floor_y: float = float(room["floor"])
		if inside and at.y >= floor_y - 0.5 and at.y <= floor_y + float(room.get("height", 3.5)):
			return room
	return {}


func _wall_distance(room: Dictionary, at: Vector3) -> float:
	var r: Array = room["rect"]
	var dx: float = minf(absf(at.x - float(r[0])), absf(at.x - float(r[2])))
	var dz: float = minf(absf(at.z - float(r[1])), absf(at.z - float(r[3])))
	return minf(dx, dz)
