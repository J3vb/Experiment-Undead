## The drop feed shows the owner's own drops in rarity colour and shape, three rows at most, each for 4 s.
extends GutTest

const FEED: PackedScene = preload("res://systems/ui/loot_feed.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var feed: LootFeed
var player: Player


func before_each() -> void:
	feed = FEED.instantiate() as LootFeed
	add_child_autofree(feed)
	player = _player(1)


func _player(authority: int) -> Player:
	var owner_player: Player = PLAYER.instantiate() as Player
	owner_player.set_multiplayer_authority(authority)
	add_child_autofree(owner_player)
	owner_player.set_physics_process(false)
	return owner_player


func _drop(rarity: String, base: String = "talon_dmr", by: Player = player) -> void:
	Events.loot_dropped.emit(by, {"v": 1, "uid": "u_%s" % rarity, "base": base, "rar": rarity, "aff": []})


func test_a_drop_shows_rarity_shape_and_name_in_rarity_colour() -> void:
	_drop("rare")
	var name: String = Content.weapon(&"talon_dmr").display_name
	assert_eq(feed.row_texts(), ["■ Rare %s" % name] as Array[String])
	var rare: RarityData = Content.get_item(&"loot", &"rare") as RarityData
	assert_eq((feed.get_child(0) as Label).get_theme_color(&"font_color"), rare.colour)


func test_newest_on_top_and_a_fourth_drop_pushes_out_the_oldest() -> void:
	for rarity: String in ["common", "uncommon", "rare", "epic"]:
		_drop(rarity)
	var texts: Array[String] = feed.row_texts()
	assert_eq(texts.size(), 3)
	assert_true(texts[0].contains("Epic"), "newest on top")
	assert_false(" ".join(texts).contains("Common"), "oldest pushed out")


func test_rows_fade_out_after_four_seconds() -> void:
	_drop("rare")
	await wait_seconds(LootFeed.SHOW_TIME + 0.2)
	assert_eq(feed.row_texts().size(), 0)


func test_another_players_drop_shows_nothing() -> void:
	_drop("legendary", "talon_dmr", _player(2))
	assert_eq(feed.row_texts().size(), 0)
