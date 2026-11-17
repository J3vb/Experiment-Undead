## Seeded personal rolls and ENet owner-only delivery/pickup in one process.
extends GutTest

const PORT: int = 24665
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var session: GameSession
var service: LootService
var _roots: Array[Node] = []
var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_loot_luck"] = "res://tests/fixtures/loot/test_loot_luck.tres"
	session = GameSession.new()
	autofree(session)
	session.director = WaveDirector.new()
	autofree(session.director)
	session.director.round_number = 17
	session.rng.seed = 73
	service = LootService.new()
	service.session = session
	autofree(service)


func after_each() -> void:
	_roots.reverse()
	for root: Node in _roots:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
	_roots.clear()
	Content._by_type[&"loot"] = _loot_before


func test_fixed_seed_repeats_the_complete_drop_stream() -> void:
	service.drop_chance_override = 1.0
	var expected: Array[Dictionary] = []
	for index: int in 100:
		expected.append(service.roll_drop(&"zombie_walker", 50, 0.2))
	session.rng.seed = 73
	for index: int in expected.size():
		assert_eq(service.roll_drop(&"zombie_walker", 50, 0.2), expected[index])


func test_unlock_level_gates_weapon_and_gear_pool() -> void:
	var bastion: WeaponData = Content.weapon(&"bastion_lmg")
	assert_false(LootService.eligible_bases(19, &"rare").has(bastion))
	assert_true(LootService.eligible_bases(20, &"rare").has(bastion))
	assert_false(LootService.eligible_bases(50, &"common").has(bastion), "rarity floor still applies")
	var gear: GearBaseData = Content.get_item(&"loot", &"vest_light") as GearBaseData
	var original: int = gear.unlock_level
	gear.unlock_level = 12
	var locked: bool = LootService.eligible_bases(11, &"rare").has(gear)
	var unlocked: bool = LootService.eligible_bases(12, &"rare").has(gear)
	gear.unlock_level = original
	assert_false(locked)
	assert_true(unlocked)
	for base: Resource in LootService.eligible_bases(50, &"rare"):
		if base is WeaponData:
			assert_false(String((base as WeaponData).id).ends_with("_reforged"))


func test_round_sets_item_level_and_caps_at_fifty() -> void:
	service.drop_chance_override = 1.0
	for round_number: int in [1, 17, 50, 83]:
		session.director.round_number = round_number
		for index: int in 20:
			assert_eq(service.roll_drop(&"zombie_walker", 1).get("ilvl"), mini(round_number, 50))


func test_source_chances_and_brute_floor() -> void:
	assert_almost_eq(LootService.drop_chance(&"zombie_walker", 1), 0.016, 0.0001)
	assert_almost_eq(LootService.drop_chance(&"zombie_runner", 100), 0.05, 0.0001)
	assert_eq(LootService.drop_chance(&"zombie_bloater", 1), 0.05)
	assert_eq(LootService.drop_chance(&"zombie_brute", 1), 1.0)
	for index: int in 100:
		var drop: Dictionary = service.roll_drop(&"zombie_brute", 50)
		assert_false(drop.is_empty())
		assert_gte(ItemRoller.RARITIES.find(StringName(drop.rar)), 2)


func test_prototypes_are_fixed_and_only_in_their_rarity_pool() -> void:
	var pool: Array[Resource] = LootService.eligible_bases(50, &"prototype")
	assert_gt(pool.size(), 0)
	for base: Resource in pool:
		assert_true(base is WeaponData)
		assert_true((base as WeaponData).loot_tags.has(&"prototype"))
	var item: Dictionary = service._prototype(pool[0] as WeaponData)
	assert_eq(item.aff, [])
	assert_eq(item.imp, ["fabricator", 1.0])
	assert_eq(item.rar, "prototype")


func _make_side(side_name: String) -> LootService:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	_roots.append(root)
	var loot: LootService = LootService.new()
	loot.name = "LootService"
	loot.session = session
	root.add_child(loot)
	return loot


func _add_player(loot: LootService, owner_id: int) -> Player:
	var owner_player: Player = PLAYER.instantiate() as Player
	owner_player.name = str(owner_id)
	owner_player.set_multiplayer_authority(owner_id)
	owner_player.get_node("PoseSync").free()
	loot.get_parent().add_child(owner_player)
	owner_player.set_physics_process(false)
	return owner_player


func test_drop_reaches_only_its_owner_and_pickup_only_changes_their_pack() -> void:
	var server: LootService = _make_side("LootHost")
	var client: LootService = _make_side("LootClient")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client.multiplayer.multiplayer_peer = client_peer
	await wait_until(func() -> bool: return server.multiplayer.get_peers().size() == 1, 5.0, "connected")
	var client_id: int = client.multiplayer.get_unique_id()
	var host_player: Player = _add_player(server, 1)
	_add_player(server, client_id)
	_add_player(client, 1)
	var client_player: Player = _add_player(client, client_id)
	server.player = host_player
	client.player = client_player
	client_player.state_sync.gear = [{"v": 1, "uid": "charm", "base": "charm", "aff": [["test_loot_luck", 1, 1.0]]}]
	client_player.state_sync.send_loadout()
	var server_copy: Player = server.get_parent().get_node(str(client_id)) as Player
	await wait_until(
		func() -> bool: return LootService.player_luck(server_copy, 1) == 0.2, 3.0, "charm luck counts on the server"
	)

	service.drop_chance_override = 1.0
	var item: Dictionary = service.roll_drop(&"zombie_walker", 1)
	server.send_drop(client_player.get_multiplayer_authority(), item, Vector3.ZERO)
	await wait_until(func() -> bool: return client.get_child_count() == 1, 3.0, "owner received drop")
	assert_eq(server.get_child_count(), 0, "host cannot see the client's drop")
	var drop: LootDrop = client.get_child(0) as LootDrop
	drop.interact(host_player)
	assert_true(client.pack.items.is_empty(), "other owner cannot take the item")
	assert_true(drop.is_local(), "the owning client picks it up itself, no server request")
	drop.interact(client_player)
	assert_eq(client.pack.items, [item])
	assert_true(server.pack.items.is_empty())
	await wait_process_frames(2)
	assert_false(is_instance_valid(drop))
	server.send_drop(1, item, Vector3.ZERO)
	assert_eq(server.get_child_count(), 1, "host uses the same local receiver")
	assert_eq(client.get_child_count(), 0, "host drop is private too")


func test_luck_combines_gear_and_rounds_and_caps_at_one() -> void:
	var owner_player: Player = Player.new()
	autofree(owner_player)
	owner_player.stats.add_modifier(&"loot_luck", "increased", 0.2, &"charm")
	assert_eq(LootService.player_luck(owner_player, 1), 0.2)
	assert_almost_eq(LootService.player_luck(owner_player, 20), 0.4, 0.0001)
	assert_eq(LootService.player_luck(owner_player, 100), 1.0)
