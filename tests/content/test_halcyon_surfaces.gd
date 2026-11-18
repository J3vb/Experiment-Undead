## Every visible surface in Halcyon Labs has a textured material: a procedural
## shader, an albedo texture or a real glow (light fixture or experiment).
extends GutTest

const SCENES: Array[String] = [
	"res://levels/halcyon_labs/blockout.tscn",
	"res://levels/halcyon_labs/map.tscn",
]
const BUILDER: String = "res://tools/blockout_builder.gd"
const DECALS: String = "res://levels/halcyon_labs/decals.tscn"
const LAYOUT: String = "res://levels/halcyon_labs/layout.json"
const TEXTURED: Array[String] = [
	"ceiling_stained",
	"wall_paint",
	"raw_concrete",
	"steel_plate",
	"linoleum",
	"clinic_tile",
	"grating",
	"sealed_concrete",
	"panel_paint",
	"panel_trim",
	"pipe",
	"steel",
	"rubber",
	"paper",
	"alarm_paint",
	"sodium_paint",
]
## Look rule 3: only fixtures and gameplay objects glow above 1.0, so a weak glow
## is a flat surface, not a light.
const GLOW_ENERGY: float = 1.0
const MONITOR_SCREEN: String = "res://systems/effects/monitor_screen.tres"


func test_no_flat_surfaces() -> void:
	var flat: Dictionary = _flat_surfaces()
	assert_eq(flat.size(), 0, "flat surfaces (material: example node), give them a textured material: %s" % flat)


func test_prop_screens_use_the_monitor_material() -> void:
	var bench: Node = (load("res://assets/models/props/lab_bench.glb") as PackedScene).instantiate()
	var screens: int = 0
	for node: Node in bench.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			if mesh.surface_get_material(i).resource_path == MONITOR_SCREEN:
				screens += 1
	bench.free()
	assert_gt(screens, 0, "the lab bench Screen slot maps to the atmosphere's monitor material")


func test_new_texture_materials_use_the_halcyon_sets() -> void:
	for name: String in TEXTURED:
		var material: ShaderMaterial = load("res://levels/materials/%s.tres" % name) as ShaderMaterial
		assert_not_null(material, name)
		if material == null:
			continue
		for slot: StringName in [&"albedo_map", &"normal_map", &"orm_map"]:
			var texture: Texture2D = material.get_shader_parameter(slot) as Texture2D
			assert_not_null(texture, "%s %s" % [name, slot])
			if texture:
				assert_string_starts_with(texture.resource_path, "res://assets/textures/halcyon/", name)


func test_rooms_take_their_materials_from_the_layout() -> void:
	var plain: Dictionary = {"id": "plain", "rect": [0, 0, 4, 4], "floor": 0, "height": 4, "lights": false}
	var dressed: Dictionary = plain.duplicate()
	dressed["id"] = "dressed"
	dressed["rect"] = [10, 0, 14, 4]
	dressed["floor_material"] = "steel_plate"
	dressed["ceiling_material"] = "raw_concrete"
	dressed["wall_material"] = "raw_concrete"
	var builder: GDScript = load(BUILDER) as GDScript
	var built: Node3D = builder.build({"rooms": [plain, dressed]})
	var expect: Dictionary = {
		"plain/Floor": "tiled_wet_floor",
		"plain/Ceiling": "ceiling_stained",
		"plain/Walls/Edge0Run0": "wall_paint",
		"dressed/Floor": "steel_plate",
		"dressed/Ceiling": "raw_concrete",
		"dressed/Walls/Edge0Run0": "raw_concrete",
	}
	for path: String in expect:
		var node: Node = built.get_node(path)
		var material: Material = (node as Block).material if node is Block else _upper_material(node)
		assert_eq(material.resource_path, "res://levels/materials/%s.tres" % expect[path], path)
	assert_false(built.get_node("plain/Walls").has_meta(&"material"), "the build-time wall material is not saved")
	built.free()


func test_decals_have_textures_and_lie_on_a_room_floor() -> void:
	var rooms: Array = (JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary)["rooms"]
	var decals: Node = (load(DECALS) as PackedScene).instantiate()
	assert_gt(decals.get_child_count(), 20, "decals at doors and in every room")
	for decal: Decal in decals.get_children():
		assert_not_null(decal.texture_albedo, decal.name)
		var floor_y: float = _floor_under(rooms, decal.position)
		assert_false(is_nan(floor_y), "%s is inside a room" % decal.name)
		if not is_nan(floor_y):
			assert_lt(absf(decal.position.y - floor_y), decal.size.y * 0.5, "%s reaches the floor" % decal.name)
	assert_not_null(_map_child("Decals"), "map.tscn instances decals.tscn")
	decals.free()


func _floor_under(rooms: Array, at: Vector3) -> float:
	for room: Dictionary in rooms:
		var r: Array = room["rect"]
		if at.x >= float(r[0]) and at.x <= float(r[2]) and at.z >= float(r[1]) and at.z <= float(r[3]):
			return float(room["floor"])
	return NAN


func _map_child(child: String) -> Node:
	var map: Node = (load(SCENES[1]) as PackedScene).instantiate()
	var found: bool = map.has_node(child)
	map.free()
	return self if found else null


func _upper_material(run: Node) -> Material:
	return ((run.get_node("Upper") as MeshInstance3D).mesh as BoxMesh).material


## Flat surfaces as key -> example node path.
func _flat_surfaces() -> Dictionary:
	var flat: Dictionary = {}
	for path: String in SCENES:
		var root: Node = (load(path) as PackedScene).instantiate()
		_collect(root, root, flat)
		root.free()
	return flat


func _collect(root: Node, node: Node, flat: Dictionary) -> void:
	for material: Material in _materials(node):
		if _is_flat(material):
			var key: String = material.resource_path
			if key.is_empty():
				key = "<%s>" % root.get_path_to(node)
			flat[key] = str(root.get_path_to(node))
	for child: Node in node.get_children():
		_collect(root, child, flat)


func _materials(node: Node) -> Array[Material]:
	var out: Array[Material] = []
	if node is Block:
		out.append((node as Block).material)
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node and mesh_node.mesh and mesh_node.visible:
		for i: int in mesh_node.mesh.get_surface_count():
			var material: Material = mesh_node.get_surface_override_material(i)
			if material == null:
				material = mesh_node.mesh.surface_get_material(i)
			out.append(material)
		if mesh_node.material_override:
			out = [mesh_node.material_override]
	return out


func _is_flat(material: Material) -> bool:
	var standard: BaseMaterial3D = material as BaseMaterial3D
	if material == null:
		return true
	if standard == null:
		return false
	var glows: bool = standard.emission_enabled and standard.emission_energy_multiplier >= GLOW_ENERGY
	return standard.albedo_texture == null and not glows
