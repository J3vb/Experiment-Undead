## Every Serum and weapon has a HUD icon, so the HUD never falls back to letters or an empty picture.
extends GutTest


func test_every_serum_has_an_icon() -> void:
	for id: StringName in Content.ids(&"serums"):
		var serum: SerumData = Content.get_item(&"serums", id) as SerumData
		assert_not_null(serum.icon, "%s has no HUD icon" % id)
		if serum.icon:
			assert_eq(serum.icon.resource_path, "res://assets/ui/hud/serum_%s.svg" % id)


func test_every_weapon_has_a_hud_icon() -> void:
	for type: StringName in [&"weapons", &"melee"]:
		for id: StringName in Content.ids(type):
			var data: WeaponData = Content.get_item(type, id) as WeaponData
			assert_not_null(data.hud_icon, "%s has no HUD icon" % id)
			if data.hud_icon:
				assert_string_starts_with(data.hud_icon.resource_path, "res://assets/ui/hud/gun_")


func test_reforged_guns_keep_their_base_icon() -> void:
	for id: StringName in Content.ids(&"weapons"):
		var data: WeaponData = Content.get_item(&"weapons", id) as WeaponData
		if data.upgraded:
			assert_eq(data.upgraded.hud_icon, data.hud_icon, "%s and its Reforged copy share a class icon" % id)
