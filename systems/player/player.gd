## First-person player body and controller. Consumes one InputFrame per
## physics tick (from LocalInput now, from the network later), moves, and
## drives its components (camera rig, weapons, health, wallet).
## Everything per-player lives here, never in a global.
class_name Player
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 6.8
@export var crouch_speed_multiplier: float = 0.49
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

## Set by GameSession when spawned. Gives access to the session RNG and tick.
var session: GameSession
var net_id: int = 0
## Character name from the co-op hello; empty in solo.
var display_name: String = ""

var input_enabled: bool = true
var is_sprinting: bool = false
var is_aiming: bool = false
var is_crouching: bool = false
## Down but not out: solo Second Wind or a co-op teammate can revive us.
var is_downed: bool = false
var is_dead: bool = false
var state_sync: PlayerStateSync
var loadout_sync: LoadoutSync
var revive: Revive
var move_input: Vector2 = Vector2.ZERO
var sprint_left: float = 4.0
var last_frame: InputFrame = InputFrame.new()
## The Interactable under the crosshair, or null. Updated every tick.
var focus: Interactable
## Serums bought this run. Their multipliers are read through get_stat().
var serums: Array[SerumData] = []
var stats: StatBlock = StatBlock.new()
## Skill ranks: the owner's save, and the server's copy from LoadoutSync. Folded into stats by equip_gear.
var skill_ranks: Dictionary[StringName, int] = {}
var skill_rules: Dictionary[int, bool] = {}
var moves: PlayerMoves = PlayerMoves.new()
var interaction: PlayerInteract = PlayerInteract.new()
## Equipped item guns by uid. The server fills its copy from the owner's loadout.
var item_guns: Dictionary[String, ItemInstance] = {}

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fallback_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _base_max_health: float = 100.0
var _base_regen_delay: float = 0.0
var _base_slots: int = 2
var _sprint_cooldown_left: float = 0.0
var _teleport_to: Transform3D
var _teleport_pending: bool = false

@onready var camera_rig: PlayerCamera = $Head
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var weapons: WeaponHolder = $Head/RecoilPivot/Camera3D/WeaponHolder
@onready var health: HealthComponent = $HealthComponent
@onready var wallet: Wallet = $Wallet
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var local_input: LocalInput = $LocalInput
@onready var body: Node3D = $Body
@onready var gear_rig: GearRig = $Body/GearRig


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
	_base_regen_delay = health.regen_delay
	_base_slots = weapons.max_slots
	_set_local(is_multiplayer_authority())
	state_sync = PlayerStateSync.new()
	add_child(state_sync)
	loadout_sync = LoadoutSync.new()
	add_child(loadout_sync)
	revive = Revive.new()
	add_child(revive)


## The owning peer sees through this player's camera and drives it; everyone
## else sees the equipped body moved by the synchronizer.
func _set_local(local: bool) -> void:
	camera.current = local
	if not local:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	weapons.visible = local
	local_input.enabled = local
	gear_rig.set_owner_view(local)
	set_physics_process(local)


func spawn(p_session: GameSession, loadout: Array[WeaponData]) -> void:
	session = p_session
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not session.profile_id.is_empty():
		var profile: CharacterProfile = CharacterProfile.load_or_create(session.profile_id)
		var equipped: Variant = profile.to_dict().get("loadout", {})
		gear_rig.apply(LookBuilder.from_equipped(equipped if equipped is Dictionary else {}))
	Events.player_spawned.emit(self)
	for data: WeaponData in loadout:
		weapons.give(data)
	_on_health_changed(health.current, health.max_health)
	_on_points_changed(wallet.points, 0)


func is_alive() -> bool:
	return not health.is_dead


func take_damage(info: DamageInfo) -> void:
	if multiplayer.is_server() and is_alive() and not (session and session.is_over):
		health.take_damage(info)


## Gear modifiers and the product of active Serum multipliers.
func get_stat(stat: StringName, base: float = 1.0, other: StatBlock = null) -> float:
	var value: float = 1.0
	for serum: SerumData in serums:
		value *= serum.multipliers.get(stat, 1.0)
	return ItemInstance.stat_value(stats, stat, base, other, value)


## Rebuilds stats from scratch: gear, then skill ranks. A respec is new ranks and a call here.
func equip_gear(items: Array[Dictionary], heal: bool = true) -> void:
	stats = StatBlock.new()
	for equipped: Dictionary in items:
		var item: ItemInstance = ItemInstance.new(equipped)
		for modifier: Modifier in item.stats.modifiers:
			stats.add_modifier(modifier.stat, modifier.op, modifier.value, modifier.source)
	SkillEffects.add_to(stats, skill_ranks)
	skill_rules = SkillEffects.rules_for(skill_ranks)
	_refresh_stats(heal)


func has_serum(id: StringName) -> bool:
	for serum: SerumData in serums:
		if serum.id == id:
			return true
	return false


## Down with Second Wind still waiting to get them up: the squad is not out yet.
func can_self_revive() -> bool:
	return is_downed and not is_dead and has_serum(&"second_wind")


func add_serum(serum: SerumData) -> void:
	if not multiplayer.is_server() or serums.has(serum):
		return
	serums.append(serum)
	_refresh_stats()
	Events.serum_gained.emit(self, serum)


## Server: going down costs every Serum; a Second Wind self-revive costs only Second Wind.
func lose_serums(only_second_wind: bool = false) -> void:
	for index: int in range(serums.size() - 1, -1, -1):
		if multiplayer.is_server() and (not only_second_wind or serums[index].id == &"second_wind"):
			serums.remove_at(index)
	_refresh_stats()


