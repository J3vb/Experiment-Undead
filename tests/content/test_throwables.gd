## Every throwable in content/throwables/ is complete and safe to throw.
extends GutTest


func test_every_throwable_is_complete() -> void:
	var ids: Array[StringName] = Content.sorted_ids(&"throwables")
	assert_gt(ids.size(), 0, "at least the frag")
	for id: StringName in ids:
		var data: ThrowableData = Content.get_item(&"throwables", id) as ThrowableData
		assert_not_null(data, "%s is a ThrowableData" % id)
		if data == null:
			continue
		assert_eq(data.id, id, "id matches the file name")
		assert_gte(data.carry, 1, id)
		assert_gt(data.fuse, 0.0, id)
		assert_gt(data.full_radius, 0.0, id)
		assert_gt(data.radius, data.full_radius, id)
		assert_gt(data.throw_speed, 0.0, id)
		assert_gt(data.centre_damage, 0.0, id)
		assert_lt(data.self_damage_max, 100.0, "%s never downs a full-health player alone" % id)
		assert_not_null(data.scene, id)
		if data.scene:
			var grenade: Grenade = data.scene.instantiate() as Grenade
			assert_not_null(grenade, "%s scene is a Grenade" % id)
			if grenade:
				grenade.free()
