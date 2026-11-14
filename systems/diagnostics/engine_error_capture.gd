## Sends engine errors and warnings (push_error, push_warning, script and
## shader errors) to the Log with file, line and script stack.
## Godot may call it from any thread.
class_name EngineErrorCapture
extends Logger

const KINDS: Array[String] = ["error", "warning", "script", "shader"]

var _log: Node
var _busy: bool = false


func _init(log_node: Node) -> void:
	_log = log_node


# The engine fixes this signature (8 arguments).
# gdlint:ignore = function-arguments-number
func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	# Guards against a loop if writing the log line itself raises an error.
	if _busy:
		return
	_busy = true
	var data: Dictionary = {
		"message": rationale if rationale != "" else code,
		"kind": KINDS[clampi(error_type, 0, KINDS.size() - 1)],
		"where": "%s:%d" % [file, line],
		"function": function,
	}
	for bt: ScriptBacktrace in script_backtraces:
		if not bt.is_empty():
			data["stack"] = bt.format(0, 2)
			break
	var level: String = "warn" if error_type == ERROR_TYPE_WARNING else "error"
	_log.write(level, &"engine", StringName("engine_" + data["kind"]), data)
	_busy = false
