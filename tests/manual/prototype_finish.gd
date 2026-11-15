## Render the imported Prototype finish under cold light and in darkness.
## Run with --rendering-method gl_compatibility -s res://tests/manual/prototype_finish.gd.
extends SceneTree

const GUNS: Array[String] = ["cryo_lance", "synapse"]

var _environment: Environment
var _lamp: OmniLight3D


func _initialize() -> void:
	root.size = Vector2i(1400, 900)
	var stage: Node3D = Node3D.new()
	var world: WorldEnvironment = WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("0a1416")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("cdeee8")
	_environment.ambient_light_energy = 0.2
	world.environment = _environment
	stage.add_child(world)
	for index: int in GUNS.size():
		var gun: Node3D = (load("res://assets/models/weapons/%s.glb" % GUNS[index]) as PackedScene).instantiate()
		gun.rotation.y = -PI / 2.0
		gun.position.y = -index * 0.4
		stage.add_child(gun)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(-0.3, 0.5, 1.0)
	_lamp.light_color = Color("cdeee8")
	_lamp.light_energy = 2.0
	_lamp.omni_range = 4.0
	stage.add_child(_lamp)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.05
	stage.add_child(camera)
	root.add_child(stage)
	camera.look_at_from_position(Vector3(0.15, -0.1, 2), Vector3(0.03, -0.17, 0))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for mode: String in ["lit", "dark"]:
		for frame: int in 30:
			await process_frame
		root.get_texture().get_image().save_png("res://screenshots/prototype_finish_%s.png" % mode)
		_lamp.visible = false
		_environment.ambient_light_energy = 0.0
	quit()
