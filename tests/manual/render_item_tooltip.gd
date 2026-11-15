## Captures three tooltip states at 1440p; run with a display and --script res://tests/manual/render_item_tooltip.gd.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background: ColorRect = ColorRect.new()
	background.color = Color("0b1014")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var title: Label = Label.new()
	title.theme = load("res://systems/ui/theme.tres") as Theme
	title.position = Vector2(48, 32)
	title.text = "Character screen · item tooltip preview"
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)
	var captions: Array[String] = [
		"Selected item", "Hold Shift · compare with Talon DMR", "Unknown content stays readable"
	]
	for index: int in 3:
		var caption: Label = Label.new()
		caption.theme = title.theme
		caption.position = Vector2(48 + index * 510, 108)
		caption.text = captions[index]
		root.add_child(caption)
		var tooltip: Control = (load("res://systems/ui/item_tooltip.tscn") as PackedScene).instantiate() as Control
		tooltip.position = Vector2(48 + index * 510, 160)
		tooltip.size.x = 480
		root.add_child(tooltip)
		var item: Dictionary = {
			"uid": "preview",
			"base": "rifle_ar",
			"rar": "legendary",
			"ilvl": 17,
			"aff": [["reload_pct", 2, 2.0 / 3.0], ["mag_pct", 3, 0.5]],
			"imp": []
		}
		if index == 2:
			item.aff = [["unknown_affix", 1, 0.5]]
		tooltip.call("show_item", item, {"base": "talon_dmr", "aff": [["reload_pct", 1, 0.0]]})
		tooltip.call("set_comparing", index == 1)
	for frame: int in 12:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	root.get_texture().get_image().save_png("res://screenshots/item_tooltip_1440p.png")
	quit()
