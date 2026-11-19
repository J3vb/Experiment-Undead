## Personal drop pickup, full-Pack refusal, sixty-second expiry and the landing glow.
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
	assert_false(drop.lifetime.is_stopped(), "the expiry timer runs from spawn")
	drop.lifetime.timeout.emit()
	await wait_process_frames(2)
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


func test_drop_glows_and_flashes_on_landing() -> void:
	var ring: StandardMaterial3D = (drop.get_node(^"Ring") as MeshInstance3D).material_override as StandardMaterial3D
	assert_ne(ring.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded ignores emission")
	assert_gt(ring.emission_energy_multiplier, 1.0, "bright enough to bloom")
	var light: OmniLight3D = drop.get_node(^"Glow") as OmniLight3D
	var rare: Color = (Content.get_item(&"loot", &"rare") as RarityData).colour
	assert_eq(light.light_color, rare, "light in the rarity colour")
	assert_gt(light.light_energy, LootDrop.STEADY_LIGHT, "flash on landing")
	await wait_seconds(1.4)
	assert_almost_eq(light.light_energy, LootDrop.STEADY_LIGHT, 0.01, "settles to a steady glow")
