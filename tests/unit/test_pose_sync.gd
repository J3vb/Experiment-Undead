## Real ENet peers: the owner's crouch, held gun and reload ride PoseSync to every peer.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var server_root: Node
var client_root: Node
var server_spawner: PlayerSpawner
var client_spawner: PlayerSpawner
var client_id: int


func _make_side(side_name: String) -> Node:
	var root: Node = TwoPeers.make_side(self, side_name)
	TwoPeers.add_player_spawner(root, PLAYER)
	return root


func before_each() -> void:
	var port: int = TwoPeers.next_port()
	server_root = _make_side("PoseServer")
	client_root = _make_side("PoseClient")
	assert_eq(TwoPeers.host(server_root, port, 2), OK)
	assert_eq(TwoPeers.join(client_root, port), OK)
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


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		for player: Player in TwoPeers.players(root):
			player.free()
		TwoPeers.close_side(root)


func test_owner_crouch_reaches_other_peers_and_survives_health_snapshots() -> void:
	client_spawner.find_player(client_id).is_crouching = true
	var server_copy: Player = server_spawner.find_player(client_id)
	await wait_until(func() -> bool: return server_copy.is_crouching, 3.0, "client crouch reached the server")
	var host: Player = server_spawner.find_player(1)
	var host_copy: Player = client_spawner.find_player(1)
	host.is_crouching = true
	await wait_until(func() -> bool: return host_copy.is_crouching, 3.0, "host crouch reached the client")
	host.take_damage(DamageInfo.create(20.0, null))
	await wait_until(func() -> bool: return host_copy.health.current == 80.0, 3.0, "health snapshot arrived")
	await wait_physics_frames(2)
	assert_true(host_copy.is_crouching, "a health snapshot does not stand a crouching teammate up")
	assert_false(host_copy.is_downed)


func test_owner_held_gun_and_reload_reach_other_peers() -> void:
	var owner: Player = client_spawner.find_player(client_id)
	var weapon: Weapon = owner.weapons.give(Content.weapon(&"rifle_ar"))
	var copy: BodyAnimator = server_spawner.find_player(client_id).get_node("Body/BodyAnimator") as BodyAnimator
	await wait_until(func() -> bool: return copy.held_weapon == &"rifle_ar", 3.0, "held gun reached the server")
	weapon.instance.ammo_in_mag = 0
	assert_true(weapon.start_reload())
	await wait_until(func() -> bool: return copy.reload_time > 0.0, 3.0, "reload reached the server")
