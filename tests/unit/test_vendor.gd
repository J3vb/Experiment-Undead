## A Lantern Post stall keeper (F-76): prompt, lines in order only for this peer's own player, greet then idle,
## and a head that turns only to this peer's player inside LOOK_RANGE.
extends GutTest

const SCENE: PackedScene = preload("res://systems/hub/vendor.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const DATA: VendorData = preload("res://content/vendors/quartermaster.tres")

var vendor: Vendor
var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	player.net_id = multiplayer.get_unique_id()
	add_child_autofree(player)
	player.set_physics_process(false)
	vendor = SCENE.instantiate() as Vendor
	vendor.data = DATA
	add_child_autofree(vendor)


func test_prompt_names_the_keeper_and_talk_stays_on_this_peer() -> void:
	assert_eq(vendor.get_prompt(player), "Talk to Odile Brandt [F]")
	assert_true(vendor.is_local(), "talking is personal, no server request")


func test_talks_give_the_lines_in_order_and_wrap_after_four() -> void:
	assert_false(vendor.line.visible)
	vendor.interact(player)
	assert_true(vendor.line.visible)
	assert_eq(vendor.line.text, DATA.lines[0])
	vendor.interact(player)
	assert_eq(vendor.line.text, DATA.lines[1])
	vendor.interact(player)
	vendor.interact(player)
	vendor.interact(player)
	assert_eq(vendor.line.text, DATA.lines[0], "back to the first line after the fourth")


func test_line_hides_after_its_time() -> void:
	vendor.interact(player)
	vendor._process(Vendor.LINE_SECONDS + 0.1)
	assert_false(vendor.line.visible)


func test_a_remote_players_talk_shows_nothing_here() -> void:
	var other: Player = PLAYER.instantiate() as Player
	other.net_id = player.net_id + 7
	add_child_autofree(other)
	other.set_physics_process(false)
	vendor.interact(other)
	assert_false(vendor.line.visible, "the host runs interact for remote players too; they see their own line")
	assert_eq(vendor.next_line, 0)


func test_talk_plays_the_greet_then_goes_back_to_the_idle() -> void:
	assert_eq(vendor.anim.current_animation, String(DATA.idle_clip))
	vendor.interact(player)
	assert_eq(vendor.anim.current_animation, String(Vendor.GREET))
	assert_eq(vendor.anim.get_queue().size(), 1)
	assert_true(vendor.anim.get_queue().has(DATA.idle_clip), "then back to the idle")


func test_head_turns_to_this_peers_player_only_inside_range() -> void:
	assert_not_null(vendor.look, "the head turn modifier sits on the skeleton")
	assert_eq(vendor.look.get_node(vendor.look.target_node), vendor.look_target)
	player.global_position = vendor.global_position + Vector3(0, 0, Vendor.LOOK_RANGE + 1.0)
	vendor.update_look()
	var ahead: Vector3 = vendor.look_target.global_position
	assert_almost_eq(ahead, vendor.to_global(Vector3(0, 1.55, 2.5)), Vector3.ONE * 0.01, "straight ahead")
	player.global_position = vendor.global_position + Vector3(1.0, 0, 2.0)
	vendor.update_look()
	assert_almost_eq(vendor.look_target.global_position, player.camera.global_position, Vector3.ONE * 0.01)


func test_head_ignores_a_remote_player_in_range() -> void:
	player.net_id += 7
	player.global_position = vendor.global_position + Vector3(0, 0, 1.5)
	vendor.update_look()
	assert_almost_eq(vendor.look_target.global_position, vendor.to_global(Vector3(0, 1.55, 2.5)), Vector3.ONE * 0.01)


func test_a_missing_idle_clip_leaves_the_keeper_still_without_errors() -> void:
	var broken: VendorData = DATA.duplicate() as VendorData
	broken.idle_clip = &"no_such_clip"
	var still: Vendor = SCENE.instantiate() as Vendor
	still.data = broken
	add_child_autofree(still)
	assert_false(still.anim.is_playing(), "logs vendor_clip_missing and stands in rest pose")
