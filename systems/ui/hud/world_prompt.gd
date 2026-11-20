## Pickup prompt anchored to what you look at (docs/design/concepts/screens/hud_concept_2.jpg):
## corner brackets around the focused Interactable, a thin leader line, and the prompt box
## moved beside it. With no focus (revive, downed), a focus behind the camera or one bigger
## than MAX_SHARE of the screen, the box sits at its fixed spot under the crosshair.
class_name WorldPrompt
extends Control

const TEXT: Color = Color(0.902, 0.925, 0.925, 0.85)
const MAX_SHARE: float = 0.4
const FIXED_DROP: float = 115.0
const BOX_GAP: Vector2 = Vector2(40.0, 24.0)
const BRACKET: float = 14.0
const MARGIN: float = 16.0

var player: Player
var box: Control
var brackets: Rect2 = Rect2()
var _focus: Interactable
var _corners: PackedVector3Array = PackedVector3Array()
var _world: PackedVector3Array = PackedVector3Array()
var _shape: CollisionShape3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.player_spawned.connect(_on_player_spawned)


## Screen rect around world-space corners, or an empty Rect2 when any corner is behind the camera.
static func screen_rect(camera: Camera3D, corners: PackedVector3Array) -> Rect2:
	if corners.is_empty():
		return Rect2()
	var rect: Rect2 = Rect2()
	for index: int in corners.size():
		if camera.is_position_behind(corners[index]):
			return Rect2()
		var point: Vector2 = camera.unproject_position(corners[index])
		rect = Rect2(point, Vector2.ZERO) if index == 0 else rect.expand(point)
	return rect


## Where the prompt box goes: up and right of the brackets, kept on screen.
static func box_position(around: Rect2, box_size: Vector2, screen: Vector2) -> Vector2:
	var spot: Vector2 = Vector2(around.end.x + BOX_GAP.x, around.position.y - BOX_GAP.y - box_size.y)
	return spot.clamp(Vector2.ONE * MARGIN, screen - box_size - Vector2.ONE * MARGIN)


func _process(_delta: float) -> void:
	var was: Rect2 = brackets
	brackets = _find_brackets()
	if box and box.visible:
		var screen: Vector2 = get_viewport_rect().size
		if brackets.has_area():
			box.position = box_position(brackets, box.size, screen)
		else:
			box.position = Vector2((screen.x - box.size.x) * 0.5, screen.y * 0.5 + FIXED_DROP)
	if brackets != was or brackets.has_area():
		queue_redraw()


func _find_brackets() -> Rect2:
	if box == null or not box.visible or not is_instance_valid(player) or not is_instance_valid(player.focus):
		return Rect2()
	if player.focus != _focus:
		_cache_corners(player.focus)
	if _shape == null or not is_instance_valid(_shape):
		return Rect2()
	for index: int in _corners.size():
		_world[index] = _shape.global_transform * _corners[index]
	var rect: Rect2 = screen_rect(player.camera, _world)
	var screen: Vector2 = get_viewport_rect().size
	if rect.size.x > screen.x * MAX_SHARE or rect.size.y > screen.y * MAX_SHARE:
		return Rect2()
	return rect


func _cache_corners(focus: Interactable) -> void:
	_focus = focus
	_shape = null
	_corners.clear()
	for child: Node in focus.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape:
			_shape = child as CollisionShape3D
			break
	if _shape == null:
		return
	var bounds: AABB = _shape.shape.get_debug_mesh().get_aabb()
	for index: int in 8:
		_corners.append(bounds.get_endpoint(index))
	_world.resize(8)


func _draw() -> void:
	if not brackets.has_area():
		return
	var r: Rect2 = brackets.grow(6.0)
	var arm: float = minf(BRACKET, minf(r.size.x, r.size.y) * 0.4)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var x_dir: float = 1.0 if corner.x == r.position.x else -1.0
		var y_dir: float = 1.0 if corner.y == r.position.y else -1.0
		draw_line(corner, corner + Vector2(arm * x_dir, 0.0), TEXT, 1.5, true)
		draw_line(corner, corner + Vector2(0.0, arm * y_dir), TEXT, 1.5, true)
	var start: Vector2 = r.get_center() + Vector2(r.size.x * 0.25, -r.size.y * 0.25)
	draw_circle(start, 2.5, TEXT)
	if box:
		draw_line(start, box.position + Vector2(0.0, box.size.y * 0.5), TEXT, 1.0, true)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned
