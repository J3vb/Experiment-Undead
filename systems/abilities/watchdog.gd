## Watchdog turret (plans/field-abilities.md step 6): a grey-box sentry gun set down in front of
## its user for duration. Every SCAN seconds it picks the nearest live zombie within radius whose
## head it can see; every SHOT_GAP seconds it shoots that head for amount of the zombie's max
## health, so three shots kill anything. Only the server's turret deals damage (the user is the
## attacker: points, XP and kill credit are theirs). Every client's turret aims and shows its shots
## on its own from the synced zombie positions.
class_name Watchdog
extends Node3D

const SCAN: float = 0.2
const SHOT_GAP: float = 0.6
const MUZZLE_HEIGHT: float = 1.1
## Its sound and tracer colour; damage comes from the ability.
const GUN: WeaponData = preload("res://content/weapons/rifle_ar.tres")
## Wall paint and alarm (look-rules.md palette).
const CASING: Color = Color("5f6d68")
const EYE: Color = Color("c3201b")

var data: AbilityData
var user: Player
var spawner: Spawner
var hit_claims: HitClaims
## True for the server's turret, the only one that deals damage.
var live: bool = false
var target: Zombie
var shots: int = 0
var _left: float = 0.0
var _scan: float = 0.0
var _shot: float = 0.0
var _head: Node3D
var _effects: RemoteShotEffects


## Sets a turret down at point under session (a plain Node, so position is world space).
static func place(session: GameSession, ability: AbilityData, by: Player, point: Vector3, damages: bool) -> Watchdog:
	var turret: Watchdog = Watchdog.new()
	turret.data = ability
	turret.user = by
	turret.spawner = session.spawner
	turret.hit_claims = session.hit_claims
	turret.live = damages
	turret.position = point
	session.add_child(turret)
	return turret


func _ready() -> void:
	_left = data.duration
	_shot = SHOT_GAP
	if not Build.is_server():
		_build()


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	_scan -= delta
	_shot -= delta
	if _scan <= 0.0:
		_scan = SCAN
		target = find_target()
	if target and is_instance_valid(target) and _shot <= 0.0:
		_shot = SHOT_GAP
		_fire(target)


func muzzle() -> Vector3:
	return global_position + Vector3.UP * MUZZLE_HEIGHT


## The nearest live zombie within radius whose head the turret can see, or null.
func find_target() -> Zombie:
	if spawner == null:
		return null
	var best: Zombie = null
	var best_distance: float = data.radius * data.radius
	for zombie: Zombie in spawner.zombies:
		if zombie.state == Zombie.State.DEAD or zombie.health.is_dead:
			continue
		var distance: float = muzzle().distance_squared_to(zombie.head_zone.global_position)
		if distance < best_distance and _can_see(zombie.head_zone.global_position):
			best = zombie
			best_distance = distance
	return best


func _can_see(point: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle(), point, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fire(zombie: Zombie) -> void:
	shots += 1
	var head: HitZone = zombie.head_zone
	var aim: Vector3 = head.global_position
	if live:
		var amount: float = zombie.health.max_health * data.amount / maxf(head.damage_multiplier, 0.01)
		var info: DamageInfo = DamageInfo.create(amount, user)
		info.weapon_id = &"watchdog"
		info.position = aim
		info.impulse = (aim - muzzle()).normalized() * 2.0
		if hit_claims:
			hit_claims.apply_server_hit(head, info)
		else:
			head.receive_hit(info)
	if _effects:
		_head.look_at(aim, Vector3.UP)
		_effects.play(GUN, muzzle(), PackedVector3Array([aim]))


func _build() -> void:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = CASING
	paint.metallic = 0.5
	paint.roughness = 0.55
	var post: MeshInstance3D = MeshInstance3D.new()
	var stand: CylinderMesh = CylinderMesh.new()
	stand.top_radius = 0.05
	stand.bottom_radius = 0.28
	stand.height = MUZZLE_HEIGHT - 0.1
	post.mesh = stand
	post.material_override = paint
	post.position.y = stand.height * 0.5
	add_child(post)
	_head = Node3D.new()
	_head.position.y = MUZZLE_HEIGHT
	add_child(_head)
	var gun: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.22, 0.2, 0.6)
	gun.mesh = box
	gun.material_override = paint
	_head.add_child(gun)
	var eye: OmniLight3D = OmniLight3D.new()
	eye.light_color = EYE
	eye.light_energy = 1.5
	eye.omni_range = 1.5
	eye.position = Vector3(0.0, 0.12, -0.3)
	_head.add_child(eye)
	_effects = RemoteShotEffects.new()
	add_child(_effects)
