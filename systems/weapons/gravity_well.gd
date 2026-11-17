## A WELL gun's slow orb is local presentation; its accepted well pulls and damages
## only the server's zombies. Damage is the gun's total, spread over three seconds.
class_name GravityWell
extends Node3D

const RADIUS: float = 6.0
const MAX_TARGETS: int = 12
const DURATION: float = 3.0
const MAX_WELLS: int = 2
const ORB_SPEED: float = 10.0
const ORB_RANGE: float = 25.0
const PULL_SPEED: float = 8.0
const DAMAGE_INTERVAL: float = 0.5
const SCENE: String = "res://systems/weapons/gravity_well.tscn"

var attacker: Player
## The gun that fired this orb or well; null on cosmetic copies.
var weapon_data: WeaponData
var gameplay: bool = true
var collapsed: bool = false
var elapsed: float = 0.0

var _total_damage: float = 0.0
var _pulse_time: float = 0.0
var _orb: bool = false
var _claim: bool = false
var _direction: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _candidates: Array[Zombie] = []
var _captured: Array[Zombie] = []
var _targets: Array[Zombie] = []
var _claims: Node
var _orb_query: PhysicsRayQueryParameters3D


static func launch(weapon: Weapon) -> void:
	var player: Player = weapon.shooter
	if not is_instance_valid(player) or not player.is_multiplayer_authority():
		return
	var claims: Node = player.session.get_node_or_null("HitClaims") if player.session else null
	var origin: Vector3 = weapon.camera.global_position
	var direction: Vector3 = -weapon.camera.global_basis.z
	var parent: Node = player.session if player.session else player.get_parent()
	var orb: GravityWell = spawn_orb(parent, player, origin, direction, claims)
	orb.weapon_data = weapon.data
	if claims:
		claims.call("send_well_orb", origin, direction, weapon.data.id)
	var shots: Node = player.session.get_node_or_null("RemoteShots") if player.session else null
	if shots:
		var muzzle: Node3D = weapon.find_child("Muzzle", true, false) as Node3D
		shots.call("record_trace", weapon, muzzle.global_position if muzzle else origin)


static func spawn_orb(
	parent: Node, player: Player, origin: Vector3, direction: Vector3, claims: Node = null, claim: bool = true
) -> GravityWell:
	var orb: GravityWell = load(SCENE).instantiate() as GravityWell
	orb._orb = true
	orb._claim = claim
	orb.gameplay = false
	orb.attacker = player
	orb._claims = claims
	orb._direction = direction.normalized()
	orb._orb_query = PhysicsRayQueryParameters3D.new()
	orb._orb_query.collision_mask = Layers.WORLD | Layers.HIT_ZONE
	orb._orb_query.collide_with_areas = true
	orb._orb_query.exclude = [player.get_rid()]
	parent.add_child(orb)
	orb.global_position = origin
	orb.scale = Vector3.ONE * 0.18
	return orb


static func open(
	parent: Node, player: Player, point: Vector3, data: WeaponData, cosmetic: bool = false, claims: Node = null
) -> GravityWell:
	var count: int = 0
	var oldest: GravityWell
	for node: Node in parent.get_tree().get_nodes_in_group(&"gravity_wells"):
		var existing: GravityWell = node as GravityWell
		if existing.multiplayer == parent.multiplayer and existing.attacker == player and not existing.collapsed:
			count += 1
			if oldest == null or existing.elapsed > oldest.elapsed:
				oldest = existing
	if count >= MAX_WELLS:
		if not cosmetic:
			return null
		oldest.collapse()
	var well: GravityWell = load(SCENE).instantiate() as GravityWell
	well.gameplay = not cosmetic
	well._claims = claims
	well.setup(player, point, data)
	parent.add_child(well)
	well.global_position = point
	return well


func setup(player: Player, point: Vector3, data: WeaponData) -> void:
	attacker = player
	position = point
	weapon_data = data
	_total_damage = data.damage if data else 0.0


