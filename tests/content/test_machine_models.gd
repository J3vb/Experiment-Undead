## Checks the code-built Halcyon Labs machine models (plan F-64): each loads as one
## dynamic (unbaked) mesh, only racks you buy wear hazard paint, every wall-buy is a
## rack that fits its board box with its gun hung on the open side, and the Specimen
## Vault body is a model that fits its box.
extends GutTest

const FOLDER: String = "res://assets/models/machines/"
const MAP: String = "res://levels/halcyon_labs/map.tscn"
const VAULT: String = "res://systems/interactables/specimen_vault.tscn"
const HAZARD: String = "res://levels/materials/hazard_paint.tres"
const FIT_SLACK: float = 0.05
## Wall-buys whose wall is on their local +X, so the rack faces -X (found with a ray probe).
const WALL_ON_PLUS_X: Array[String] = ["WallBuyBrennerTrench", "WallBuyRifle"]


func _models() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(FOLDER):
		if file.ends_with(".glb"):
			out.append(FOLDER + file)
	return out


func _mesh(root: Node) -> MeshInstance3D:
	return root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D


## `node`'s transform in `ancestor`'s space, without needing the scene tree.
func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var out: Transform3D = Transform3D.IDENTITY
	var at: Node3D = node
	while at != ancestor:
		out = at.transform * out
		at = at.get_parent_node_3d()
	return out


## The model's bounds in `body`'s space fit `body`'s box shape plus FIT_SLACK.
func _assert_fits(body: StaticBody3D, label: String) -> void:
	assert_false(body is Block, label + " draws its model, not a grey box")
	assert_eq(body.collision_layer, Layers.WORLD)
	assert_eq(body.collision_mask, 0)
	var box: Vector3 = ((body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
	var mesh: MeshInstance3D = _mesh(body.get_node("Model"))
	var bounds: AABB = _relative(mesh, body) * mesh.get_aabb()
	var half: Vector3 = box * 0.5 + Vector3.ONE * FIT_SLACK
	assert_true(AABB(-half, half * 2.0).encloses(bounds), "%s model %s fits box %s" % [label, bounds, box])
	assert_gt(bounds.get_volume(), box.x * box.y * box.z * 0.6, label + " model fills its box")


func test_every_machine_model_is_one_unbaked_mesh() -> void:
	assert_eq(_models().size(), 3, "two racks and the Vault")
	for path: String in _models():
		var scene: Node = autofree((load(path) as PackedScene).instantiate())
		assert_eq(scene.find_children("*", "MeshInstance3D", true, false).size(), 1, path + " is one mesh")
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(path + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3, path + " is dynamic, like the boxes were")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/prop_import.gd")
		var mesh: MeshInstance3D = _mesh(scene)
		assert_ne(mesh.gi_mode, GeometryInstance3D.GI_MODE_STATIC, path + " stays out of the lightmap")
		var paths: Array[String] = []
		for i: int in mesh.mesh.get_surface_count():
			paths.append(mesh.mesh.surface_get_material(i).resource_path)
		assert_eq(paths.has(HAZARD), path.ends_with("weapon_rack.glb"), path + ": only racks you buy wear hazard")


func test_every_wall_buy_is_a_rack_with_its_gun_on_the_open_side() -> void:
	var level: Node = autofree((load(MAP) as PackedScene).instantiate())
	add_child(level)
	var wall_buys: Array[WallBuy] = []
	for node: Node in level.find_children("*", "Area3D"):
		if node is WallBuy:
			wall_buys.append(node as WallBuy)
	assert_eq(wall_buys.size(), 6, "five wall guns and the Cryo Lance rack")
	for wall_buy: WallBuy in wall_buys:
		var board: StaticBody3D = wall_buy.get_node("Board") as StaticBody3D
		_assert_fits(board, wall_buy.name)
		var mount: Node3D = board.get_node("GunMount") as Node3D
		var open_side: float = -1.0 if WALL_ON_PLUS_X.has(String(wall_buy.name)) else 1.0
		assert_gt(mount.position.x * open_side, 0.05, "%s gun hangs away from the wall" % wall_buy.name)
		assert_eq(mount.get_child_count(), 1, "%s hangs one gun" % wall_buy.name)
		var gun: Node3D = mount.get_child(0) as Node3D
		assert_eq(
			gun.scene_file_path, wall_buy.weapon.world_model.resource_path, "%s shows its own gun" % wall_buy.name
		)


func test_specimen_vault_body_is_a_model_that_fits() -> void:
	var vault: Node3D = autofree((load(VAULT) as PackedScene).instantiate()) as Node3D
	_assert_fits(vault.get_node("Body") as StaticBody3D, "SpecimenVault")
