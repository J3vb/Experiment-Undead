## Every rarity look loads with the shared design colours, bounded glow and intended motion.
extends GutTest

const RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"prototype"]
const COLOURS: Array[String] = ["d9d9d2", "3fe0c8", "3d7dff", "a64dff", "ff8a1c", "8dff3a"]
const GLOW: Array[float] = [0.0, 0.0, 0.6, 1.2, 2.0, 2.0]
const PULSE: Array[float] = [0.0, 0.0, 0.0, 4.0, 4.0, 0.0]


func test_all_six_rarity_looks_load_and_are_indexed() -> void:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at("res://content/looks/rarity"):
		if file.trim_suffix(".remap").ends_with(".tres"):
			files.append(file.trim_suffix(".remap"))
	assert_eq(files.size(), 6, "exactly one resource per rarity")
	for rarity: StringName in RARITIES:
		var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
		assert_not_null(look, String(rarity))
		if look == null:
			continue
		assert_eq(look.rarity, rarity)
		assert_same(Content.get_item(&"looks", rarity), look)


func test_rarity_colours_glow_and_motion_match_the_design() -> void:
	for index: int in RARITIES.size():
		var look: RarityLook = load("res://content/looks/rarity/%s.tres" % RARITIES[index]) as RarityLook
		assert_not_null(look, String(RARITIES[index]))
		if look == null:
			continue
		assert_true(look.trim_color.is_equal_approx(Color(COLOURS[index])), String(RARITIES[index]))
		assert_almost_eq(look.glow_strength, GLOW[index], 0.000001)
		assert_between(look.glow_strength, 0.0, 2.0)
		assert_eq(look.pulse_seconds, PULSE[index])
		assert_eq(look.flicker, RARITIES[index] == &"prototype")
