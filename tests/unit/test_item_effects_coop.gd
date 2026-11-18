## Item gun on-hit effects (leech, points per hit) run once on the server for
## clients, the host and Pack guns, and item claims use the item gun's numbers.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")
const UID: String = "leech_rifle"

var server: HitClaims
var client: HitClaims
var claimant: Player
var host: Player
var mine: Player
var normal_points: int
var _port: int


func _make_side(side_name: String) -> HitClaims:
	var root: Node = TwoPeers.make_side(self, side_name)
	var session: GameSession = GameSession.new()
	session.rng.seed = 7
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var economy: Economy = Economy.new()
	economy.name = "Economy"
	economy.rules = load("res://content/economy/default_economy.tres")
	normal_points = economy.rules.points_per_hit
	root.add_child(economy)
	session.spawner = Spawner.new()
	session.spawner.name = "Enemies"
	session.spawner.spawn_group = &"test_item_effect_points"
	session.spawner.session = session
	root.add_child(session.spawner)
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players.player_scene = PLAYER
	session.players.player_added.connect(_prepare_player.bind(session))
	root.add_child(session.players)
	var claims: HitClaims = HitClaims.new()
	claims.name = "HitClaims"
	claims.session = session
	root.add_child(claims)
	return claims


func _prepare_player(player: Player, session: GameSession) -> void:
	player.spawn(session, [RIFLE])
	player.set_physics_process(false)
	player.input_enabled = false


func before_each() -> void:
	_port = TwoPeers.next_port()
	server = _make_side("Server")
	client = _make_side("Client")
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_item_effect_points")
	marker.position = Vector3(0, 0, -4)
	server.get_parent().add_child(marker)
	assert_eq(TwoPeers.host(server, _port, 2), OK)
	assert_eq(TwoPeers.join(client, _port), OK)
	client.session.players.setup(client.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	server.session.players.setup(server.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(_players_ready, 5.0, "players connected")
	var peer_id: int = client.multiplayer.get_unique_id()
	claimant = server.session.players.find_player(peer_id)
	host = server.session.players.find_player(1)
	mine = client.session.players.find_player(peer_id)
	for player: Player in [claimant, host]:
		player.health.regen_delay = 0.0
		player.health.current = 50.0


func _players_ready() -> bool:
	var peer_id: int = client.multiplayer.get_unique_id()
	return (
		peer_id > 1
		and server.session.players.find_player(peer_id) != null
		and client.session.players.find_player(peer_id) != null
	)


func after_each() -> void:
	for claims: HitClaims in [client, server]:
		var root: Node = claims.get_parent()
		for node: Node in claims.session.spawner.get_children():
			if node is Zombie:
				node.free()
		for node: Node in root.get_node("World").get_children():
			if node is Player:
				node.free()
		claims.session.free()
		TwoPeers.close_side(root)


func _item(affixes: Array, uid: String = UID) -> Dictionary:
	return {"v": 1, "uid": uid, "base": "rifle_ar", "rar": "rare", "ilvl": 30, "aff": affixes}


func _leech_item() -> Dictionary:
	return _item([["leech", 5, 1.0], ["points_per_hit", 5, 1.0]])


func _arm_client(item: Dictionary) -> void:
	mine.weapons.current.item = ItemInstance.new(item)
	mine.loadout_sync.send_loadout()
	var uid: String = str(item.uid)
	await wait_until(func() -> bool: return claimant.item_guns.has(uid), 3.0, "loadout reached server")


func _zombie() -> Zombie:
	var zombie: Zombie = server.session.spawner.spawn(WALKER, 1, WAVES)
	zombie.set_physics_process(false)
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client.session.spawner.has_node(path), 3.0, "zombie replicated")
	return zombie


func _claim(zombie: Zombie, amount: float, uid: String = UID) -> void:
	client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, amount, RIFLE.id, Vector3.ZERO, Vector3.ZERO, uid)


func test_protocol_was_bumped_for_item_hits() -> void:
	assert_gte(Build.PROTOCOL_VERSION, 7, "later protocol bumps keep this one")


