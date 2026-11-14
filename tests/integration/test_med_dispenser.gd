## Med Dispensers on Halcyon Labs: they need power, sell their Serum once,
## and each Serum changes the stat it names in a real match.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var level: Level


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.rng_seed = 7
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	level = session.level
	player.wallet.set_points(20000)


func _dispenser(serum_id: String) -> MedDispenser:
	for node: Node in get_tree().get_nodes_in_group(&"med_dispenser"):
		var machine: MedDispenser = node as MedDispenser
		if machine and String(machine.serum.id) == serum_id:
			return machine
	return null


func test_dispensers_need_power() -> void:
	var machine: MedDispenser = _dispenser("quickhands")
	assert_eq(machine.get_prompt(player), "Needs power")
	machine.interact(player)
	assert_eq(player.serums.size(), 0)
	assert_eq(player.wallet.points, 20000)
	assert_false(machine.get_node("Glow").visible, "dark before power")
	level.turn_power_on()
	assert_true(machine.get_node("Glow").visible, "lights up with power")
	assert_string_contains(machine.get_prompt(player), "2000")


func test_serum_sells_once() -> void:
	level.turn_power_on()
	var machine: MedDispenser = _dispenser("quickhands")
	machine.interact(player)
	machine.interact(player)
	assert_eq(player.serums.size(), 1)
	assert_eq(player.wallet.points, 18000, "paid once")
	assert_eq(machine.get_prompt(player), "", "nothing to buy any more")


func test_ironhide_raises_and_fills_max_health() -> void:
	level.turn_power_on()
	player.health.take_damage(DamageInfo.create(40.0, null))
	_dispenser("ironhide").interact(player)
	assert_eq(player.health.max_health, 250.0)
	assert_eq(player.health.current, 210.0, "gains the extra 150 on top of current health")


func test_quickhands_shortens_reload() -> void:
	level.turn_power_on()
	_dispenser("quickhands").interact(player)
	var weapon: Weapon = player.weapons.current
	weapon.instance.ammo_in_mag = 1
	var events: Array[float] = []
	weapon.reload_started.connect(func(duration: float) -> void: events.append(duration))
	weapon.start_reload()
	assert_almost_eq(events[0], weapon.data.reload_time * 0.6, 0.001)


func test_mule_gives_a_third_slot() -> void:
	level.turn_power_on()
	var before: int = player.weapons.weapons.size()
	_dispenser("mule").interact(player)
	assert_eq(player.weapons.max_slots, 3)
	player.weapons.give(player.weapons.current.data.duplicate() as WeaponData)
	assert_eq(player.weapons.weapons.size(), before + 1, "new gun added, nothing replaced")


func test_every_real_dispenser_sells_a_different_serum() -> void:
	var seen: Array[StringName] = []
	for node: Node in get_tree().get_nodes_in_group(&"med_dispenser"):
		var machine: MedDispenser = node as MedDispenser
		if machine:
			assert_does_not_have(seen, machine.serum.id)
			seen.append(machine.serum.id)
	assert_eq(seen.size(), 5, "Ironhide, Quickhands, Overclock, Deadeye, Mule")
