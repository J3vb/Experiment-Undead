## Real ENet peers retain one local arm rig through downing, revival, death and respawn.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var server_root: Node
var client_root: Node
var server_spawner: PlayerSpawner
var client_spawner: PlayerSpawner
var client_id: int
var _port: int


func _make_side(side_name: String) -> Node:
	var root: Node = TwoPeers.make_side(self, side_name)
	TwoPeers.add_player_spawner(root, PLAYER)
	return root


func before_each() -> void:
	_port = TwoPeers.next_port()
	server_root = _make_side("Server")
	client_root = _make_side("Client")
	assert_eq(TwoPeers.host(server_root, _port, 2), OK)
	assert_eq(TwoPeers.join(client_root, _port), OK)
	server_spawner = server_root.get_node("PlayerSpawner") as PlayerSpawner
	client_spawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	var spawn_point: Transform3D = Transform3D(Basis(), Vector3(5, 0, 5))
	client_spawner.setup(client_root.get_node("World") as Node3D, spawn_point)
	server_spawner.setup(server_root.get_node("World") as Node3D, spawn_point)
	await wait_until(
		func() -> bool: return TwoPeers.players(server_root).size() == 2 and TwoPeers.players(client_root).size() == 2,
		5.0,
		"both peers see the squad"
	)
	client_id = client_root.multiplayer.get_unique_id()
	for root: Node in [server_root, client_root]:
		for player: Player in TwoPeers.players(root):
			player.set_physics_process(false)
			player.health.set_physics_process(false)
			player.health.regen_delay = 0.0


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		for player: Player in TwoPeers.players(root):
			player.free()
		TwoPeers.close_side(root)


func _server(peer_id: int = 1) -> Player:
	return server_spawner.find_player(peer_id)


func _client(peer_id: int = 1) -> Player:
	return client_spawner.find_player(peer_id)


func test_arm_rig_lifecycle_follows_coop_down_revive_death_respawn() -> void:
	for root: Node in [server_root, client_root]:
		for player: Player in TwoPeers.players(root):
			player.weapons.give(Content.weapon(&"rifle_ar"))
			if player.is_multiplayer_authority():
				assert_not_null(player.weapons.arm_view)
			else:
				assert_null(player.weapons.arm_view)
	var local_player: Player = _client(client_id)
	var original: PlayerArmView = local_player.weapons.arm_view
	var standing: Weapon = local_player.weapons.current
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return local_player.is_downed, 3.0, "owner downed")
	assert_eq(local_player.weapons.arm_view, original)
	assert_eq(original.weapon, local_player.weapons.current)
	assert_eq(original.profile.id, &"pistol_service")
	assert_true(original.is_visible_in_tree())
	assert_null(_server(client_id).weapons.arm_view)
	_server(client_id).state_sync.revive_player()
	await wait_until(func() -> bool: return local_player.is_alive(), 3.0, "owner revived")
	assert_eq(local_player.weapons.arm_view, original)
	assert_eq(original.weapon, standing)
	assert_eq(original.profile.id, &"rifle_ar")
	assert_true(original.is_visible_in_tree())
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return local_player.is_downed, 3.0, "owner downed again")
	_server(client_id).state_sync._physics_process(30.0)
	await wait_until(func() -> bool: return local_player.is_dead, 3.0, "owner death")
	assert_false(original.is_visible_in_tree())
	Events.round_started.emit(2, 8)
	await wait_until(func() -> bool: return local_player.is_alive(), 3.0, "owner respawn")
	await wait_physics_frames(2)
	assert_eq(local_player.weapons.arm_view, original)
	assert_eq(original.weapon, local_player.weapons.current)
	assert_eq(original.profile.id, &"pistol_service")
	assert_true(original.is_visible_in_tree())
	assert_eq(local_player.weapons.find_children("*", "PlayerArmView", true, false).size(), 1)
	assert_null(_server(client_id).weapons.arm_view)
