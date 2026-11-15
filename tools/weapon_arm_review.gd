## Captures actual weapon-holder arms at hip and ADS, with the same inspection camera.
extends "res://tools/character_review.gd"

var _holder: WeaponHolder
var _weapon: Weapon


func _capture() -> void:
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 110.0
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	(_booth.get_node("Floor") as MeshInstance3D).hide()
	_holder = WeaponHolder.new()
	_holder.max_slots = 1
	add_child(_holder)
	_holder.setup(null, _camera)
	_holder.set_process(false)
	var selected: PackedStringArray = OS.get_cmdline_user_args().slice(1)
	for id: StringName in PlayerArmProfiles.weapon_ids():
		if not selected.is_empty() and not String(id) in selected:
			continue
		await _weapon_views(id)
	print("Runtime weapon arm inspection saved to ", _out)
	get_tree().quit()


func _weapon_views(id: StringName) -> void:
	var data: WeaponData = load("res://content/weapons/%s.tres" % id) as WeaponData
	_weapon = _holder.give(data)
	if _holder.arm_view == null or _holder.arm_view.profile == null:
		push_error("Cannot inspect an unauthored weapon grip: " + String(id))
		get_tree().quit(1)
		return
	var morph: StringName = _holder.arm_view.profile.morph
	if not morph.is_empty() and _holder.arm_view.mesh.find_blend_shape_by_name(morph) < 0:
		push_error("Cannot inspect missing grip morph: " + String(morph))
		get_tree().quit(1)
		return
	_weapon.set_process(false)
	_holder.arm_view.set_process(false)
	for ads: bool in [false, true]:
		_set_stance(ads)
		for rarity: String in RARITIES:
			_runtime_look(rarity)
			var mode: String = "ads" if ads else "hip"
			var lens: String = "%.0f DEG VFOV" % data.ads_fov if ads else "110 DEG HFOV"
			var caption: String = "%s / %s / %s / RUNTIME POSE / %s" % [id, mode, rarity, lens]
			await _shot("%s_%s_%s" % [id, mode, rarity], caption.to_upper())
	_set_stance(false)
	await _hand_detail(id, "R")
	await _hand_detail(id, "L")
	_camera.fov = 60.0
	_camera.position = Vector3(1.1, -.18, -.23)
	_camera.look_at(Vector3(0, -.30, -.23))
	await _shot(String(id) + "_side", String(id).to_upper() + " / WHOLE RUNTIME ARM POSE")
	_camera.position = Vector3(-.45, -.62, -.20)
	_camera.look_at(Vector3(.08, -.26, -.32))
	await _shot(String(id) + "_under", String(id).to_upper() + " / BOTH GRIPS / UNDERSIDE")


func _set_stance(ads: bool) -> void:
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT if ads else Camera3D.KEEP_WIDTH
	_camera.fov = _weapon.data.ads_fov if ads else 110.0
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	_holder.set_state(ads, false, 0.0)
	for _step: int in 120:
		_holder.tick(1.0 / 60.0)
		_weapon._process(1.0 / 60.0)
	_holder.arm_view.update_pose()


func _runtime_look(rarity: String) -> void:
	var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
	GearLook.apply(_holder.arm_view, look, Color.WHITE, Color.WHITE)
	for node: Node in _holder.arm_view.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter(&"pulse_seconds", 0.0)


func _hand_detail(id: StringName, side: String) -> void:
	var skeleton: Skeleton3D = _holder.arm_view.skeleton
	var hand: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
	)
	var target: Vector3 = hand.origin + hand.basis.y * .075
	var rest: Basis = skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)).basis
	var dorsal: Vector3 = hand.basis * rest.inverse() * Vector3.FORWARD
	var offset: Vector3 = (dorsal + Vector3.DOWN * .3 + hand.basis.y * .15).normalized() * .5
	_camera.fov = 50.0
	_camera.position = target + offset
	_camera.look_at(target)
	await _shot("%s_%s" % [id, side.to_lower()], "%s / %s HAND / RUNTIME CONTACT" % [String(id).to_upper(), side])
