## Zombie models in game: each enemy type loads its code-built model, the head
## hit zone rides on the head bone, and code-driven poses move the skeleton.
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
	assert_eq(_skeleton(zombie.visual).get_bone_count(), 22, "walker shares the character skeleton")


func test_head_zone_follows_the_head_bone_when_it_turns() -> void:
	var zombie: Zombie = _spawn(WALKER)
	zombie.set_process(false)
	zombie.set_physics_process(false)
	assert_eq(zombie.head_zone.get_parent(), zombie.visual.head, "head zone is on the model's head center")
	var anchor: BoneAttachment3D = zombie.visual.head.get_parent() as BoneAttachment3D
	assert_not_null(anchor, "head center rides a BoneAttachment3D")
	assert_eq(anchor.bone_name, &"head")
	assert_eq(zombie.head_zone.zone, DamageInfo.Zone.HEAD)
	zombie.visual.position = Vector3.ZERO
	var height: float = zombie.head_zone.global_position.y - zombie.global_position.y
	assert_between(height, 1.55, 1.9, "head zone sits at head height")
	var forward: float = (zombie.head_zone.global_position - zombie.global_position).dot(-zombie.global_basis.z)
	assert_gt(forward, 0.0, "model faces the zombie's forward (-Z)")
	var skeleton: Skeleton3D = _skeleton(zombie.visual)
	var bone: int = skeleton.find_bone("head")
	var before: Transform3D = zombie.head_zone.global_transform
	var rotation: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, rotation * Quaternion(Vector3.UP, 0.7))
	skeleton.force_update_all_bone_transforms()
	await wait_process_frames(1)
	var expected: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	expected = expected * zombie.visual.head.transform * zombie.head_zone.transform
	assert_almost_eq(zombie.head_zone.global_position.distance_to(expected.origin), 0.0, 0.001)
	assert_false(zombie.head_zone.global_basis.is_equal_approx(before.basis), "head zone turns with the head bone")
	assert_gt(zombie.head_zone.global_position.distance_to(before.origin), 0.01, "head center follows the turn")


func test_walk_swings_legs_in_opposite_directions() -> void:
	var zombie: Zombie = _spawn(WALKER)
	var rig: ZombieRig = zombie.visual
	var left: Array[float] = []
	var right: Array[float] = []
	for i: int in 20:
		rig.pose_walk(2.0, 0.0, 0.05)
		left.append(_bone_offset(rig, "thigh_L").x)
		right.append(_bone_offset(rig, "thigh_R").x)
		assert_almost_eq(rig.get_offset(&"LegL").x, left[-1], 0.001, "legacy offset reads the thigh pose")
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
	for bone: String in ["upperarm_L", "upperarm_R"]:
		assert_almost_eq(_bone_offset(rig, bone).x, -ZombieRig.ATTACK_LIFT, 0.01, "both upperarms lift")
	assert_lt(_bone_offset(rig, "forearm_L").x, -0.3, "elbow bends during the swing")
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


func test_walk_cycle_steps_twice_per_cycle() -> void:
	var zombie: Zombie = _spawn(WALKER)
	zombie.set_process(false)
	var rig: ZombieRig = zombie.visual
	var steps: Array[int] = [0]
	rig.stepped.connect(func() -> void: steps[0] += 1)
	var speed: float = 2.0
	var cycle: float = TAU / (1.5 + speed * 2.5)
	for i: int in 300:
		rig.pose_walk(speed, 0.0, cycle * 3.0 / 300.0)
	assert_between(steps[0], 5, 7, "two footsteps per walk cycle")
	steps[0] = 0
	for i: int in 300:
		rig.pose_walk(0.1, 0.0, 0.01)
	assert_eq(steps[0], 0, "no footsteps while shuffling on the spot")


func test_dying_zombie_says_a_death_sound_once() -> void:
	var zombie: Zombie = _spawn(WALKER)
	await wait_process_frames(1)
	zombie.health.take_damage(DamageInfo.create(99999.0, null))
	await wait_process_frames(2)
	assert_true(zombie.voice.stream in zombie.data.death_sounds, "death sound plays")
	zombie.voice.stream = null
	zombie.voice.show_state(Zombie.State.DEAD)
	assert_null(zombie.voice.stream, "the death plays only once")


func test_voice_waiting_for_sync_stays_silent_for_an_old_corpse() -> void:
	var zombie: Zombie = _spawn(WALKER)
	zombie.voice.waiting_for_sync = true
	zombie.voice.show_state(Zombie.State.DEAD)
	assert_null(zombie.voice.stream, "nothing plays before the first sync")
	zombie.voice.start_state(Zombie.State.DEAD)
	zombie.voice.show_state(Zombie.State.DEAD)
	assert_null(zombie.voice.stream, "a corpse already down at the first sync stays silent")
	assert_false(zombie.voice.is_processing(), "and does not groan")
	var live: Zombie = _spawn(WALKER)
	live.voice.waiting_for_sync = true
	live.voice.start_state(Zombie.State.CHASING)
	live.voice.show_state(Zombie.State.DEAD)
	assert_true(live.voice.stream in live.data.death_sounds, "a death after the first sync is heard")


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
	assert_eq(zombie.voice.deaths, zombie.data.death_sounds)
	assert_eq(zombie.voice.footsteps, zombie.data.footstep_sounds)


