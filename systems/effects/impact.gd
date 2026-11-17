## One-shot hit effect: a burst of particles plus a short-lived mark.
## The newest MAX_ALIVE impacts are kept and reused; meshes and materials are shared.
class_name Impact
extends Node3D

enum Kind { SURFACE, FLESH }

const MAX_ALIVE: int = 48
const LIFETIME: float = 6.0
const FLESH_LIFETIME: float = 1.0

static var _ring: Array[Impact] = []
static var _next: int = 0
static var _flesh_mesh: QuadMesh
static var _surface_mesh: QuadMesh
static var _mark_mesh: QuadMesh

var _flesh: CPUParticles3D
var _surface: CPUParticles3D
var _mark: MeshInstance3D
var _left: float = 0.0


static func spawn(parent: Node, point: Vector3, normal: Vector3, kind: Kind) -> Impact:
	if parent == null:
		return null
	var impact: Impact = _take(parent)
	impact.global_position = point + normal * 0.01
	impact._show(normal, kind)
	return impact


## A new impact until MAX_ALIVE exist, then the oldest one, moved under `parent`.
static func _take(parent: Node) -> Impact:
	if _ring.size() < MAX_ALIVE:
		var fresh: Impact = Impact.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next
	_next = (_next + 1) % MAX_ALIVE
	var impact: Impact = _ring[index]
	if not is_instance_valid(impact) or impact.is_queued_for_deletion():
		impact = Impact.new()
		_ring[index] = impact
		parent.add_child(impact)
	elif impact.get_parent() != parent:
		impact.reparent(parent, false)
	return impact


static func _shared_meshes() -> void:
	if _mark_mesh:
		return
	_flesh_mesh = _quad(0.04, Color(0.45, 0.02, 0.02), true)
	_surface_mesh = _quad(0.04, Color(0.55, 0.5, 0.45), true)
	_mark_mesh = _quad(0.07, Color(0.03, 0.03, 0.03), false)


static func _quad(size: float, color: Color, particle: bool) -> QuadMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if particle:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	else:
		material.roughness = 1.0
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(size, size)
	mesh.material = material
	return mesh


func _init() -> void:
	_shared_meshes()
	_flesh = _particles(_flesh_mesh, 14)
	_surface = _particles(_surface_mesh, 8)
	_mark = MeshInstance3D.new()
	_mark.mesh = _mark_mesh
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark)
	set_process(false)


func _particles(mesh: QuadMesh, amount: int) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.spread = 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.mesh = mesh
	add_child(particles)
	return particles


func _show(normal: Vector3, kind: Kind) -> void:
	var flesh: bool = kind == Kind.FLESH
	var particles: CPUParticles3D = _flesh if flesh else _surface
	_flesh.visible = flesh
	_surface.visible = not flesh
	particles.direction = normal
	particles.restart()
	_mark.visible = not flesh
	if not flesh:
		var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		_mark.look_at(global_position - normal, up)
	visible = true
	_left = FLESH_LIFETIME if flesh else LIFETIME
	set_process(true)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		visible = false
		set_process(false)
