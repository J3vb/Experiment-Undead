## Compact look packets survive bad input and reach real peers, including late joins.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24670
const MIXED: Dictionary = {
	"vest": {"base": "vest_heavy", "rar": "rare"},
	"charm": {"base": "charm_vial", "rar": "epic"},
	"implant": {"base": "implant_relay", "rar": "legendary"},
}
const HOST_LOOK: Dictionary = {"vest": {"base": "vest_light", "rar": "uncommon"}}

var _codec: LookCodec
var _sides: Array[Node] = []


func before_each() -> void:
	_codec = LookCodec.new()


func after_each() -> void:
	_sides.reverse()
	for root: Node in _sides:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
	_sides.clear()


func test_encode_decode_preserves_every_visual_and_rarity_in_at_most_64_bytes() -> void:
	for visual_id: StringName in Content.ids(&"gear_visuals"):
		var visual: GearVisual = GearVisual.find(visual_id)
		for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"prototype"]:
			var look: CharacterLook = LookBuilder.from_equipped(MIXED)
			look.slots[visual.slot]["visual_id"] = visual_id
			look.slots[visual.slot]["rarity"] = rarity
			var bytes: PackedByteArray = _codec.encode(look)
			assert_lte(bytes.size(), 64)
			assert_eq(_codec.decode(bytes).slots, look.slots, "%s %s" % [visual_id, rarity])
			assert_eq(LookCodec.new().encode(look), bytes, "independent peers build the same tables")


func test_empty_and_partly_filled_looks_round_trip_without_adding_gear() -> void:
	for loadout: Dictionary in [{}, HOST_LOOK, {"charm": MIXED["charm"], "implant": MIXED["implant"]}]:
		var look: CharacterLook = LookBuilder.from_equipped(loadout)
		assert_eq(_codec.decode(_codec.encode(look)).slots, look.slots)
	assert_eq(_codec.encode(CharacterLook.new()), PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))


func test_visual_indexes_follow_sorted_content_ids() -> void:
	var visuals: Array = Content.ids(&"gear_visuals")
	visuals.sort()
	var look: CharacterLook = LookBuilder.from_equipped(MIXED)
	var bytes: PackedByteArray = _codec.encode(look)
	for index: int in CharacterLook.SLOTS.size():
		var slot: StringName = CharacterLook.SLOTS[index]
		assert_eq(bytes.decode_u16(index * 5), visuals.find(look.slots[slot]["visual_id"]) + 1)


func test_bad_lengths_use_common_base_meshes_in_every_slot() -> void:
	for bytes: PackedByteArray in [
		PackedByteArray(),
		PackedByteArray([255]),
		_codec.encode(LookBuilder.from_equipped(MIXED)).slice(0, 14),
		PackedByteArray(range(65)),
	]:
		var look: CharacterLook = _codec.decode(bytes)
		for slot: StringName in CharacterLook.SLOTS:
			_assert_common(look, slot)


func test_unknown_visual_rarity_or_dye_falls_back_only_the_damaged_slot() -> void:
	var good: CharacterLook = LookBuilder.from_equipped(MIXED)
	for index: int in CharacterLook.SLOTS.size():
		for field: int in [0, 2, 3, 4]:
			var bytes: PackedByteArray = _codec.encode(good)
			if field == 0:
				bytes.encode_u16(index * 5, 65535)
			else:
				bytes[index * 5 + field] = 255
			var bad_slot: StringName = CharacterLook.SLOTS[index]
			var decoded: CharacterLook = _codec.decode(bytes)
			_assert_common(decoded, bad_slot)
			for slot: StringName in CharacterLook.SLOTS:
				if slot != bad_slot:
					assert_eq(decoded.slots[slot], good.slots[slot], "other slots retain their actual look")


func test_visual_for_another_slot_and_noncanonical_empty_slot_fall_back() -> void:
	var bytes: PackedByteArray = _codec.encode(LookBuilder.from_equipped(MIXED))
	bytes.encode_u16(0, bytes.decode_u16(5))
	_assert_common(_codec.decode(bytes), &"vest")
	bytes.encode_u16(0, 0)
	bytes[2] = 255
	_assert_common(_codec.decode(bytes), &"vest")


