## Synapse's server-owned secondary hits and the short cosmetic arcs every peer sees.
class_name Chain
extends Node

signal secondary_killed(player: Player)

const MAX_TARGETS: int = 3
const RANGE: float = 6.0
const DAMAGE_FRACTION: float = 0.5
const ARC_TIME: float = 0.12
const ARC_COLOR: Color = Color("3fe0c8")


func _init() -> void:
	name = "Chain"


## Runs before the primary hit, while a lethal shot's source is still alive.
func apply(zombie: Zombie, info: DamageInfo) -> void:
	if not multiplayer.is_server() or zombie.health.is_dead or zombie.state == Zombie.State.DEAD:
		return
	if info.amount <= 0.0:
		return
	var targets: Array[Zombie] = _targets(zombie)
	var ends: PackedVector3Array = PackedVector3Array()
	var killed: bool = false
	for target: Zombie in targets:
		var hit: DamageInfo = DamageInfo.create(info.amount * DAMAGE_FRACTION, info.attacker, info.damage_type)
		hit.weapon_id = info.weapon_id
		hit.position = target.global_position + Vector3.UP
		ends.append(hit.position)
		target.health.take_damage(hit)
		killed = killed or target.health.is_dead
	if killed:
		_confirm_kill(info.attacker)
	if ends.is_empty():
		return
	var start: Vector3 = zombie.global_position + Vector3.UP
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		show_arcs(start, ends)
	else:
		show_arcs.rpc(start, ends)


func _confirm_kill(attacker: Node) -> void:
	if attacker is Player:
		secondary_killed.emit(attacker as Player)


func _targets(source: Zombie) -> Array[Zombie]:
	var targets: Array[Zombie] = []
	for child: Node in source.get_parent().get_children():
		var zombie: Zombie = child as Zombie
		if zombie == null or zombie == source or zombie.health.is_dead or zombie.state == Zombie.State.DEAD:
			continue
		if source.global_position.distance_squared_to(zombie.global_position) <= RANGE * RANGE:
			targets.append(zombie)
	targets.sort_custom(
		func(a: Zombie, b: Zombie) -> bool:
			var da: float = source.global_position.distance_squared_to(a.global_position)
			var db: float = source.global_position.distance_squared_to(b.global_position)
			return a.net_id < b.net_id if is_equal_approx(da, db) else da < db
	)
	if targets.size() > MAX_TARGETS:
		targets.resize(MAX_TARGETS)
	return targets


## Cosmetic only: no health, hit events or chained effects run on receiving peers.
@rpc("authority", "call_local", "unreliable")
func show_arcs(start: Vector3, ends: PackedVector3Array) -> void:
	for end: Vector3 in ends:
		var arc: Node3D = Node3D.new()
		add_child(arc)
		arc.global_position = start
		var delta: Vector3 = end - start
		var side: Vector3 = delta.cross(Vector3.UP).normalized() * 0.12
		var points: PackedVector3Array = PackedVector3Array(
			[Vector3.ZERO, delta * 0.33 + side, delta * 0.67 - side, delta]
		)
		for i: int in points.size() - 1:
			_segment(arc, points[i], points[i + 1])
		get_tree().create_timer(ARC_TIME).timeout.connect(arc.queue_free)


func _segment(parent: Node3D, start: Vector3, end: Vector3) -> void:
	var delta: Vector3 = end - start
	if delta.length_squared() < 0.000001:
		return
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.012
	mesh.height = delta.length()
	mesh.radial_segments = 4
	mesh.rings = 0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = ARC_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = ARC_COLOR
	material.emission_energy_multiplier = 1.5
	mesh.material = material
	var segment: MeshInstance3D = MeshInstance3D.new()
	segment.mesh = mesh
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(segment)
	segment.position = (start + end) * 0.5
	segment.quaternion = Quaternion(Vector3.UP, delta.normalized())
