## Owns a player's weapon slots, the active weapon and viewmodel sway/bob.
## Re-emits the active weapon's local signals as global facts.
class_name WeaponHolder
extends Node3D

const WEAPON_SCENE: PackedScene = preload("res://systems/weapons/weapon.tscn")

@export var max_slots: int = 2
## Sway per radian of look movement.
@export var sway_amount: float = 0.27
@export var sway_max: float = 0.06
@export var sway_smoothing: float = 10.0

var weapons: Array[Weapon] = []
var current: Weapon
var _player: Player
var _camera: Camera3D
var _sway: Vector2 = Vector2.ZERO
var _move_factor: float = 0.0
var _bob_time: float = 0.0

func setup(player: Player, camera: Camera3D) -> void:
	_player = player
	_camera = camera

func give(data: WeaponData) -> Weapon:
	var weapon: Weapon = WEAPON_SCENE.instantiate()
	weapon.setup(WeaponInstance.new(data), _player, _camera)
	add_child(weapon)
	weapon.set_active(false)
	weapon.ammo_changed.connect(_on_ammo_changed.bind(weapon))
	weapon.fired.connect(_on_fired.bind(weapon))
	weapon.reload_started.connect(_on_reload_started.bind(weapon))
	weapon.hit_landed.connect(_on_hit_landed)
	if weapons.size() >= max_slots and current:
		var index: int = weapons.find(current)
		weapons[index] = weapon
		current.queue_free()
		current = null
	else:
		weapons.append(weapon)
	equip(weapons.find(weapon))
	return weapon

func equip(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if current:
		current.set_active(false)
	current = weapons[index]
	current.set_active(true)
	Events.weapon_switched.emit(_player, current)

func cycle(direction: int) -> void:
	if weapons.size() > 1 and current:
		equip(posmod(weapons.find(current) + direction, weapons.size()))

func set_trigger(held: bool) -> void:
	if current:
		current.trigger_held = held

func reload() -> void:
	if current:
		current.start_reload()

func set_state(aiming: bool, sprinting: bool, move_factor: float) -> void:
	_move_factor = move_factor
	if current:
		current.aiming = aiming
		current.sprinting = sprinting
		current.move_factor = move_factor

func add_sway(look_delta: Vector2) -> void:
	var scale_factor: float = lerpf(1.0, 0.25, get_ads_progress())
	_sway = (_sway + look_delta * sway_amount * scale_factor).limit_length(sway_max)

## Simulation step for the active weapon. Called from the player's physics tick.
func tick(delta: float) -> void:
	if current:
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
	position = Vector3(cos(_bob_time * 0.5) * bob, -absf(sin(_bob_time)) * bob, 0.0)

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
