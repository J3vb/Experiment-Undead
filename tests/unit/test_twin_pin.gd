## Twin Pin (docs/plans/legendaries-traits.md, step 6): a frag from a player with the
## trait splits into two smaller frags that do not split again.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var root: Node3D
var session: GameSession
var player: Player
var frag: ThrowableData


func before_each() -> void:
	session = GameSession.new()
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.local_input.enabled = false
	player.global_position = Vector3(30, -50, 0)
	frag = GrenadeThrower.FRAG.duplicate() as ThrowableData


func after_each() -> void:
	session.free()


func _grenades() -> Array[Grenade]:
	var out: Array[Grenade] = []
	for node: Node in root.get_children():
		if node is Grenade:
			out.append(node as Grenade)
	return out


func test_twin_pin_splits_a_frag_into_two_smaller_frags_once() -> void:
	player.stats.add_modifier(&"twin_pin", "flat", 60.0, &"gear")
	var grenade: Grenade = Grenade.spawn(root, frag, player, Vector3.ZERO, Vector3.ZERO, 0.0)
	grenade.go_off()
	var children: Array[Grenade] = []
	for made: Grenade in _grenades():
		if made.split_child:
			children.append(made)
	assert_eq(children.size(), 2)
	for child: Grenade in children:
		assert_almost_eq(child.fuse_left, Grenade.TWIN_PIN_FUSE, 0.001)
		assert_almost_eq(child.data.centre_damage, 600.0, 0.001, "60% of the frag's damage")
		assert_almost_eq(child.data.radius, frag.radius * 0.5, 0.001)
		assert_eq(child.thrower, player)
	assert_eq(frag.centre_damage, 1000.0, "the shared frag data is not changed")
	var before: int = _grenades().size()
	children[0].go_off()
	assert_eq(_grenades().size(), before, "a child frag does not split again")


func test_frag_without_twin_pin_does_not_split() -> void:
	var grenade: Grenade = Grenade.spawn(root, frag, player, Vector3.ZERO, Vector3.ZERO, 0.0)
	grenade.go_off()
	for made: Grenade in _grenades():
		assert_false(made.split_child)
