## Starts the headless CPU benchmark after autoloads are available to gameplay scripts.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: GDScript = load("res://tools/benchmark/benchmark_run.gd") as GDScript
	root.add_child(runner.new())
