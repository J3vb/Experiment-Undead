## The four Lantern Post stall keepers made in Tripo (tools/assets/tripo/vendors.json): each imports as a moving
## (not lightmapped) skinned body on our 22 bones, keeps its baked maps and carries the keeper clips.
extends GutTest

const GEAR_IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const FOLDER: String = "res://assets/models/characters/%s.glb"
const KEEPERS: Array[String] = ["npc_quartermaster", "npc_gunsmith", "npc_technician", "npc_cordon_liaison"]


func _scene(id: String) -> Node:
	var packed: PackedScene = load(FOLDER % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	return scene


func test_keepers_are_dynamic_for_light_baking() -> void:
	for id: String in KEEPERS:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(FOLDER % id + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3, id + " is a moving actor")


func test_keepers_are_skinned_on_our_skeleton_with_baked_maps() -> void:
	for id: String in KEEPERS:
		var scene: Node = _scene(id)
		var skeletons: Array[Node] = scene.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, id + " has one skeleton")
		assert_eq((skeletons[0] as Skeleton3D).get_bone_count(), 22, id + " uses our 22 bones")
		var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, id + " is one mesh")
		var material: StandardMaterial3D = (
			(meshes[0] as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		)
		assert_not_null(material, id + " keeps its baked material")
		assert_not_null(material.albedo_texture, id + " albedo map")
		assert_not_null(material.normal_texture, id + " normal map")


func test_keepers_carry_the_five_keeper_clips() -> void:
	var one_shots: Array[StringName] = [&"greet"]
	var expected: Array[StringName] = GEAR_IMPORTER.KEEPER_LOOPS + one_shots
	expected.sort()
	for id: String in KEEPERS:
		var players: Array[Node] = _scene(id).find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, id + " has clips")
		var anim: AnimationPlayer = players[0] as AnimationPlayer
		var found: Array[StringName] = []
		for clip: StringName in anim.get_animation_list():
			found.append(clip)
		found.sort()
		assert_eq(found, expected, id + " has exactly the keeper clips")
		for clip: StringName in found:
			var looped: bool = anim.get_animation(clip).loop_mode == Animation.LOOP_LINEAR
			assert_eq(looped, clip not in one_shots, id + " " + String(clip) + " loop mode")
