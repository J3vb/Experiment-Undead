## Reload as weapon-local key poses. Magazine guns: the support hand carries the magazine out and back, and on
## an empty reload presses the bolt catch above the well so the bolt slams home. Times are fractions of the reload.
## Shell guns: each round is one cycle, the hand brings a shell up into the loading port; from empty it then racks.
## Cues name the sound moments (mag_out, mag_in, bolt, shell_in, pump) as times in the same fractions.
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
## Where the wrist sits relative to a shell's middle when the fingers push it into the port.
const SHELL_GRAB: Vector3 = Vector3(-0.035, -0.06, 0.07)
const SHELL_BELOW: Vector3 = Vector3(0.0, -0.035, 0.01)
## Shell cycle: shell shown from fetch to push, in the port by SHELL_IN.
const SHELL_IN: float = 0.7
const EMPTY_SHELL_IN: float = 0.42

var hand_target: Vector3 = Vector3.ZERO
var hand_weight: float = 0.0
## Offset of the magazine (or the loading shell) from its rest, weapon-local.
var mag_offset: Vector3 = Vector3.ZERO
## The loading shell is in the hand (shell guns only).
var part_shown: bool = false
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
	var shown: PackedFloat32Array = []
	var cue_times: PackedFloat32Array = []
	var cue_names: Array[StringName] = []


## mag_center: magazine middle, mag_top: its feed lip, mag_down: unit vector out of the well, all weapon-local.
static func for_magazine(mag_center: Vector3, mag_top: Vector3, mag_down: Vector3) -> ReloadMotion:
	var motion: ReloadMotion = ReloadMotion.new()
	motion._set_magazine(mag_center, mag_top, mag_down)
	return motion


## port: the loading shell's middle when it sits in the loading port, weapon-local.
static func for_shells(port: Vector3) -> ReloadMotion:
	var motion: ReloadMotion = ReloadMotion.new()
	var grab: Vector3 = port + SHELL_GRAB
	var below: Vector3 = grab + SHELL_BELOW
	var low: Vector3 = grab + DROP
	var z: Vector3 = Vector3.ZERO
	var keys: Keys = motion._tactical
	keys.times = PackedFloat32Array([0.0, 0.22, 0.32, 0.55, SHELL_IN, 1.0])
	keys.hand = PackedVector3Array([low, low, low, below, grab, grab])
	keys.mag = PackedVector3Array([DROP, DROP, DROP, SHELL_BELOW, z, z])
	keys.weight = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 0.0])
	keys.bolt = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	keys.roll = PackedFloat32Array([0.0, 0.6, 0.6, 0.6, 0.6, 0.0])
	keys.shown = PackedFloat32Array([0.0, 0.0, 1.0, 1.0, 1.0, 0.0])
	keys.cue_times = PackedFloat32Array([SHELL_IN])
	keys.cue_names = [&"shell_in"]
	keys = motion._empty
	keys.times = PackedFloat32Array([0.0, 0.12, 0.18, 0.33, EMPTY_SHELL_IN, 0.56, 0.68, 0.8, 1.0])
	keys.hand = PackedVector3Array([low, low, low, below, grab, grab, grab, grab, grab])
	keys.mag = PackedVector3Array([DROP, DROP, DROP, SHELL_BELOW, z, z, z, z, z])
	keys.weight = PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	keys.bolt = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0])
	keys.roll = PackedFloat32Array([0.0, 0.6, 0.6, 0.6, 0.6, 0.2, 0.0, 0.0, 0.0])
	keys.shown = PackedFloat32Array([0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	keys.cue_times = PackedFloat32Array([EMPTY_SHELL_IN, 0.58])
	keys.cue_names = [&"shell_in", &"pump"]
	return motion


func _set_magazine(mag_center: Vector3, mag_top: Vector3, mag_down: Vector3) -> void:
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
	_tactical.shown.resize(_tactical.times.size())
	_tactical.cue_times = PackedFloat32Array([0.2, SEATED])
	_tactical.cue_names = [&"mag_out", &"mag_in"]
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
	_empty.shown.resize(_empty.times.size())
	_empty.cue_times = PackedFloat32Array([0.15, EMPTY_SEATED, BOLT_RELEASE])
	_empty.cue_names = [&"mag_out", &"mag_in", &"bolt"]


## Builds the shell motion from a viewmodel's LoadShell node, or null when it has none.
static func from_shell(weapon: Node3D, shell: Node3D) -> ReloadMotion:
	if shell == null:
		return null
	return ReloadMotion.for_shells(weapon.to_local(shell.global_position))


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
	return ReloadMotion.for_magazine(center, to_weapon.origin, down)


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
	part_shown = (keys.shown[i] if k < 0.5 else keys.shown[i + 1]) > 0.5


## The sound moment the reload passed between two samples (from_t excluded), or &"" when none.
func cue_between(empty: bool, from_t: float, to_t: float) -> StringName:
	var keys: Keys = _empty if empty else _tactical
	for i: int in keys.cue_times.size():
		if keys.cue_times[i] > from_t and keys.cue_times[i] <= to_t:
			return keys.cue_names[i]
	return &""
