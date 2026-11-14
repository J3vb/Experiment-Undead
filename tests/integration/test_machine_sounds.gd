## Scene-owned SFX follow real purchases and actions, including after their owner vanishes.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var level: Level


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.rng_seed = 5
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	level = session.level


func _sound(owner_node: Node, child: String, wav: String) -> AudioStreamPlayer3D:
	var sound: AudioStreamPlayer3D = owner_node.get_node(child) as AudioStreamPlayer3D
	assert_eq(sound.bus, &"SFX")
	assert_eq(sound.stream, load("res://assets/audio/%s.wav" % wav))
	assert_false(sound.playing, "silent before action")
	return sound


func _purchase(machine: Interactable) -> void:
	var buy: AudioStreamPlayer3D = _sound(machine, "BuySound", "buy")
	var denied: AudioStreamPlayer3D = _sound(machine, "DeniedSound", "denied")
	player.wallet.set_points(0)
	machine.interact(player)
	assert_true(denied.playing, "cannot pay")
	assert_false(buy.playing)
	assert_eq(player.wallet.points, 0)
	denied.stop()
	player.wallet.set_points(20000)
	machine.interact(player)
	assert_true(buy.playing, "paid")
	assert_false(denied.playing)


func test_door_purchase_and_open_sounds_survive_removal() -> void:
	var door: Door = level.find_child("GuardPostDoor", true, false) as Door
	var opening: AudioStreamPlayer3D = _sound(door, "OpenSound", "door_open")
	var buy: AudioStreamPlayer3D = door.get_node("BuySound") as AudioStreamPlayer3D
	var position: Vector3 = door.global_position
	_purchase(door)
	assert_true(opening.playing)
	assert_true(door.is_queued_for_deletion())
	await wait_physics_frames(2)
	assert_true(is_instance_valid(opening), "opening sound outlives door")
	assert_true(is_instance_valid(buy), "purchase sound outlives door")
	assert_true(opening.playing)
	assert_true(buy.playing)
	assert_eq(opening.global_position, position)
	assert_eq(buy.global_position, position)
	opening.finished.emit()
	buy.finished.emit()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(opening), "sound frees itself when finished")
	assert_false(is_instance_valid(buy))


func test_wall_buy_gun_sounds() -> void:
	for machine_name: String in ["WallBuyBrennerTrench", "WallBuyKestrel", "WallBuyTalon"]:
		_purchase(level.find_child(machine_name, true, false) as WallBuy)


func test_wall_buy_ammo_sounds() -> void:
	var machine: WallBuy = level.find_child("WallBuyRifle", true, false) as WallBuy
	player.weapons.weapons[1].instance.ammo_reserve = 0
	_purchase(machine)


func test_med_dispenser_sounds() -> void:
	level.turn_power_on()
	var machine: MedDispenser = get_tree().get_first_node_in_group(&"med_dispenser") as MedDispenser
	_purchase(machine)


func test_last_dispenser_sale_keeps_chime_alive() -> void:
	level.turn_power_on()
	var machine: MedDispenser = get_tree().get_first_node_in_group(&"med_dispenser") as MedDispenser
	machine.max_sales = 1
	var buy: AudioStreamPlayer3D = _sound(machine, "BuySound", "buy")
	var position: Vector3 = machine.global_position
	player.wallet.set_points(20000)
	machine.interact(player)
	assert_true(machine.is_queued_for_deletion())
	await wait_physics_frames(2)
	assert_true(is_instance_valid(buy))
	assert_true(buy.playing)
	assert_eq(buy.global_position, position)
	buy.finished.emit()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(buy))


func test_reforger_upgrade_sounds() -> void:
	level.turn_power_on()
	_purchase(get_tree().get_first_node_in_group(&"reforger") as Reforger)


func test_reforger_refill_sounds() -> void:
	level.turn_power_on()
	player.weapons.replace_current(player.weapons.current.data.upgraded)
	player.weapons.current.instance.ammo_reserve = 0
	_purchase(get_tree().get_first_node_in_group(&"reforger") as Reforger)


func test_specimen_vault_sounds() -> void:
	level.turn_power_on()
	_purchase(get_tree().get_first_node_in_group(&"specimen_vault") as SpecimenVault)


func test_power_switch_and_free_doors_sound_once() -> void:
	var machine: PowerSwitch = level.find_child("PowerSwitch", true, false) as PowerSwitch
	var power: AudioStreamPlayer3D = _sound(machine, "PowerSound", "power_on")
	var door: Door = level.find_child("TunnelWestShutter", true, false) as Door
	var opening: AudioStreamPlayer3D = _sound(door, "OpenSound", "door_open")
	machine.interact(player)
	assert_true(power.playing)
	assert_true(opening.playing)
	assert_true(level.power_on)
	power.stop()
	opening.stop()
	machine.interact(player)
	door.open()
	assert_false(power.playing, "already powered")
	assert_false(opening.playing, "already open")


func test_barrier_tear_and_repair_sounds() -> void:
	var barrier: Barrier = get_tree().get_first_node_in_group(&"barriers") as Barrier
	var tear: AudioStreamPlayer3D = _sound(barrier, "TearSound", "plank_tear")
	var repair: AudioStreamPlayer3D = _sound(barrier, "RepairSound", "plank_repair")
	barrier.interact(player)
	assert_false(repair.playing, "full barrier")
	barrier.tear_plank()
	assert_true(tear.playing)
	assert_false(repair.playing)
	barrier.interact(player)
	assert_true(repair.playing)
	repair.stop()
	barrier.interact(player)
	assert_false(repair.playing, "repair on cooldown")
	for i: int in Barrier.PLANKS:
		barrier.tear_plank()
	tear.stop()
	barrier.tear_plank()
	assert_false(tear.playing, "no plank left")


func test_power_up_chime_outlives_pickup() -> void:
	var pickup: PowerUp = session.power_up_drops.drop(
		Content.get_item(&"power_ups", &"resupply") as PowerUpData, Vector3(40, 0, 40)
	)
	var sound: AudioStreamPlayer = pickup.get_node("CollectSound") as AudioStreamPlayer
	assert_eq(sound.bus, &"SFX")
	assert_eq(sound.stream, load("res://assets/audio/power_up.wav"))
	assert_false(sound.playing)
	pickup.collect(player)
	assert_true(sound.playing)
	pickup.collect(player)
	assert_true(pickup.is_queued_for_deletion())
	await wait_physics_frames(2)
	assert_true(is_instance_valid(sound))
	sound.finished.emit()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(sound))


func test_hud_round_end_sound() -> void:
	var sound: AudioStreamPlayer = session.get_node("Hud/RoundEndSound") as AudioStreamPlayer
	assert_eq(sound.bus, &"SFX")
	assert_eq(sound.stream, load("res://assets/audio/round_end.wav"))
	assert_false(sound.playing)
	Events.round_ended.emit(1)
	assert_true(sound.playing)
