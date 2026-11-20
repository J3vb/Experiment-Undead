## A head popping on a headshot kill (Full gore only): three bloody chunks that
## fly, bounce off the floor and settle, plus a puff of red mist. The newest
## MAX_ALIVE pops are reused; chunks freeze after FREEZE_TIME and the pop
## hides after LIFETIME. Visual only: skipped on a dedicated server.
class_name HeadPop
extends Node3D

const MAX_ALIVE: int = 8
const CHUNKS: int = 3
const FREEZE_TIME: float = 1.5
const LIFETIME: float = 10.0
const MIST_PARTICLES: int = 16

static var _ring: Array[HeadPop] = []
static var _next: int = 0
static var _chunk_mesh: BoxMesh
static var _mist_mesh: QuadMesh

var chunks: Array[RigidBody3D] = []
var _mist: CPUParticles3D
var _age: float = 0.0


static func spawn(parent: Node, point: Vector3) -> HeadPop:
	if parent == null or Build.is_server():
		return null
	var pop: HeadPop = _take(parent)
	pop.global_position = point
	pop._start()
	return pop


static func _take(parent: Node) -> HeadPop:
	if _ring.size() < MAX_ALIVE:
		var fresh: HeadPop = HeadPop.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next
	_next = (_next + 1) % MAX_ALIVE
	var pop: HeadPop = _ring[index]
	if not is_instance_valid(pop) or pop.is_queued_for_deletion():
		pop = HeadPop.new()
		_ring[index] = pop
		parent.add_child(pop)
	elif pop.get_parent() != parent:
		pop.reparent(parent, false)
	return pop


## Shared meshes, for ShaderWarmUp to draw once at match start.
static func warm_up_meshes() -> Array[Mesh]:
	_shared_meshes()
	return [_chunk_mesh, _mist_mesh]


static func _shared_meshes() -> void:
	if _chunk_mesh:
		return
	var flesh: StandardMaterial3D = StandardMaterial3D.new()
	flesh.albedo_color = Impact.BLOOD_COLOR.darkened(0.2)
	flesh.roughness = 0.8
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3(0.07, 0.05, 0.06)
	_chunk_mesh.material = flesh
	var mist: StandardMaterial3D = StandardMaterial3D.new()
	mist.albedo_color = Color(Impact.BLOOD_COLOR, 0.5)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mist_mesh = QuadMesh.new()
	_mist_mesh.size = Vector2(0.12, 0.12)
	_mist_mesh.material = mist


func _init() -> void:
	_shared_meshes()
	for index: int in CHUNKS:
		var chunk: RigidBody3D = RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = Layers.WORLD
		chunk.mass = 0.2
		chunk.top_level = true
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = _chunk_mesh.size
		chunk.add_child(shape)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = _chunk_mesh
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(mesh)
		add_child(chunk)
		chunks.append(chunk)
	_mist = CPUParticles3D.new()
	_mist.one_shot = true
	_mist.emitting = false
	_mist.amount = MIST_PARTICLES
	_mist.lifetime = 0.6
	_mist.explosiveness = 1.0
	_mist.spread = 180.0
	_mist.initial_velocity_min = 0.5
	_mist.initial_velocity_max = 1.6
	_mist.gravity = Vector3(0.0, -1.5, 0.0)
	_mist.mesh = _mist_mesh
	add_child(_mist)
	set_physics_process(false)


func _start() -> void:
	_age = 0.0
	visible = true
	for chunk: RigidBody3D in chunks:
		chunk.freeze = false
		chunk.global_position = global_position
		chunk.linear_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(2.0, 4.0), randf_range(-2.0, 2.0))  # cosmetic
		chunk.angular_velocity = Vector3(randf(), randf(), randf()) * 12.0  # cosmetic
	_mist.restart()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= FREEZE_TIME and not chunks[0].freeze:
		for chunk: RigidBody3D in chunks:
			chunk.freeze = true
	if _age >= LIFETIME:
		visible = false
		set_physics_process(false)
