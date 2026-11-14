## First-person player body and controller. Consumes one InputFrame per
## physics tick (from LocalInput now, from the network later), moves, and
## drives its components (camera rig, weapons, health, wallet).
## Everything per-player lives here, never in a global.
class_name Player
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.6
@export var crouch_speed_multiplier: float = 0.55
@export var ads_speed_multiplier: float = 0.6
@export var ground_accel: float = 14.0
@export var ground_decel: float = 18.0
@export var air_accel: float = 3.0
## Seconds of sprint before the legs give out (Stride scales it).
@export var sprint_time: float = 4.0
## Seconds without sprint after running out; also how long a full refill takes.
@export var sprint_cooldown: float = 3.0
@export var jump_velocity: float = 4.8
@export var gravity_multiplier: float = 1.3

## Seconds spent down before Second Wind gets the player back up.
@export var second_wind_time: float = 3.0

@export_group("Interact")
@export var interact_range: float = 2.5

@export_group("Look")
@export var ads_sensitivity_multiplier: float = 0.65

## Set by GameSession when spawned. Gives access to the session RNG and tick.
var session: GameSession
var net_id: int = 0

var input_enabled: bool = true
var is_sprinting: bool = false
var is_aiming: bool = false
var is_crouching: bool = false
## Down but not out: Second Wind brings the player back up soon.
var is_downed: bool = false
var move_input: Vector2 = Vector2.ZERO
var sprint_left: float = 4.0
var last_frame: InputFrame = InputFrame.new()
## The Interactable under the crosshair, or null. Updated every tick.
var focus: Interactable
## Serums bought this run. Their multipliers are read through get_stat().
var serums: Array[SerumData] = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fallback_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _focus_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _base_max_health: float = 100.0
var _base_slots: int = 2
var _sprint_cooldown_left: float = 0.0

@onready var camera_rig: PlayerCamera = $Head
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var weapons: WeaponHolder = $Head/RecoilPivot/Camera3D/WeaponHolder
@onready var health: HealthComponent = $HealthComponent
@onready var wallet: Wallet = $Wallet
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var local_input: LocalInput = $LocalInput


func _ready() -> void:
	add_to_group(&"players")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.BARRIER
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	wallet.points_changed.connect(_on_points_changed)
	weapons.setup(self, camera)
	_base_max_health = health.max_health
	_base_slots = weapons.max_slots
	_focus_query.collision_mask = Layers.INTERACTABLE | Layers.WORLD
	_focus_query.collide_with_areas = true


func spawn(p_session: GameSession, loadout: Array[WeaponData]) -> void:
	session = p_session
	Events.player_spawned.emit(self)
	for data: WeaponData in loadout:
		weapons.give(data)
	_on_health_changed(health.current, health.max_health)
	_on_points_changed(wallet.points, 0)


func is_alive() -> bool:
	return not health.is_dead


func take_damage(info: DamageInfo) -> void:
	if Net.is_authority():
		health.take_damage(info)


## Product of every active Serum's multiplier for this stat (1.0 when none).
func get_stat(stat: StringName) -> float:
	var value: float = 1.0
	for serum: SerumData in serums:
		value *= serum.multipliers.get(stat, 1.0)
	return value


func has_serum(id: StringName) -> bool:
	for serum: SerumData in serums:
		if serum.id == id:
			return true
	return false


func add_serum(serum: SerumData) -> void:
	if serums.has(serum):
		return
	serums.append(serum)
	var new_max: float = _base_max_health * get_stat(&"max_health")
	var gained: float = new_max - health.max_health
	health.max_health = new_max
	health.heal(gained)
	weapons.max_slots = roundi(_base_slots * get_stat(&"weapon_slots"))
	Events.serum_gained.emit(self, serum)


func get_rng() -> RandomNumberGenerator:
	return session.rng if session else _fallback_rng


func look(delta_radians: Vector2) -> void:
	rotate_y(-delta_radians.x)
	camera_rig.add_pitch(-delta_radians.y)


func _physics_process(delta: float) -> void:
	local_input.enabled = input_enabled
	local_input.sensitivity_scale = lerpf(1.0, ads_sensitivity_multiplier, weapons.get_ads_progress())
	var tick: int = session.tick if session else 0
	apply_frame(local_input.sample(tick), delta)


## Runs one tick of player simulation from an InputFrame.
func apply_frame(frame: InputFrame, delta: float) -> void:
	last_frame = frame
	if input_enabled and frame.look != Vector2.ZERO:
		look(frame.look)
		weapons.add_sway(frame.look)
	_read_input(frame)
	_tick_stamina(delta)
	_update_focus()
	if input_enabled and focus and frame.has(InputFrame.INTERACT) and Net.is_authority():
		focus.interact(self)
	_move(delta, frame)
	weapons.tick(delta)
	camera_rig.update_feel(
		delta,
		is_crouching,
		is_sprinting,
		weapons.get_ads_progress(),
		weapons.get_ads_fov(camera_rig.base_fov),
		walk_speed
	)


