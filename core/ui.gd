## Screen router: the only code that changes the scene, stacks screens and sets the mouse mode.
## UI.replace(&"match"), UI.push(&"settings"), UI.hold_mouse(self, open). Ids are content/screens files.
extends Node

const TYPE: StringName = &"screens"

var _root: ScreenData
## {id, layer, focus} per pushed screen, top last.
var _stack: Array[Dictionary] = []
var _holders: Array[Node] = []
## Scene path of the root being loaded behind a loading screen, or empty.
var _loading_path: String = ""
var _loading_layer: CanvasLayer
## Threaded loads that were cancelled; collected once done so ResourceLoader lets go of them.
var _dropped_paths: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	Settings.changed.connect(_on_setting_changed)
	_on_setting_changed(&"accessibility", &"text_scale", Settings.get_value(&"accessibility", &"text_scale"))


## Text size scales every Control (stretch mode canvas_items); the 3D view keeps its resolution.
func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"accessibility" and key == &"text_scale":
		get_tree().root.content_scale_factor = float(value)


## Goes to a root place (main menu, match): frees every pushed screen and unpauses.
## A root that names a loading screen loads on a thread behind it.
func replace(id: StringName) -> void:
	var data: ScreenData = _screen(id)
	if data == null or _loading_path == data.scene:
		return
	_clear()
	_end_loading()
	get_tree().paused = false
	var loading: ScreenData = null if data.loading_screen.is_empty() else _screen(data.loading_screen)
	if loading == null or not _request(data.scene):
		get_tree().change_scene_to_file(data.scene)
		return
	_loading_path = data.scene
	get_viewport().gui_release_focus()
	if get_tree().current_scene:
		get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	_loading_layer = CanvasLayer.new()
	_loading_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_layer.layer = loading.layer
	var screen: Node = (load(loading.scene) as PackedScene).instantiate()
	_loading_layer.add_child(screen)
	add_child(_loading_layer)
	if screen.has_method(&"setup"):
		screen.call(&"setup", data.title, data.tips)
	set_process(true)


## A load cancelled earlier is still in ResourceLoader, so it is picked up again instead of requested twice.
func _request(path: String) -> bool:
	if _dropped_paths.has(path):
		_dropped_paths.erase(path)
		return true
	return ResourceLoader.load_threaded_request(path) == OK


func is_loading() -> bool:
	return not _loading_path.is_empty()


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


func _process(_delta: float) -> void:
	_collect_dropped()
	if _loading_path.is_empty():
		set_process(not _dropped_paths.is_empty())
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_loading_path, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_show_progress(float(progress[0]) if not progress.is_empty() else 0.0)
		return
	var path: String = _loading_path
	var scene: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		scene = ResourceLoader.load_threaded_get(path) as PackedScene
	_finish_loading(path, scene)


## Swaps in the loaded scene; a failed load falls back to a plain scene change.
func _finish_loading(path: String, scene: PackedScene) -> void:
	_loading_path = ""
	set_process(not _dropped_paths.is_empty())
	if scene == null:
		Log.warn(&"ui", &"loading_failed", {"scene": path})
		get_tree().change_scene_to_file(path)
		return
	_show_progress(1.0)
	get_tree().change_scene_to_packed(scene)


func _collect_dropped() -> void:
	for index: int in range(_dropped_paths.size() - 1, -1, -1):
		var path: String = _dropped_paths[index]
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(path)
			_dropped_paths.remove_at(index)


func _show_progress(value: float) -> void:
	if is_instance_valid(_loading_layer) and _loading_layer.get_child_count() > 0:
		var screen: Node = _loading_layer.get_child(0)
		if screen.has_method(&"set_progress"):
			screen.call(&"set_progress", value)


func _end_loading() -> void:
	if not _loading_path.is_empty():
		_dropped_paths.append(_loading_path)
	_loading_path = ""
	set_process(not _dropped_paths.is_empty())
	if is_instance_valid(_loading_layer):
		_loading_layer.queue_free()
	_loading_layer = null


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
	var focus: Control = get_viewport().gui_get_focus_owner()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = data.layer
	if not _stack.is_empty():
		var below: CanvasLayer = _stack.back()["layer"]
		layer.layer = maxi(data.layer, below.layer)
		_set_covered(below, true)
	var screen: Node = (load(data.scene) as PackedScene).instantiate()
	layer.add_child(screen)
	_stack.append({"id": id, "layer": layer, "focus": focus})
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
	if not Content.has(TYPE, id):
		Log.warn(&"ui", &"unknown_screen", {"id": String(id)})
		return null
	return Content.get_item(TYPE, id) as ScreenData


func _on_scene_changed() -> void:
	if _loading_path.is_empty() and is_instance_valid(_loading_layer):
		_end_loading()
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
