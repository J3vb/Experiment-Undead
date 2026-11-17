## Owns a player's weapon slots, the active weapon and viewmodel sway/bob.
## Re-emits the active weapon's local signals as global facts.
class_name WeaponHolder
extends Node3D

const WEAPON_SCENE: PackedScene = preload("res://systems/weapons/weapon.tscn")
## Seconds from switching guns until the new one can fire or aim (game-design.md).
const SWAP_TIME: float = 0.4
## How far the gun dips while it is being raised.
const SWAP_DIP: float = 0.25

@export var max_slots: int = 2
## Sway per radian of look movement.
@export var sway_amount: float = 0.27
@export var sway_max: float = 0.06
@export var sway_smoothing: float = 10.0

var weapons: Array[Weapon] = []
var current: Weapon
var arm_view: PlayerArmView
var melee: Melee = Melee.new()
var _player: Player
var _camera: Camera3D
var _sway: Vector2 = Vector2.ZERO
var _move_factor: float = 0.0
var _bob_time: float = 0.0
var _swap_left: float = 0.0
var _swap_time: float = SWAP_TIME


func setup(player: Player, camera: Camera3D) -> void:
	_player = player
	_camera = camera
	melee.shooter = player
	melee.camera = camera
	if not melee.hit_landed.is_connected(_on_hit_landed):
		melee.hit_landed.connect(_on_hit_landed)


## Adds a gun. When every slot is full it replaces the gun in hand.
func give(data: WeaponData) -> Weapon:
	if weapons.size() >= max_slots and current:
		return replace_current(data)
	var weapon: Weapon = WEAPON_SCENE.instantiate()
	weapon.setup(WeaponInstance.new(data), _player, _camera)
	add_child(weapon)
	weapon.set_active(false)
	weapon.ammo_changed.connect(_on_ammo_changed.bind(weapon))
	weapon.fired.connect(_on_fired.bind(weapon))
	weapon.reload_started.connect(_on_reload_started.bind(weapon))
	weapon.hit_landed.connect(_on_hit_landed)
	weapons.append(weapon)
	Events.weapon_acquired.emit(_player, data.id)
	equip(weapons.find(weapon))
	return weapon


## Swaps the gun in hand for a new one in the same slot (full ammo).
func replace_current(data: WeaponData) -> Weapon:
	return replace(current, data)


## Swaps old for a new gun in old's slot (full ammo). Stays in hand only if old was.
func replace(old: Weapon, data: WeaponData) -> Weapon:
	var was_current: bool = old == current
	var weapon: Weapon = WEAPON_SCENE.instantiate()
	weapon.setup(WeaponInstance.new(data), _player, _camera)
	add_child(weapon)
	weapon.set_active(false)
	weapon.ammo_changed.connect(_on_ammo_changed.bind(weapon))
	weapon.fired.connect(_on_fired.bind(weapon))
	weapon.reload_started.connect(_on_reload_started.bind(weapon))
	weapon.hit_landed.connect(_on_hit_landed)
	weapons[weapons.find(old)] = weapon
	old.queue_free()
	Events.weapon_acquired.emit(_player, data.id)
	if was_current:
		current = null
		equip(weapons.find(weapon))
	return weapon


