## Draws every effect mesh once at match start, hidden under the floor in front of the camera, so their
## shaders compile during the quiet start instead of freezing the first kill, headshot or loot drop
## mid-fight. Frees itself after FRAMES drawn frames. Visual only: never added on a dedicated server.
class_name ShaderWarmUp
extends Node3D

const FRAMES: int = 4
## Camera-space spot: below the floor (eye height is about 1.7 m) yet inside the view, hidden by the floor.
const SPOT: Vector3 = Vector3(0.0, -3.0, -6.0)
## Seconds to wait for a camera before giving up.
const CAMERA_WAIT: float = 10.0

var drawn: int = 0
var _waited: float = 0.0


static func meshes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	out.append_array(Impact.warm_up_meshes())
	out.append_array(HeadPop.warm_up_meshes())
	out.append_array(BloodPool.warm_up_meshes())
	out.append_array(LootDrop.warm_up_meshes())
	out.append_array(BlastEffect.warm_up_meshes())
	return out


func _ready() -> void:
	for mesh: Mesh in meshes():
		add_child(_drawer(mesh))
	visible = false


## Billboard-particle materials are drawn as particles (a different pipeline), the rest as plain meshes.
func _drawer(mesh: Mesh) -> GeometryInstance3D:
	var material: BaseMaterial3D = mesh.surface_get_material(0) as BaseMaterial3D
	if material and material.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES:
		var particles: CPUParticles3D = CPUParticles3D.new()
		particles.mesh = mesh
		particles.amount = 1
		particles.lifetime = 1.0
		particles.gravity = Vector3.ZERO
		return particles
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_waited += delta
		if _waited > CAMERA_WAIT:
			queue_free()
		return
	global_transform = Transform3D(camera.global_basis, camera.global_transform * SPOT)
	visible = true
	drawn += 1
	if drawn > FRAMES:
		queue_free()