func test_bloater_has_its_own_model_and_wider_body() -> void:
	var zombie: Zombie = _spawn(BLOATER)
	assert_not_null(zombie.visual.find_child("Belly", true, false), "bloater model loaded")
	assert_eq(zombie.head_zone.get_parent(), zombie.visual.head, "bloater head zone on its head")
	var body: CollisionShape3D = zombie.get_node("HitZones/Body/Shape") as CollisionShape3D
	assert_gt((body.shape as BoxShape3D).size.x, 0.9, "body zone covers the wide belly")
	var belly: Node3D = zombie.visual.find_child("Belly", true, false) as Node3D
	zombie.visual.pulse_belly()
	assert_gt((belly.get_parent() as Node3D).scale.x, 1.0, "belly swells when hit")


func test_belly_pulse_stays_centered_and_follows_the_spine() -> void:
	var zombie: Zombie = _spawn(BLOATER)
	zombie.set_process(false)
	zombie.set_physics_process(false)
	zombie.visual.position = Vector3.ZERO
	var belly: MeshInstance3D = zombie.visual.find_child("Belly", true, false) as MeshInstance3D
	var pulse: Node3D = belly.get_parent() as Node3D
	var attachment: BoneAttachment3D = pulse.get_parent() as BoneAttachment3D
	assert_eq(attachment.bone_name, &"spine_01")
	assert_null(belly.skin, "rigid bone attachment replaces skinning for the centered pulse")
	assert_true(belly.skeleton.is_empty())
	var center: Vector3 = belly.global_transform * belly.get_aabb().get_center()
	var size: Vector3 = (belly.global_transform * belly.get_aabb()).size
	zombie.visual.pulse_belly()
	assert_almost_eq(belly.global_transform * belly.get_aabb().get_center(), center, Vector3.ONE * 0.001)
	assert_almost_eq((belly.global_transform * belly.get_aabb()).size, size * 1.12, Vector3.ONE * 0.001)
	var skeleton: Skeleton3D = _skeleton(zombie.visual)
	var bone: int = skeleton.find_bone("spine_01")
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, 0.4))
	skeleton.force_update_all_bone_transforms()
	await wait_process_frames(1)
	var expected: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(bone) * pulse.transform).origin
	assert_almost_eq(belly.global_transform * belly.get_aabb().get_center(), expected, Vector3.ONE * 0.001)
	assert_gt(center.distance_to(expected), 0.02, "belly center follows the spine instead of staying at rest")


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
	assert_eq(zombie.entry.vault_progress(), -1.0, "not vaulting outside a window")


func test_walk_and_vault_bend_the_new_elbows_and_knees() -> void:
	var rig: ZombieRig = _spawn(WALKER).visual
	rig.pose_walk(2.0, 0.0, 0.15)
	assert_lt(_bone_offset(rig, "forearm_L").x, -0.1, "walk has a slight elbow bend")
	assert_gt(_bone_offset(rig, "shin_L").x, 0.1, "forward knee bends")
	rig.pose_vault(0.5)
	assert_gt(_bone_offset(rig, "shin_L").x, 0.7, "vault tucks the knees")
	assert_lt(_bone_offset(rig, "forearm_R").x, -0.3, "vault bends the elbows")


func test_crawler_keeps_the_skeleton_without_exposing_missing_legs() -> void:
	var rig: ZombieRig = ZombieRig.new()
	rig.model = load("res://assets/models/zombies/crawler.glb") as PackedScene
	add_child_autofree(rig)
	assert_eq(_skeleton(rig).get_bone_count(), 22)
	assert_true(rig.has_part(&"Head"))
	assert_false(rig.has_part(&"LegL"), "crawler has no visible legs")
	assert_false(rig.has_part(&"LegR"))
	rig.pose_walk(1.0, 1.0, 0.1)
	rig.pose_attack(1.0)
	rig.pose_vault(0.5)
	assert_eq(rig.get_offset(&"LegL"), Vector3.ZERO, "missing part retains the caller contract")
	assert_eq(rig.get_offset(&"Unknown"), Vector3.ZERO)


func _skeleton(rig: ZombieRig) -> Skeleton3D:
	return rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _bone_offset(rig: ZombieRig, bone_name: String) -> Vector3:
	var skeleton: Skeleton3D = _skeleton(rig)
	var bone: int = skeleton.find_bone(bone_name)
	var rest: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	var axes: Quaternion = skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	return (axes * rest.inverse() * skeleton.get_bone_pose_rotation(bone) * axes.inverse()).get_euler()
