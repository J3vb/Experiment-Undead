## The player's interact job: finds the Interactable under the crosshair and
## uses it once per press, or again every hold_interval(player) while interact is
## held (barrier repair). Solo and the server run interact(); a client asks.
class_name PlayerInteract
extends RefCounted

var _query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _hold_left: float = 0.0


func _init() -> void:
	_query.collision_mask = Layers.INTERACTABLE | Layers.WORLD
	_query.collide_with_areas = true


## One tick: refresh player.focus, then use it if the frame asks to.
func update(player: Player, frame: InputFrame, delta: float) -> void:
	player.focus = _find_focus(player)
	if not player.input_enabled or player.is_downed or player.focus == null:
		_hold_left = 0.0
		return
	if _wants_use(player, frame, delta):
		_use(player)


func _find_focus(player: Player) -> Interactable:
	var camera: Camera3D = player.camera
	_query.from = camera.global_position
	_query.to = _query.from - camera.global_basis.z * player.interact_range
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(_query)
	return hit.get("collider") as Interactable if not hit.is_empty() else null


func _wants_use(player: Player, frame: InputFrame, delta: float) -> bool:
	var interval: float = player.focus.hold_interval(player)
	if frame.has(InputFrame.INTERACT):
		_hold_left = interval
		return true
	if interval <= 0.0 or not frame.has(InputFrame.INTERACT_HELD):
		_hold_left = 0.0
		return false
	_hold_left -= delta
	if _hold_left > 0.0:
		return false
	_hold_left += interval
	return true


func _use(player: Player) -> void:
	if Net.is_authority() or player.focus.is_local():
		player.focus.interact(player)
	elif player.session:
		player.session.interactions.request(player, player.focus)
