## Weapon-local hand targets and camera-relative shoulders for the shared arm rig.
class_name PlayerArmProfiles
extends RefCounted

const METADATA: String = "res://assets/models/characters/player_arm_grips.json"
const IDS: Array[StringName] = [
	&"rifle_ar",
	&"kestrel_smg",
	&"talon_dmr",
	&"brenner_trench",
	&"mako_pdw",
	&"atlas_auto",
	&"halberd_lmg",
	&"corvid_338",
	&"hollis_44",
	&"pistol_service",
	&"fieldhand_lever",
	&"ironwood_50",
	&"wren_mp",
	&"siphon",
	&"sentry_br3",
	&"nightjar_sd",
	&"rampart_br",
	&"cryo_lance",
	&"synapse",
	&"coachman_2b",
	&"grubber_sawnoff",
	&"bastion_lmg",
]
const RIGHT: Dictionary[StringName, Vector3] = {
	&"rifle_ar": Vector3(0, -.129, -.111),
	&"talon_dmr": Vector3(0, -.13325, -.108),
	&"kestrel_smg": Vector3(0, -.109, -.105),
	&"mako_pdw": Vector3(0, -.121, -.097),
	&"atlas_auto": Vector3(0, -.127, -.11525),
	&"halberd_lmg": Vector3(0, -.13375, -.1155),
	&"hollis_44": Vector3(0, -.0575, -.069),
	&"pistol_service": Vector3(0, -.046, -.064),
	&"corvid_338": Vector3(0, -.110, -.095),
	&"brenner_trench": Vector3(0, -.134, -.020),
	&"fieldhand_lever": Vector3(-.008, -.145, -.050),
	&"ironwood_50": Vector3(0, -.159, -.122),
	&"wren_mp": Vector3(.002, -.067, -.073),
	&"siphon": Vector3(0, -.108, -.127),
	&"sentry_br3": Vector3(0, -.124, -.107),
	&"nightjar_sd": Vector3(0, -.1165, -.102),
	&"rampart_br": Vector3(0, -.1555, -.119),
	&"cryo_lance": Vector3(0, -.126, -.100),
	&"synapse": Vector3(0, -.1335, -.098),
	&"coachman_2b": Vector3(0, -.140, -.015),
	&"grubber_sawnoff": Vector3(0, -.121, -.067),
	&"bastion_lmg": Vector3(0, -.1445, -.123),
}
const LEFT: Dictionary[StringName, Vector3] = {
	&"rifle_ar": Vector3(0, .220, .016),
	&"talon_dmr": Vector3(0, .220, .016),
	&"kestrel_smg": Vector3(0, .175, .008),
	&"mako_pdw": Vector3(0, .178, -.040),
	&"atlas_auto": Vector3(0, .220, .025),
	&"halberd_lmg": Vector3(-.021, .219, .030),
	&"brenner_trench": Vector3(0, .260, -.005),
	&"corvid_338": Vector3(0, .210, -.0241667),
	&"hollis_44": Vector3(-.0085, -.0475, -.080),
	&"pistol_service": Vector3(.007678149, -.036, -.075),
	&"fieldhand_lever": Vector3(0, .195, -.031),
	&"ironwood_50": Vector3(0, .220, .018),
	&"wren_mp": Vector3(.006301256, -.057, -.084),
	&"siphon": Vector3(-.030, .110, -.020),
	&"sentry_br3": Vector3(0, .215, -.028),
	&"nightjar_sd": Vector3(0, .190, .014),
	&"rampart_br": Vector3(0, .210, .016),
	&"cryo_lance": Vector3(-.030, .205, .035),
	&"synapse": Vector3(0, .195, .024),
	&"coachman_2b": Vector3(0, .155, .005),
	&"grubber_sawnoff": Vector3(0, .115, -.009),
	&"bastion_lmg": Vector3(-.045, .210, .045),
}

static var _geometry: Dictionary = {}


class Hand:
	extends RefCounted
	var wrist: Vector3
	var rotation: Basis
	var shoulder: Vector3
	## Lateral response to weapon height: x when lowering, y when raising.
	var shoulder_sway: Vector2 = Vector2.ZERO
	## Maximum vertical and fore/aft accommodation while the weapon rises.
	var shoulder_lift: Vector2 = Vector2(.07, .112)
	var shoulder_drop: float = 0.0
	## Camera-space shoulder offset blended by the weapon’s existing sprint progress.
	var shoulder_sprint_offset: Vector3 = Vector3.ZERO
	var source_index: Vector3
	var source_thumb: Vector3


class Profile:
	extends RefCounted
	var id: StringName
	var morph: StringName
	var hip_position: Vector3
	var right: Hand
	var left: Hand
	var support_part: NodePath


static func weapon_ids() -> Array[StringName]:
	return IDS.duplicate()


