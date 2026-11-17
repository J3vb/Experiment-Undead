## The knife is MELEE data kept out of the gun folder, so the Vault, loot and
## wall buys can never offer it.
extends GutTest


func test_knife_is_melee_and_never_a_gun() -> void:
	var knife: WeaponData = Content.get_item(&"melee", &"knife") as WeaponData
	assert_not_null(knife)
	assert_eq(knife.slot, WeaponData.Slot.MELEE)
	assert_eq(knife.id, &"knife")
	assert_eq(knife.damage, 150.0)
	assert_eq(knife.max_range, 2.0)
	assert_almost_eq(knife.get_fire_interval(), 0.6, 0.001)
	assert_false(Content.ids(&"weapons").has(&"knife"), "not a Vault or loot gun")
	assert_eq(knife.loot_tags.size(), 0)


func test_no_gun_uses_the_melee_slot() -> void:
	for id: StringName in Content.ids(&"weapons"):
		assert_ne(Content.weapon(id).slot, WeaponData.Slot.MELEE, id)
