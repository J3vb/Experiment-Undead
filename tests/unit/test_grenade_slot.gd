## HUD grenade slot (frag-grenades plan step 3): count and key follow the local player,
## the slot dims at 0 and shows cooking.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var slot: GrenadeSlot


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	slot = GrenadeSlot.new()
	slot.size = Vector2(300, 36)
	add_child_autofree(slot)
	slot.player = player


func test_count_follows_the_player() -> void:
	player.grenades.count = 2
	slot._process(0.0)
	assert_eq(slot.shown_count, 2)
	assert_false(slot.dimmed())
	assert_eq(slot.modulate.a, 1.0)


func test_dims_at_zero() -> void:
	player.grenades.count = 0
	slot._process(0.0)
	assert_true(slot.dimmed())
	assert_almost_eq(slot.modulate.a, GrenadeSlot.EMPTY_ALPHA, 0.001)


func test_shows_cooking() -> void:
	player.grenades.count = 1
	player.grenades.cooking = true
	slot._process(0.0)
	assert_true(slot.shown_cooking)


func test_key_text_follows_the_binding() -> void:
	assert_eq(slot.key_text, "[%s]" % Settings.key_name(&"lethal"))
	slot.key_text = ""
	Settings.changed.emit(&"bindings", &"lethal", null)
	assert_eq(slot.key_text, "[%s]" % Settings.key_name(&"lethal"), "rebinding updates the key")


func test_local_player_spawn_is_picked_up() -> void:
	slot.player = null
	Events.player_spawned.emit(player)
	assert_eq(slot.player, player)
