## VitalsPanel shows the local player's health as five segments and the sprint bar.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var panel: VitalsPanel
var player: Player


func before_each() -> void:
	panel = VitalsPanel.new()
	add_child_autofree(panel)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	Events.player_spawned.emit(player)


func test_segments_follow_health() -> void:
	Events.player_health_changed.emit(player, 100.0, 100.0)
	assert_almost_eq(panel.filled_segments(), 5.0, 0.001)
	Events.player_health_changed.emit(player, 50.0, 100.0)
	assert_almost_eq(panel.filled_segments(), 2.5, 0.001)
	Events.player_health_changed.emit(player, 10.0, 250.0)
	assert_almost_eq(panel.filled_segments(), 0.2, 0.001)


func test_low_health_turns_red() -> void:
	Events.player_health_changed.emit(player, 30.0, 100.0)
	assert_eq(panel.health_colour(), VitalsPanel.TEXT)
	Events.player_health_changed.emit(player, 29.0, 100.0)
	assert_eq(panel.health_colour(), VitalsPanel.DANGER)


func test_other_players_health_ignored() -> void:
	Events.player_health_changed.emit(player, 40.0, 100.0)
	var other: Player = Player.new()
	autofree(other)
	Events.player_health_changed.emit(other, 100.0, 100.0)
	assert_almost_eq(panel.filled_segments(), 2.0, 0.001)


func test_stamina_share_and_cooldown() -> void:
	player.sprint_left = player.sprint_time * player.get_stat(&"sprint_time") * 0.5
	panel._process(0.0)
	assert_almost_eq(panel.stamina_share, 0.5, 0.01)
	assert_false(panel.cooling)
	assert_eq(panel.stamina_colour(), VitalsPanel.TEXT)
	player.sprint_left = 0.0
	player.moves.sprint_cooldown_left = 1.0
	panel._process(0.0)
	assert_almost_eq(panel.stamina_share, 0.0, 0.001)
	assert_true(panel.cooling)
	assert_eq(panel.stamina_colour(), VitalsPanel.WARN)


func test_no_player_draws_without_errors() -> void:
	var lonely: VitalsPanel = VitalsPanel.new()
	add_child_autofree(lonely)
	lonely.size = Vector2(360.0, 72.0)
	lonely._process(0.0)
	lonely.queue_redraw()
	await wait_process_frames(1)
	assert_null(lonely.player)
