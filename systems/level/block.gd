## Grey-box building block: a static box with matching collision.
## Set size and material in the inspector; navigation and LightmapGI bake from it.
@tool
class_name Block
extends StaticBody3D

@export var size: Vector3 = Vector3(1, 1, 1):
	set(value):
		size = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()
## Off for any Block that moves or disappears,
## so the lightmap keeps no shadow of it; it is lit by the probes instead.
@export var baked: bool = true

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = material
	box.add_uv2 = true
	_mesh.mesh = box
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC if baked else GeometryInstance3D.GI_MODE_DYNAMIC
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_shape.shape = shape


# LightmapGI skips internal (unowned) children, so the box is handed to it
# through the same duck-typed hooks GridMap uses.
func get_bake_meshes() -> Array:
	if _mesh == null or not baked:
		return []
	return [_mesh.mesh, Transform3D.IDENTITY]


func get_bake_mesh_instance(_index: int) -> RID:
	return _mesh.get_instance()
