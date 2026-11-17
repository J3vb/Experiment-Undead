## Screen router: the only code that changes the scene, stacks screens and sets the mouse mode.
## UI.replace(&"match"), UI.push(&"settings"), UI.hold_mouse(self, open). Ids are content/screens files.
extends Node

const TYPE: StringName = &"screens"

var _root: ScreenData
## {id, layer, focus} per pushed screen, top last.
var _stack: Array[Dictionary] = []
var _holders: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


## Goes to a root place (main menu, match): frees every pushed screen and unpauses.
func replace(id: StringName) -> void:
	var data: ScreenData = _screen(id)
	if data == null:
		return
	_clear()
	get_tree().paused = false
	get_tree().change_scene_to_file(data.scene)


## Restarts the current root with an empty stack.
func reload() -> void:
	_clear()
	get_tree().reload_current_scene()


## Opens a screen above the current one and returns it so the caller can pass it data.
func push(id: StringName) -> Node:
	var data: ScreenData = _screen(id)
	return _open(id, data) if data else null


## Closes the top screen and gives focus back to the control that had it before the push.
func pop() -> void:
	if _stack.is_empty():
		Log.warn(&"ui", &"pop_empty", {})
		return
	var entry: Dictionary = _stack.pop_back()
	(entry["layer"] as CanvasLayer).queue_free()
	if not _stack.is_empty():
		_set_covered(_stack.back()["layer"], false)
	if is_instance_valid(entry["focus"]) and (entry["focus"] as Control).is_inside_tree():
		(entry["focus"] as Control).grab_focus()
	_apply_mouse()


func top() -> StringName:
	return _stack.back()["id"] if not _stack.is_empty() else &""


## For panels that are not pushed screens (Pack overlay, debug console). A freed node lets go.
func hold_mouse(node: Node, held: bool) -> void:
	var connected: bool = node.tree_exiting.is_connected(_apply_mouse)
	if held and not _holders.has(node):
		_holders.append(node)
		if not connected:
			node.tree_exiting.connect(_apply_mouse, CONNECT_DEFERRED)
	elif not held:
		_holders.erase(node)
		if connected:
			node.tree_exiting.disconnect(_apply_mouse)
	_apply_mouse()


## The mouse is captured only on a captures-mouse root with no screen open and no panel holding it.
func mouse_should_be_free() -> bool:
	for index: int in range(_holders.size() - 1, -1, -1):
		if not is_instance_valid(_holders[index]) or not _holders[index].is_inside_tree():
			_holders.remove_at(index)
	return _root == null or not _root.captures_mouse or not _stack.is_empty() or not _holders.is_empty()


## A click recaptures the mouse in the match, for example after alt-tab.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_apply_mouse()


func _open(id: StringName, data: ScreenData) -> Node:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = data.layer
	if not _stack.is_empty():
		var below: CanvasLayer = _stack.back()["layer"]
		layer.layer = maxi(data.layer, below.layer)
		_set_covered(below, true)
	var screen: Node = (load(data.scene) as PackedScene).instantiate()
	layer.add_child(screen)
	_stack.append({"id": id, "layer": layer, "focus": get_viewport().gui_get_focus_owner()})
	add_child(layer)
	if screen.has_signal(&"closed"):
		screen.connect(&"closed", pop)
	_apply_mouse()
	return screen


func _set_covered(layer: CanvasLayer, covered: bool) -> void:
	layer.visible = not covered
	layer.process_mode = Node.PROCESS_MODE_DISABLED if covered else Node.PROCESS_MODE_ALWAYS


func _clear() -> void:
	for entry: Dictionary in _stack:
		(entry["layer"] as CanvasLayer).queue_free()
	_stack.clear()


func _screen(id: StringName) -> ScreenData:
	if not Content.ids(TYPE).has(id):
		Log.warn(&"ui", &"unknown_screen", {"id": String(id)})
		return null
	return Content.get_item(TYPE, id) as ScreenData


func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	_root = null
	for id: StringName in Content.ids(TYPE):
		var data: ScreenData = Content.get_item(TYPE, id) as ScreenData
		if data.root and scene and data.scene == scene.scene_file_path:
			_root = data
	_apply_mouse()


func _apply_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_should_be_free() else Input.MOUSE_MODE_CAPTURED
