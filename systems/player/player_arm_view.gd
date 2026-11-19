## One imported first-person arm rig per weapon holder, with Common cosmetic medium cuffs.
class_name PlayerArmView
extends Node3D

const ARMS: PackedScene = preload("res://assets/models/characters/player_arms.glb")
const CUFFS: PackedScene = preload("res://assets/models/gear/vest_medium.glb")
const COMMON: RarityLook = preload("res://content/looks/rarity/common.tres")
const PLACEHOLDERS: Array[String] = ["HandRight", "HandLeft", "SleeveRight", "SleeveLeft"]

static var _warned_no_grip: Dictionary[StringName, bool] = {}
static var _warned_reach: Dictionary[StringName, bool] = {}

var skeleton: Skeleton3D
var mesh: MeshInstance3D
var weapon: Weapon
var profile: PlayerArmProfiles.Profile

var _solver: PlayerArmPose
var _support: Node3D
var _support_rest: Vector3 = Vector3.ZERO
var _morph_index: int = -1
var _markers: Array[Node3D] = []
var _hand_rest: Array[Transform3D] = []


func _ready() -> void:
	process_priority = 1
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child(arms)
	skeleton = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	mesh = arms.find_child("PlayerArms", true, false) as MeshInstance3D
	_solver = PlayerArmPose.new(skeleton)
	for side: String in ["R", "L"]:
		_hand_rest.append(skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)))
		_markers.append(arms.find_child("GripIndexTip_" + side, true, false) as Node3D)
		_markers.append(arms.find_child("GripThumbTip_" + side, true, false) as Node3D)
	_attach_cuffs()
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.layers = ScopeLens.VIEWMODEL_LAYER
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GearLook.apply(self, COMMON, Color.WHITE, Color.WHITE)
	hide()


func bind_weapon(current: Weapon) -> void:
	weapon = current
	profile = null
	_support = null
	if current == null:
		hide()
		return
	profile = PlayerArmProfiles.profile(current.data)
	if profile == null:
		_warn_no_grip(current.data)
		hide()
		return
	var viewmodel: Node3D = current.get_node("Viewmodel").get_child(0) as Node3D
	for part: String in PLACEHOLDERS:
		var placeholder: Node3D = viewmodel.find_child(part, true, false) as Node3D
		if placeholder:
			placeholder.hide()
	_support = (
		viewmodel.get_node_or_null(profile.support_part) as Node3D if not profile.support_part.is_empty() else null
	)
	if _support and not _support.has_meta(&"arm_support_rest"):
		_support.set_meta(&"arm_support_rest", current.to_local(_support.global_position))
	_support_rest = (_support.get_meta(&"arm_support_rest", Vector3.ZERO) as Vector3 if _support else Vector3.ZERO)
	_select_grip()
	update_pose()


func _warn_no_grip(data: WeaponData) -> void:
	if data.grip != null or _warned_no_grip.has(data.id):
		return
	_warned_no_grip[data.id] = true
	Log.warn(&"player", &"weapon_has_no_grip", {"weapon": String(data.id)})


func _select_grip() -> void:
	if _morph_index >= 0:
		mesh.set_blend_shape_value(_morph_index, 0.0)
	_morph_index = (mesh.find_blend_shape_by_name(profile.morph) if not profile.morph.is_empty() else -1)
	if _morph_index >= 0:
		mesh.set_blend_shape_value(_morph_index, 1.0)
	_set_markers(0, profile.right)
	_set_markers(1, profile.left)


func _set_markers(index: int, grip: PlayerArmProfiles.Hand) -> void:
	var inverse: Transform3D = _hand_rest[index].affine_inverse()
	_markers[index * 2].position = inverse * grip.source_index
	_markers[index * 2 + 1].position = inverse * grip.source_thumb


func _process(_delta: float) -> void:
	update_pose()


func update_pose() -> void:
	visible = is_instance_valid(weapon) and profile != null and weapon.active and weapon.visible
	if not visible or not is_visible_in_tree():
		return
	var pump_delta: Vector3 = weapon.to_local(_support.global_position) - _support_rest if _support else Vector3.ZERO
	pump_delta += weapon.pose.reload_hand(profile.left.wrist + pump_delta)
	_solver.pose(profile, weapon.transform, pump_delta, weapon._sprint_progress, weapon.pose.reload_relax())
	if weapon.pose.motion and weapon.is_reloading() and not _warned_reach.has(weapon.data.id):
		_check_reach()


## How far the left forearm stretches past its length; zero when the hand target is reachable.
func left_reach_gap() -> float:
	var hand: int = skeleton.find_bone("hand_L")
	var forearm: int = skeleton.get_bone_parent(hand)
	var length: float = skeleton.get_bone_rest(hand).origin.length()
	var span: float = skeleton.get_bone_global_pose(forearm).origin.distance_to(
		skeleton.get_bone_global_pose(hand).origin
	)
	return absf(span - length)


func _check_reach() -> void:
	var gap: float = left_reach_gap()
	if gap > 0.02:
		_warned_reach[weapon.data.id] = true
		Log.warn(
			&"player", &"reload_motion_unreachable", {"weapon": String(weapon.data.id), "gap": snappedf(gap, 0.001)}
		)


func _attach_cuffs() -> void:
	var vest: Node3D = CUFFS.instantiate() as Node3D
	for side: String in ["R", "L"]:
		var cuff: Node3D = vest.find_child("CuffFP_" + side, true, false) as Node3D
		var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("forearm_" + side))
		var offset: Transform3D = rest.affine_inverse() * cuff.transform
		cuff.get_parent().remove_child(cuff)
		cuff.owner = null
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.bone_name = "forearm_" + side
		skeleton.add_child(attachment)
		attachment.add_child(cuff)
		cuff.transform = offset
	vest.free()
