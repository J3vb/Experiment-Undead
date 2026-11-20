## The shuffled drop deck: every type comes out once before any repeats, and the Supply
## Crate (deck_chance 0.333) sits in about one deck in three.
extends GutTest

const SESSION_SCENE: PackedScene = preload("res://systems/game/game_session.tscn")

var drops: PowerUpDrops
var session: GameSession


func before_each() -> void:
	var scene_drops: PowerUpDrops = SESSION_SCENE.instantiate().get_node(^"PowerUpDrops") as PowerUpDrops
	session = GameSession.new()
	session.rng.seed = 11
	autofree(session)
	drops = PowerUpDrops.new()
	drops.session = session
	drops.power_ups = scene_drops.power_ups
	autofree(drops)
	scene_drops.get_parent().free()


func _deck_size_without_crate() -> int:
	var count: int = 0
	for data: PowerUpData in drops.power_ups:
		if data.deck_chance >= 1.0:
			count += 1
	return count


func test_the_deck_holds_all_seven_power_ups() -> void:
	var ids: PackedStringArray = []
	for data: PowerUpData in drops.power_ups:
		ids.append(String(data.id))
	ids.sort()
	assert_eq(
		ids, PackedStringArray(["overkill", "payday", "purge", "resupply", "scrap_kit", "stasis", "supply_crate"])
	)


func test_no_repeats_before_every_type_came_out() -> void:
	var always: int = _deck_size_without_crate()
	for deck: int in 20:
		var seen: Dictionary[PowerUpData, bool] = {drops._next(): true}
		while not drops._deck.is_empty():
			var data: PowerUpData = drops._next()
			assert_false(seen.has(data), "no repeat inside a deck")
			seen[data] = true
		assert_between(seen.size(), always, always + 1, "every type once, the crate only sometimes")


func test_supply_crate_in_about_one_deck_in_three() -> void:
	var with_crate: int = 0
	for deck: int in 300:
		drops._deck.clear()
		var first: PowerUpData = drops._next()
		var crate: bool = first.id == &"supply_crate"
		for data: PowerUpData in drops._deck:
			crate = crate or data.id == &"supply_crate"
		with_crate += 1 if crate else 0
	assert_between(with_crate, 70, 130, "about 100 of 300 decks (seeded)")