func _ready() -> void:
	if not _orb:
		add_to_group(&"gravity_wells")
		if gameplay and Net.is_authority() and multiplayer.is_server():
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				_track_enemy(node as Node3D)
			Events.enemy_spawned.connect(_track_enemy)


func _track_enemy(node: Node3D) -> void:
	var zombie: Zombie = node as Zombie
	if zombie and zombie.multiplayer == multiplayer and not _candidates.has(zombie):
		_candidates.append(zombie)


func _physics_process(delta: float) -> void:
	if _orb:
		_tick_orb(delta)
	else:
		tick(delta)


func tick(delta: float) -> void:
	if collapsed or delta <= 0.0:
		return
	if not is_instance_valid(attacker):
		collapse()
		return
	var step: float = minf(delta, DURATION - elapsed)
	elapsed = minf(elapsed + step, DURATION)
	if gameplay and Net.is_authority() and multiplayer.is_server():
		_select_targets()
		_pull(step)
		_pulse_time += step
		while _pulse_time + 0.00001 >= DAMAGE_INTERVAL:
			_pulse_time = maxf(_pulse_time - DAMAGE_INTERVAL, 0.0)
			_damage()
	if elapsed >= DURATION:
		collapse()


func _select_targets() -> void:
	_targets.clear()
	for zombie: Zombie in _candidates:
		if not is_instance_valid(zombie) or zombie.health.is_dead:
			continue
		if global_position.distance_squared_to(zombie.global_position) > RADIUS * RADIUS:
			continue
		if not _captured.has(zombie):
			if _captured.size() == MAX_TARGETS:
				continue
			_captured.append(zombie)
		_targets.append(zombie)
		if _targets.size() == MAX_TARGETS:
			break


func _pull(delta: float) -> void:
	for zombie: Zombie in _targets:
		var offset: Vector3 = global_position - zombie.global_position
		var motion: Vector3 = offset.limit_length(PULL_SPEED * delta)
		zombie.move_and_collide(motion)


func _damage() -> void:
	var damaged: bool = false
	var killed: bool = false
	for zombie: Zombie in _targets:
		if not is_instance_valid(zombie) or zombie.health.is_dead:
			continue
		var info: DamageInfo = DamageInfo.create(_total_damage * DAMAGE_INTERVAL / DURATION, attacker)
		info.weapon_id = weapon_data.id
		info.position = zombie.global_position
		var before: float = zombie.health.current
		zombie.health.take_damage(info)
		damaged = damaged or zombie.health.current < before
		killed = killed or zombie.health.is_dead
	if not damaged or not is_instance_valid(attacker):
		return
	if is_instance_valid(_claims):
		_claims.call("confirm_well_hit", attacker, killed)
	else:
		Events.hit_confirmed.emit(attacker, killed, false)


func _tick_orb(delta: float) -> void:
	if not is_instance_valid(attacker):
		collapse()
		return
	var distance: float = minf(ORB_SPEED * delta, ORB_RANGE - _travelled)
	var end: Vector3 = global_position + _direction * distance
	_orb_query.from = global_position
	_orb_query.to = end
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_orb_query)
	_travelled += distance
	global_position = hit.get("position", end)
	if not hit.is_empty() or _travelled >= ORB_RANGE:
		_land()


func _land() -> void:
	if _claim and weapon_data:
		if is_instance_valid(_claims):
			_claims.call("request_well", global_position, weapon_data.id)
		elif Net.is_authority() and multiplayer.is_server():
			open(get_parent(), attacker, global_position, weapon_data)
	collapse()


func collapse() -> void:
	collapsed = true
	set_physics_process(false)
	queue_free()


func _process(delta: float) -> void:
	rotate_y(delta * 2.0)
	if not _orb:
		var opening: float = minf(elapsed * 5.0 + 0.1, 1.0)
		var closing: float = clampf((DURATION - elapsed) * 5.0, 0.0, 1.0)
		scale = Vector3.ONE * opening * closing
