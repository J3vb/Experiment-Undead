## Debug-only performance counters, sampled four times per real second.
extends CanvasLayer

var _label: Label
var _timer: Timer
var _session: GameSession


func _ready() -> void:
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	layer = 99
	_session = get_parent() as GameSession
	_label = Label.new()
	_label.theme = preload("res://systems/ui/theme.tres")
	_label.position = Vector2(12, 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.hide()
	add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = 0.25
	_timer.ignore_time_scale = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_label.visible = not _label.visible
		if _label.visible:
			_refresh()
			_timer.start()
		else:
			_timer.stop()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	_label.text = (
		"FPS: %.0f | frame: %.2f ms\nPhysics ticks: %d (%d Hz)\nEnemies: %d | draw calls: %d\nStatic memory: %.1f MiB"
		% [
			fps,
			1000.0 / fps if fps > 0.0 else 0.0,
			_session.tick,
			Engine.physics_ticks_per_second,
			_session.spawner.alive_count() if _session.spawner else 0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		]
	)
