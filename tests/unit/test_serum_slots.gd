## SerumSlots shows the local player's held Serums as filled slots and keeps at least four.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var slots: SerumSlots
var player: Player


func before_each() -> void:
	slots = SerumSlots.new()
	add_child_autofree(slots)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	Events.player_spawned.emit(player)


func _give(id: StringName) -> SerumData:
	var serum: SerumData = Content.get_item(&"serums", id) as SerumData
	player.serums.append(serum)
	Events.serum_gained.emit(player, serum)
	return serum


func test_no_serums_shows_four_empty_slots() -> void:
	assert_eq(slots.slot_count(), 4)
	assert_eq(slots.shown.size(), 0)


func test_two_serums_fill_two_slots_in_buy_order() -> void:
	_give(&"ironhide")
	_give(&"stride")
	_give(&"stride")
	assert_eq(slots.shown_ids(), PackedStringArray(["ironhide", "stride"]))
	assert_eq(slots.slot_count(), 4)


func test_all_eight_serums_grow_the_row() -> void:
	for id: StringName in Content.ids(&"serums"):
		_give(id)
	assert_eq(slots.shown.size(), 8)
	assert_eq(slots.slot_count(), 8)
	assert_almost_eq(slots.custom_minimum_size.x, 8 * SerumSlots.SLOT + 7 * SerumSlots.GAP, 0.01)


func test_going_down_empties_lost_slots() -> void:
	_give(&"ironhide")
	_give(&"second_wind")
	player.serums.erase(Content.get_item(&"serums", &"second_wind"))
	Events.player_revived.emit(player)
	assert_eq(slots.shown_ids(), PackedStringArray(["ironhide"]))
	player.serums.clear()
	Events.player_health_changed.emit(player, 100.0, 100.0)
	assert_eq(slots.shown.size(), 0)


func test_other_players_serums_ignored() -> void:
	var other: Player = Player.new()
	autofree(other)
	Events.serum_gained.emit(other, Content.get_item(&"serums", &"mule") as SerumData)
	assert_eq(slots.shown.size(), 0)


func test_missing_icon_warns_once_and_still_draws() -> void:
	var serum: SerumData = SerumData.new()
	serum.id = &"test_serum"
	serum.badge = "XX"
	player.serums.append(serum)
	Events.serum_gained.emit(player, serum)
	assert_eq(slots.shown_ids(), PackedStringArray(["test_serum"]))
	assert_true(slots._warned.has(&"test_serum"), "a missing icon warns")
	Events.serum_gained.emit(player, serum)
	assert_eq(slots._warned.size(), 1, "and only once")
	slots.size = Vector2(300.0, 44.0)
	slots.queue_redraw()
	await wait_process_frames(1)
	assert_eq(slots.slot_count(), 4, "the badge-letter fallback draws without errors")


func test_no_local_player_never_warns() -> void:
	var lonely: SerumSlots = SerumSlots.new()
	add_child_autofree(lonely)
	var serum: SerumData = SerumData.new()
	serum.id = &"server_side"
	var stranger: Player = Player.new()
	autofree(stranger)
	Events.serum_gained.emit(stranger, serum)
	assert_true(lonely._warned.is_empty())
