## Captures the actual Character screen at 1440p with a deterministic fixture; needs a display.
extends Node

const SCREEN: PackedScene = preload("res://systems/ui/character_screen.tscn")
const BASES: Array[String] = [
	"rifle_ar", "pistol_service", "talon_dmr", "vest_medium", "charm_dog_tags", "implant_reflex"
]


func _ready() -> void:
	get_window().size = Vector2i(2560, 1440)
	get_window().content_scale_size = Vector2i(1600, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = &"character_screen_preview"
	profile.display_name = "Rook"
	profile.total_xp = CharacterProfile.XP_RULES.total_xp_for_level(14)
	for index: int in 48:
		profile.stash[index] = _item(index)
	for index: int in CharacterScreen.SLOTS.size():
		var base: String = ["talon_dmr", "pistol_service", "vest_medium", "charm_dog_tags", "implant_reflex"][index]
		var rarity: String = ["epic", "rare", "rare", "epic", "legendary"][index]
		profile.loadout[CharacterScreen.SLOTS[index]] = _item(index).merged({"base": base, "rar": rarity}, true)
	profile.loadout[&"primary"]["aff"] = [["reload_pct", 2, 0.0], ["mag_pct", 3, 1.0]]
	var screen: CharacterScreen = SCREEN.instantiate() as CharacterScreen
	add_child(screen)
	screen.open(profile)
	for button: Button in screen.stash_buttons:
		if button.get_meta("stash_index") == 42:
			button.grab_focus()
	screen.tooltip.set_comparing(true)
	for frame: int in 12:
		await RenderingServer.frame_post_draw
	var path: String = "res://tests/artifacts/character_screen_1440p.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	assert(error == OK, "Character screenshot could not be written")
	get_tree().quit(int(error))


func _item(index: int) -> Dictionary:
	return {
		"v": 1,
		"uid": "preview_%d" % index,
		"base": BASES[index % BASES.size()],
		"rar": ItemRoller.RARITIES[4 - index % 5],
		"ilvl": 15 + index % 20,
		"aff": [["reload_pct", 2, 2.0 / 3.0], ["mag_pct", 3, 0.5]] if index % 6 < 3 else [],
		"imp": []
	}
