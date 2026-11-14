## A boarded window. Zombies spawned behind it tear the planks off from
## outside (+Z faces into the room), then climb through. Players repair one
## plank per press from inside for points. The Blocker keeps players in; it
## sits on the barrier layer, which zombies and the navmesh bake ignore.
class_name Barrier
extends Interactable

const PLANKS: int = 6
const REPAIR_TIME: float = 0.5
## Where a zombie stands to tear planks, and where it lands after climbing in.
const OUTSIDE_DEPTH: float = 0.8
const INSIDE_DEPTH: float = 1.0

var planks: int = PLANKS
var _repair_cooldown: float = 0.0

@onready var _boards: Array[Node] = $Planks.get_children()


func _ready() -> void:
	super()
	add_to_group(&"barriers")
	($Blocker as StaticBody3D).collision_layer = Layers.BARRIER
	($Blocker as StaticBody3D).collision_mask = 0


func _physics_process(delta: float) -> void:
	_repair_cooldown = maxf(_repair_cooldown - delta, 0.0)


func get_prompt(_player: Player) -> String:
	return "Repair barrier [F]" if planks < PLANKS else ""


func interact(player: Player) -> void:
	if planks >= PLANKS or _repair_cooldown > 0.0:
		return
	_repair_cooldown = REPAIR_TIME
	_set_planks(planks + 1)
	($RepairSound as AudioStreamPlayer3D).play()
	var session: GameSession = get_tree().get_first_node_in_group(&"game_session") as GameSession
	if session:
		session.economy.pay_repair(player)


func tear_plank() -> void:
	if planks > 0:
		_set_planks(planks - 1)
		($TearSound as AudioStreamPlayer3D).play()


func is_broken() -> bool:
	return planks == 0


func outside_point() -> Vector3:
	return global_position - global_basis.z * OUTSIDE_DEPTH


func inside_point() -> Vector3:
	return global_position + global_basis.z * INSIDE_DEPTH


func _set_planks(count: int) -> void:
	planks = count
	for i: int in _boards.size():
		(_boards[i] as Node3D).visible = i < planks
