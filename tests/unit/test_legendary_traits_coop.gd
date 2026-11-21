## A co-op client's Legendary trait runs on the server through its hit claims.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")

var server: GameSession
var client: GameSession
var claimant: Player


func _prepare_player(player: Player, session: GameSession) -> void:
	player.spawn(session, [RIFLE])
	player.set_physics_process(false)
	player.input_enabled = false


func before_each() -> void:
	var port: int = TwoPeers.next_port()
	for side_name: String in ["Server", "Client"]:
		var session: GameSession = CoopSide.make(self, side_name, [&"hit_claims"])
		session.players.player_added.connect(_prepare_player.bind(session))
		if side_name == "Server":
			server = session
		else:
			client = session
	CoopSide.add_spawn_point(server, Vector3(0, 0, -4))
	assert_eq(TwoPeers.host(server.hit_claims, port, 2), OK)
	assert_eq(TwoPeers.join(client.hit_claims, port), OK)
	CoopSide.start_players(client)
	CoopSide.start_players(server)
	await wait_until(
		func() -> bool:
			var peer_id: int = client.multiplayer.get_unique_id()
			return peer_id > 1 and server.players.find_player(peer_id) != null,
		5.0,
		"players connected"
	)
	claimant = server.players.find_player(client.multiplayer.get_unique_id())


func after_each() -> void:
	for session: GameSession in [client, server]:
		CoopSide.close(session)


func _zombie() -> Zombie:
	var zombie: Zombie = server.spawner.spawn(WALKER, 1, WAVES)
	zombie.set_physics_process(false)
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client.spawner.has_node(path), 3.0, "zombie replicated")
	return zombie


func test_tidewater_from_a_client_claim_stacks_on_the_server() -> void:
	var zombie: Zombie = await _zombie()
	claimant.item_guns["tw"] = ItemInstance.new({"uid": "tw", "rar": "legendary", "trait": ["tidewater", 1.0]})
	for index: int in 3:
		client.hit_claims.claim_hit.rpc_id(
			1, zombie.name, DamageInfo.Zone.BODY, 20.0, RIFLE.id, Vector3.ZERO, Vector3.ZERO, "tw"
		)
	await wait_until(func() -> bool: return zombie.health.current < 40.0, 3.0, "three stacking hits")
	assert_almost_eq(zombie.health.current, 100.0 - 20.0 - 21.0 - 22.0, 0.001, "+0%, +5%, +10%")


func test_ricochet_from_a_client_headshot_claim_hits_a_second_zombie() -> void:
	var target: Zombie = await _zombie()
	var bystander: Zombie = await _zombie()
	claimant.item_guns["rc"] = ItemInstance.new(
		{"uid": "rc", "base": "mako_pdw", "rar": "legendary", "trait": ["ricochet", 0.0]}
	)
	client.hit_claims.claim_hit.rpc_id(
		1, target.name, DamageInfo.Zone.HEAD, 10.0, &"mako_pdw", Vector3.ZERO, Vector3.ZERO, "rc"
	)
	await wait_until(func() -> bool: return bystander.health.current < 100.0, 3.0, "ricochet landed")
	assert_almost_eq(bystander.health.current, 96.0, 0.001, "40% of the 10-point hit")