static func profile(weapon_id: StringName) -> Profile:
	var id: StringName = StringName(String(weapon_id).trim_suffix("_reforged"))
	var source: Dictionary = _source(id)
	if source.is_empty() or not RIGHT.has(id) or not LEFT.has(id):
		push_error("Missing authored arm grip profile: " + String(id))
		return null
	var result: Profile = Profile.new()
	result.id = id
	result.morph = StringName(source["morph"])
	result.hip_position = (load("res://content/weapons/%s.tres" % id) as WeaponData).hip_position
	var stock: bool = id in [&"brenner_trench", &"coachman_2b"]
	var handgun: bool = id in [&"hollis_44", &"pistol_service", &"wren_mp"]
	var right_forward: Vector3 = Vector3(-.45, .8, sqrt(.1575)) if stock else Vector3(0, sqrt(.75), .5)
	var right_dorsal: Vector3 = Vector3(.287252039, .550451875, -.783893526) if stock else Vector3.RIGHT
	var right_shoulder: Vector3 = Vector3(.25, -.225, -.234) if stock else Vector3(.19, -.115, -.234)
	if handgun:
		right_shoulder = Vector3(.19, -.155, -.234)
	if id == &"grubber_sawnoff":
		right_shoulder = Vector3(.19, -.225, -.234)
	if id == &"fieldhand_lever":
		right_shoulder = Vector3(.19, -.10, -.234)
		right_forward = Vector3(-.1, .76220458746, .63956558704)
		right_dorsal = Vector3.RIGHT
	var left_forward: Vector3 = (
		Vector3(.7, .49, sqrt(.2699)) if handgun else Vector3(.8 * sqrt(.96), .6 * sqrt(.96), .2)
	)
	var left_dorsal: Vector3 = (
		Vector3(-sqrt(.51), .7 * .49 / sqrt(.51), .7 * sqrt(.2699) / sqrt(.51))
		if handgun
		else Vector3(.16, .12, -sqrt(.96))
	)
	var left_shoulder: Vector3 = Vector3(-.14, -.02 if handgun else .03, -.234)
	if id == &"halberd_lmg":
		left_dorsal = Vector3(-.5090923495, .7927965138, -.3351099332)
		left_shoulder = Vector3(-.115, .032, -.234)
	elif id == &"siphon":
		left_dorsal = Vector3(-.26310545, .60615542, -.75056720)
	elif id == &"bastion_lmg":
		left_forward = Vector3(.85, .487339705, .2)
		left_dorsal = Vector3(-.173505515, -.099477805, .979795873)
		left_shoulder = Vector3(-.155, .030, -.220)
	elif id == &"rampart_br":
		left_shoulder = Vector3(-.125, .030, -.234)
	result.right = _hand("R", RIGHT[id], source["R"], right_forward, right_dorsal, right_shoulder)
	result.left = _hand("L", LEFT[id], source["L"], left_forward, left_dorsal, left_shoulder)
	_shoulder_motion(result)
	result.support_part = ^"Shotgun/Receiver/Bolt" if id == &"brenner_trench" else NodePath()
	return result


static func _shoulder_motion(result: Profile) -> void:
	if result.id == &"coachman_2b":
		result.right.shoulder_lift = Vector2(.07, .038)
	elif result.id == &"grubber_sawnoff":
		result.right.shoulder_lift = Vector2(.07, .035)
	elif result.id == &"bastion_lmg":
		result.left.shoulder_sway = Vector2(.5, -.9)
		result.left.shoulder_lift = Vector2(.055, .112)
	if result.id in [&"brenner_trench", &"coachman_2b"]:
		result.right.shoulder_sprint_offset = Vector3(0, -.04, -.10)


static func _source(id: StringName) -> Dictionary:
	if _geometry.is_empty() and FileAccess.file_exists(METADATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METADATA))
		if parsed is Dictionary:
			_geometry = (parsed as Dictionary).get("profiles", {}) as Dictionary
	return _geometry.get(String(id), {}) as Dictionary


static func _hand(
	side: String, anchor: Vector3, source: Dictionary, forward: Vector3, dorsal: Vector3, shoulder: Vector3
) -> Hand:
	var sign_x: float = -1.0 if side == "R" else 1.0
	var rest_forward: Vector3 = Vector3(sign_x, 0, -1).normalized()
	var rotation: Basis = _basis(forward, dorsal) * _basis(rest_forward, Vector3(0, 1, 0)).inverse()
	var centre: Vector3 = _vector(source["center"])
	var rest_wrist: Vector3 = Vector3(sign_x * .61, 0, 1.05)
	var conversion: Basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var result: Hand = Hand.new()
	result.wrist = conversion * (anchor - rotation * (centre - rest_wrist))
	result.rotation = conversion * rotation * conversion.inverse()
	result.shoulder = conversion * shoulder
	result.shoulder_drop = .35 if side == "L" else 0.0
	result.source_index = conversion * _vector(source["index"])
	result.source_thumb = conversion * _vector(source["thumb"])
	return result


static func _basis(forward: Vector3, dorsal: Vector3) -> Basis:
	var axis: Vector3 = forward.normalized()
	var outward: Vector3 = (dorsal - axis * dorsal.dot(axis)).normalized()
	return Basis(outward.cross(axis), outward, axis)


static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
