## Gear refreshes preserve server-owned health and publish maximum-health reductions;
## owners send their loadout and the server applies it.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HEALTH_AFFIX: String = "res://tests/fixtures/loot/test_max_health.tres"
const PORT: int = 24649

var server: Player
var client: Player
var _roots: Array[Node3D] = []
var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = HEALTH_AFFIX
	for index: int in 2:
		var root: Node3D = Node3D.new()
		root.name = "Server" if index == 0 else "Client"
		add_child(root)
		get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
		var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
		var error: Error = peer.create_server(PORT, 1) if index == 0 else peer.create_client("127.0.0.1", PORT)
		assert_eq(error, OK)
		root.multiplayer.multiplayer_peer = peer
		_roots.append(root)
	await wait_until(func() -> bool: return _roots[0].multiplayer.get_peers().size() == 1, 3.0, "peers connected")
	var owner_id: int = _roots[1].multiplayer.get_unique_id()
	for root: Node3D in _roots:
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
	for root: Node3D in _roots:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
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


func test_client_loadout_raises_server_health_and_records_item_guns() -> void:
	var weapon: Weapon = client.weapons.give(Content.weapon(&"pistol_service"))
	weapon.item = ItemInstance.new(_gun())
	client.state_sync.gear = [_vest()]
	client.state_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 140.0, 3.0, "loadout reached server")
	assert_eq(server.health.current, 140.0)
	assert_eq(server.item_guns.keys(), ["gun_pistol_service"])
	assert_eq(server.item_guns["gun_pistol_service"].data.get("base"), "pistol_service")
	await wait_until(func() -> bool: return client.health.max_health == 140.0, 3.0, "snapshot reached owner")
	assert_eq(client.health.current, 140.0)


func test_new_loadout_without_the_vest_drops_max_health() -> void:
	client.state_sync.gear = [_vest()]
	client.state_sync.send_loadout()
	await wait_until(func() -> bool: return client.health.max_health == 140.0, 3.0, "vest applied")
	client.state_sync.gear = []
	client.state_sync.send_loadout()
	await wait_until(func() -> bool: return server.health.max_health == 100.0, 3.0, "vest removed on server")
	await wait_until(func() -> bool: return client.health.max_health == 100.0, 3.0, "owner sees removal")
	assert_eq(client.health.current, 100.0)


func test_malformed_loadouts_are_rejected_logged_and_change_nothing() -> void:
	var before: int = Log.event_counts.get("net.loadout_rejected", 0)
	client.state_sync.submit_loadout.rpc_id(1, ["vest"], [])
	client.state_sync.submit_loadout.rpc_id(1, [_vest(), _vest(), _vest(), _vest()], [])
	client.state_sync.submit_loadout.rpc_id(1, [_vest()], [_gun("not_a_gun")])
	await wait_until(
		func() -> bool: return Log.event_counts.get("net.loadout_rejected", 0) == before + 3, 3.0, "all rejected"
	)
	assert_eq(server.health.max_health, 100.0)
	assert_true(server.item_guns.is_empty())


func test_host_loadout_applies_once_on_its_own_player() -> void:
	var host: Player = PLAYER.instantiate() as Player
	add_child_autofree(host)
	host.set_physics_process(false)
	host.state_sync.gear = [_vest()]
	host.equip_gear([_vest()])
	host.state_sync.send_loadout()
	host.state_sync.send_loadout()
	assert_eq(host.health.max_health, 140.0, "the host's gear is not stacked twice")
	assert_eq(host.health.current, 140.0)