func test_client_look_reaches_hosts_player_and_late_joiner() -> void:
	var server: Node = _listen()
	var client: Node = _join("LookClient", MIXED)
	await _wait_for_look(server, client, &"vest", &"vest_heavy", &"rare")
	var client_id: int = client.multiplayer.get_unique_id()
	_assert_rig(server, client_id, MIXED)
	_assert_rig(client, 1, HOST_LOOK)
	var owner: Player = _spawner(client).find_player(client_id)
	assert_true(owner.camera.current)
	assert_true(owner.weapons.visible, "own first-person weapon view stays active")
	var late: Node = _join("LookLate", {})
	await _wait_for_look(late, client, &"vest", &"vest_heavy", &"rare")
	_assert_rig(late, client_id, MIXED)
	_assert_rig(late, 1, HOST_LOOK)
	assert_eq((_sync(server)._looks[client_id] as PackedByteArray).size(), 15)
	var changed_host: Dictionary = {"vest": {"base": "vest_light", "rar": "epic"}}
	_spawner(server).find_player(1).gear_rig.apply(LookBuilder.from_equipped(changed_host))
	await _wait_for_look(client, server, &"vest", &"vest_light", &"epic")
	await _wait_for_look(late, server, &"vest", &"vest_light", &"epic")
	_assert_rig(client, 1, changed_host)
	_assert_rig(late, 1, changed_host)


func test_changed_look_relays_once_and_unchanged_look_does_not_replace_remote_gear() -> void:
	var server: Node = _listen()
	var client: Node = _join("LookClient", MIXED)
	await _wait_for_look(server, client, &"vest", &"vest_heavy", &"rare")
	var client_id: int = client.multiplayer.get_unique_id()
	var owner: Player = _spawner(client).find_player(client_id)
	var first: Node = _piece(server, client_id, &"vest")
	owner.gear_rig.apply(LookBuilder.from_equipped(MIXED))
	await wait_physics_frames(8)
	assert_true(is_instance_valid(first), "unchanged appearance sends no replacement")
	assert_same(_piece(server, client_id, &"vest"), first)
	var changed: Dictionary = MIXED.duplicate(true)
	changed["vest"]["rar"] = "legendary"
	owner.gear_rig.apply(LookBuilder.from_equipped(changed))
	await _wait_for_look(server, client, &"vest", &"vest_heavy", &"legendary")
	assert_false(is_instance_valid(first), "changed appearance replaces the remote piece")
	_assert_rig(server, client_id, changed)
	var replacement: Node = _piece(server, client_id, &"vest")
	await wait_physics_frames(8)
	assert_same(_piece(server, client_id, &"vest"), replacement, "idle physics ticks do not resend")


func test_malformed_client_packet_applies_common_base_meshes_on_the_host() -> void:
	var server: Node = _listen()
	var client: Node = _join("LookClient", MIXED)
	await _wait_for_look(server, client, &"vest", &"vest_heavy", &"rare")
	_sync(client)._submit_look.rpc_id(1, PackedByteArray([255]))
	await _wait_for_look(server, client, &"vest", &"vest_medium", &"common")
	var base_loadout: Dictionary = {}
	for slot: StringName in CharacterLook.SLOTS:
		base_loadout[slot] = {"base": GearVisual.BASES[slot], "rar": "common"}
	_assert_rig(server, client.multiplayer.get_unique_id(), base_loadout)
	var bytes: PackedByteArray = _sync(server)._looks[client.multiplayer.get_unique_id()]
	assert_eq(bytes.size(), 15, "server caches the sanitized compact packet")
	assert_eq(_codec.encode(_codec.decode(bytes)), bytes)


func test_disconnected_peers_are_removed_from_look_caches() -> void:
	var server: Node = _listen()
	var client: Node = _join("LookClient", MIXED)
	await _wait_for_look(server, client, &"vest", &"vest_heavy", &"rare")
	var late: Node = _join("LookLate", {})
	await _wait_for_look(late, client, &"vest", &"vest_heavy", &"rare")
	var client_id: int = client.multiplayer.get_unique_id()
	await wait_physics_frames(4)
	client.multiplayer.multiplayer_peer.close()
	client.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	await wait_until(
		func() -> bool: return not _sync(server)._looks.has(client_id) and not _sync(late)._looks.has(client_id),
		5.0,
		"disconnected appearance removed on host and remaining peer"
	)
	assert_false(_sync(server)._looks.has(client_id))
	assert_false(_sync(late)._looks.has(client_id))


func test_rejected_hello_never_publishes_a_look_or_spawns_a_player() -> void:
	var server: Node = _listen()
	var client: Node = _make_side("LookRefused", MIXED)
	var handshake: Handshake = client.get_node("Handshake") as Handshake
	handshake.content_hash = "wrong-content"
	_connect(client)
	await wait_until(
		func() -> bool: return handshake.refusal_reason == Net.RefusalReason.CONTENT_MISMATCH,
		5.0,
		"content mismatch refused before replication"
	)
	assert_eq(_sync(client)._last_sent.size(), 0)
	assert_eq(_sync(server)._looks.keys(), [1], "only the accepted host has a cached look")
	assert_eq(client.get_node("World").get_child_count(), 0)


