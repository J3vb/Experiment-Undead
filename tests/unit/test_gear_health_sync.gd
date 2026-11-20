## Gear refreshes preserve server-owned health and publish maximum-health reductions;
## owners send their loadout and the server applies it.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HEALTH_AFFIX: String = "res://tests/fixtures/loot/test_max_health.tres"

var server: Player
var client: Player
var _port: int
var _roots: Array[Node] = []
var _loot_before: Dictionary


func before_each() -> void:
	_port = TwoPeers.next_port()
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = HEALTH_AFFIX
	for index: int in 2:
		var root: Node = TwoPeers.make_side(self, "Server" if index == 0 else "Client")
		var error: Error = TwoPeers.host(root, _port, 1) if index == 0 else TwoPeers.join(root, _port)
		assert_eq(error, OK)
		_roots.append(root)
	await wait_until(func() -> bool: return _roots[0].multiplayer.get_peers().size() == 1, 3.0, "peers connected")
	var owner_id: int = _roots[1].multiplayer.get_unique_id()
	for root: Node in _roots:
		var player: Player = PLAYER.instantiate() as Player
		player.name = "Player"
		player.net_id = owner_id
		player.set_multiplayer_authority(owner_id)
		root.add_child(player)
		player.set_physics_process(false)
		player.health.regen_delay = 0.0
	server = _roots[0].get_node("Player") as Player
	client = _roots[1].get_node("Player") as Player
	await wait_physics_frames(3)


func after_each() -> void:
	_roots.reverse()
	for root: Node in _roots:
		TwoPeers.close_side(root)
	_roots.clear()
	Content._by_type[&"loot"] = _loot_before


func _vest() -> Dictionary:
	return {
		"v": 1,
		"uid": "health_vest",
		"base": "vest_medium",
		"rar": "rare",
		"ilvl": 30,
		"aff": [["test_max_health", 1, 1.0]],
	}


func test_client_equipping_health_gear_does_not_mutate_its_health() -> void:
	assert_true(client.is_multiplayer_authority())
	client.equip_gear([_vest()])
	assert_eq(client.health.max_health, 100.0, "the owner cannot increase maximum health locally")
	assert_eq(client.health.current, 100.0, "the owner cannot heal itself through gear")
	await wait_physics_frames(3)
	assert_eq(server.health.max_health, 100.0)
	assert_eq(server.health.current, 100.0)


func test_server_equipping_health_gear_updates_the_owning_clients_health() -> void:
	server.equip_gear([_vest()])
	assert_eq(server.health.max_health, 140.0)
	assert_eq(server.health.current, 140.0)
	await wait_until(func() -> bool: return client.health.max_health == 140.0, 3.0, "gear health reached owner")
	assert_eq(client.health.current, 140.0)


func test_server_removing_health_gear_publishes_the_clamped_health() -> void:
	server.equip_gear([_vest()])
	await wait_until(func() -> bool: return client.health.current == 140.0, 3.0, "gear health reached owner")
	watch_signals(server.health)
	server.equip_gear([])
	assert_eq(server.health.max_health, 100.0)
	assert_eq(server.health.current, 100.0)
	assert_signal_not_emitted(server.health, "health_changed", "a negative heal does not emit HealthComponent's signal")
	await wait_until(func() -> bool: return client.health.max_health == 100.0, 3.0, "gear removal reached owner")
	assert_eq(client.health.current, 100.0, "the owner sees the server's clamped pool")


func _gun(base: String = "pistol_service") -> Dictionary:
	return {"v": 1, "uid": "gun_" + base, "base": base, "rar": "rare", "ilvl": 30, "aff": []}


func test_protocol_was_bumped_for_the_loadout_rpc() -> void:
	assert_gte(Build.PROTOCOL_VERSION, 6, "later protocol bumps keep this one")


