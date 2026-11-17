## Two ENet peers: a co-op player who goes down loses every Serum, unless they
## hold Second Wind, which gets them up again and is the only Serum used up.
extends "res://tests/unit/coop_interaction_fixture.gd"


func port() -> int:
	return 24711


func _give_serums(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		on_server().add_serum(Content.get_item(&"serums", id) as SerumData)
	await wait_until(func() -> bool: return on_client().serums.size() == ids.size(), 3.0, "serums reached the owner")


func _serum_ids(player: Player) -> Array[StringName]:
	var out: Array[StringName] = []
	for serum: SerumData in player.serums:
		out.append(serum.id)
	return out


func test_going_down_loses_every_serum_on_both_peers() -> void:
	await _give_serums([&"ironhide", &"stride"])
	assert_eq(on_client().health.max_health, 250.0, "Ironhide raised max health")
	add_player(client, 1)
	add_player(server, 1)  # A living teammate, so the squad is not out.
	on_server().take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return on_client().is_downed, 3.0, "downed state reached the owner")
	await wait_until(func() -> bool: return on_client().serums.is_empty(), 3.0, "lost serums reached the owner")
	assert_true(on_server().serums.is_empty())
	assert_eq(on_server().health.max_health, 100.0, "Ironhide's health is gone")
	on_server().state_sync.revive_player()
	await wait_until(func() -> bool: return on_client().is_alive(), 3.0, "revive reached the owner")
	assert_eq(on_client().health.max_health, 100.0)
	assert_eq(on_client().health.current, 100.0)


func test_second_wind_gets_a_coop_player_up_and_keeps_other_serums() -> void:
	await _give_serums([&"ironhide", &"second_wind"])
	on_server().second_wind_time = 0.2
	on_server().take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return on_client().is_downed, 3.0, "downed state reached the owner")
	await wait_until(func() -> bool: return on_client().is_alive(), 3.0, "second wind got the owner up")
	assert_false(on_server().is_downed)
	assert_eq(_serum_ids(on_server()), [&"ironhide"] as Array[StringName])
	await wait_until(func() -> bool: return _serum_ids(on_client()) == [&"ironhide"], 3.0, "only Second Wind used up")
	assert_eq(on_client().health.current, 250.0)