func test_client_leech_hit_heals_the_server_copy_and_pays_item_points() -> void:
	await _arm_client(_leech_item())
	var zombie: Zombie = await _zombie()
	var points: int = claimant.wallet.points
	_claim(zombie, 10.0)
	await wait_until(func() -> bool: return claimant.health.current > 50.0, 3.0, "leech healed on server")
	assert_eq(claimant.health.current, 53.0)
	assert_eq(claimant.wallet.points, points + normal_points + 3)
	await wait_until(func() -> bool: return mine.health.current == 53.0, 3.0, "owner sees the heal")


func test_unknown_uid_pays_only_normal_hit_points() -> void:
	await _arm_client(_leech_item())
	var zombie: Zombie = await _zombie()
	var points: int = claimant.wallet.points
	_claim(zombie, 10.0, "not_equipped")
	await wait_until(func() -> bool: return zombie.health.current < zombie.health.max_health, 3.0, "claim applied")
	assert_eq(claimant.wallet.points, points + normal_points)
	assert_eq(claimant.health.current, 50.0)


func test_claim_within_the_item_guns_damage_is_accepted() -> void:
	await _arm_client(_item([["dmg_pct", 5, 1.0]], "hot_rifle"))
	var zombie: Zombie = await _zombie()
	var too_strong_for_plain: float = 120.0
	assert_gt(too_strong_for_plain, RIFLE.damage * RIFLE.head_multiplier * HitClaims.SLACK)
	_claim(zombie, too_strong_for_plain, "")
	await wait_physics_frames(8)
	assert_eq(zombie.health.current, zombie.health.max_health, "the plain rifle cannot claim this much")
	_claim(zombie, too_strong_for_plain, "hot_rifle")
	await wait_until(func() -> bool: return zombie.health.is_dead, 3.0, "item claim accepted")


func test_host_item_gun_trace_heals_through_the_same_server_path() -> void:
	host.weapons.current.item = ItemInstance.new(_leech_item())
	host.loadout_sync.send_loadout()
	var zombie: Zombie = await _zombie()
	var body: HitZone = zombie.hit_zones[1]
	var copy: Zombie = client.session.spawner.get_node(NodePath(String(zombie.name))) as Zombie
	for zone: HitZone in copy.hit_zones:
		zone.set_enabled(false)
	zombie.position = Vector3(0, 0, -4)
	zombie.visual.position = Vector3.ZERO
	await wait_physics_frames(2)
	host.weapons.current._trace(body.global_position + Vector3(0, 0, 2), Vector3.FORWARD)
	assert_lt(zombie.health.current, zombie.health.max_health)
	assert_eq(host.health.current, 53.0)


func test_shattering_a_frozen_zombie_heals_once() -> void:
	await _arm_client(_leech_item())
	var target: Zombie = await _zombie()
	var neighbour: Zombie = await _zombie()
	target.frozen = true
	neighbour.frozen = true
	_claim(target, 10.0)
	await wait_until(func() -> bool: return target.health.is_dead, 3.0, "shatter killed")
	assert_lt(neighbour.health.current, neighbour.health.max_health, "collateral shatter hit the neighbour")
	assert_eq(claimant.health.current, 53.0, "one shot heals and pays once; collateral adds nothing")


func test_pack_leech_gun_heals_for_a_client() -> void:
	var service: LootService = LootService.new()
	service.session = client.session
	service.player = mine
	client.get_parent().add_child(service)
	var hud: Hud = HUD.instantiate() as Hud
	client.get_parent().add_child(hud)
	var overlay: PackOverlay = hud.get_node("Root/Pack") as PackOverlay
	overlay.setup(service)
	service.pack.add(_item([["leech", 5, 1.0]], "pack_rifle"))
	overlay._equip()
	await wait_until(func() -> bool: return claimant.item_guns.has("pack_rifle"), 3.0, "pack gun reached server")
	var zombie: Zombie = await _zombie()
	_claim(zombie, 10.0, str(mine.weapons.current.item.data.uid))
	await wait_until(func() -> bool: return claimant.health.current == 53.0, 3.0, "pack leech healed")
