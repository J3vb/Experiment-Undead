## Checks the code-built prop, dressing and large prop models (plans F-15, F-77): each
## loads as one mesh, imports as a static lightmapped piece with baked AO shading, every
## surface uses a shared prop_import.gd slot material, and monitors use the shared screen.
extends GutTest

const FOLDERS: Array[String] = [
	"res://assets/models/props/",
	"res://assets/models/dressing/",
	"res://assets/models/props_large/",
]
const IMPORTER: GDScript = preload("res://tools/assets/prop_import.gd")
const SCREEN: String = "res://systems/effects/monitor_screen.tres"
const WITH_SCREEN: Array[String] = [
	"res://assets/models/props/lab_bench.glb",
	"res://assets/models/props/guard_desk.glb",
	"res://assets/models/props/vending_machine.glb",
]


func _models() -> Array[String]:
	var out: Array[String] = []
	for folder: String in FOLDERS:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".glb"):
				out.append(folder + file)
	return out


func _meshes(path: String) -> Array[MeshInstance3D]:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var out: Array[MeshInstance3D] = []
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	autofree(scene)
	return out


func test_every_model_is_one_static_lightmapped_mesh() -> void:
	assert_gt(_models().size(), 0, "prop models exist")
	for path: String in _models():
		assert_eq(_meshes(path).size(), 1, path + " is one mesh (one draw per material)")
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(path + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 2, path + " bakes into the lightmap")
		assert_eq(
			settings.get_value("params", "import_script/path"),
			"res://tools/assets/prop_import.gd",
			path + " uses its baked AO shading"
		)


func test_monitors_keep_a_screen_surface() -> void:
	for path: String in WITH_SCREEN:
		var paths: Array[String] = []
		for mesh: MeshInstance3D in _meshes(path):
			for i: int in mesh.mesh.get_surface_count():
				var mat: Material = mesh.mesh.surface_get_material(i)
				paths.append(mat.resource_path if mat else "")
		assert_has(paths, SCREEN, path + " shows the shared monitor screen")


func test_every_surface_uses_a_shared_slot() -> void:
	var shared: Array = IMPORTER.SHARED.values()
	for path: String in _models():
		for mesh: MeshInstance3D in _meshes(path):
			for i: int in mesh.mesh.get_surface_count():
				var mat: Material = mesh.mesh.surface_get_material(i)
				var where: String = mat.resource_path if mat else "no material"
				assert_has(shared, where, "%s surface %d uses a prop_import.gd SHARED slot" % [path, i])


func test_library_slots_load() -> void:
	for slot: String in ["Stone", "Tile", "Enamel", "Ice", "Beacon"]:
		assert_true(IMPORTER.SHARED.has(slot), slot + " is a shared slot")
		assert_true(load(IMPORTER.SHARED[slot]) is Material, slot + " loads as a material")
