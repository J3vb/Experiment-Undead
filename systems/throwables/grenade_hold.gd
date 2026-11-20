## First-person frag motion for the left hand (visual only): while cooking the hand leaves the
## gun and holds the frag low in view, on release it flicks forward, then it eases back to the
## grip so it is home when the throw's recover_time ends. PlayerArmView steps and reads it.
class_name GrenadeHold
extends RefCounted

const RAISE_TIME: float = 0.15
const FLICK_TIME: float = 0.12
## Camera-space wrist spot while cooking: low left, in view.
const HOLD: Vector3 = Vector3(-0.15, -0.13, -0.34)
## Camera-space wrist spot at the end of the flick.
const FLICK: Vector3 = Vector3(-0.06, -0.04, -0.52)
## Camera-space hand turn while holding: fingers forward and up, back of the hand down and out,
## so the palm faces up under the frag and the fingers close over it.
const FINGERS: Vector3 = Vector3(0.25, 0.35, -1.0)
const BACK: Vector3 = Vector3(-0.45, -1.0, -0.1)
## Frag centre from the wrist: along the fingers and off the palm, in metres.
const ALONG_FINGERS: float = 0.06
const OFF_PALM: float = 0.045

## How far the hand is off its grip: 0 on the gun, 1 at the hold spot.
var weight: float = 0.0
## True while the frag is in the hand (cooking); the thrown grenade takes over on release.
var shows_frag: bool = false
var _flick: float = 0.0
var _return_left: float = 0.0
var _return_time: float = 0.0


func step(cooking: bool, delta: float, recover_time: float) -> void:
	if cooking:
		shows_frag = true
		_flick = 0.0
		_return_left = 0.0
		weight = minf(weight + delta / RAISE_TIME, 1.0)
		return
	if shows_frag:
		shows_frag = false
		_flick = FLICK_TIME
		_return_time = maxf(recover_time - FLICK_TIME, 0.01)
		_return_left = _return_time
	if _flick > 0.0:
		_flick = maxf(_flick - delta, 0.0)
		return
	if _return_left > 0.0:
		_return_left = maxf(_return_left - delta, 0.0)
		weight = minf(weight, _return_left / _return_time)
		return
	weight = maxf(weight - delta / RAISE_TIME, 0.0)


## Where the left wrist goes, in camera space.
func wrist_target() -> Vector3:
	var t: float = 1.0 - _flick / FLICK_TIME if _flick > 0.0 or _return_left > 0.0 else 0.0
	return HOLD.lerp(FLICK, t)


## Camera-space frag centre for a wrist at `wrist`.
func frag_position(wrist: Vector3) -> Vector3:
	return wrist + FINGERS.normalized() * ALONG_FINGERS - BACK.normalized() * OFF_PALM