func test_loadout_sync_is_a_server_owned_child_on_both_sides() -> void:
	assert_gte(Build.PROTOCOL_VERSION, 19, "loadout RPC moved to its own node")
	for player: Player in [server, client]:
		var node: LoadoutSync = player.get_node("LoadoutSync") as LoadoutSync
		assert_eq(node, player.loadout_sync)
		assert_eq(node.get_multiplayer_authority(), 1, "the server owns the loadout node")
	assert_false(server.state_sync.has_method("submit_loadout"), "PlayerStateSync no longer takes loadouts")


func test_client_loadout_raises_server_health_and_records_item_guns() -> void:
	var weapon: Weapon = client.weapons.give(Content.weapon(&"pistol_service"))
	weapon.item = ItemInstance.new(_gun())
	client.loadout_sync.gear = [_vest()]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 140.0, 3.0, "loadout reached server")
	assert_eq(server.health.current, 140.0)
	assert_eq(server.item_guns.keys(), ["gun_pistol_service"])
	assert_eq(server.item_guns["gun_pistol_service"].data.get("base"), "pistol_service")
	await wait_until(func() -> bool: return client.health.max_health == 140.0, 3.0, "snapshot reached owner")
	assert_eq(client.health.current, 140.0)


func test_client_damage_reduction_gear_shrinks_hits_on_the_server_copy() -> void:
	var vest: Dictionary = {"v": 1, "uid": "dr_vest", "base": "vest_medium", "aff": [["damage_reduction", 5, 1.0]]}
	client.loadout_sync.gear = [vest]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.get_stat(&"damage_reduction") > 1.0, 3.0, "loadout reached server")
	server.take_damage(DamageInfo.create(50.0, null))
	assert_almost_eq(server.health.current, 55.0, 0.0001)
	await wait_until(func() -> bool: return is_equal_approx(client.health.current, 55.0), 3.0, "owner sees 55")


func test_new_loadout_without_the_vest_drops_max_health() -> void:
	client.loadout_sync.gear = [_vest()]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return client.health.max_health == 140.0, 3.0, "vest applied")
	client.loadout_sync.gear = []
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 100.0, 3.0, "vest removed on server")
	await wait_until(func() -> bool: return client.health.max_health == 100.0, 3.0, "owner sees removal")
	assert_eq(client.health.current, 100.0)


func test_malformed_loadouts_are_rejected_logged_and_change_nothing() -> void:
	var before: int = Log.event_counts.get("net.loadout_rejected", 0)
	client.loadout_sync.submit_loadout.rpc_id(1, ["vest"], [], {})
	client.loadout_sync.submit_loadout.rpc_id(1, _all_seven() + [_piece("vest_light", [])], [], {})
	client.loadout_sync.submit_loadout.rpc_id(1, [_vest()], [_gun("not_a_gun")], {})
	await wait_until(
		func() -> bool: return Log.event_counts.get("net.loadout_rejected", 0) == before + 3, 3.0, "all rejected"
	)
	assert_eq(server.health.max_health, 100.0)
	assert_true(server.item_guns.is_empty())


func test_loadout_handler_on_a_client_returns_before_anything_else() -> void:
	var before: int = Log.event_counts.get("net.loadout_rejected", 0)
	client.loadout_sync.submit_loadout([_vest()], [_gun()], {})
	await wait_physics_frames(3)
	assert_eq(client.health.max_health, 100.0, "only the server applies a loadout")
	assert_true(client.item_guns.is_empty())
	assert_eq(Log.event_counts.get("net.loadout_rejected", 0), before, "a client never logs a refusal")


func test_host_loadout_applies_once_on_its_own_player() -> void:
	var host: Player = PLAYER.instantiate() as Player
	add_child_autofree(host)
	host.set_physics_process(false)
	host.loadout_sync.gear = [_vest()]
	host.equip_gear([_vest()])
	host.loadout_sync.send_loadout()
	host.loadout_sync.send_loadout()
	assert_eq(host.health.max_health, 140.0, "the host's gear is not stacked twice")
	assert_eq(host.health.current, 140.0)


