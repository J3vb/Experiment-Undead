## One-shot hit effect: a burst of particles plus a short-lived mark.
## Placeholder until the Pool autoload and real decals arrive.
class_name Impact
extends Node3D

enum Kind { SURFACE, FLESH }

const MAX_ALIVE: int = 48
const LIFETIME: float = 6.0


static func spawn(parent: Node, point: Vector3, normal: Vector3, kind: Kind) -> void:
	if parent == null:
		return
	var tree: SceneTree = parent.get_tree()
	var alive: Array[Node] = tree.get_nodes_in_group(&"impacts")
	if alive.size() >= MAX_ALIVE:
		alive[0].queue_free()
	var impact: Impact = Impact.new()
	impact.add_to_group(&"impacts")
	parent.add_child(impact)
	impact.global_position = point + normal * 0.01
	impact._build(normal, kind)


func _build(normal: Vector3, kind: Kind) -> void:
	var flesh: bool = kind == Kind.FLESH
	var color: Color = Color(0.45, 0.02, 0.02) if flesh else Color(0.55, 0.5, 0.45)

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 14 if flesh else 8
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.direction = normal
	particles.spread = 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.04, 0.04)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mat
	particles.mesh = mesh
	add_child(particles)

	if not flesh:
		var mark: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var mark_mat: StandardMaterial3D = StandardMaterial3D.new()
		mark_mat.albedo_color = Color(0.03, 0.03, 0.03)
		mark_mat.roughness = 1.0
		quad.material = mark_mat
		mark.mesh = quad
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		mark.look_at(global_position - normal, up)

	var timer: SceneTreeTimer = get_tree().create_timer(LIFETIME if not flesh else 1.0)
	timer.timeout.connect(queue_free)
