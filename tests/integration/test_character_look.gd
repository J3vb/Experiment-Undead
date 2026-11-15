## Solo match spawning reads the character's equipped gear without changing its save.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const ID: StringName = &"test_character_look"
const PATH: String = "user://characters/test_character_look.json"

var session: GameSession
var player: Player


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
	var before: String = FileAccess.get_file_as_string(PATH)
	player.spawn(session, [])
	for slot: StringName in CharacterLook.SLOTS:
		var attachment: BoneAttachment3D = (
			player.gear_rig.skeleton.get_node(String(slot).capitalize()) as BoneAttachment3D
		)
		assert_not_null(attachment)
		assert_eq(attachment.bone_name, String(GearVisual.find(StringName(loadout[slot].base)).attach))
		var piece: Node = attachment.get_child(0)
		assert_eq(piece.scene_file_path, GearVisual.SCENES[StringName(loadout[slot].base)])
		var mesh: GeometryInstance3D = (
			piece.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		)
		var rarity: RarityLook = load("res://content/looks/rarity/%s.tres" % loadout[slot].rar) as RarityLook
		assert_eq(mesh.get_instance_shader_parameter(&"trim_color"), rarity.trim_color)
		assert_eq(mesh.get_instance_shader_parameter(&"dye_main"), CharacterLook.DEFAULT_DYE_MAIN)
	assert_eq(FileAccess.get_file_as_string(PATH), before)


func test_profile_without_loadout_clears_previously_applied_gear() -> void:
	_save({"total_xp": 50})
	player.gear_rig.apply(LookBuilder.from_equipped({"vest": {"base": "vest_light", "rar": "epic"}}))
	player.spawn(session, [])
	_assert_empty_gear()


func test_legacy_array_loadout_is_empty() -> void:
	_save({"loadout": []})
	player.spawn(session, [])
	_assert_empty_gear()


func test_new_character_starts_with_empty_gear_and_creates_no_save() -> void:
	player.spawn(session, [])
	_assert_empty_gear()
	assert_false(FileAccess.file_exists(PATH))


func _assert_empty_gear() -> void:
	for slot: StringName in CharacterLook.SLOTS:
		assert_false(player.gear_rig.skeleton.has_node(String(slot).capitalize()))


func _save(fields: Dictionary) -> void:
	fields["id"] = String(ID)
	var profile: CharacterProfile = CharacterProfile.from_dict(fields)
	assert_eq(profile.save(), OK)


func _remove_files() -> void:
	for path: String in [PATH, PATH + ".tmp", PATH + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