func test_later_loadouts_only_cap_health_so_a_vest_swap_never_heals() -> void:
	client.loadout_sync.gear = [_vest()]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.current == 140.0, 3.0, "first loadout heals to full")
	client.loadout_sync.gear = []
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 100.0, 3.0, "vest off")
	client.loadout_sync.gear = [_vest()]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 140.0, 3.0, "vest back on")
	assert_eq(server.health.current, 100.0, "the swap back did not heal")


func _piece(base: String, affixes: Array) -> Dictionary:
	return {"v": 1, "uid": "piece_" + base, "base": base, "rar": "rare", "ilvl": 30, "aff": affixes}


func _all_seven() -> Array[Dictionary]:
	var health: Array = [["test_max_health", 1, 1.0]]
	var pieces: Array[Dictionary] = [_vest(), _piece("headgear_cap", health)]
	for base: String in ["charm_coin", "implant_relay", "gloves_tactical", "backpack_pack", "boots_field"]:
		pieces.append(_piece(base, []))
	return pieces


func test_client_with_all_seven_gear_slots_filled_reaches_the_server_copy() -> void:
	client.loadout_sync.gear = _all_seven()
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 180.0, 3.0, "vest and cap health on server")
	assert_eq(server.loadout_sync.gear.size(), 7)
	await wait_until(func() -> bool: return client.health.max_health == 180.0, 3.0, "owner sees it")


func test_two_headgear_pieces_are_rejected() -> void:
	var before: int = Log.event_counts.get("net.loadout_rejected", 0)
	var second: Dictionary = _piece("headgear_cap", [])
	second["uid"] = "second_cap"
	client.loadout_sync.submit_loadout.rpc_id(1, [_piece("headgear_cap", []), second], [], {})
	await wait_until(
		func() -> bool: return Log.event_counts.get("net.loadout_rejected", 0) == before + 1, 3.0, "refused"
	)
	assert_true(server.loadout_sync.gear.is_empty())


func test_two_pieces_for_one_slot_or_a_gun_as_gear_are_rejected() -> void:
	var before: int = Log.event_counts.get("net.loadout_rejected", 0)
	var second: Dictionary = _vest()
	second["uid"] = "second_vest"
	client.loadout_sync.submit_loadout.rpc_id(1, [_vest(), second], [], {})
	client.loadout_sync.submit_loadout.rpc_id(1, [_gun()], [], {})
	await wait_until(
		func() -> bool: return Log.event_counts.get("net.loadout_rejected", 0) == before + 2, 3.0, "both rejected"
	)
	assert_eq(server.health.max_health, 100.0)


func test_client_skill_ranks_reach_the_server_copy_and_respec_removes_them() -> void:
	client.skill_ranks = {&"thick_skin": 3}
	client.loadout_sync.gear = [_vest()]
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 170.0, 3.0, "vest plus Thick Skin 3")
	assert_eq(server.skill_ranks, {&"thick_skin": 3} as Dictionary[StringName, int])
	client.skill_ranks = {}
	client.loadout_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 140.0, 3.0, "respec drops the skill")


func test_bad_skill_ranks_are_rejected_logged_and_change_nothing() -> void:
	var before: int = Log.event_counts.get("net.skills_rejected", 0)
	client.loadout_sync.submit_loadout.rpc_id(1, [], [], {"thick_skin": 4})
	client.loadout_sync.submit_loadout.rpc_id(1, [], [], {"no_such_skill": 1})
	client.loadout_sync.submit_loadout.rpc_id(1, [], [], {"thick_skin": "3"})
	await wait_until(
		func() -> bool: return Log.event_counts.get("net.skills_rejected", 0) == before + 3, 3.0, "all rejected"
	)
	assert_eq(server.health.max_health, 100.0)
	assert_true(server.skill_ranks.is_empty())
