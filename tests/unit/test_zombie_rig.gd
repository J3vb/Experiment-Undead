## Zombie models in game: each enemy type loads its code-built model, the head
## hit zone rides on the model's head, and the code-driven poses move the limbs.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const BLOATER: String = "res://content/enemies/zombie_bloater.tres"


func _spawn(path: String) -> Zombie:
	var data: EnemyData = load(path) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, 1, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	add_child_autofree(zombie)
	return zombie


func test_walker_uses_shambler_model_with_all_limbs() -> void:
	var zombie: Zombie = _spawn(WALKER)
	for part: StringName in ZombieRig.PARTS:
		assert_true(zombie.visual.has_part(part), "walker model has " + part)
	assert_not_null(zombie.visual.find_child("CoatSkirt", true, false), "walker wears the Shambler lab coat")


func test_head_zone_follows_the_model_head() -> void:
	var zombie: Zombie = _spawn(WALKER)
	assert_eq(zombie.head_zone.get_parent(), zombie.visual.head, "head zone is a child of the model's Head")
	assert_eq(zombie.head_zone.zone, DamageInfo.Zone.HEAD)
	zombie.visual.position = Vector3.ZERO
	var height: float = zombie.head_zone.global_position.y - zombie.global_position.y
	assert_between(height, 1.55, 1.9, "head zone sits at head height")
	var forward: float = (zombie.head_zone.global_position - zombie.global_position).dot(-zombie.global_basis.z)
	assert_gt(forward, 0.0, "model faces the zombie's forward (-Z)")


func test_walk_swings_legs_in_opposite_directions() -> void:
	var zombie: Zombie = _spawn(WALKER)
	var rig: ZombieRig = zombie.visual
	var left: Array[float] = []
	var right: Array[float] = []
	for i: int in 20:
		rig.pose_walk(2.0, 0.0, 0.05)
		left.append(rig.get_offset(&"LegL").x)
		right.append(rig.get_offset(&"LegR").x)
	assert_gt(left.max(), 0.3, "left leg swings forward and back")
	assert_lt(left.min(), -0.3)
	for i: int in left.size():
		assert_almost_eq(left[i], -right[i], 0.001, "legs move opposite")


func test_reach_lifts_the_arms() -> void:
	var zombie: Zombie = _spawn(WALKER)
	var rig: ZombieRig = zombie.visual
	rig.pose_walk(0.0, 0.0, 0.0)
	var relaxed: float = rig.get_offset(&"ArmL").x
	rig.pose_walk(0.0, 1.0, 0.0)
	assert_lt(rig.get_offset(&"ArmL").x, relaxed - 0.3, "close target: arms come up")


func test_attack_raises_then_slams_arms() -> void:
	var zombie: Zombie = _spawn(WALKER)
	var rig: ZombieRig = zombie.visual
	rig.pose_attack(0.0)
	assert_almost_eq(rig.get_offset(&"ArmR").x, 0.0, 0.01, "attack starts from rest")
	rig.pose_attack(1.0)
	assert_almost_eq(rig.get_offset(&"ArmR").x, -ZombieRig.ATTACK_LIFT, 0.01, "arms high at end of wind-up")
	rig.pose_attack(2.0)
	assert_almost_eq(rig.get_offset(&"ArmR").x, ZombieRig.ATTACK_DROP, 0.01, "arms slammed down after strike")


func test_death_disables_hit_zones_and_goes_limp() -> void:
	var zombie: Zombie = _spawn(WALKER)
	zombie.health.take_damage(DamageInfo.create(99999.0, null))
	assert_eq(zombie.state, Zombie.State.DEAD)
	assert_eq(zombie.head_zone.collision_layer, 0, "head zone off when dead")
	await wait_seconds(0.5)
	assert_gt(zombie.visual.get_offset(&"ArmL").x, 0.5, "arms fall slack")
	assert_lt(zombie.visual.rotation.x, -1.0, "body tipped over")
	assert_false(zombie.voice.is_processing(), "dead zombies stop groaning")


func test_rising_zombie_climbs_out_of_the_floor() -> void:
	var zombie: Zombie = _spawn(WALKER)
	zombie.state_time = 0.0
	zombie.visual.follow(zombie, 0.0)
	assert_almost_eq(zombie.visual.position.y, -1.8, 0.01, "starts under the floor")
	zombie.state_time = Zombie.SPAWN_TIME
	zombie.visual.follow(zombie, 0.0)
	assert_almost_eq(zombie.visual.position.y, 0.0, 0.01, "standing at the end of the rise")


func test_voice_gets_the_enemy_groans() -> void:
	var zombie: Zombie = _spawn(WALKER)
	assert_eq(zombie.voice.groans, zombie.data.groan_sounds)


func test_bloater_has_its_own_model_and_wider_body() -> void:
	var zombie: Zombie = _spawn(BLOATER)
	assert_not_null(zombie.visual.find_child("Belly", true, false), "bloater model loaded")
	assert_eq(zombie.head_zone.get_parent(), zombie.visual.head, "bloater head zone on its head")
	var body: CollisionShape3D = zombie.get_node("HitZones/Body/Shape") as CollisionShape3D
	assert_gt((body.shape as BoxShape3D).size.x, 0.9, "body zone covers the wide belly")
	var belly: Node3D = zombie.visual.find_child("Belly", true, false) as Node3D
	zombie.visual.pulse_belly()
	assert_gt(belly.scale.x, 1.0, "belly swells when hit")


func test_moving_limbs_skip_lightmap_probes() -> void:
	for path: String in [WALKER, BLOATER]:
		var zombie: Zombie = _spawn(path)
		var meshes: Array[Node] = zombie.visual.find_children("*", "GeometryInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has meshes" % path)
		for mesh: Node in meshes:
			var gi: int = (mesh as GeometryInstance3D).gi_mode
			assert_eq(gi, GeometryInstance3D.GI_MODE_DISABLED, "%s: no per-frame probe capture" % mesh.name)


func test_vault_pose_hops_and_reaches_forward() -> void:
	var zombie: Zombie = _spawn(WALKER)
	var rig: ZombieRig = zombie.visual
	rig.pose_vault(0.0)
	assert_almost_eq(rig.position.y, 0.0, 0.001, "starts on the ground")
	assert_lt(rig.get_offset(&"ArmL").x, -1.0, "hands reach for the sill")
	rig.pose_vault(0.5)
	assert_almost_eq(rig.position.y, ZombieRig.VAULT_HEIGHT, 0.001, "top of the hop")
	assert_gt(rig.get_offset(&"Torso").x, 0.4, "body pitches forward over the sill")
	assert_lt(rig.get_offset(&"LegL").x, -0.5, "legs tuck")
	rig.pose_vault(1.0)
	assert_almost_eq(rig.position.y, 0.0, 0.001, "lands")
	assert_eq(zombie.vault_progress(), -1.0, "not vaulting outside a window")
