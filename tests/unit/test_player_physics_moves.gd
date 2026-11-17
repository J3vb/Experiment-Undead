## Respawn moves and down/death rolls reach the owner's interpolated camera only
## on the physics tick (they arrive by RPC, outside it).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.input_enabled = false


func test_owner_teleport_outside_physics_waits_for_the_next_tick() -> void:
	var target: Transform3D = Transform3D(Basis(), Vector3(12.0, 0.0, -4.0))
	# Start outside a physics tick: the test before may have ended inside one.
	await wait_process_frames(1)
	player.teleport(target)
	assert_ne(player.global_position, target.origin, "no move outside the physics tick")
	await wait_physics_frames(1)
	assert_almost_eq(player.global_position.x, 12.0, 0.01)
	assert_almost_eq(player.global_position.z, -4.0, 0.01)
	assert_false(player._teleport_pending)


func test_teleport_moves_at_once_when_the_player_runs_no_physics() -> void:
	player.set_physics_process(false)
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player.teleport(Transform3D(Basis(), Vector3(5.0, 1.0, 2.0)))
	assert_eq(player.global_position, Vector3(5.0, 1.0, 2.0))
	assert_eq(player.velocity, Vector3.ZERO)


func test_tilt_steps_on_the_physics_tick() -> void:
	var tween: Tween = player.camera_rig.tilt(25.0, 0.2)
	assert_eq(player.camera_rig.rotation.z, 0.0)
	await wait_physics_frames(20)
	assert_false(tween.is_valid())
	assert_almost_eq(player.camera_rig.rotation.z, deg_to_rad(25.0), 0.001)


func test_asking_for_the_same_tilt_keeps_the_running_tween() -> void:
	var first: Tween = player.camera_rig.tilt(25.0, 0.4)
	assert_same(player.camera_rig.tilt(25.0, 0.4), first)
	assert_ne(player.camera_rig.tilt(0.0, 0.4), first)
	assert_false(first.is_valid(), "a new target replaces the old roll")
