## Basic zombie: rises, chases the nearest living player over the navmesh,
## swings when close, dies. State machine is a plain enum + match.
class_name Zombie
extends CharacterBody3D

enum State { SPAWNING, CHASING, ATTACKING, DEAD }

const SPAWN_TIME: float = 0.9
const CORPSE_TIME: float = 5.0
const SEPARATION_RADIUS: float = 0.9
const SEPARATION_FORCE: float = 2.5
const STRIKE_TIME: float = 0.35
## Arms start lifting toward a target closer than this.
const REACH_DISTANCE: float = 3.0
## A chasing zombie that moves less than STUCK_DISTANCE in STUCK_TIME seconds
## while out of reach is reported to the Log once.
const STUCK_TIME: float = 3.0
const STUCK_DISTANCE: float = 0.3
const FELL_OUT_Y: float = -50.0

var data: EnemyData
var net_id: int = 0
var state: State = State.SPAWNING
var target: Player

var _max_health: float = 100.0
var _speed: float = 1.8
var _damage: float = 35.0
var _state_time: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_landed: bool = false
var _repath_timer: float = 0.0
var _retarget_timer: float = 0.0
var _groan_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO
var _stuck_reported: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng: RandomNumberGenerator

@onready var health: HealthComponent = $HealthComponent
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: ZombieRig = $Visual
@onready var head_zone: HitZone = $HitZones/Head
@onready var voice: AudioStreamPlayer3D = $Voice
@onready var hit_zones: Array[HitZone] = [$HitZones/Head, $HitZones/Body]


## Called by the Spawner before adding to the tree.
func setup(
	p_data: EnemyData,
	p_net_id: int,
	health_mult: float,
	speed_mult: float,
	damage_mult: float,
	rng: RandomNumberGenerator
) -> void:
	data = p_data
	net_id = p_net_id
	_max_health = data.max_health * health_mult
	_speed = data.move_speed * speed_mult * rng.randf_range(0.9, 1.1)
	_damage = data.attack_damage * damage_mult
	_rng = rng


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	if data:
		health.reset(_max_health)
		visual.scale = Vector3.ONE * data.body_scale
	# The head zone rides on the model's head so headshots follow the animation.
	head_zone.reparent(visual.head, false)
	head_zone.position = Vector3.ZERO
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_repath_timer = _rng.randf() * 0.25
	_groan_timer = _rng.randf_range(1.0, 5.0)
	visual.position.y = -1.8
	_enter(State.SPAWNING)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	match state:
		State.SPAWNING:
			_tick_spawning()
		State.CHASING:
			_tick_chasing(delta)
		State.ATTACKING:
			_tick_attacking(delta)
		State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	_tick_voice(delta)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_attack_landed = false


func _tick_spawning() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_time >= SPAWN_TIME:
		_stuck_from = global_position
		_enter(State.CHASING)


func _tick_chasing(delta: float) -> void:
	_update_target(delta)
	if target == null:
		_steer(Vector3.ZERO, delta)
		return
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	_watch_progress(delta, distance)
	if distance <= data.attack_range * 0.85 and _attack_cooldown <= 0.0 and _can_see(target):
		_enter(State.ATTACKING)
		_play(data.attack_sound)
		return

	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = _repath_interval(distance)
		agent.target_position = target.global_position

	var next: Vector3 = agent.get_next_path_position()
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01 or agent.is_navigation_finished():
		direction = to_target
	direction = direction.normalized()
	if distance < data.attack_range * 0.7:
		direction = Vector3.ZERO
	_steer(direction * _speed + _separation(), delta)
	_face(to_target, delta)


## Early warning for navmesh holes, bad spawn points and zombies wedged in
## geometry. Logs only; the zombie keeps trying.
func _watch_progress(delta: float, distance: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < STUCK_TIME or _stuck_reported:
		return
	_stuck_timer = 0.0
	var moved: float = global_position.distance_to(_stuck_from)
	_stuck_from = global_position
	var fell: bool = global_position.y < FELL_OUT_Y
	if fell or (moved < STUCK_DISTANCE and distance > data.attack_range):
		_stuck_reported = true
		var data_out: Dictionary = {
			"net_id": net_id,
			"enemy": data.resource_path.get_file().get_basename(),
			"at": str(global_position.snappedf(0.1)),
			"target_distance": snappedf(distance, 0.1),
			"next_path_point": str(agent.get_next_path_position().snappedf(0.1)),
			"path_finished": agent.is_navigation_finished(),
		}
		Log.warn(&"enemies", &"zombie_fell_out" if fell else &"zombie_stuck", data_out)


func _tick_attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, data.acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, data.acceleration * delta)
	if target:
		_face(target.global_position - global_position, delta)
	if not _attack_landed and _state_time >= data.attack_windup:
		_attack_landed = true
		_try_hit_target()
	if _state_time >= data.attack_windup + STRIKE_TIME:
		_attack_cooldown = data.attack_cooldown
		_enter(State.CHASING)


