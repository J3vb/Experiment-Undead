## Boots the normal session after autoloads load; also checks a single run's JSON-lines log.
extends SceneTree

const FAIL_EVENTS: Array[String] = [
	"waves.round_stalled",
	"enemies.zombie_fell_out",
	"perf.orphan_nodes_growing",
	"level.navigation_not_ready",
]
const WARN_EVENTS: Array[String] = ["enemies.zombie_stuck", "perf.long_frames"]


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: GDScript = load("res://tools/soak/soak_run.gd") as GDScript
	root.add_child(runner.new())


static func check_log(path: String, target_round: int) -> Dictionary:
	var result: Dictionary = {"failed": false, "reached": 0, "completed": 0, "problems": {}}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["failed"] = true
		result["reason"] = "Cannot read run log: " + path
		return result
	var line_number: int = 0
	while not file.eof_reached():
		var text: String = file.get_line()
		line_number += 1
		if text.is_empty():
			continue
		var json: JSON = JSON.new()
		if json.parse(text) != OK or not json.data is Dictionary:
			result["failed"] = true
			result["reason"] = "Invalid JSON object at line %d" % line_number
			continue
		var entry: Dictionary = json.data
		var key: String = "%s.%s" % [entry.get("system", ""), entry.get("event", "")]
		if key == "waves.round_started":
			result["reached"] = maxi(result["reached"], int(entry.get("round", 0)))
		if key == "waves.round_ended":
			result["completed"] = maxi(result["completed"], int(entry.get("round", 0)))
		var fails: bool = entry.get("level", "") == "error" or key in FAIL_EVENTS
		if fails:
			result["failed"] = true
		if fails or key in WARN_EVENTS or entry.get("level", "") == "warn":
			var problems: Dictionary = result["problems"]
			if not problems.has(key):
				problems[key] = {"count": 0, "first": text, "line": line_number, "fails": false}
			problems[key]["count"] += 1
			problems[key]["fails"] = problems[key]["fails"] or fails
	if int(result["reached"]) < target_round or int(result["completed"]) < target_round:
		result["failed"] = true
		result["reason"] = "Target round %d did not finish" % target_round
	return result
