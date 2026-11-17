## Solo match spawning reads the character's equipped gear without changing its save.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const ID: StringName = &"test_character_look"

var session: GameSession
var player: Player
var _path: String = CharacterProfile.directory() + "test_character_look.json"


func before_each() -> void:
	_remove_files()
	session = GameSession.new()
	session.profile_id = ID
	autofree(session)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func after_each() -> void:
	_remove_files()


func test_match_start_applies_the_saved_loadout_and_leaves_the_profile_unchanged() -> void:
	var loadout: Dictionary = {
		"vest": {"base": "vest_heavy", "rar": "rare"},
		"charm": {"base": "charm_dog_tags", "rar": "epic"},
		"implant": {"base": "implant_reflex", "rar": "legendary"},
	}
	_save({"loadout": loadout, "future_field": {"kept": true}})
	var before: String = FileAccess.get_file_as_string(_path)
	player.spawn(session, [])
	for slot: StringName in CharacterLook.SLOTS:
		var holder: Node3D = player.gear_rig.skeleton.get_node(String(slot).capitalize()) as Node3D
		assert_not_null(holder)
		if holder is BoneAttachment3D:
			var attach: StringName = GearVisual.find(StringName(loadout[slot].base)).attach
			assert_eq((holder as BoneAttachment3D).bone_name, String(attach))
		else:
			assert_eq(slot, &"vest", "only the skinned vest sits in a plain holder")
		var piece: Node = holder.get_child(0)
		assert_eq(piece.scene_file_path, "res://assets/models/gear/%s.glb" % loadout[slot].base)
		var mesh: GeometryInstance3D = (
			piece.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		)
		var rarity: RarityLook = load("res://content/looks/rarity/%s.tres" % loadout[slot].rar) as RarityLook
		assert_eq(mesh.get_instance_shader_parameter(&"trim_color"), rarity.trim_color)
		assert_eq(mesh.get_instance_shader_parameter(&"dye_main"), CharacterLook.DEFAULT_DYE_MAIN)
	assert_eq(FileAccess.get_file_as_string(_path), before)


func test_profile_without_loadout_clears_previously_applied_gear() -> void:
	_save({"total_xp": 50})
	player.gear_rig.apply(LookBuilder.from_equipped({"vest": {"base": "vest_light", "rar": "epic"}}))
	player.spawn(session, [])
	_assert_empty_gear()


func test_legacy_array_loadout_is_empty() -> void:
	_save({"loadout": []})
	var before: String = FileAccess.get_file_as_string(_path)
	player.spawn(session, [])
	_assert_empty_gear()
	assert_eq(FileAccess.get_file_as_string(_path), before, "Rendering legacy gear does not rewrite the profile")


func test_new_character_starts_with_empty_gear_and_creates_no_save() -> void:
	player.spawn(session, [])
	_assert_empty_gear()
	assert_false(FileAccess.file_exists(_path))


func _assert_empty_gear() -> void:
	for slot: StringName in CharacterLook.SLOTS:
		assert_false(player.gear_rig.skeleton.has_node(String(slot).capitalize()))


func _save(fields: Dictionary) -> void:
	fields["id"] = String(ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterProfile.directory()))
	assert_eq(SaveFile.write(_path, fields), OK)


func _remove_files() -> void:
	for path: String in [_path, _path + ".tmp", _path + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
