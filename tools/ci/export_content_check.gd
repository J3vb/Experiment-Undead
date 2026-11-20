## Run with an exported build: checks that content data survives export (choice rows keep their
## options, screens keep their tips). Exported .tres lost typed packed arrays once (2026-11-19).
extends SceneTree


func _init() -> void:
	var problems: PackedStringArray = []
	for path: String in _tres("res://content/settings"):
		var row: Resource = load(path)
		if row.get("kind") == &"choice" and (row.get("options") as Array).is_empty():
			problems.append("%s: choice row has no options" % path)
	for path: String in _tres("res://content/screens"):
		var screen: Resource = load(path)
		if not str(screen.get("loading_screen")).is_empty() and (screen.get("tips") as Array).is_empty():
			problems.append("%s: no loading tips" % path)
	for line: String in problems:
		printerr(line)
	print("Export content check: %s" % ("OK" if problems.is_empty() else "%d problems" % problems.size()))
	quit(0 if problems.is_empty() else 1)


func _tres(folder: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		var clean: String = file.trim_suffix(".remap")
		if clean.get_extension() == "tres":
			out.append(folder.path_join(clean))
	return out
