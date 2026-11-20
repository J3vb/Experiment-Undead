## Every primary viewmodel has one CharmMount for the worn charm; sidearms have none (gear-visuals.md).
extends GutTest


func test_primaries_have_one_charm_mount_and_sidearms_none() -> void:
	for id: StringName in Content.sorted_ids(&"weapons"):
		var data: WeaponData = Content.weapon(id)
		if data.viewmodel_scene == null:
			continue
		var viewmodel: Node3D = data.viewmodel_scene.instantiate() as Node3D
		var mounts: Array[Node] = viewmodel.find_children("CharmMount", "Marker3D", true, false)
		var expected: int = 1 if data.slot == WeaponData.Slot.PRIMARY else 0
		assert_eq(mounts.size(), expected, "%s has %d CharmMount" % [id, expected])
		viewmodel.free()
