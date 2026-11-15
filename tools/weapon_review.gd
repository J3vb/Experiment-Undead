## Weapon review booth: fixed Common/Legendary close-ups, 10 m reads and live hip/ADS viewmodels.
## godot --path . res://tools/weapon_review.tscn -- --out /tmp/weapon-review/before
extends Node3D

const GUNS: Dictionary[String, String] = {
	"rifle_ar": "rifle_ar",
	"shotgun_brenner": "brenner_trench",
	"kestrel_smg": "kestrel_smg",
	"talon_dmr": "talon_dmr",
	"hollis_44": "hollis_44",
	"mako_pdw": "mako_pdw",
	"atlas_auto": "atlas_auto",
	"halberd_lmg": "halberd_lmg",
	"corvid_338": "corvid_338",
	"fieldhand_lever": "fieldhand_lever",
	"ironwood_50": "ironwood_50",
	"siphon": "siphon",
}
const RARITIES: Dictionary[String, Color] = {
	"common": Color("#D9D9D2"),
	"legendary": Color("#FF8A1C"),
}
const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const WEAPON: String = "res://systems/weapons/weapon.tscn"
const WARMUP_FRAMES: int = 12

@export var capture_on_ready: bool = true

var _camera: Camera3D
var _stage: Node3D
var _caption: Label
var _output: String = "res://screenshots/weapon_review"


func _ready() -> void:
	if capture_on_ready:
		_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Weapon review PNG capture needs a display; use xvfb-run with opengl3")
		get_tree().quit(1)
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = arguments.find("--out")
	if out_index >= 0 and out_index + 1 < arguments.size():
		_output = arguments[out_index + 1]
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	if error != OK:
		push_error("Cannot create weapon review output: %s" % _output)
		get_tree().quit(1)
		return
	_setup()
	if "--silhouettes-only" in arguments:
		for model: String in GUNS:
			await _capture_silhouette(model)
		get_tree().quit()
		return
	for model: String in GUNS:
		for rarity: String in RARITIES:
			await _capture_model(model, rarity)
	get_tree().quit()


func _setup() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load(LOOK) as Environment
	add_child(world)
	_stage = Node3D.new()
	add_child(_stage)
	_camera = Camera3D.new()
	_camera.near = 0.03
	_camera.current = true
	add_child(_camera)
	_light(Vector3(1.4, 1.2, 1.0), 2.2)
	_light(Vector3(-0.7, 0.25, 0.4), 0.7)
	_light(Vector3(-0.4, 0.8, -1.3), 1.5)
	var overlay: CanvasLayer = CanvasLayer.new()
	add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(32, 24)
	_caption.add_theme_color_override("font_color", Color("#E8ECE6"))
	_caption.add_theme_font_override("font", load("res://assets/fonts/AtkinsonHyperlegibleNext.ttf") as Font)
	_caption.add_theme_font_size_override("font_size", 24)
	overlay.add_child(_caption)


