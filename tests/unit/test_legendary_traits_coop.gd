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


func test_cold_snap_from_a_client_freezes_on_the_server_and_is_rate_limited() -> void:
	var zombie: Zombie = await _zombie()
	claimant.item_guns["cs"] = ItemInstance.new(
		{"uid": "cs", "base": "atlas_auto", "rar": "legendary", "trait": ["cold_snap", 1.0]}
	)
	var mine: Player = client.players.find_player(client.multiplayer.get_unique_id())
	client.legendary_traits.request_cold_snap(mine, "nobody_owns_this")
	await wait_physics_frames(8)
	assert_false(zombie.frozen, "someone else's or a missing gun is refused")
	client.legendary_traits.request_cold_snap(mine, "cs")
	await wait_until(func() -> bool: return zombie.frozen, 3.0, "frozen by the client's Cold Snap")
	zombie.frozen = false
	client.legendary_traits.request_cold_snap(mine, "cs")
	await wait_physics_frames(8)
	assert_false(zombie.frozen, "a repeat inside the cooldown is refused")


func test_dead_mans_hand_claim_passes_bounds_only_from_its_item() -> void:
	var zombie: Zombie = await _zombie()
	var hollis: WeaponData = Content.weapon(&"hollis_44")
	var big: float = hollis.damage * hollis.head_multiplier * 1.5 * 2.0
	claimant.item_guns["dmh"] = ItemInstance.new(
		{"uid": "dmh", "base": "hollis_44", "rar": "legendary", "trait": ["dead_mans_hand", 0.5]}
	)
	claimant.item_guns["plain"] = ItemInstance.new({"uid": "plain", "base": "hollis_44", "rar": "rare"})
	for uid: String in ["", "plain"]:
		client.hit_claims.claim_hit.rpc_id(
			1, zombie.name, DamageInfo.Zone.BODY, big, &"hollis_44", Vector3.ZERO, Vector3.ZERO, uid
		)
	await wait_physics_frames(8)
	assert_eq(zombie.health.current, 100.0, "too big for a plain Hollis")
	client.hit_claims.claim_hit.rpc_id(
		1, zombie.name, DamageInfo.Zone.BODY, big, &"hollis_44", Vector3.ZERO, Vector3.ZERO, "dmh"
	)
	await wait_until(func() -> bool: return zombie.health.is_dead, 3.0, "a 4x last round lands")


func test_last_rites_from_a_downed_client_gets_them_up_through_claims() -> void:
	claimant.item_guns["lr"] = ItemInstance.new(
		{"uid": "lr", "base": "pistol_service", "rar": "legendary", "trait": ["last_rites", 1.0]}
	)
	claimant.state_sync.down_player()
	assert_true(claimant.can_self_revive())
	var pistol: StringName = PlayerStateSync.PISTOL
	for kill: int in 5:
		var zombie: Zombie = await _zombie()
		zombie.health.current = 1.0
		client.hit_claims.claim_hit.rpc_id(
			1, zombie.name, DamageInfo.Zone.BODY, 5.0, pistol, Vector3.ZERO, Vector3.ZERO, "lr"
		)
		await wait_until(func() -> bool: return zombie.health.is_dead, 3.0, "downed kill")
	await wait_until(func() -> bool: return not claimant.is_downed, 3.0, "Last Rites got them up")
