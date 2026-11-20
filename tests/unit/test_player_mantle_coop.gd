## Real ENet peers: a client's PlayerMantle climb reaches the server through PoseSync
## (docs/plans/mantle.md, step 2). Mantling sends no message of its own.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const TICK: float = 1.0 / 60.0
## Far from the origin, so bodies other tests leave in the shared physics world cannot block the climb.
const SPOT: Vector3 = Vector3(300, 0, 300)

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
	server_root = _make_side("MantleServer")
	client_root = _make_side("MantleClient")
	assert_eq(TwoPeers.host(server_root, port, 2), OK)
	assert_eq(TwoPeers.join(client_root, port), OK)
	server_spawner = server_root.get_node("PlayerSpawner") as PlayerSpawner
	client_spawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	var spawn_point: Transform3D = Transform3D(Basis(), Vector3(0, 0.05, 0))
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


## Both sides share one physics world in a test, so only the climbing player keeps collision.
func _only_owner_collides(owner: Player) -> void:
	for root: Node in [server_root, client_root]:
		for player: Player in TwoPeers.players(root):
			if player != owner:
				player.collision_layer = 0
				player.collision_mask = 0


func _box(centre: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = centre


func _frame(buttons: int) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	frame.move = Vector2(0, -1)
	return frame


func test_a_client_mantle_moves_the_server_copy_onto_the_ledge() -> void:
	var owner: Player = client_spawner.find_player(client_id)
	_only_owner_collides(owner)
	_box(SPOT + Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_box(SPOT + Vector3(0, 0.5, -1.6), Vector3(3, 1.0, 2))
	owner.global_basis = Basis.IDENTITY
	owner.global_position = SPOT + Vector3(0, 0.05, 0)
	await wait_physics_frames(2)
	for i: int in 20:
		owner.apply_frame(_frame(0), TICK)
	owner.apply_frame(_frame(InputFrame.JUMP), TICK)
	assert_true(owner.mantle.is_active(), "the client climbs")
	for i: int in 30:
		owner.apply_frame(_frame(0), TICK)
	assert_almost_eq(owner.global_position.y, 1.0, 0.06)
	var copy: Player = server_spawner.find_player(client_id)
	await wait_until(func() -> bool: return copy.global_position.y > 0.9, 3.0, "the climb reached the server")
	assert_almost_eq(copy.global_position.z, owner.global_position.z, 0.05, "the copy moved onto the ledge too")
	assert_false(copy.mantle.is_active(), "the server copy never runs a mantle of its own")
