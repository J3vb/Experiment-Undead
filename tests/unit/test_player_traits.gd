## Player Legendary traits on the server: Quarantine Shell, Iron Lung and Last Rites (in Revive).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var enemy: Node3D


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	enemy = autofree(Node3D.new())


func _gear(stat: StringName, value: float) -> void:
	player.stats.add_modifier(stat, "flat", value, &"gear")


func _kill(uid: String = "") -> void:
	var info: DamageInfo = DamageInfo.create(10.0, player)
	info.item_uid = uid
	Events.enemy_killed.emit(enemy, info)


func test_quarantine_shell_blocks_the_first_hit_in_each_window() -> void:
	_gear(&"quarantine_shell", 6.0)
	var full: float = player.health.current
	player.take_damage(DamageInfo.create(30.0, null))
	assert_eq(player.health.current, full, "blocked")
	player.take_damage(DamageInfo.create(30.0, null))
	assert_eq(player.health.current, full - 30.0, "the next hit lands")
	player.revive._physics_process(5.9)
	player.take_damage(DamageInfo.create(10.0, null))
	assert_eq(player.health.current, full - 40.0, "still inside the window")
	player.revive._physics_process(0.2)
	player.take_damage(DamageInfo.create(10.0, null))
	assert_eq(player.health.current, full - 40.0, "blocked again after 6 s")


func test_iron_lung_skips_the_regen_delay_after_a_clean_streak() -> void:
	_gear(&"iron_lung", 4.0)
	player.health.regen_delay = 5.0
	player.health.take_damage(DamageInfo.create(30.0, null))
	for kill: int in 3:
		_kill()
	Events.player_damaged.emit(player, DamageInfo.create(1.0, null))
	_kill()
	assert_lt(player.health._since_damage, 5.0, "a hit resets the streak")
	for kill: int in 3:
		_kill()
	assert_eq(player.health._since_damage, 5.0, "four kills in a row start regen")


func test_last_rites_gets_a_downed_player_up_once_per_round() -> void:
	player.item_guns["lr"] = ItemInstance.new(
		{"uid": "lr", "base": "pistol_service", "rar": "legendary", "trait": ["last_rites", 1.0]}
	)
	player.is_downed = true
	assert_true(player.can_self_revive(), "the squad is not out while Last Rites can fire")
	for kill: int in 4:
		_kill("lr")
	_kill("other")
	assert_true(player.is_downed, "four kills with it, one with another gun")
	_kill("lr")
	assert_false(player.is_downed, "five kills get them up")
	player.is_downed = true
	assert_false(player.can_self_revive(), "used this round")
	for kill: int in 5:
		_kill("lr")
	assert_true(player.is_downed)
	Events.round_started.emit(2, 10)
	assert_true(player.can_self_revive(), "a new round resets it")


func test_last_rites_leaves_serums_and_undying_alone() -> void:
	player.item_guns["lr"] = ItemInstance.new(
		{"uid": "lr", "base": "pistol_service", "rar": "legendary", "trait": ["last_rites", 1.0]}
	)
	player.skill_ranks = {&"undying": 1}
	player.equip_gear([])
	player.is_downed = true
	for kill: int in 5:
		_kill("lr")
	assert_false(player.is_downed)
	assert_true(player.revive.has_undying_charge())


func test_no_last_rites_without_the_gun() -> void:
	player.is_downed = true
	assert_false(player.can_self_revive())
	for kill: int in 10:
		_kill("lr")
	assert_true(player.is_downed)
