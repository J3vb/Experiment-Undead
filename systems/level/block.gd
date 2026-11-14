## Grey-box building block: a static box with matching collision.
## Set size and material in the inspector; navigation bakes from it.
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
	_mesh.mesh = box
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
