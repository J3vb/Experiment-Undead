## Lantern Post props from tools/assets/town_props.py: they import, stand on the ground and face +Z. The street
## lamp and wall lantern use the shared Iron material (asset list P9).
extends GutTest

const MODELS: String = "res://assets/models/town/%s.glb"
const IDS: Array[String] = ["street_lamp", "wall_lantern", "window_lit", "window_dark", "signpost"]


func _extent(scene: Node3D) -> AABB:
	var box: AABB = AABB()
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	return box


func _place(id: String) -> Node3D:
	var packed: PackedScene = load(MODELS % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node3D = packed.instantiate() as Node3D
	add_child_autofree(scene)
	return scene


func _has_glow(scene: Node3D) -> bool:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
			if material and material.emission_enabled:
				return true
	return false


func test_every_prop_stands_on_the_origin() -> void:
	for id: String in IDS:
		var box: AABB = _extent(_place(id))
		assert_almost_eq(box.position.y, 0.0, 0.01, id + " bottom on the ground")
		var centre: Vector3 = box.get_center()
		assert_lt(Vector2(centre.x, centre.z).length(), 0.36, id + " origin under the footprint")


func test_street_lamp_is_tall_and_reaches_forward() -> void:
	var box: AABB = _extent(_place("street_lamp"))
	assert_between(box.size.y, 4.3, 4.8, "about 4.6 m tall")
	assert_gt(box.end.z, 0.3, "arm and lantern reach +Z (towards the street)")
	assert_true(_has_glow(_place("street_lamp")), "lantern glass glows")


func test_windows_open_shutters_towards_the_front() -> void:
	var lit: Node3D = _place("window_lit")
	var box: AABB = _extent(lit)
	assert_between(box.size.x, 2.0, 2.3, "frame plus two open shutters")
	var shutter: Node3D = lit.find_child("Shutter0Plank1", true, false) as Node3D
	var glass: Node3D = lit.find_child("Glass", true, false) as Node3D
	assert_not_null(shutter, "shutter planks are named parts")
	if shutter and glass:
		assert_gt(shutter.global_position.z, glass.global_position.z, "shutters sit in front of the glass")
	assert_true(_has_glow(lit), "lit window glows")
	assert_false(_has_glow(_place("window_dark")), "dark window does not glow")


func test_street_lamp_and_wall_lantern_use_shared_iron() -> void:
	for id: String in ["street_lamp", "wall_lantern"]:
		var used: Array[String] = []
		for node: Node in _place(id).find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for i: int in mesh.get_surface_count():
				used.append(mesh.surface_get_material(i).resource_path)
		assert_has(used, "res://levels/materials/iron.tres", id + " iron parts use the shared Iron material")
