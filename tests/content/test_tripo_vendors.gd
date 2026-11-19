## The four Lantern Post stall keepers made in Tripo (tools/assets/tripo/vendors.json): each imports as a moving
## (not lightmapped) skinned body on our 22 bones, keeps its baked maps and carries looping clips.
extends GutTest

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


func test_keepers_idle_loops() -> void:
	for id: String in KEEPERS:
		var players: Array[Node] = _scene(id).find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, id + " has clips")
		var anim: AnimationPlayer = players[0] as AnimationPlayer
		assert_true(anim.has_animation(&"idle"), id + " has idle")
		assert_eq(anim.get_animation(&"idle").loop_mode, Animation.LOOP_LINEAR, id + " idle loops")