func _try_hit_target() -> void:
	if target == null or not target.is_alive() or not Net.is_authority():
		return
	var flat: Vector3 = target.global_position - global_position
	flat.y = 0.0
	if flat.length() <= data.attack_range + 0.3 and _can_see(target):
		var info: DamageInfo = DamageInfo.create(_damage, self, DamageInfo.Type.MELEE)
		info.position = target.global_position
		info.impulse = flat.normalized()
		target.take_damage(info)


## True when no world geometry sits between our chest and the target's.
func _can_see(other: Node3D) -> bool:
	var from: Vector3 = global_position + Vector3.UP * 1.2
	var to: Vector3 = other.global_position + Vector3.UP * 1.2
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_target(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer > 0.0 and target != null and target.is_alive():
		return
	_retarget_timer = 0.5
	target = null
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player == null or not player.is_alive():
			continue
		var d: float = global_position.distance_squared_to(player.global_position)
		if d < best:
			best = d
			target = player


func _repath_interval(distance: float) -> float:
	if distance < 10.0:
		return 0.25
	if distance < 30.0:
		return 0.5
	return 1.5


func _separation() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node == self:
			continue
		var other: Zombie = node as Zombie
		if other == null or other.state == State.DEAD:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var d: float = away.length()
		if d > 0.001 and d < SEPARATION_RADIUS:
			push += away / d * (SEPARATION_RADIUS - d) / SEPARATION_RADIUS
	return push * SEPARATION_FORCE


func _steer(wish: Vector3, delta: float) -> void:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(wish, data.acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(data.turn_speed * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	_animate(delta)


## Code-driven limb animation until real clips arrive.
func _animate(delta: float) -> void:
	if state == State.SPAWNING:
		visual.position.y = lerpf(-1.8, 0.0, clampf(_state_time / SPAWN_TIME, 0.0, 1.0))
		return
	if state == State.DEAD:
		return
	visual.position = visual.position.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))
	if state == State.ATTACKING:
		var windup: float = maxf(data.attack_windup, 0.01)
		if _state_time < windup:
			visual.pose_attack(_state_time / windup)
		else:
			visual.pose_attack(1.0 + (_state_time - windup) / STRIKE_TIME)
		return
	var reach: float = 0.0
	if target:
		reach = clampf(1.0 - global_position.distance_to(target.global_position) / REACH_DISTANCE, 0.0, 1.0)
	visual.pose_walk(Vector2(velocity.x, velocity.z).length(), reach, delta)


func _tick_voice(delta: float) -> void:
	if state == State.DEAD or data == null or data.groan_sounds.is_empty():
		return
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(3.0, 8.0)
		_play(data.groan_sounds[randi() % data.groan_sounds.size()])


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	voice.stream = stream
	voice.pitch_scale = randf_range(0.85, 1.15)
	voice.play()


func _on_damaged(info: DamageInfo) -> void:
	Events.enemy_damaged.emit(self, info)
	if state == State.DEAD:
		return
	# Flinch: small shove of the body mesh, reads as impact.
	visual.position += global_basis.inverse() * info.impulse.normalized() * 0.06
	visual.pulse_belly()


func _on_died(info: DamageInfo) -> void:
	_enter(State.DEAD)
	collision_layer = 0
	for zone: HitZone in hit_zones:
		zone.set_enabled(false)
	voice.stop()
	Events.enemy_killed.emit(self, info)
	visual.pose_dead()
	var fall_dir: float = 1.0 if randf() < 0.5 else -1.0
	var tween: Tween = create_tween()
	(
		tween
		. tween_property(visual, "rotation", Vector3(deg_to_rad(-85.0), 0.0, deg_to_rad(10.0) * fall_dir), 0.45)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_interval(CORPSE_TIME)
	tween.tween_property(visual, "position:y", -1.0, 1.5)
	tween.tween_callback(queue_free)
