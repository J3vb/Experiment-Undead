## Every Serum has a HUD icon, so the Serum slots never fall back to badge letters.
extends GutTest


func test_every_serum_has_an_icon() -> void:
	for id: StringName in Content.ids(&"serums"):
		var serum: SerumData = Content.get_item(&"serums", id) as SerumData
		assert_not_null(serum.icon, "%s has no HUD icon" % id)
		if serum.icon:
			assert_eq(serum.icon.resource_path, "res://assets/ui/hud/serum_%s.svg" % id)
