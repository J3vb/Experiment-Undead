## Two peers in one process: zombies made by the server's Spawner appear on
## the client with the same name, follow the server's pose and state, run no
## AI there, show their death and vanish when the server frees them.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const RULES: String = "res://content/waves/default_waves.tres"

var server_root: Node
var client_root: Node
var server_spawner: Spawner
var client_spawner: Spawner
var _port: int
var _session: GameSession

var _gore_before: Variant


func _make_side(side_name: String) -> Spawner:
	var root: Node = TwoPeers.make_side(self, side_name)
	var spawner: Spawner = Spawner.new()
	spawner.name = "Enemies"
	spawner.spawn_group = &"test_zombie_sync_points"
	spawner.session = _session
	root.add_child(spawner)
	return spawner


func before_each() -> void:
	_gore_before = Settings.get_value(&"graphics", &"gore")
	Settings._values[&"graphics"][&"gore"] = Impact.Gore.FULL
	_port = TwoPeers.next_port()
	_session = GameSession.new()
	_session.rng.seed = 7
	server_spawner = _make_side("Server")
	client_spawner = _make_side("Client")
	server_root = server_spawner.get_parent()
	client_root = client_spawner.get_parent()
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_zombie_sync_points")
	marker.position = Vector3(4, 0, -3)
	server_root.add_child(marker)
	assert_eq(TwoPeers.host(server_root, _port, 2), OK)
	assert_eq(TwoPeers.join(client_root, _port), OK)
	await wait_until(
		func() -> bool:
			return client_root.multiplayer.get_unique_id() > 1 and server_root.multiplayer.get_peers().size() == 1,
		5.0,
		"connected"
	)


func after_each() -> void:
	Settings._values[&"graphics"][&"gore"] = _gore_before
	for root: Node in [client_root, server_root]:
		for child: Node in (root.get_node("Enemies") as Node).get_children():
			if child is Zombie:
				child.free()
		TwoPeers.close_side(root)
	_session.free()


func _spawn_on_server() -> Array[Zombie]:
	var zombie: Zombie = server_spawner.spawn(load(WALKER) as EnemyData, 1, load(RULES) as WaveRules)
	var copy_path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client_spawner.has_node(copy_path), 3.0, "zombie reached client")
	return [zombie, client_spawner.get_node_or_null(copy_path) as Zombie]


func test_client_copy_follows_the_server_zombie() -> void:
	var pair: Array[Zombie] = await _spawn_on_server()
	var zombie: Zombie = pair[0]
	var copy: Zombie = pair[1]
	assert_not_null(copy)
	if copy == null:
		return
	assert_eq(copy.net_id, zombie.net_id)
	assert_false(copy.voice.waiting_for_sync, "the copy's voice starts after the first sync")
	assert_true(copy.get_node("Sync") is ZombieSync)
	assert_eq(copy.data.resource_path, WALKER)
	assert_false(copy.is_physics_processing(), "clients run no zombie AI")
	assert_true(zombie.is_physics_processing(), "the server runs the AI")
	zombie.set_physics_process(false)
	zombie.position = Vector3(10, 2, 6)
	zombie.rotation.y = 0.8
	zombie.state = Zombie.State.CHASING
	zombie.velocity = Vector3(1.5, 0, 0)
	await wait_until(func() -> bool: return copy.position.is_equal_approx(zombie.position), 3.0, "pose synced")
	assert_almost_eq(copy.rotation.y, 0.8, 0.001)
	assert_eq(copy.state, Zombie.State.CHASING)
	assert_eq(copy.velocity, Vector3(1.5, 0, 0))
	zombie.state = Zombie.State.ATTACKING
	await wait_until(func() -> bool: return copy.voice.stream == copy.data.attack_sound, 3.0, "attack heard")
	assert_eq(copy.voice.stream, copy.data.attack_sound, "clients hear swings from the synced state")


func test_death_shows_on_client_and_free_despawns() -> void:
	var pair: Array[Zombie] = await _spawn_on_server()
	var zombie: Zombie = pair[0]
	var copy: Zombie = pair[1]
	var info: DamageInfo = DamageInfo.new()
	info.amount = 100000.0
	zombie.health.take_damage(info)
	assert_eq(zombie.state, Zombie.State.DEAD)
	await wait_until(func() -> bool: return copy.collision_layer == 0, 3.0, "client shows the death")
	assert_eq(copy.state, Zombie.State.DEAD)
	assert_eq(copy.head_zone.collision_layer, 0, "dead zombies cannot be shot on the client")
	assert_false(copy.head_popped, "a body kill keeps the head")
	await wait_until(func() -> bool: return copy.voice.stream in copy.data.death_sounds, 3.0, "death heard")
	assert_true(copy.voice.stream in copy.data.death_sounds, "the client hears the death sound")
	await wait_physics_frames(3)
	assert_true(copy.voice.playing, "the client's death sound is not cut off by the sync")
	var copy_name: StringName = copy.name
	zombie.queue_free()
	await wait_until(func() -> bool: return not client_spawner.has_node(NodePath(String(copy_name))), 3.0, "despawned")
	assert_false(client_spawner.has_node(NodePath(String(copy_name))))


func test_headshot_kill_syncs_the_head_pop() -> void:
	assert_true(^".:head_popped" in ZombieSync.SYNCED)
	var pair: Array[Zombie] = await _spawn_on_server()
	var info: DamageInfo = DamageInfo.new()
	info.amount = 100000.0
	info.hit_zone = DamageInfo.Zone.HEAD
	pair[0].health.take_damage(info)
	assert_true(pair[0].head_popped)
	await wait_until(func() -> bool: return pair[1].head_popped, 3.0, "head pop synced")
	assert_true(pair[1].head_popped, "the client copy knows the head popped")
	await wait_until(func() -> bool: return pair[1].visual.head_scale() < 0.05, 3.0, "client pops the head")
	assert_lt(pair[1].visual.head_scale(), 0.05, "the client copy shows the stump on Full gore")


func test_copy_that_arrives_dead_is_not_a_fresh_death() -> void:
	var zombie: Zombie = server_spawner.spawn(load(WALKER) as EnemyData, 1, load(RULES) as WaveRules)
	zombie.set_physics_process(false)
	zombie.state = Zombie.State.DEAD
	var copy_path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client_spawner.has_node(copy_path), 3.0, "zombie reached client")
	var copy: Zombie = client_spawner.get_node(copy_path) as Zombie
	assert_false((copy.get_node("Sync") as ZombieSync)._seen_alive, "a corpse a late joiner finds is not seen dying")


func test_vault_progress_reaches_the_client_copy() -> void:
	var pair: Array[Zombie] = await _spawn_on_server()
	var zombie: Zombie = pair[0]
	var copy: Zombie = pair[1]
	zombie.set_physics_process(false)
	zombie.entry.vault_time = ZombieEntry.VAULT_TIME * 0.5
	await wait_until(func() -> bool: return copy.entry.vault_progress() >= 0.0, 3.0, "vault synced")
	assert_almost_eq(copy.entry.vault_progress(), 0.5, 0.001, "the client copy shows the hop")
