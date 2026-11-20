## Every loot gun and gear base has a rendered 128 px icon (tools/render_item_icons.gd).
extends GutTest

const ICONS: Script = preload("res://tools/render_item_icons.gd")


func test_every_loot_base_has_an_icon_with_transparency() -> void:
	var bases: Array[Resource] = ICONS.item_bases()
	assert_gt(bases.size(), 20)
	for base: Resource in bases:
		var item: Dictionary = {"base": String(base.get("id"))}
		var texture: Texture2D = ItemTooltip.icon_for(item)
		assert_not_null(texture, "%s needs an icon: run tools/render_item_icons.tscn" % base.get("id"))
		if texture == null:
			continue
		var image: Image = texture.get_image()
		assert_eq(image.get_size(), Vector2i(128, 128), String(base.get("id")))
		assert_true(image.detect_alpha() != Image.ALPHA_NONE, "%s icon keeps a clear background" % base.get("id"))


func test_unknown_or_empty_items_have_no_icon() -> void:
	assert_null(ItemTooltip.icon_for({}))
	assert_null(ItemTooltip.icon_for({"base": "not_a_base"}))
