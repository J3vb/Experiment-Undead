## Personal drop pickup, full-Pack refusal and sixty-second expiry.
extends GutTest

const SCENE: PackedScene = preload("res://systems/loot/loot_drop.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var drop: LootDrop
var player: Player
var pack: Pack


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	pack = Pack.new()
	drop = SCENE.instantiate() as LootDrop
	drop.player = player
	drop.pack = pack
	drop.item = {"uid": "pickup", "base": "vest_light", "rar": "rare", "ilvl": 3}
	add_child_autofree(drop)


func test_pickup_adds_item_once_and_frees_drop() -> void:
	assert_string_contains(drop.get_prompt(player), "Lantern Rig")
	drop.interact(player)
	drop.interact(player)
	assert_eq(pack.items, [drop.item])
	await wait_process_frames(2)
	assert_false(is_instance_valid(drop))


func test_full_pack_refuses_and_keeps_drop() -> void:
	for index: int in Pack.CAPACITY:
		pack.add({"uid": str(index)})
	assert_eq(drop.get_prompt(player), "Pack full")
	drop.interact(player)
	assert_false(drop.is_queued_for_deletion())
	assert_eq(pack.items.size(), 6)
	pack.remove(0)
	drop.interact(player)
	assert_true(drop.is_queued_for_deletion())


func test_sixty_second_timer_frees_the_drop() -> void:
	assert_eq(drop.lifetime.wait_time, 60.0)
	assert_true(drop.lifetime.one_shot)
	# Advance the real physics Timer quickly; no minute-long unit test.
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 1000.0
	await wait_process_frames(10)
	Engine.time_scale = previous_scale
	assert_false(is_instance_valid(drop))
	assert_true(pack.items.is_empty())


func test_out_of_range_and_downed_cannot_pick_up() -> void:
	player.position = Vector3(10, 0, 0)
	drop.interact(player)
	assert_eq(drop.get_prompt(player), "")
	player.position = Vector3.ZERO
	player.is_downed = true
	drop.interact(player)
	assert_true(pack.items.is_empty())
	assert_false(drop.is_queued_for_deletion())
