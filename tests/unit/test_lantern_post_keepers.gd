## Lantern Post stall keepers in the town scene (F-76 step 4): one keeper inside each market stall, facing the
## street, and each one takes the player's look from the street before the stall's collider does.
extends GutTest

const SCENE: String = "res://levels/lantern_post/lantern_post.tscn"
const STALLS: Array[String] = ["Missions", "Trader", "Gunsmith", "Technician"]
## A stall's counter front, measured from the stall's middle along its front (+Z) axis (test_lantern_post.gd).
const COUNTER_FRONT: float = 1.6

var _hub: Level


func before_each() -> void:
	_hub = (load(SCENE) as PackedScene).instantiate() as Level
	add_child_autofree(_hub)


func test_each_stall_has_its_keeper_inside() -> void:
	var keepers: Array[StringName] = []
	for stall_name: String in STALLS:
		var stall: Node3D = _hub.get_node("Market/%sStall" % stall_name) as Node3D
		var keeper: Vendor = _hub.get_node_or_null("Market/%sKeeper" % stall_name) as Vendor
		assert_not_null(keeper, stall_name + " has a keeper")
		if keeper == null:
			continue
		assert_eq(String(keeper.data.stall), stall_name.to_upper(), stall_name + " keeper runs this stall")
		keepers.append(keeper.data.stall)
		var local: Vector3 = stall.to_local(keeper.global_position)
		assert_lt(absf(local.x), 0.5, stall_name + " keeper stands mid-stall")
		assert_lt(absf(local.z), 0.8, stall_name + " keeper stands inside the stall, behind the counter")
		assert_between(local.y, 0.0, 0.35, stall_name + " keeper stands on the floor or a low hidden step")
		assert_almost_eq(keeper.global_basis.z.dot(stall.global_basis.z), 1.0, 0.01, stall_name + " faces the street")
	assert_eq(keepers.size(), STALLS.size())


func test_every_keeper_can_be_talked_to_from_the_street() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	for stall_name: String in STALLS:
		var stall: Node3D = _hub.get_node("Market/%sStall" % stall_name) as Node3D
		var keeper: Vendor = _hub.get_node("Market/%sKeeper" % stall_name) as Vendor
		var eye: Vector3 = stall.global_position + stall.global_basis.z * (COUNTER_FRONT + 0.6) + Vector3.UP * 1.6
		var chest: Vector3 = keeper.global_position + Vector3.UP * 1.3
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			eye, chest, Layers.INTERACTABLE | Layers.WORLD
		)
		ray.collide_with_areas = true
		assert_eq(space.intersect_ray(ray).get("collider"), keeper, stall_name + " keeper takes the look first")
