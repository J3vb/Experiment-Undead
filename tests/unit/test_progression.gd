## Checks authority-only XP grants, per-player totals and ordered level-up facts.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var progression: ProgressionService
var player: Player


func before_each() -> void:
	progression = ProgressionService.new()
	add_child_autofree(progression)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	watch_signals(Events)
	watch_signals(progression)


func test_body_kill_grants_enemy_reward() -> void:
	var zombie: Zombie = Zombie.new()
	autofree(zombie)
	zombie.data = EnemyData.new()
	zombie.data.xp_reward = 17
	Events.enemy_killed.emit(zombie, DamageInfo.create(100.0, player))
	assert_eq(progression.get_xp(player), 17)


func test_headshot_kill_grants_enemy_reward_plus_five() -> void:
	var zombie: Zombie = Zombie.new()
	autofree(zombie)
	zombie.data = EnemyData.new()
	zombie.data.xp_reward = 17
	var info: DamageInfo = DamageInfo.create(100.0, player)
	info.hit_zone = DamageInfo.Zone.HEAD
	Events.enemy_killed.emit(zombie, info)
	assert_eq(progression.get_xp(player), 22)
	assert_eq(zombie.data.xp_reward, 17, "enemy data stays unchanged")


func test_round_three_pays_each_living_player_only() -> void:
	var other: Player = PLAYER.instantiate() as Player
	add_child_autofree(other)
	other.set_physics_process(false)
	var dead: Player = PLAYER.instantiate() as Player
	add_child_autofree(dead)
	dead.set_physics_process(false)
	dead.health.is_dead = true
	Events.round_ended.emit(3)
	assert_eq(progression.get_xp(player), 150)
	assert_eq(progression.get_xp(other), 150)
	assert_eq(progression.get_xp(dead), 0)


func test_big_grant_emits_each_new_level_in_order() -> void:
	progression.add_xp(player, 3650)
	assert_eq(progression.get_level(player), 4)
	assert_signal_emit_count(Events, "player_leveled_up", 3)
	for index: int in range(3):
		assert_eq(get_signal_parameters(Events, "player_leveled_up", index), [player, index + 2])
	assert_signal_emitted_with_parameters(progression, "xp_gained", [player, 3650, 3650])


func test_starting_total_does_not_change_run_xp_or_emit_level_ups() -> void:
	assert_eq(progression.get_xp(player), 0)
	assert_eq(progression.get_total_xp(player), 0)
	assert_eq(progression.get_level(player), 1)
	progression.set_start_total(player, 1699)
	assert_eq(progression.get_total_xp(player), 1699)
	assert_eq(progression.get_level(player), 2)
	assert_eq(progression.get_xp(player), 0)
	assert_signal_not_emitted(Events, "player_leveled_up")
	progression.add_xp(player, 1)
	assert_eq(progression.get_total_xp(player), 1700)
	assert_eq(progression.get_xp(player), 1)
	assert_signal_emitted_with_parameters(Events, "player_leveled_up", [player, 3])


func test_exfil_bonus_uses_only_run_xp() -> void:
	progression.set_start_total(player, 10000)
	progression.add_xp(player, 1000)
	progression.add_xp(player, int(progression.get_xp(player) * 0.5))
	assert_eq(progression.get_xp(player), 1500)
	assert_eq(progression.get_total_xp(player), 11500)


func test_no_level_up_past_fifty() -> void:
	progression.set_start_total(player, 1444149)
	progression.add_xp(player, 100000)
	progression.add_xp(player, 100000)
	assert_eq(progression.get_level(player), 50)
	assert_signal_emit_count(Events, "player_leveled_up", 1)
	assert_signal_emitted_with_parameters(Events, "player_leveled_up", [player, 50])


func test_nonpositive_grants_do_nothing() -> void:
	progression.add_xp(player, 0)
	progression.add_xp(player, -1000)
	assert_eq(progression.get_total_xp(player), 0)
	assert_signal_not_emitted(progression, "xp_gained")
	assert_signal_not_emitted(Events, "player_leveled_up")


func test_client_cannot_change_xp_or_emit_signals() -> void:
	var zombie: Zombie = Zombie.new()
	autofree(zombie)
	zombie.data = EnemyData.new()
	var info: DamageInfo = DamageInfo.create(100.0, player)
	info.hit_zone = DamageInfo.Zone.HEAD
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 19999), OK)
	var previous: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = peer
	var denied: bool = not Net.is_authority()
	progression.set_start_total(player, 10000)
	progression.add_xp(player, 10000)
	Events.enemy_killed.emit(zombie, info)
	Events.round_ended.emit(3)
	multiplayer.multiplayer_peer = previous
	peer.close()
	assert_true(denied)
	assert_eq(progression.get_xp(player), 0)
	assert_eq(progression.get_total_xp(player), 0)
	assert_signal_not_emitted(progression, "xp_gained")
	assert_signal_not_emitted(Events, "player_leveled_up")