func _light(at: Vector3, energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_color = Color("#CDEEE8")
	light.light_energy = energy
	light.omni_range = 12.0
	add_child(light)


func _capture_model(model: String, rarity: String) -> void:
	var scene: PackedScene = load("res://assets/models/weapons/%s.glb" % model) as PackedScene
	var gun: Node3D = scene.instantiate() as Node3D
	_stage.add_child(gun)
	apply_rarity(gun, RARITIES[rarity])
	_camera.fov = 35.0
	_camera.look_at_from_position(Vector3(1.35, 0.6, 0.75), Vector3(0, -0.03, -0.18))
	await _save(model, rarity, "booth", "Fixed booth / 35 deg vertical FOV")
	_camera.fov = hip_fov()
	_camera.look_at_from_position(Vector3(10, 0, -0.18), Vector3(0, 0, -0.18))
	await _save(model, rarity, "10m", "10 m / 110 deg horizontal FOV / full frame")
	gun.free()
	await _capture_first_person(model, rarity)


func _capture_first_person(model: String, rarity: String) -> void:
	_camera.transform = Transform3D.IDENTITY
	var data: WeaponData = load("res://content/weapons/%s.tres" % GUNS[model]) as WeaponData
	var weapon: Weapon = (load(WEAPON) as PackedScene).instantiate() as Weapon
	weapon.setup(WeaponInstance.new(data), null, _camera)
	_camera.add_child(weapon)
	weapon.set_active(true)
	weapon.set_process(false)
	apply_rarity(weapon, RARITIES[rarity])
	var target: Node3D = _target()
	_stage.add_child(target)
	for aimed: bool in [false, true]:
		configure_view(_camera, weapon, aimed)
		await _save(model, rarity, "ads" if aimed else "hip", "Actual viewmodel / content pose and FOV / 10 m target")
	weapon.free()
	target.free()


func _capture_silhouette(model: String) -> void:
	var scene: PackedScene = load("res://assets/models/weapons/%s.glb" % model) as PackedScene
	var gun: Node3D = scene.instantiate() as Node3D
	_stage.add_child(gun)
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	black.disable_fog = true
	for child: Node in gun.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = black
	var background: Environment = Environment.new()
	background.background_mode = Environment.BG_COLOR
	background.background_color = Color("#D9D9D2")
	_camera.environment = background
	_camera.fov = 35.0
	_camera.look_at_from_position(Vector3(1.6, 0, -0.18), Vector3(0, 0, -0.18))
	_caption.add_theme_color_override("font_color", Color.BLACK)
	await _save(model, "shape", "silhouette", "Black only / fixed side camera / same metre scale")
	gun.free()


static func hip_fov() -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(110.0) / 2.0) * 9.0 / 16.0))


static func configure_view(camera: Camera3D, weapon: Weapon, aimed: bool) -> void:
	camera.near = 0.03
	camera.fov = weapon.data.ads_fov if aimed else hip_fov()
	weapon.ads_progress = 1.0 if aimed else 0.0
	weapon.position = weapon.data.ads_position if aimed else weapon.data.hip_position
	weapon.rotation = Vector3.ZERO


static func has_rarity(mesh: MeshInstance3D) -> bool:
	for parameter: Dictionary in mesh.get_property_list():
		if parameter.name == "instance_shader_parameters/rarity_color":
			return true
	return false


static func apply_rarity(gun: Node3D, color: Color) -> void:
	var supported: bool = false
	for child: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if has_rarity(mesh):
			mesh.set_instance_shader_parameter(&"rarity_color", color)
			supported = true
	if supported:
		_tint_glass(gun, color)


static func _tint_glass(gun: Node3D, color: Color) -> void:
	for child: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh is ScopeLens:
			(mesh.material_override as ShaderMaterial).set_shader_parameter(&"glass_color", color * 0.12)
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			if source is StandardMaterial3D and source.resource_name == "OpticGlass":
				var glass: StandardMaterial3D = source.duplicate() as StandardMaterial3D
				glass.albedo_color = color.darkened(0.55)
				mesh.set_surface_override_material(surface, glass)


func _target() -> Node3D:
	var target: Node3D = Node3D.new()
	for index: int in range(-4, 5):
		_target_bar(target, Vector3(index * 0.25, 0, -10), Vector3(0.012, 2, 0.012), Color("#5F6D68"))
		_target_bar(target, Vector3(0, index * 0.25, -10), Vector3(2, 0.012, 0.012), Color("#5F6D68"))
	_target_bar(target, Vector3(0, 0, -9.99), Vector3(0.06, 0.06, 0.012), Color("#D9D9D2"))
	return target


func _target_bar(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)


func _save(model: String, rarity: String, view: String, detail: String) -> void:
	_caption.text = "%s / %s / %s\n%s" % [model.to_upper(), rarity.to_upper(), view.to_upper(), detail]
	for _frame: int in WARMUP_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _output.path_join("%s_%s_%s.png" % [model, rarity, view])
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Failed to save weapon review image: %s" % path)
		get_tree().quit(1)
	print("saved ", path)
