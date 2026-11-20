## A Lantern Post stall keeper (F-76): plays their idle at the stall, turns their head to this peer's own player
## when it comes within LOOK_RANGE and, when that player talks to them, plays the greet and shows their next line.
## Nothing is shared: every peer sees the same idle; only the talker sees the greet, the line and the head turn.
class_name Vendor
extends Interactable

const LOOK_RANGE: float = 4.0
const LINE_SECONDS: float = 4.0
const LOOK_INTERVAL: float = 0.25
const GREET: StringName = &"greet"
const GREET_BLEND: float = 0.25
const HEAD: String = "head"
const HEAD_YAW_LIMIT: float = deg_to_rad(65.0)
const HEAD_PITCH_LIMIT: float = deg_to_rad(25.0)
const TALK_WIDTH: float = 0.9
const TALK_HEIGHT: float = 1.0
const TALK_MIDDLE: float = 1.25
const TALK_BEHIND: float = 0.3

@export var data: VendorData
## How far in front of the keeper the talk area reaches: just past the stall's collider front, so a look from the
## street finds the keeper before the stall. Set by the town generator.
@export var reach: float = 1.2

var next_line: int = 0
var anim: AnimationPlayer
var look: LookAtModifier3D
var _line_left: float = 0.0
var _look_left: float = 0.0
var _me: Player

@onready var line: Label3D = $Line
@onready var look_target: Marker3D = $LookTarget
@onready var _ahead: Marker3D = $Ahead


func _ready() -> void:
	super()
	add_to_group(&"vendor")
	line.visible = false
	look_target.global_position = _ahead.global_position
	_fit_talk_area()
	if data and data.model:
		_add_model(data.model.instantiate() as Node3D)


func get_prompt(_player: Player) -> String:
	return "Talk to %s [F]" % data.display_name if data else ""


func is_local() -> bool:
	return true


## Runs on the talker's own peer only (is_local). The host also calls this for remote players; those return.
func interact(player: Player, _facts: Dictionary = {}) -> void:
	if not _is_mine(player) or data == null or data.lines.is_empty():
		return
	line.text = data.lines[next_line]
	line.visible = true
	_line_left = LINE_SECONDS
	next_line = (next_line + 1) % data.lines.size()
	if anim and anim.has_animation(GREET):
		anim.play(GREET, GREET_BLEND)
		anim.queue(data.idle_clip)


func _process(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		line.visible = _line_left > 0.0
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK_INTERVAL
		update_look()


## Points the head at this peer's player inside LOOK_RANGE, else straight ahead.
func update_look() -> void:
	if not is_instance_valid(_me):
		_me = _find_me()
	var near: bool = _me != null and _me.global_position.distance_to(global_position) <= LOOK_RANGE
	look_target.global_position = _me.camera.global_position if near else _ahead.global_position


func _is_mine(player: Player) -> bool:
	return player != null and player.net_id == multiplayer.get_unique_id()


func _find_me() -> Player:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		if _is_mine(node as Player):
			return node as Player
	return null


func _fit_talk_area() -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(TALK_WIDTH, TALK_HEIGHT, reach + TALK_BEHIND)
	var area: CollisionShape3D = $Shape as CollisionShape3D
	area.shape = box
	area.position = Vector3(0.0, TALK_MIDDLE, (reach - TALK_BEHIND) * 0.5)


func _add_model(model: Node3D) -> void:
	model.name = "Model"
	add_child(model)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	anim = players[0] as AnimationPlayer if not players.is_empty() else null
	if anim and anim.has_animation(data.idle_clip):
		anim.play(data.idle_clip)
		anim.seek(fmod(position.x * 0.37, 1.0) * anim.current_animation_length)  # cosmetic: stalls out of step
	else:
		Log.warn(&"vendor", &"vendor_clip_missing", {"vendor": data.display_name, "clip": data.idle_clip})
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_add_head_turn(skeletons[0] as Skeleton3D)


func _add_head_turn(skeleton: Skeleton3D) -> void:
	look = LookAtModifier3D.new()
	look.name = "HeadTurn"
	look.bone_name = HEAD
	look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	look.primary_rotation_axis = Vector3.AXIS_Y
	look.use_secondary_rotation = true
	look.use_angle_limitation = true
	look.primary_limit_angle = HEAD_YAW_LIMIT * 2.0
	look.secondary_limit_angle = HEAD_PITCH_LIMIT * 2.0
	look.duration = 0.4
	skeleton.add_child(look)
	look.target_node = look.get_path_to(look_target)
