## Every visible surface in Halcyon Labs has a textured material: a procedural
## shader, an albedo texture or a real glow (light fixture or experiment).
## FLAT_TODAY lists what is still flat; steps of docs/plans/halcyon-surfaces.md
## shrink it to empty, and the test fails when an entry is fixed but still listed.
extends GutTest

const SCENES: Array[String] = [
	"res://levels/halcyon_labs/blockout.tscn",
	"res://levels/halcyon_labs/map.tscn",
]
## Look rule 3: only fixtures and gameplay objects glow above 1.0, so a weak glow
## is a flat surface, not a light.
const GLOW_ENERGY: float = 1.0
## Material resource paths ("scene::id" for materials saved inside a scene).
const FLAT_TODAY: Array[String] = [
	"res://levels/halcyon_labs/map.tscn::door_dev",
	"res://levels/halcyon_labs/map.tscn::machine_dev",
	"res://levels/materials/pipe.tres",
]
## Prop models whose built-in slots still need the remap to levels/materials (step 3).
const FLAT_MODELS_TODAY: Array[String] = [
	"res://assets/models/dressing/hazard_sign.glb",
	"res://assets/models/dressing/lab_papers.glb",
	"res://assets/models/dressing/mess_spill.glb",
	"res://assets/models/dressing/pipe_run_3.glb",
	"res://assets/models/dressing/pipe_run_6.glb",
	"res://assets/models/props/crate_large.glb",
	"res://assets/models/props/crate_long.glb",
	"res://assets/models/props/crate_stack.glb",
	"res://assets/models/props/filing_cabinets.glb",
	"res://assets/models/props/forklift.glb",
	"res://assets/models/props/fuel_drum.glb",
	"res://assets/models/props/generator.glb",
	"res://assets/models/props/guard_desk.glb",
	"res://assets/models/props/holding_cell.glb",
	"res://assets/models/props/jar_shelf.glb",
	"res://assets/models/props/lab_bench.glb",
	"res://assets/models/props/locker_row.glb",
	"res://assets/models/props/mess_table.glb",
	"res://assets/models/props/serving_counter.glb",
	"res://assets/models/props/specimen_tank.glb",
	"res://assets/models/props/supply_truck.glb",
]


func test_no_flat_surfaces_outside_the_list() -> void:
	var flat: Dictionary = _flat_surfaces()
	for key: String in flat:
		if FLAT_MODELS_TODAY.has(key.get_slice("::", 0)):
			continue
		assert_has(FLAT_TODAY, key, "flat surface, give it a textured material: %s (%s)" % [key, flat[key]])


func test_the_list_only_names_surfaces_that_are_still_flat() -> void:
	var flat: Dictionary = _flat_surfaces()
	for key: String in FLAT_TODAY:
		assert_true(flat.has(key), "%s is textured now, remove it from FLAT_TODAY" % key)
	var flat_models: Array[String] = []
	for key: String in flat:
		flat_models.append(key.get_slice("::", 0))
	for model: String in FLAT_MODELS_TODAY:
		assert_has(flat_models, model, "%s is textured now, remove it from FLAT_MODELS_TODAY" % model)


func test_new_texture_materials_use_the_halcyon_sets() -> void:
	for name: String in ["ceiling_stained", "wall_paint", "raw_concrete"]:
		var material: ShaderMaterial = load("res://levels/materials/%s.tres" % name) as ShaderMaterial
		assert_not_null(material, name)
		if material == null:
			continue
		for slot: StringName in [&"albedo_map", &"normal_map", &"orm_map"]:
			var texture: Texture2D = material.get_shader_parameter(slot) as Texture2D
			assert_not_null(texture, "%s %s" % [name, slot])
			if texture:
				assert_string_starts_with(texture.resource_path, "res://assets/textures/halcyon/", name)


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
