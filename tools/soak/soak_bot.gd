## Balance bot for the soak: backs away from close zombies, turns toward the nearest zombie it can see,
## holds fire, reloads, buys one wall gun (and its ammo) from anywhere once it can pay.
## A zombie it cannot see for HUNT_AFTER seconds is killed outright, standing in for
## the player walking over to it (zombies can stall out of sight, see the soak notes).
extends Node

const TURN_RATE: float = 6.0  ## Radians per second, about a quick human flick.
const AIM_HEIGHT: float = 1.15  ## Chest height: body shots only, no headshots.
const HUNT_AFTER: float = 10.0
const BACK_OFF: float = 4.0  ## Metres: closer than this, walk backwards while shooting.

var player: Player
var wall: WallBuy
var hunts: int = 0

var _query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _unseen: float = 0.0
var _ticks: int = 0


func setup(p_player: Player, wall_id: StringName) -> void:
	player = p_player
	_query.collision_mask = Layers.WORLD | Layers.HIT_ZONE
	_query.collide_with_areas = true
	_query.exclude = [player.get_rid()]
	for node: Node in player.session.level.find_children("*", "WallBuy", true, false):
		var buy: WallBuy = node as WallBuy
		if buy.weapon.id == wall_id:
			wall = buy


func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive():
		return
	_shop()
	var gun: Weapon = player.weapons.current
	var frame: InputFrame = InputFrame.new()
	_ticks += 1
	var target: Vector3 = _nearest_target()
	_unseen = 0.0 if target != Vector3.INF else _unseen + delta
	if _unseen >= HUNT_AFTER:
		_hunt()
	if target != Vector3.INF:
		frame.look = _look_toward(target, TURN_RATE * delta)
		frame.buttons |= InputFrame.ADS
		if player.camera.global_position.distance_to(target) < BACK_OFF:
			frame.move = Vector2(0.0, 1.0)
		# Semi and burst guns fire on a fresh press, so tap the trigger every other tick.
		var trigger_down: bool = gun.data.fire_mode == WeaponData.FireMode.AUTO or _ticks % 2 == 0
		if frame.look.length() < 0.05 and trigger_down:
			frame.buttons |= InputFrame.FIRE
	if gun.instance.ammo_in_mag == 0 and gun.instance.ammo_reserve > 0 and not gun.is_reloading():
		frame.buttons |= InputFrame.RELOAD
	player.apply_frame(frame, delta)


func _shop() -> void:
	if wall == null:
		return
	var facts: Dictionary = wall.owner_facts(player)
	var owned: StringName = facts.owned
	if owned == &"":
		if player.wallet.points >= wall.weapon.cost:
			wall.interact(player, facts)
		return
	var gun: Weapon = player.weapons.weapons[facts.slot]
	var dry: bool = gun.instance.ammo_in_mag == 0 and gun.instance.ammo_reserve == 0
	if dry and player.wallet.points >= wall.ammo_cost(owned):
		wall.interact(player, facts)
	var index: int = facts.slot if gun.instance.ammo_in_mag + gun.instance.ammo_reserve > 0 else 0
	if player.weapons.current != player.weapons.weapons[index]:
		player.weapons.equip(index)


func _hunt() -> void:
	_unseen = 0.0
	for zombie: Zombie in get_tree().get_nodes_in_group(&"enemies"):
		if zombie.health.is_dead or zombie.state == Zombie.State.SPAWNING:
			continue
		var info: DamageInfo = DamageInfo.create(zombie.health.current, player)
		info.position = zombie.global_position
		zombie.hit_zones[1].receive_hit(info)
		hunts += 1
		return


func _nearest_target() -> Vector3:
	var eye: Vector3 = player.camera.global_position
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for zombie: Zombie in get_tree().get_nodes_in_group(&"enemies"):
		if zombie.health.is_dead or zombie.state == Zombie.State.SPAWNING:
			continue
		var point: Vector3 = zombie.global_position + Vector3.UP * AIM_HEIGHT * zombie.data.body_scale
		var distance: float = eye.distance_squared_to(point)
		if distance < best_distance and _can_hit(eye, point, zombie):
			best = point
			best_distance = distance
	return best


func _can_hit(eye: Vector3, point: Vector3, zombie: Zombie) -> bool:
	_query.from = eye
	_query.to = point
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(_query)
	var zone: HitZone = hit.get("collider") as HitZone
	return zone != null and zone in zombie.hit_zones


## Look change for this tick, capped at max_turn radians, in InputFrame signs.
func _look_toward(point: Vector3, max_turn: float) -> Vector2:
	var wanted: Vector3 = (point - player.camera.global_position).normalized()
	return turn_toward(-player.camera.global_basis.z, wanted, max_turn)


## Yaw and pitch change that turns forward toward wanted (InputFrame.look signs).
static func turn_toward(forward: Vector3, wanted: Vector3, max_turn: float) -> Vector2:
	var yaw: float = wrapf(atan2(-wanted.x, -wanted.z) - atan2(-forward.x, -forward.z), -PI, PI)
	var pitch: float = asin(clampf(wanted.y, -1.0, 1.0)) - asin(clampf(forward.y, -1.0, 1.0))
	return Vector2(-yaw, -pitch).limit_length(max_turn)
