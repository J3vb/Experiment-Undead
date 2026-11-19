## An empty gun clicks once per trigger pull, never once per tick while held.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")
const TICK: float = 1.0 / 60.0

var player: Player
var weapon: Weapon


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.position = Vector3(100, 100, 100)


func _empty_gun(mode: WeaponData.FireMode) -> void:
	var data: WeaponData = WeaponData.new()
	data.id = &"test_dry"
	data.fire_mode = mode
	data.magazine_size = 10
	data.starting_reserve = 0
	weapon = WEAPON.instantiate() as Weapon
	weapon.setup(WeaponInstance.new(data), player, player.camera)
	player.camera.add_child(weapon)
	weapon.set_active(true)
	weapon.instance.ammo_in_mag = 0
	weapon.instance.ammo_reserve = 0
	watch_signals(weapon)


func _hold(ticks: int) -> void:
	weapon.trigger_held = true
	for i: int in ticks:
		weapon.tick(TICK)


func _release() -> void:
	weapon.trigger_held = false
	weapon.tick(TICK)


func test_holding_an_empty_auto_gun_clicks_once() -> void:
	_empty_gun(WeaponData.FireMode.AUTO)
	_hold(120)
	assert_signal_emit_count(weapon, "dry_fired", 1, "two seconds of held trigger = one click")
	assert_signal_emit_count(weapon, "fired", 0)


func test_each_new_pull_clicks_again() -> void:
	_empty_gun(WeaponData.FireMode.AUTO)
	for pull: int in 3:
		_hold(10)
		_release()
	assert_signal_emit_count(weapon, "dry_fired", 3, "one click per pull")


func test_semi_and_burst_click_once_per_pull() -> void:
	for mode: WeaponData.FireMode in [WeaponData.FireMode.SEMI, WeaponData.FireMode.BURST]:
		_empty_gun(mode)
		_hold(60)
		assert_signal_emit_count(weapon, "dry_fired", 1, "mode %d clicks once while held" % mode)
		weapon.queue_free()
