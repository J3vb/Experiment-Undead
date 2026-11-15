## A real listen-server session publishes the look built from its local character save.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PROFILE_ID: StringName = &"test_look_session"
const PORT: int = 24674
const LOADOUT: Dictionary = {
	"vest": {"base": "vest_light", "rar": "rare"},
	"charm": {"base": "charm_coin", "rar": "epic"},
	"implant": {"base": "implant_lung", "rar": "legendary"},
}

var _session: GameSession


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	Net.leave()
	var path: String = CharacterProfile.DIRECTORY + String(PROFILE_ID) + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_online_session_builds_and_caches_its_local_saved_gear() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = PROFILE_ID
	profile.loadout = LOADOUT.duplicate(true)
	assert_eq(profile.save(), OK)
	assert_eq(Net.host(PORT), OK)
	_session = SESSION.instantiate() as GameSession
	_session.profile_id = PROFILE_ID
	_session.rng_seed = 1234
	add_child(_session)
	_session.director.stop()
	var player: Player = _session.players.find_player(1)
	assert_not_null(player)
	var expected: CharacterLook = LookBuilder.from_equipped(LOADOUT)
	var codec: LookCodec = LookCodec.new()
	assert_true(_session.look_sync._looks.has(1), "initial saved look is published without a gear change")
	assert_eq(codec.decode(_session.look_sync._looks.get(1, PackedByteArray())).slots, expected.slots)
	for slot: StringName in CharacterLook.SLOTS:
		var piece: Node = player.gear_rig.skeleton.get_node(String(slot).capitalize()).get_child(0)
		assert_eq(piece.scene_file_path, GearVisual.find(expected.slots[slot]["visual_id"]).scene.resource_path)
		for node: Node in piece.find_children("*", "GeometryInstance3D", true, false):
			var geometry: GeometryInstance3D = node as GeometryInstance3D
			assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_true(player.camera.current)
	assert_true(player.weapons.visible)
