## Research screen: spend, remove, reset, Back and Confirm against a real save file.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/research_screen.tscn")
const XP_RULES: XpRules = preload("res://content/progression/xp_rules.tres")
const PROFILE_ID: StringName = &"test_research_screen"

var screen: ResearchScreen
var profile: CharacterProfile
var closes: int = 0


func before_each() -> void:
	_remove_save()
	closes = 0
	profile = CharacterProfile.load_or_create(PROFILE_ID)
	profile.total_xp = XP_RULES.total_xp_for_level(12)
	screen = SCREEN.instantiate() as ResearchScreen
	add_child_autofree(screen)
	screen.closed.connect(func() -> void: closes += 1)
	screen.open(profile)


func after_each() -> void:
	_remove_save()


func _remove_save() -> void:
	var path: String = CharacterProfile.directory() + String(PROFILE_ID) + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _points_left() -> int:
	return SkillTree.points_available(profile.level, screen.pending)


func test_opens_with_every_skill_as_a_tile_and_focus_on_the_first() -> void:
	assert_eq(profile.level, 12)
	assert_eq(screen.tiles.size(), Content.ids(&"skills").size())
	assert_true(screen.first_tile().has_focus())
	assert_eq(screen.first_tile().node.id, &"steady_hands")
	assert_true(screen.points_label.text.contains("Points left: 12"))
	assert_true(screen.get_node("%Confirm").disabled, "nothing to confirm yet")


func test_adding_ranks_spends_points_and_shows_on_the_tile() -> void:
	screen.tiles[&"steady_hands"].pressed.emit()
	screen.tiles[&"steady_hands"].pressed.emit()
	screen.tiles[&"thick_skin"].pressed.emit()
	assert_eq(screen.pending, {&"steady_hands": 2, &"thick_skin": 1} as Dictionary[StringName, int])
	assert_eq(_points_left(), 9)
	assert_true(screen.points_label.text.contains("Points left: 9"))
	assert_true(screen.tiles[&"steady_hands"].text.contains("2/3"))
	assert_false(screen.get_node("%Confirm").disabled)


func test_a_locked_keystone_takes_no_click_and_says_why() -> void:
	var tile: SkillTile = screen.tiles[&"dead_center"]
	assert_true(tile.text.contains("Needs 8 in branch"))
	tile.pressed.emit()
	assert_false(screen.pending.has(&"dead_center"))


func test_right_click_removes_only_a_new_rank() -> void:
	screen.add_rank(&"quick_draw")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	screen.tiles[&"quick_draw"].gui_input.emit(click)
	assert_false(screen.pending.has(&"quick_draw"))
	assert_eq(_points_left(), 12)


func test_back_with_new_ranks_warns_once_then_discards() -> void:
	screen.add_rank(&"steady_hands")
	screen.back()
	assert_eq(closes, 0, "first Back only warns")
	assert_true(screen.status.text.contains("not saved"))
	screen.back()
	assert_eq(closes, 1)
	assert_true(CharacterProfile.load_or_create(PROFILE_ID).skill_ranks.is_empty(), "nothing was saved")


func test_confirm_saves_and_a_fresh_load_holds_the_same_ranks() -> void:
	screen.add_rank(&"steady_hands")
	screen.add_rank(&"light_feet")
	screen.confirm()
	assert_eq(screen.status.text, "Saved.")
	assert_false(screen.has_unsaved_changes())
	var loaded: CharacterProfile = CharacterProfile.load_or_create(PROFILE_ID)
	assert_eq(SkillEffects.ranks_from(loaded.skill_ranks), screen.pending)
	assert_false(SkillTree.can_rank_down(screen.pending, screen.saved, &"steady_hands"), "saved ranks stay")
	screen.back()
	assert_eq(closes, 1, "no warning once saved")


func test_reset_all_returns_every_point_and_saves_on_confirm() -> void:
	screen.add_rank(&"steady_hands")
	screen.confirm()
	screen.reset_all()
	assert_eq(_points_left(), 12)
	screen.confirm()
	assert_true(CharacterProfile.load_or_create(PROFILE_ID).skill_ranks.is_empty())


func test_over_budget_save_shows_reset_message() -> void:
	profile.skill_ranks = {"steady_hands": 3, "quick_draw": 3, "weak_spot": 3, "fast_hands": 3, "thick_skin": 3}
	profile.total_xp = 0
	screen.open(profile)
	assert_lt(_points_left(), 0)
	assert_true(screen.status.text.contains("Reset all"))
	screen.add_rank(&"deep_pockets")
	assert_false(screen.pending.has(&"deep_pockets"))