func equip(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if current == weapons[index]:
		return
	if current:
		current.set_active(false)
		current.trigger_held = false
		current.aiming = false
		current.ads_progress = 0.0
		_swap_time = SWAP_TIME * (_player.get_stat(&"swap_time") if _player else 1.0)
		_swap_left = _swap_time
	current = weapons[index]
	current.set_active(true)
	if not Build.is_server() and (_player == null or _player.is_multiplayer_authority()):
		_bind_arm_view()
	Events.weapon_switched.emit(_player, current)


func _bind_arm_view() -> void:
	if current.data.viewmodel_scene == null:
		if arm_view != null:
			arm_view.bind_weapon(null)
		return
	if arm_view == null:
		arm_view = PlayerArmView.new()
		arm_view.name = "PlayerArmView"
		add_child(arm_view)
	arm_view.bind_weapon(current)


## Mouse wheel, the 1/2/3 slot keys and the knife from one InputFrame.
func handle_presses(frame: InputFrame) -> void:
	if frame.has(InputFrame.MELEE):
		swing()
	if frame.has(InputFrame.NEXT_WEAPON):
		cycle(1)
	elif frame.has(InputFrame.PREV_WEAPON):
		cycle(-1)
	for slot: int in InputFrame.SLOTS.size():
		if frame.has(InputFrame.SLOTS[slot]):
			equip(slot)


func cycle(direction: int) -> void:
	if weapons.size() > 1 and current:
		equip(posmod(weapons.find(current) + direction, weapons.size()))


## Knife swing: cancels a reload and keeps the gun down (no firing) for the swing.
func swing() -> void:
	if is_swapping():
		return
	if current:
		RoundReload.cancel(current)
		current.trigger_held = false
	_swap_time = Melee.swing_time()
	_swap_left = _swap_time
	melee.swing()


## True while a freshly switched gun is still being raised.
func is_swapping() -> bool:
	return _swap_left > 0.0


func set_trigger(held: bool) -> void:
	if current:
		current.trigger_held = held and not is_swapping()


func reload() -> void:
	if current:
		current.start_reload()


func set_state(aiming: bool, sprinting: bool, move_factor: float) -> void:
	_move_factor = move_factor
	if current:
		current.aiming = aiming and not is_swapping()
		current.sprinting = sprinting
		if sprinting and current.is_reloading():
			RoundReload.cancel(current)
		current.move_factor = move_factor


func add_sway(look_delta: Vector2) -> void:
	var scale_factor: float = lerpf(1.0, 0.25, get_ads_progress())
	_sway = (_sway + look_delta * sway_amount * scale_factor).limit_length(sway_max)


## Simulation step for the active weapon. Called from the player's physics tick.
## The gun in hand does not tick while it is raised, so no fire path (alt
## fire, buffered shots, a burst) can shoot before the swap ends.
func tick(delta: float) -> void:
	_swap_left = maxf(_swap_left - delta, 0.0)
	if current and not is_swapping():
		current.tick(delta)


func get_ads_progress() -> float:
	return current.ads_progress if current else 0.0


func get_ads_fov(fallback: float) -> float:
	return current.data.ads_fov if current else fallback


func get_move_speed_multiplier() -> float:
	return current.data.move_speed_multiplier if current else 1.0


func _process(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, clampf(sway_smoothing * delta * 0.5, 0.0, 1.0))
	var target_rot: Vector3 = Vector3(-_sway.y, -_sway.x, -_sway.x * 0.5)
	rotation = rotation.lerp(target_rot, clampf(sway_smoothing * delta, 0.0, 1.0))
	_bob_time += delta * (6.0 + 4.0 * _move_factor)
	var bob: float = 0.012 * _move_factor * (1.0 - get_ads_progress() * 0.9)
	var dip: float = SWAP_DIP * _swap_left / maxf(_swap_time, 0.001)
	position = Vector3(cos(_bob_time * 0.5) * bob, -absf(sin(_bob_time)) * bob - dip, 0.0)


func _on_ammo_changed(in_mag: int, reserve: int, weapon: Weapon) -> void:
	if weapon == current:
		Events.ammo_changed.emit(_player, in_mag, reserve)


func _on_fired(weapon: Weapon) -> void:
	Events.weapon_fired.emit(_player, weapon)


func _on_reload_started(duration: float, weapon: Weapon) -> void:
	if weapon == current:
		Events.reload_started.emit(_player, duration)


func _on_hit_landed(is_kill: bool, is_headshot: bool) -> void:
	Events.hit_confirmed.emit(_player, is_kill, is_headshot)
