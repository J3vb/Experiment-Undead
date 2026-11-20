## Renders one 128 px icon per loot gun and gear base into assets/textures/ui/icons/<base id>.png.
## Run with autoloads (Content) through its scene, at a 256 px window:
##   xvfb-run -s "-screen 0 1024x768x24" godot --path . --rendering-driver opengl3 --resolution 256x256 \
##     res://tools/render_item_icons.tscn
extends Node3D

const OUT_DIR: String = "res://assets/textures/ui/icons/"
const SIZE: int = 128
const WARMUP_FRAMES: int = 20

var _camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	get_viewport().transparent_bg = true
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8b3a8")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world.environment = environment
	add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_color = Color("ffd9a0")
	key.light_energy = 1.3
	add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color("cdeee8")
	rim.light_energy = 0.9
	add_child(rim)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	_render_all.call_deferred()


func _render_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for base: Resource in item_bases():
		var scene: PackedScene = model_for(base)
		if scene == null:
			print("No model for %s: keeps its tools/assets/placeholder_gear_icons.py icon" % base.get("id"))
			continue
		await _render(scene, base is WeaponData, OUT_DIR + "%s.png" % base.get("id"))
	get_tree().quit()


## Every base a loot item can name: guns and gear across all rarities.
static func item_bases() -> Array[Resource]:
	var bases: Array[Resource] = []
	for rarity: StringName in ItemRoller.RARITIES:
		for base: Resource in LootService.eligible_bases(999, rarity):
			if not bases.has(base):
				bases.append(base)
	return bases


static func model_for(base: Resource) -> PackedScene:
	if base is WeaponData:
		return (base as WeaponData).world_model
	var visual: GearVisual = GearVisual.find((base as GearBaseData).visual_id)
	return visual.scene_for(0) if visual else null


func _render(scene: PackedScene, side_view: bool, out: String) -> void:
	var model: Node3D = scene.instantiate() as Node3D
	add_child(model)
	model.rotation.y = -PI / 2.0 if side_view else 0.0
	var box: AABB = _bounds(model)
	var centre: Vector3 = box.get_center()
	_camera.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.1
	var facing: Vector3 = Vector3(0.25, 0.15, 1.0).normalized()
	_camera.look_at_from_position(centre + facing * 10.0, centre)
	for _i: int in WARMUP_FRAMES:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	fit_square(image, SIZE, not side_view).save_png(out)
	print("saved ", out)
	model.free()


## First-person-only parts (vest cuffs, "FP" in the name) are hidden; the rest is framed.
func _bounds(model: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "VisualInstance3D", true, false):
		var visual: VisualInstance3D = node as VisualInstance3D
		if "FP" in String(visual.name):
			visual.visible = false
			continue
		var part: AABB = visual.global_transform * visual.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Crops to the drawing and pads to a centred square, so every icon fills its box. With trim_sides,
## thin columns at the sides (rest-pose vest cuffs) fall outside; guns keep every pixel (barrel tips).
static func fit_square(image: Image, size: int, trim_sides: bool) -> Image:
	var used: Rect2i = image.get_used_rect()
	if trim_sides:
		var columns: PackedInt32Array = _coverage(image)
		used.position.x = _first_solid(columns, false)
		used.end.x = _first_solid(columns, true) + 1
	if used.size.x <= 0 or used.size.y <= 0:
		return image
	var side: int = int(maxi(used.size.x, used.size.y) * 1.08)
	var square: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, used, (Vector2i(side, side) - used.size) / 2)
	square.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return square


## Drawn pixels per column.
static func _coverage(image: Image) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(image.get_width())
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.1:
				counts[x] += 1
	return counts


## Index of the first (or last) column holding at least a quarter of the busiest column's pixels.
static func _first_solid(counts: PackedInt32Array, from_end: bool) -> int:
	var busiest: int = 0
	for count: int in counts:
		busiest = maxi(busiest, count)
	for step: int in counts.size():
		var index: int = counts.size() - 1 - step if from_end else step
		if counts[index] * 4 >= busiest:
			return index
	return 0
