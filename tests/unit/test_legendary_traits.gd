## Server-side Legendary traits change only the hits of the gun that carries them.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var traits: LegendaryTraits
var player: Player
var first: Zombie
var second: Zombie


func before_each() -> void:
	traits = LegendaryTraits.new()
	add_child_autofree(traits)
	player = PLAYER.instantiate() as Player
	player.net_id = 1
	add_child_autofree(player)
	player.set_physics_process(false)
	player.item_guns["tw"] = ItemInstance.new({"uid": "tw", "rar": "legendary", "trait": ["tidewater", 1.0]})
	player.item_guns["plain"] = ItemInstance.new({"uid": "plain", "rar": "rare"})
	first = autofree(Zombie.new())
	second = autofree(Zombie.new())


func _hit(zombie: Zombie, uid: String = "tw") -> float:
	var info: DamageInfo = DamageInfo.create(100.0, player)
	info.item_uid = uid
	traits.on_hit(zombie, info)
	return info.amount


func test_tidewater_adds_a_stack_per_hit_up_to_ten() -> void:
	var amounts: Array[float] = []
	for index: int in 12:
		amounts.append(_hit(first))
	for index: int in 4:
		assert_almost_eq(amounts[index], 100.0 + 5.0 * index, 0.001, "hit %d" % index)
	assert_almost_eq(amounts[10], 150.0, 0.001, "ten stacks")
	assert_almost_eq(amounts[11], 150.0, 0.001, "never more than ten")


func test_tidewater_keeps_half_the_stacks_on_a_new_target() -> void:
	for index: int in 11:
		_hit(first)
	assert_almost_eq(_hit(second), 125.0, 0.001, "half of ten")
	assert_almost_eq(_hit(second), 130.0, 0.001)
	assert_almost_eq(_hit(first), 115.0, 0.001, "half of six back on the first")


func test_other_guns_and_hits_without_an_item_are_unchanged() -> void:
	_hit(first)
	assert_eq(_hit(first, "plain"), 100.0)
	assert_eq(_hit(first, ""), 100.0)
	assert_eq(_hit(first, "missing"), 100.0)
	var stranger: DamageInfo = DamageInfo.create(100.0, null)
	stranger.item_uid = "tw"
	traits.on_hit(first, stranger)
	assert_eq(stranger.amount, 100.0)
