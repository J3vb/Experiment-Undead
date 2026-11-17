## Every Events signal says on which peers it fires, so co-op code knows who hears it.
extends GutTest

const EVENTS: String = "res://core/events.gd"


func test_every_signal_names_its_peers() -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(EVENTS).split("\n")
	var found: int = 0
	for index: int in lines.size():
		if not lines[index].begins_with("signal "):
			continue
		found += 1
		var signal_name: String = lines[index].trim_prefix("signal ").get_slice("(", 0)
		assert_true(_comment_above(lines, index).contains("## Peers: "), "%s says which peers emit it" % signal_name)
	assert_eq(found, (load(EVENTS) as GDScript).get_script_signal_list().size(), "all signals were read")


func _comment_above(lines: PackedStringArray, index: int) -> String:
	var comment: String = ""
	var line: int = index - 1
	while line >= 0 and lines[line].begins_with("##"):
		comment = lines[line] + "\n" + comment
		line -= 1
	return comment
