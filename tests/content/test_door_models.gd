## Checks the code-built Halcyon Labs door models (plan F-63): each loads as one
## dynamic (unbaked) mesh, the orange paint is the shared Hazard material, and in
## the map every door is a model that fits inside its blocker box.
extends GutTest

const FOLDER: String = "res://assets/models/doors/"
const MAP: String = "res://levels/halcyon_labs/map.tscn"
const HAZARD: String = "res://levels/materials/hazard_paint.tres"
const FIT_SLACK: float = 0.05
## Labels whose model slides up when opened; debris and vent grates vanish.
const SLIDING: Array[String] = ["door", "shutter", "freezer door"]


func _models() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(FOLDER):
		if file.ends_with(".glb"):
			out.append(FOLDER + file)
	return out


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


func test_every_door_model_is_one_unbaked_mesh() -> void:
	assert_eq(_models().size(), 7, "door models exist")
	for path: String in _models():
		var scene: Node = autofree((load(path) as PackedScene).instantiate())
		var meshes: Array[MeshInstance3D] = _meshes(scene)
		assert_eq(meshes.size(), 1, path + " is one mesh")
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(path + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3, path + " is dynamic: doors move")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/prop_import.gd")
		assert_ne(meshes[0].gi_mode, GeometryInstance3D.GI_MODE_STATIC, path + " stays out of the lightmap")
		var paths: Array[String] = []
		for i: int in meshes[0].mesh.get_surface_count():
			paths.append(meshes[0].mesh.surface_get_material(i).resource_path)
		var bought: bool = not (path.contains("vent_grate") or path.contains("freezer"))
		assert_eq(paths.has(HAZARD), bought, path + ": only doors you buy wear hazard paint")


func test_every_door_is_a_model_that_fits_its_blocker() -> void:
	var level: Node = autofree((load(MAP) as PackedScene).instantiate())
	add_child(level)
	var doors: Array[Node] = level.get_node("NavigationRegion3D/Doors").get_children()
	assert_eq(doors.size(), 12, "9 doors, 2 vent grates, the freezer")
	for node: Node in doors:
		var door: Door = node as Door
		assert_eq(door.slide_up > 0.0, SLIDING.has(door.label), "%s slides only if it is a %s" % [door.name, SLIDING])
		var blocker: StaticBody3D = door.get_node("Blocker") as StaticBody3D
		assert_false(blocker is Block, "%s draws its model, not a grey box" % door.name)
		assert_eq(blocker.collision_layer, Layers.WORLD)
		var box: Vector3 = ((blocker.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
		var mesh: MeshInstance3D = _meshes(blocker.get_node("Model"))[0]
		var bounds: AABB = blocker.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		var half: Vector3 = box * 0.5 + Vector3.ONE * FIT_SLACK
		assert_true(AABB(-half, half * 2.0).encloses(bounds), "%s model %s fits box %s" % [door.name, bounds, box])
		assert_gt(bounds.size.x, box.x * 0.9, "%s model fills the doorway" % door.name)
