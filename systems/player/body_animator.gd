## Plays the third-person body clips from the player's measured movement, crouch and downed state.
## Visual only: works the same for the owner's shadow body and for remote teammates.
class_name BodyAnimator
extends Node

## Ground speed (m/s) at which each clip's feet stay planted, from the stride and
## cycle length in tools/assets/player_clips.py. The tree speeds clips up past them.
const WALK_CLIP_SPEED: float = 3.1
const RUN_CLIP_SPEED: float = 5.5
const CROUCH_CLIP_SPEED: float = 1.6
const MAX_TIME_SCALE: float = 1.7
## A position jump faster than this is a teleport (respawn), not movement.
const TELEPORT_SPEED: float = 20.0
const SMOOTHING: float = 12.0
## Downed players crawl at this share of walk speed (Player._move).
const DOWNED_SPEED_SHARE: float = 0.2
const FADE_TIME: float = 0.2
const GROUND: StringName = &"ground"
const CROUCH: StringName = &"crouch"
const DOWNED: StringName = &"downed"
const STATE_REQUEST: StringName = &"parameters/state/transition_request"
const STATE_CURRENT: StringName = &"parameters/state/current_state"
const GROUND_BLEND: StringName = &"parameters/ground/blend_position"
const CROUCH_BLEND: StringName = &"parameters/crouch/blend_position"
const DOWNED_BLEND: StringName = &"parameters/downed/blend_position"
const TIME_SCALE: StringName = &"parameters/speed/scale"

@export var player: Player
## The imported player.glb instance that holds the Skeleton3D and AnimationPlayer.
@export var model: Node3D
## The synced head pivot whose pitch the chest and head follow.
@export var pitch_source: Node3D

## No screen (dedicated server, headless soak): nothing is posed. Tests clear it before _ready.
var headless: bool = DisplayServer.get_name() == "headless"
var tree: AnimationTree
var aim: AimPitch
var local_velocity: Vector3 = Vector3.ZERO

var _last_position: Vector3 = Vector3.ZERO
var _state: StringName = GROUND


func _ready() -> void:
	if headless:
		set_physics_process(false)
		return
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(&"run"):
		Log.warn(&"player", &"body_clips_missing", {"model": model.scene_file_path})
		headless = true
		set_physics_process(false)
		return
	var anim: AnimationPlayer = players[0] as AnimationPlayer
	tree = AnimationTree.new()
	tree.name = "BodyTree"
	tree.tree_root = _build_tree(player.walk_speed, player.sprint_speed)
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	tree.set(STATE_REQUEST, String(GROUND))
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	aim = AimPitch.new()
	aim.name = "AimPitch"
	aim.pitch_source = pitch_source
	skeleton.add_child(aim)
	_last_position = player.global_position


func _physics_process(delta: float) -> void:
	var position: Vector3 = player.global_position
	var raw: Vector3 = (position - _last_position) / maxf(delta, 0.0001)
	_last_position = position
	raw.y = 0.0
	if raw.length() > TELEPORT_SPEED:
		raw = Vector3.ZERO
	var local: Vector3 = player.global_basis.inverse() * raw
	local_velocity = local_velocity.lerp(local, 1.0 - exp(-SMOOTHING * delta))
	_apply(pick_state(player.is_downed, player.is_crouching))


## Downed wins over crouch, crouch over standing.
static func pick_state(downed: bool, crouching: bool) -> StringName:
	if downed:
		return DOWNED
	return CROUCH if crouching else GROUND


func _apply(state: StringName) -> void:
	if state != _state:
		_state = state
		tree.set(STATE_REQUEST, String(state))
	var speed: float = Vector2(local_velocity.x, local_velocity.z).length()
	var walk: float = player.walk_speed
	tree.set(GROUND_BLEND, Vector2(local_velocity.x, -local_velocity.z) / walk)
	tree.set(CROUCH_BLEND, clampf(speed / (walk * player.crouch_speed_multiplier), 0.0, 1.0))
	tree.set(DOWNED_BLEND, clampf(speed / (walk * DOWNED_SPEED_SHARE), 0.0, 1.0))
	tree.set(TIME_SCALE, time_scale(state, speed, walk))


## Speeds clips up when the body moves faster than the clip's own stride, so feet do not slide.
static func time_scale(state: StringName, speed: float, walk: float) -> float:
	var clip_speed: float = WALK_CLIP_SPEED
	if state == CROUCH:
		clip_speed = CROUCH_CLIP_SPEED
	elif state == GROUND and speed > walk * 1.05:
		clip_speed = RUN_CLIP_SPEED
	elif state == DOWNED:
		return 1.0
	return clampf(speed / clip_speed, 1.0, MAX_TIME_SCALE)


func _build_tree(walk: float, sprint: float) -> AnimationNodeBlendTree:
	var ground: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	var reach: float = sprint / walk
	ground.min_space = Vector2(-1.0, -1.0)
	ground.max_space = Vector2(1.0, reach)
	var points: Dictionary[StringName, Vector2] = {
		&"idle": Vector2.ZERO,
		&"walk_fwd": Vector2(0.0, 1.0),
		&"walk_back": Vector2(0.0, -1.0),
		&"walk_left": Vector2(-1.0, 0.0),
		&"walk_right": Vector2(1.0, 0.0),
		&"run": Vector2(0.0, reach),
	}
	for clip: StringName in points:
		ground.add_blend_point(_clip(clip), points[clip])
	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	root.add_node(GROUND, ground)
	root.add_node(CROUCH, _line(&"crouch_idle", &"crouch_walk"))
	root.add_node(DOWNED, _line(&"downed_idle", &"downed_crawl"))
	var state: AnimationNodeTransition = AnimationNodeTransition.new()
	state.xfade_time = FADE_TIME
	for input: StringName in [GROUND, CROUCH, DOWNED]:
		state.add_input(String(input))
	root.add_node(&"state", state)
	root.add_node(&"speed", AnimationNodeTimeScale.new())
	for index: int in 3:
		root.connect_node(&"state", index, [GROUND, CROUCH, DOWNED][index])
	root.connect_node(&"speed", 0, &"state")
	root.connect_node(&"output", 0, &"speed")
	return root


func _line(still: StringName, moving: StringName) -> AnimationNodeBlendSpace1D:
	var line: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	line.min_space = 0.0
	line.max_space = 1.0
	line.add_blend_point(_clip(still), 0.0)
	line.add_blend_point(_clip(moving), 1.0)
	return line


func _clip(clip: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip
	return node