func _make_side(side_name: String, loadout: Dictionary) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	_sides.append(root)
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var handshake: Handshake = Handshake.new()
	handshake.name = "Handshake"
	root.add_child(handshake)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = PLAYER
	root.add_child(spawner)
	var sync: LookSync = LookSync.new()
	sync.name = "LookSync"
	root.add_child(sync)
	sync.setup(spawner)
	spawner.player_added.connect(_on_player_added.bind(loadout))
	return root


func _on_player_added(player: Player, loadout: Dictionary) -> void:
	player.set_physics_process(false)
	player.health.set_process(false)
	if player.is_multiplayer_authority():
		player.gear_rig.apply(LookBuilder.from_equipped(loadout))


func _listen() -> Node:
	var root: Node = _make_side("LookServer", HOST_LOOK)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(PORT, 3), OK)
	root.multiplayer.multiplayer_peer = peer
	(root.get_node("Handshake") as Handshake).setup()
	_spawner(root).setup(root.get_node("World") as Node3D, Transform3D.IDENTITY)
	return root


func _join(side_name: String, loadout: Dictionary) -> Node:
	var root: Node = _make_side(side_name, loadout)
	_connect(root)
	return root


func _connect(root: Node) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", PORT), OK)
	root.multiplayer.multiplayer_peer = peer
	(root.get_node("Handshake") as Handshake).setup()
	_spawner(root).setup(root.get_node("World") as Node3D, Transform3D.IDENTITY)


func _wait_for_look(root: Node, owner: Node, slot: StringName, visual: StringName, rarity: StringName) -> void:
	await wait_until(
		func() -> bool: return _shows(root, owner.multiplayer.get_unique_id(), slot, visual, rarity),
		5.0,
		"appearance reached %s" % root.name
	)


func _shows(root: Node, peer_id: int, slot: StringName, visual_id: StringName, rarity: StringName) -> bool:
	var piece: Node = _piece(root, peer_id, slot)
	if piece == null or piece.scene_file_path != GearVisual.find(visual_id).scene.resource_path:
		return false
	var geometry: GeometryInstance3D = piece.find_children("*", "GeometryInstance3D", true, false)[0]
	var finish: RarityLook = Content.get_item(&"looks", rarity) as RarityLook
	return geometry.get_instance_shader_parameter(&"trim_color") == finish.trim_color


func _piece(root: Node, peer_id: int, slot: StringName) -> Node:
	var player: Player = _spawner(root).find_player(peer_id)
	if player == null:
		return null
	var attachment: Node = player.gear_rig.skeleton.get_node_or_null(String(slot).capitalize())
	return attachment.get_child(0) if attachment != null else null


func _assert_rig(root: Node, peer_id: int, loadout: Dictionary) -> void:
	var expected: CharacterLook = LookBuilder.from_equipped(loadout)
	for slot: StringName in CharacterLook.SLOTS:
		var piece: Node = _piece(root, peer_id, slot)
		if not expected.slots.has(slot):
			assert_null(piece, "%s stays empty" % slot)
			continue
		assert_not_null(piece, "%s is equipped" % slot)
		if piece == null:
			continue
		var entry: Dictionary = expected.slots[slot]
		assert_eq(piece.scene_file_path, GearVisual.find(entry["visual_id"]).scene.resource_path)
		var finish: RarityLook = Content.get_item(&"looks", entry["rarity"]) as RarityLook
		for node: Node in piece.find_children("*", "GeometryInstance3D", true, false):
			var geometry: GeometryInstance3D = node as GeometryInstance3D
			assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), finish.trim_color)
			assert_eq(geometry.get_instance_shader_parameter(&"dye_main"), entry["dyes"][0])
			assert_eq(geometry.get_instance_shader_parameter(&"dye_accent"), entry["dyes"][1])


func _assert_common(look: CharacterLook, slot: StringName) -> void:
	assert_true(look.slots.has(slot))
	assert_eq(look.slots[slot]["visual_id"], GearVisual.BASES[slot])
	assert_eq(look.slots[slot]["rarity"], &"common")
	assert_eq(look.slots[slot]["dyes"], [CharacterLook.DEFAULT_DYE_MAIN, CharacterLook.DEFAULT_DYE_ACCENT])


func _spawner(root: Node) -> PlayerSpawner:
	return root.get_node("PlayerSpawner") as PlayerSpawner


func _sync(root: Node) -> LookSync:
	return root.get_node("LookSync") as LookSync
