## F3 performance counters, sampled four times per second in debug builds.
extends CanvasLayer

var label: Label
var elapsed: float = 0.0
var session: GameSession


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 99
	session = get_parent() as GameSession
	label = Label.new()
	label.theme = load("res://systems/ui/theme.tres") as Theme
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = Vector2(16, 16)
	label.hide()
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		label.visible = not label.visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not label.visible:
		return
	elapsed += delta
	if elapsed < 0.25:
		return
	elapsed = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms: float = 1000.0 / fps if fps > 0.0 else 0.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var memory: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	label.text = (
		"FPS: %.0f (%.2f ms)\nPhysics ticks: %d\nEnemies: %d\nDraw calls: %d\nMemory: %.1f MB"
		% [fps, frame_ms, session.tick, session.spawner.alive_count(), draw_calls, memory]
	)
