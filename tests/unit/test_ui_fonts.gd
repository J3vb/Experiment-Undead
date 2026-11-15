## The UI theme uses Atkinson Hyperlegible Next for text and Mono for changing numbers.
extends GutTest

const THEME: Theme = preload("res://systems/ui/theme.tres")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const WGHT: int = 2003265652


func test_theme_default_font_is_atkinson_next() -> void:
	var text: FontVariation = THEME.default_font as FontVariation
	assert_not_null(text)
	assert_eq(text.base_font.get_font_name(), "Atkinson Hyperlegible Next")
	assert_eq(text.variation_opentype[WGHT], 400)


func test_label_mono_variation_uses_mono_font() -> void:
	assert_eq(THEME.get_type_variation_base(&"LabelMono"), &"Label")
	var mono: FontVariation = THEME.get_font(&"font", &"LabelMono") as FontVariation
	assert_not_null(mono)
	assert_string_starts_with(mono.base_font.get_font_name(), "Atkinson Hyperlegible Mono")
	assert_eq(mono.variation_opentype[WGHT], 500)


func test_hud_numbers_use_mono() -> void:
	var hud: Hud = HUD.instantiate() as Hud
	add_child_autofree(hud)
	for path: String in ["Root/Loadout/Ammo/AmmoLabel", "Root/Loadout/PointsLabel", "Root/RoundInfo/RoundLabel"]:
		var label: Label = hud.get_node(path) as Label
		assert_eq(label.theme_type_variation, &"LabelMono", path)
	var name_label: Label = hud.get_node("Root/RoundInfo/MapName") as Label
	var text: FontVariation = name_label.get_theme_font(&"font") as FontVariation
	assert_eq(text.base_font.get_font_name(), "Atkinson Hyperlegible Next")


func test_font_licences_ship_with_fonts() -> void:
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-AtkinsonHyperlegibleNext.txt"))
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-AtkinsonHyperlegibleMono.txt"))
