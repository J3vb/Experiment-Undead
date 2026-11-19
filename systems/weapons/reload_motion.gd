## Magazine reload as weapon-local key poses: the support hand carries the magazine out and back, and on
## an empty reload presses the bolt catch above the well so the bolt slams home. Times are fractions of the reload.
class_name ReloadMotion
extends RefCounted

## Ammo lands at 1.0, so the magazine must be home before this.
const SEATED: float = 0.75
const EMPTY_SEATED: float = 0.56
const BOLT_RELEASE: float = 0.8
const WELL_GAP: float = 0.08
const DROP: Vector3 = Vector3(-0.08, -0.08, 0.04)
## Where the wrist sits relative to the magazine's middle when the hand holds it.
const GRAB: Vector3 = Vector3(-0.045, -0.06, 0.06)
## Where the wrist sits relative to the magazine's feed lip when the thumb is on the bolt catch.
const CATCH: Vector3 = Vector3(-0.07, -0.03, 0.08)
const PRESS: Vector3 = Vector3(0.008, 0.004, 0.0)

var hand_target: Vector3 = Vector3.ZERO
var hand_weight: float = 0.0
var mag_offset: Vector3 = Vector3.ZERO
var bolt_back: float = 0.0
var roll: float = 0.0

var _tactical: Keys = Keys.new()
var _empty: Keys = Keys.new()


class Keys:
	extends RefCounted
	var times: PackedFloat32Array = []
	var hand: PackedVector3Array = []
	var mag: PackedVector3Array = []
	var weight: PackedFloat32Array = []
	var bolt: PackedFloat32Array = []
	var roll: PackedFloat32Array = []


## mag_center: magazine middle, mag_top: its feed lip, mag_down: unit vector out of the well, all weapon-local.
func _init(mag_center: Vector3, mag_top: Vector3, mag_down: Vector3) -> void:
	var grab: Vector3 = mag_center + GRAB
	var out: Vector3 = mag_down * WELL_GAP
	var low: Vector3 = DROP + out
	var slap_up: Vector3 = grab + Vector3(0.0, 0.012, 0.0)
	var slap_off: Vector3 = grab + Vector3(0.0, -0.04, 0.02)
	var catch: Vector3 = mag_top + CATCH
	var z: Vector3 = Vector3.ZERO
	_tactical.times = PackedFloat32Array([0.0, 0.12, 0.3, 0.45, 0.55, 0.65, SEATED, 0.78, 0.82, 1.0])
	_tactical.hand = PackedVector3Array(
		[grab, grab, grab + out, grab + low, grab + low, grab + out, grab, slap_up, slap_off, slap_off]
	)
	_tactical.mag = PackedVector3Array([z, z, out, low, low, out, z, z, z, z])
	_tactical.weight = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0])
	_tactical.bolt = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	_tactical.roll = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.0])
	_empty.times = PackedFloat32Array([0.0, 0.1, 0.28, 0.36, 0.48, EMPTY_SEATED, 0.62, 0.72, 0.77, BOLT_RELEASE, 1.0])
	_empty.hand = PackedVector3Array(
		[
			grab,
			grab + Vector3(0, -0.04, 0.03),
			grab + low,
			grab + low,
			grab + out,
			grab,
			slap_off,
			catch,
			catch + PRESS,
			catch,
			catch
		]
	)
	_empty.mag = PackedVector3Array([z, z, low, low, out, z, z, z, z, z, z])
	_empty.weight = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0])
	_empty.bolt = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0])
	_empty.roll = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.0])


## Builds the motion from a viewmodel's Magazine node, or null when it has none.
static func from_viewmodel(weapon: Node3D, magazine: Node3D) -> ReloadMotion:
	if magazine == null:
		return null
	var to_weapon: Transform3D = weapon.global_transform.affine_inverse() * magazine.global_transform
	var center: Vector3 = to_weapon.origin
	var mesh: MeshInstance3D = magazine as MeshInstance3D
	if mesh and mesh.mesh:
		center = to_weapon * mesh.get_aabb().get_center()
	var down: Vector3 = (center - to_weapon.origin).normalized() if center != to_weapon.origin else Vector3.DOWN
	return ReloadMotion.new(center, to_weapon.origin, down)


## Seated time for this reload kind: the magazine offset is zero from here to the end.
static func seated_at(empty: bool) -> float:
	return EMPTY_SEATED if empty else SEATED


func sample(empty: bool, t: float) -> void:
	var keys: Keys = _empty if empty else _tactical
	t = clampf(t, 0.0, 1.0)
	var i: int = 0
	while i < keys.times.size() - 2 and t >= keys.times[i + 1]:
		i += 1
	var span: float = maxf(keys.times[i + 1] - keys.times[i], 0.0001)
	var k: float = smoothstep(0.0, 1.0, clampf((t - keys.times[i]) / span, 0.0, 1.0))
	hand_target = keys.hand[i].lerp(keys.hand[i + 1], k)
	mag_offset = keys.mag[i].lerp(keys.mag[i + 1], k)
	hand_weight = lerpf(keys.weight[i], keys.weight[i + 1], k)
	bolt_back = lerpf(keys.bolt[i], keys.bolt[i + 1], k)
	roll = lerpf(keys.roll[i], keys.roll[i + 1], k)
