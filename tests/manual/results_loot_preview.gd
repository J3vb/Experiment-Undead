## Render the results loot column: Godot --script res://tests/manual/results_loot_preview.gd.
extends SceneTree


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var screen: Control = load("res://systems/ui/results_screen.tscn").instantiate() as Control
	root.add_child(screen)
	(
		screen
		. show_results(
			{
				"round": 17,
				"kills": 412,
				"headshots": 168,
				"points": 61240,
				"xp": 14930,
				"start_total_xp": 4000,
				"total_xp": 18930,
				"loot":
				[
					{"base": "rifle_ar", "rar": "legendary", "ilvl": 17},
					{"base": "talon_dmr", "rar": "rare", "ilvl": 15},
					{"base": "kestrel_smg", "rar": "uncommon", "ilvl": 12},
				],
				"loot_lost": 1,
			},
			2468
		)
	)
	await create_timer(1.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/manual/results_loot_preview.png")
	quit()
