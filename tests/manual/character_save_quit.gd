## Standalone check that the pause Quit game button banks XP before the engine exits.
extends SceneTree

const ID: StringName = &"test_character_quit"
const PATH: String = "user://characters/test_character_quit.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profiles: Script = load("res://systems/progression/character_profile.gd")
	var saves: Script = load("res://systems/save/save_file.gd")
	var profile: RefCounted = profiles.call("load_or_create", ID) as RefCounted
	profile.set("total_xp", 450)
	assert(profile.call("save") == OK)
	var scene: PackedScene = load("res://systems/game/game_session.tscn") as PackedScene
	var session: Node = scene.instantiate()
	session.set("profile_id", ID)
	session.set("rng_seed", 1234)
	root.add_child(session)
	session.get_node("WaveDirector").call("stop")
	var players: Array = session.call("get_players")
	session.get_node("Progression").call("add_xp", players[0], 75)
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	session.call("_unhandled_input", pause)
	var ui: Node = root.get_node("UI")
	var pause_layer: Node = ui.get_child(ui.get_child_count() - 1)
	(pause_layer.get_node("PauseScreen/Menu/QuitGame") as Button).pressed.emit()
	var data: Dictionary = saves.call("read", PATH)
	var total: int = int(data.get("total_xp", -1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if total != 525:
		push_error("Quit did not bank run XP: %d" % total)
		quit(1)
		return
	print("Quit game banked run XP before exit")
