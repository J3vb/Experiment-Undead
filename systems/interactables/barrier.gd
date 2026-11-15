## A boarded window. Zombies spawned behind it tear the planks off from
## outside (+Z faces into the room), then climb through. Players repair one
## plank per press from inside for points. The Blocker keeps players in; it
## sits on the barrier layer, which zombies and the navmesh bake ignore.
## Three attack slots line the window; extra zombies wait at queue points
## further back, and only one zombie vaults through at a time.
class_name Barrier
extends Interactable

const PLANKS: int = 6
const REPAIR_TIME: float = 0.5
## Where a zombie stands to tear planks, and where it lands after climbing in.
const OUTSIDE_DEPTH: float = 0.8
const INSIDE_DEPTH: float = 1.0
const SLOTS: int = 3
const SLOT_SPACING: float = 0.55
## How far back from the wall the waiting zombies stand, and how far apart.
const QUEUE_DEPTH: float = 2.0
const QUEUE_SPACING: float = 0.7

var planks: int = PLANKS
var _repair_cooldown: float = 0.0
var _slots: Array[Node3D] = []
var _vaulter: Node3D

@onready var _boards: Array[Node] = $Planks.get_children()


func _ready() -> void:
	super()
	add_to_group(&"barriers")
	_slots.resize(SLOTS)
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


## The slot `who` holds, or the nearest free one it now takes; -1 when all are taken.
func claim_slot(who: Node3D) -> int:
	var best: int = -1
	var best_distance: float = INF
	for i: int in SLOTS:
		if _slots[i] == who:
			return i
		if is_instance_valid(_slots[i]):
			continue
		var d: float = who.global_position.distance_squared_to(slot_point(i))
		if d < best_distance:
			best_distance = d
			best = i
	if best >= 0:
		_slots[best] = who
	return best


## Frees the slot and the vault for `who` (climbed in or died).
func release(who: Node3D) -> void:
	for i: int in SLOTS:
		if _slots[i] == who:
			_slots[i] = null
	if _vaulter == who:
		_vaulter = null


## True when `who` may climb through now; one zombie at a time.
func try_start_vault(who: Node3D) -> bool:
	if is_instance_valid(_vaulter) and _vaulter != who:
		return false
	_vaulter = who
	return true


func slot_point(index: int) -> Vector3:
	return outside_point() + global_basis.x * float(index - 1) * SLOT_SPACING


## Where a zombie without a slot waits; `lane` spreads the queue sideways.
func queue_point(lane: int) -> Vector3:
	var side: float = float(posmod(lane, 3) - 1) * QUEUE_SPACING
	return global_position - global_basis.z * QUEUE_DEPTH + global_basis.x * side
