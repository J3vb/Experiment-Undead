## Picture-in-picture scope: while the player aims, a second camera renders a
## zoomed view of the world (without the viewmodel) and the lens shows it.
class_name ScopeLens
extends MeshInstance3D

## Render layer for first-person gun meshes, so the scope camera can skip them.
const VIEWMODEL_LAYER: int = 1 << 19
const AIMED: float = 0.5

@export var zoom: float = 2.0

var camera: Camera3D
var viewport: SubViewport

var _weapon: Weapon
var _material: ShaderMaterial


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.cull_mask = 0xFFFFF & ~VIEWMODEL_LAYER
	camera.near = 0.05
	viewport.add_child(camera)
	add_child(viewport)
	_material = material_override as ShaderMaterial
	_material.set_shader_parameter(&"view", viewport.get_texture())
	_material.set_shader_parameter(&"live", false)
	var node: Node = get_parent()
	while node != null and not node is Weapon:
		node = node.get_parent()
	_weapon = node as Weapon


func is_rendering() -> bool:
	return viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func _process(_delta: float) -> void:
	var main: Camera3D = get_viewport().get_camera_3d()
	var aimed: bool = _weapon != null and _weapon.active and _weapon.ads_progress > AIMED and main != null
	if aimed != is_rendering():
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if aimed else SubViewport.UPDATE_DISABLED
		_material.set_shader_parameter(&"live", aimed)
	if not aimed:
		return
	viewport.size = Vector2i(get_viewport().get_visible_rect().size / 2.0)
	camera.global_transform = main.get_global_transform_interpolated()
	camera.fov = main.fov / zoom
