## Stage setup shared by the lineup renders (gun_lineup.gd, zombie_lineup.gd,
## prop_lineup.gd): world look, omni lights, camera and the warm-up-then-save step.
extends RefCounted

const WARMUP_FRAMES: int = 60


static func build(look: String) -> Node3D:
	var stage: Node3D = Node3D.new()
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load(look) as Environment
	stage.add_child(world)
	return stage


static func floor_plane(stage: Node3D, material: String, size: Vector2) -> MeshInstance3D:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.material = load(material) as Material
	ground.mesh = plane
	stage.add_child(ground)
	return ground


static func light(stage: Node3D, at: Vector3, energy: float, color: Color, reach: float) -> OmniLight3D:
	var omni: OmniLight3D = OmniLight3D.new()
	omni.position = at
	omni.light_energy = energy
	omni.light_color = color
	omni.omni_range = reach
	stage.add_child(omni)
	return omni


static func camera(stage: Node3D) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	stage.add_child(cam)
	return cam


## Waits for lights and shaders to settle, then saves the viewport as a PNG.
static func save(tree: SceneTree, out: String) -> void:
	for _i: int in WARMUP_FRAMES:
		await tree.process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	tree.root.get_texture().get_image().save_png(out)
	print("saved ", out)
