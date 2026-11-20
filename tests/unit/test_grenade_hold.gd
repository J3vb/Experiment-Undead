## First-person frag hold (frag-grenades plan step 4): the left hand holds the frag while
## cooking, flicks it on release and is back on the grip when recover_time ends.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const DT: float = 0.02

var player: Player
var view: PlayerArmView


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.set_process(false)
	player.weapons.give(Content.weapon(&"rifle_ar")).set_process(false)
	view = player.weapons.arm_view
	view.set_process(false)


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		view._process(DT)


func _left_hand() -> Vector3:
	return view.skeleton.get_bone_global_pose(view.skeleton.find_bone("hand_L")).origin


func test_hold_rises_flicks_and_returns_within_recover_time() -> void:
	var hold: GrenadeHold = GrenadeHold.new()
	for i: int in 10:
		hold.step(true, DT, 0.5)
	assert_eq(hold.weight, 1.0, "fully up after the raise")
	assert_true(hold.shows_frag)
	assert_almost_eq(hold.frag_position(Vector3.ZERO).length(), 0.085, 0.001, "frag in the palm, not at the wrist")
	hold.step(false, DT, 0.5)
	assert_false(hold.shows_frag, "the thrown grenade takes over on release")
	assert_eq(hold.weight, 1.0, "still out during the flick")
	for i: int in 25:
		hold.step(false, DT, 0.5)
	assert_eq(hold.weight, 0.0, "back on the grip by recover_time")


func test_left_hand_holds_the_frag_at_full_cook_and_returns_to_the_grip() -> void:
	assert_eq(view.thrower, player.grenades)
	player.grenades.cooking = true
	_run(0.3)
	var holder: Node3D = player.weapons
	var target: Vector3 = holder.transform.affine_inverse() * view.grenade_hold.wrist_target()
	assert_almost_eq(_left_hand(), target, Vector3.ONE * 0.02, "left wrist at the hold spot")
	var hand: Basis = view.skeleton.get_bone_global_pose(view.skeleton.find_bone("hand_L")).basis
	var back: Vector3 = (holder.transform.basis.inverse() * GrenadeHold.BACK).normalized()
	var fingers: Vector3 = (holder.transform.basis.inverse() * GrenadeHold.FINGERS).normalized()
	assert_gt(hand.y.normalized().dot(fingers), 0.8, "fingers point forward and up, not back at the camera")
	var frag: Node3D = view.get_node("HeldFrag") as Node3D
	assert_gt((frag.position - _left_hand()).normalized().dot(-back), 0.3, "frag sits on the palm side")
	assert_true(frag.visible, "frag shown in the palm")
	assert_lt(frag.position.distance_to(_left_hand()), 0.1, "frag sits in the left hand")
	player.grenades.cooking = false
	_run(player.grenades.data.recover_time + DT)
	var grip: Vector3 = view.weapon.transform * view.profile.left.wrist
	assert_almost_eq(_left_hand(), grip, Vector3.ONE * 0.001, "left hand back on the grip")
	assert_false(frag.visible)