func _refresh_stats(heal: bool = true) -> void:
	if multiplayer.is_server():
		var new_max: float = get_stat(&"max_health", _base_max_health)
		var gained: float = new_max - health.max_health
		health.max_health = new_max
		health.current = minf(health.current, new_max)
		health.heal(gained if heal else 0.0)
		health.regen_delay = maxf(
			get_stat(&"regen_delay", _base_regen_delay), 0.001 if _base_regen_delay > 0.0 else 0.0
		)
		_on_health_changed(health.current, health.max_health)
	weapons.max_slots = roundi(_base_slots * get_stat(&"weapon_slots"))


func get_rng() -> RandomNumberGenerator:
	return session.rng if session else _fallback_rng


## RPC moves land outside the physics tick; the owner waits for its next tick (interpolated camera).
func teleport(to: Transform3D) -> void:
	_teleport_to = to
	_teleport_pending = is_physics_processing() and not Engine.is_in_physics_frame()
	if not _teleport_pending:
		global_transform = to
		velocity = Vector3.ZERO
		reset_physics_interpolation()


func look(delta_radians: Vector2) -> void:
	rotate_y(-delta_radians.x)
	camera_rig.add_pitch(-delta_radians.y)


func _physics_process(delta: float) -> void:
	if _teleport_pending:
		teleport(_teleport_to)
	local_input.enabled = input_enabled
	local_input.sensitivity_scale = lerpf(1.0, local_input.ads_multiplier, weapons.get_ads_progress())
	var tick: int = session.tick if session else 0
	apply_frame(local_input.sample(tick), delta)


## Runs one tick of player simulation from an InputFrame.
func apply_frame(frame: InputFrame, delta: float) -> void:
	if is_dead and state_sync.is_coop():
		return
	last_frame = frame
	if input_enabled and frame.look != Vector2.ZERO:
		look(frame.look)
		weapons.add_sway(frame.look)
	_read_input(frame)
	_tick_stamina(delta)
	interaction.update(self, frame, delta)
	_move(delta, frame)
	weapons.tick(delta)
	var fov: float = weapons.get_ads_fov(camera_rig.base_fov)
	camera_rig.update_feel(delta, is_crouching, is_sprinting, weapons.get_ads_progress(), fov, walk_speed)


func _read_input(frame: InputFrame) -> void:
	if not input_enabled:
		move_input = Vector2.ZERO
		is_sprinting = false
		is_aiming = false
		weapons.set_trigger(false)
		return
	move_input = frame.move
	var sliding: bool = moves.update_slide(self, frame)
	is_crouching = is_downed or sliding or (frame.has(InputFrame.CROUCH) and is_on_floor())
	var wants_sprint: bool = frame.has(InputFrame.SPRINT) and move_input.y < -0.4 and not is_crouching
	is_aiming = frame.has(InputFrame.ADS) and not wants_sprint
	is_sprinting = wants_sprint and is_on_floor() and can_sprint()
	weapons.set_trigger(frame.has(InputFrame.FIRE))
	if frame.has(InputFrame.RELOAD):
		weapons.reload()
	if is_downed:
		return
	weapons.handle_presses(frame)


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
	var jump: bool = input_enabled and frame.has(InputFrame.JUMP) and not is_crouching
	velocity.y = moves.vertical(self, delta, jump, _gravity * gravity_multiplier)
	var speed: float = sprint_speed if is_sprinting else walk_speed
	if is_crouching:
		speed *= 0.2 if is_downed else crouch_speed_multiplier
	speed *= lerpf(1.0, ads_speed_multiplier, weapons.get_ads_progress())
	speed *= weapons.get_move_speed_multiplier()
	speed *= get_stat(&"move_speed")

	var wish: Vector3 = (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized() * speed
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = air_accel
	if is_on_floor():
		rate = ground_accel if wish.length_squared() > 0.0 else ground_decel
	horizontal = horizontal.lerp(wish, clampf(rate * delta, 0.0, 1.0))
	if moves.is_sliding():
		horizontal = moves.slide_step(delta, speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	weapons.set_state(is_aiming, is_sprinting, clampf(horizontal.length() / walk_speed, 0.0, 1.5))


func _on_damaged(info: DamageInfo) -> void:
	hurt_sound.pitch_scale = randf_range(0.9, 1.1)  # cosmetic
	hurt_sound.play()
	var rng: RandomNumberGenerator = get_rng()
	camera_rig.add_flinch(rng.randf_range(1.0, 2.5), rng.randf_range(-1.0, 1.0))
	Events.player_damaged.emit(self, info)


func _on_health_changed(current: float, maximum: float) -> void:
	Events.player_health_changed.emit(self, current, maximum)
	if state_sync:
		state_sync.queue_publish()


func _on_points_changed(total: int, delta: int) -> void:
	Events.points_changed.emit(self, total, delta)


func _on_died(_info: DamageInfo) -> void:
	if not multiplayer.is_server():
		return
	var second_wind: bool = has_serum(&"second_wind")
	if state_sync.is_coop():
		state_sync.down_player(second_wind)
		return
	input_enabled = false
	weapons.set_trigger(false)
	if second_wind:
		revive.second_wind()
		return
	is_dead = true
	weapons.visible = false
	camera_rig.tilt_down(true)
	Events.player_died.emit(self)
