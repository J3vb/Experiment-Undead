## Renders every shared surface material as a lit wall-and-floor corner into
## screenshots/surfaces/<floor material>.png, for look checks of texture sets:
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tools/surface_board.tscn
extends Node

const MATERIALS: String = "res://levels/materials/%s.tres"
const ENVIRONMENT: String = "res://levels/looks/halcyon_interior.tres"
const OUT: String = "res://screenshots/surfaces/%s.png"
## Material shown on the wall, material shown on the floor.
const BOARDS: Array = [
	["wall_paint", "tiled_wet_floor"],
	["ceiling_stained", "raw_concrete"],
	["panel_paint", "sealed_concrete"],
	["wall_paint", "linoleum"],
	["raw_concrete", "steel_plate"],
	["wall_paint", "clinic_tile"],
	["raw_concrete", "grating"],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/surfaces"))
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load(ENVIRONMENT)
	add_child(world)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("#CDEEE8")
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position = Vector3(1.2, 2.6, 1.6)
	add_child(light)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(-0.4, 1.5, 3.2), Vector3(0.3, 1.0, 0))
	var wall: Block = _block(Vector3(4, 3, 0.2), Vector3(0, 1.5, -0.1))
	var ground: Block = _block(Vector3(4, 0.2, 4), Vector3(0, -0.1, 1.9))
	for board: Array in BOARDS:
		wall.material = load(MATERIALS % board[0])
		ground.material = load(MATERIALS % board[1])
		for _i: int in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT % board[1])
		print("saved ", board[1])
	get_tree().quit()


func _block(size: Vector3, at: Vector3) -> Block:
	var block: Block = Block.new()
	block.size = size
	block.position = at
	add_child(block)
	return block