func _update_focus() -> void:
	_focus_query.from = camera.global_position
	_focus_query.to = _focus_query.from - camera.global_basis.z * interact_range
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_focus_query)
	focus = hit.get("collider") as Interactable if not hit.is_empty() else null


func _read_input(frame: InputFrame) -> void:
	if not input_enabled:
		move_input = Vector2.ZERO
		is_sprinting = false
		is_aiming = false
		weapons.set_trigger(false)
		return
	move_input = frame.move
	is_crouching = frame.has(InputFrame.CROUCH) and is_on_floor()
	var wants_sprint: bool = frame.has(InputFrame.SPRINT) and move_input.y < -0.4 and not is_crouching
	is_aiming = frame.has(InputFrame.ADS) and not wants_sprint
	is_sprinting = wants_sprint and is_on_floor() and can_sprint()
	weapons.set_trigger(frame.has(InputFrame.FIRE))
	if frame.has(InputFrame.RELOAD):
		weapons.reload()
	if frame.has(InputFrame.NEXT_WEAPON):
		weapons.cycle(1)
	elif frame.has(InputFrame.PREV_WEAPON):
		weapons.cycle(-1)


func can_sprint() -> bool:
	return _sprint_cooldown_left <= 0.0


## Sprint drains sprint_left; running out blocks sprint for sprint_cooldown,
## then refills it. Stopping early refills it over sprint_cooldown seconds.
func _tick_stamina(delta: float) -> void:
	var full: float = sprint_time * get_stat(&"sprint_time")
	if _sprint_cooldown_left > 0.0:
		_sprint_cooldown_left -= delta
		if _sprint_cooldown_left <= 0.0:
			sprint_left = full
	elif is_sprinting:
		sprint_left -= delta
		if sprint_left <= 0.0:
			sprint_left = 0.0
			_sprint_cooldown_left = sprint_cooldown
	else:
		sprint_left = minf(sprint_left + delta * full / sprint_cooldown, full)


func _move(delta: float, frame: InputFrame) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	elif input_enabled and frame.has(InputFrame.JUMP) and not is_crouching:
		velocity.y = jump_velocity

	var speed: float = sprint_speed if is_sprinting else walk_speed
	if is_crouching:
		speed *= crouch_speed_multiplier
	speed *= lerpf(1.0, ads_speed_multiplier, weapons.get_ads_progress())
	speed *= weapons.get_move_speed_multiplier()

	var wish: Vector3 = (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized() * speed
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = air_accel
	if is_on_floor():
		rate = ground_accel if wish.length_squared() > 0.0 else ground_decel
	horizontal = horizontal.lerp(wish, clampf(rate * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	weapons.set_state(is_aiming, is_sprinting, clampf(horizontal.length() / walk_speed, 0.0, 1.5))


func _on_damaged(info: DamageInfo) -> void:
	hurt_sound.pitch_scale = randf_range(0.9, 1.1)
	hurt_sound.play()
	camera_rig.add_flinch(randf_range(1.0, 2.5))
	Events.player_damaged.emit(self, info)


func _on_health_changed(current: float, maximum: float) -> void:
	Events.player_health_changed.emit(self, current, maximum)


func _on_points_changed(total: int, delta: int) -> void:
	Events.points_changed.emit(self, total, delta)


func _on_died(_info: DamageInfo) -> void:
	input_enabled = false
	weapons.set_trigger(false)
	if has_serum(&"second_wind"):
		_go_down()
		return
	weapons.visible = false
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(camera_rig, "position:y", 0.3, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera_rig, "rotation:z", deg_to_rad(70.0), 0.8)
	Events.player_died.emit(self)


## Second Wind: stay down for second_wind_time, then get up with full health.
## Uses up Second Wind; the other Serums stay.
func _go_down() -> void:
	is_downed = true
	is_crouching = true
	create_tween().tween_property(camera_rig, "rotation:z", deg_to_rad(25.0), 0.4)
	await get_tree().create_timer(second_wind_time, false, true).timeout
	for serum: SerumData in serums:
		if serum.id == &"second_wind":
			serums.erase(serum)
			break
	is_downed = false
	is_crouching = false
	input_enabled = true
	health.reset(health.max_health)
	create_tween().tween_property(camera_rig, "rotation:z", 0.0, 0.4)
	Events.player_revived.emit(self)
