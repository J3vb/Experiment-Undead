## Tripo zombies (F-86): Walkers show one of two Shambler looks picked from the synced net_id, the same on
## every peer; Bloaters and Glowers keep their own model; only the Bloater's pods swell on a hit.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const BLOATER: String = "res://content/enemies/zombie_bloater.tres"
const GLOWER: String = "res://content/enemies/zombie_glower.tres"
const LABTECH: String = "res://assets/models/zombies/shambler.glb"
const GUARD: String = "res://assets/models/zombies/shambler_guard.glb"


func _spawn(path: String, net_id: int = 1) -> Zombie:
	var data: EnemyData = load(path) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, net_id, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	add_child_autofree(zombie)
	return zombie


func test_walkers_show_both_shambler_looks_picked_from_net_id() -> void:
	var seen: Dictionary[String, bool] = {}
	for net_id: int in range(1, 9):
		var zombie: Zombie = _spawn(WALKER, net_id)
		var model: String = _model_path(zombie)
		assert_true(model in [LABTECH, GUARD], "walker shows a Shambler look, got " + model)
		seen[model] = true
		assert_eq(zombie.visual.look, hash(net_id), "look comes from the synced net_id")
		for part: StringName in ZombieRig.PARTS:
			assert_true(zombie.visual.has_part(part), "%s has %s" % [model, part])
		zombie.visual.position = Vector3.ZERO
		var height: float = zombie.head_zone.global_position.y - zombie.global_position.y
		assert_between(height, 1.5, 1.85, "%s head zone at head height" % model)
		var again: Zombie = _spawn(WALKER, net_id)
		assert_eq(_model_path(again), model, "the same net_id shows the same look on every peer")
	assert_eq(seen.size(), 2, "eight walkers show both looks")


func test_bloater_and_glower_never_take_a_shambler_look() -> void:
	for net_id: int in range(1, 9):
		assert_string_contains(_model_path(_spawn(BLOATER, net_id)), "bloater.glb")
		assert_string_contains(_model_path(_spawn(GLOWER, net_id)), "glower.glb")


func _model_path(zombie: Zombie) -> String:
	var skeleton: Skeleton3D = _skeleton(zombie.visual)
	return skeleton.owner.scene_file_path if skeleton.owner else ""


func test_belly_pulse_swells_the_bloater_pods_and_settles() -> void:
	var zombie: Zombie = _spawn(BLOATER)
	assert_eq(zombie.visual.pulse_amount(), 0.0)
	zombie.visual.pulse_belly()
	assert_gt(zombie.visual.pulse_amount(), 0.0, "a hit swells the pods")
	await wait_seconds(0.4)
	assert_almost_eq(zombie.visual.pulse_amount(), 0.0, 0.001, "the swell settles")


func test_walkers_and_glowers_do_not_swell_on_hits() -> void:
	for path: String in [WALKER, GLOWER]:
		var zombie: Zombie = _spawn(path)
		zombie.visual.pulse_belly()
		assert_eq(zombie.visual.pulse_amount(), 0.0, path + " keeps its shape")


func _skeleton(rig: ZombieRig) -> Skeleton3D:
	return rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
