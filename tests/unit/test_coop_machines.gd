## Two ENet peers: a client buys wall guns, ammo, Reforges and Serums. The
## server takes the points from its own prices; guns change only on the
## client that paid, through grants that name the gun they are for.
extends "res://tests/unit/coop_interaction_fixture.gd"


func _give(id: StringName) -> Weapon:
	return on_client().weapons.give(Content.weapon(id))


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for weapon: Weapon in on_client().weapons.weapons:
		out.append(weapon.data.id)
	return out


func _power_on() -> void:
	server.level.turn_power_on()
	await wait_until(func() -> bool: return client.level.power_on, 3.0, "power reached the client")


func test_client_buys_a_wall_gun_only_for_itself() -> void:
	on_server().wallet.set_points(5000)
	await press("WallBuy")
	await wait_until(func() -> bool: return _ids() == [&"kestrel_smg"], 3.0, "gun granted to the client")
	assert_eq(on_server().wallet.points, 4000)
	assert_eq(on_server().weapons.weapons.size(), 0, "the server copy holds no guns")


func test_ammo_costs_half_and_reforged_ammo_costs_4000() -> void:
	var gun: Weapon = _give(&"kestrel_smg")
	gun.instance.ammo_reserve = 0
	on_server().wallet.set_points(5000)
	await press("WallBuy")
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.max_reserve, 3.0, "refilled")
	assert_eq(on_server().wallet.points, 4500)
	var reforged: Weapon = on_client().weapons.replace(gun, Content.weapon(&"kestrel_smg_reforged"))
	reforged.instance.ammo_reserve = 0
	server.interactions._time += 1.0
	await press("WallBuy")
	await wait_until(func() -> bool: return reforged.instance.ammo_reserve == 360, 3.0, "reforged refilled")
	assert_eq(on_server().wallet.points, 500)


func test_full_gun_is_not_charged() -> void:
	_give(&"kestrel_smg")
	on_server().wallet.set_points(5000)
	await press("WallBuy")
	await wait_physics_frames(6)
	assert_eq(on_server().wallet.points, 5000)


func test_client_reforges_gun_in_hand_and_refills_top_tier() -> void:
	await _power_on()
	_give(&"kestrel_smg")
	on_server().wallet.set_points(8000)
	await press("Reforger")
	await wait_until(func() -> bool: return _ids() == [&"kestrel_smg_reforged"], 3.0, "upgraded in hand")
	assert_eq(on_client().weapons.current.data.id, &"kestrel_smg_reforged")
	assert_eq(on_server().wallet.points, 3000)
	var top: Weapon = on_client().weapons.current
	top.instance.ammo_reserve = 0
	server.interactions._time += 1.0
	await press("Reforger")
	await wait_until(func() -> bool: return top.instance.ammo_reserve == 360, 3.0, "top tier refilled")
	assert_eq(on_server().wallet.points, 500)


func test_forged_facts_are_refused_and_not_charged() -> void:
	await _power_on()
	on_server().wallet.set_points(9000)
	var forged: Array[Array] = [
		[^"WallBuy", {"owned": &"atlas_auto", "slot": 0, "full": false}],
		[^"WallBuy", {"owned": &"nope", "slot": 0, "full": false}],
		[^"WallBuy", {}],
		[^"Reforger", {"current": &"nope", "slot": 0, "full": false}],
		[^"Reforger", {"current": "kestrel_smg"}],
	]
	for request: Array in forged:
		client.interactions.request_interact.rpc_id(1, request[0], request[1])
		var node_name: String = str(request[0])
		await wait_until(func() -> bool: return denied_on(client, node_name), 3.0, "denied %s" % [request[1]])
		(target(client, node_name).get_node("DeniedSound") as AudioStreamPlayer3D).stop()
	assert_eq(on_server().wallet.points, 9000)
	assert_eq(_ids(), [] as Array[StringName])


func test_client_buys_a_serum() -> void:
	await _power_on()
	var serum: SerumData = Content.get_item(&"serums", &"ironhide") as SerumData
	on_server().wallet.set_points(serum.cost + 100)
	await press("Dispenser")
	await wait_until(func() -> bool: return on_server().serums.has(serum), 3.0, "server gave the serum")
	assert_eq(on_server().wallet.points, 100)
	await wait_until(func() -> bool: return (target(client, "Dispenser") as MedDispenser).sales == 1, 3.0, "sales")


func test_sold_out_dispenser_is_gone_for_everyone_and_late_joiners() -> void:
	await _power_on()
	on_server().wallet.set_points(20000)
	await press("LastDispenser")
	await wait_until(func() -> bool: return gone(client, "LastDispenser"), 3.0, "sold out on the client")
	assert_true(gone(server, "LastDispenser"))
	var chime: AudioStreamPlayer3D = client.level.get_node_or_null("BuySound") as AudioStreamPlayer3D
	assert_true(chime != null and chime.playing, "the buyer's last chime outlives the dispenser")
	late = make_side("InteractLate")
	add_player(late, client_id)
	await join(late)
	await wait_until(func() -> bool: return gone(late, "LastDispenser"), 3.0, "late joiner never sees it")
	assert_false(gone(late, "Dispenser"))


func test_reforge_hits_the_gun_it_was_for_after_a_switch() -> void:
	await _power_on()
	_give(&"kestrel_smg")
	_give(&"atlas_auto")
	on_client().weapons.equip(0)
	on_server().wallet.set_points(5000)
	client.interactions.request(on_client(), target(client, "Reforger"))
	on_client().weapons.equip(1)
	await wait_until(func() -> bool: return _ids()[0] == &"kestrel_smg_reforged", 3.0, "A upgraded")
	assert_eq(_ids(), [&"kestrel_smg_reforged", &"atlas_auto"] as Array[StringName])
	assert_eq(on_client().weapons.current.data.id, &"atlas_auto", "B stays in hand, untouched")


func test_refill_for_a_gun_no_longer_held_changes_nothing() -> void:
	var gun: Weapon = _give(&"kestrel_smg")
	gun.instance.ammo_reserve = 0
	on_server().wallet.set_points(5000)
	client.interactions.request(on_client(), target(client, "WallBuy"))
	var other: Weapon = on_client().weapons.replace(gun, Content.weapon(&"atlas_auto"))
	other.instance.ammo_reserve = 5
	await wait_until(func() -> bool: return on_server().wallet.points == 4500, 3.0, "server charged")
	await wait_until(func() -> bool: return not server.interactions._pending.has(client_id), 3.0, "grant applied")
	assert_eq(other.instance.ammo_reserve, 5)


func test_second_reforge_press_before_the_grant_is_refused() -> void:
	await _power_on()
	_give(&"kestrel_smg")
	on_server().wallet.set_points(20000)
	client.interactions.request(on_client(), target(client, "Reforger"))
	await wait_until(func() -> bool: return on_server().wallet.points == 15000, 3.0, "first press charged")
	server.interactions._time += 1.0
	client.interactions.request(on_client(), target(client, "Reforger"))
	await wait_until(func() -> bool: return not server.interactions._pending.has(client_id), 3.0, "grant applied")
	await wait_physics_frames(6)
	assert_eq(on_server().wallet.points, 15000, "charged once")
	assert_eq(_ids(), [&"kestrel_smg_reforged"] as Array[StringName], "one upgrade")


func test_reforge_upgrades_only_the_second_of_two_same_guns() -> void:
	await _power_on()
	_give(&"kestrel_smg")
	_give(&"kestrel_smg")
	on_client().weapons.equip(1)
	on_server().wallet.set_points(5000)
	await press("Reforger")
	await wait_until(func() -> bool: return _ids()[1] == &"kestrel_smg_reforged", 3.0, "second upgraded")
	assert_eq(_ids()[0], &"kestrel_smg")


func test_full_holder_wall_buy_replaces_the_gun_in_hand_at_the_press() -> void:
	_give(&"atlas_auto")
	_give(&"hollis_44")
	assert_eq(on_client().weapons.current.data.id, &"hollis_44")
	on_server().wallet.set_points(5000)
	client.interactions.request(on_client(), target(client, "WallBuy"))
	on_client().weapons.equip(0)
	await wait_until(func() -> bool: return _ids().has(&"kestrel_smg"), 3.0, "gun granted")
	assert_eq(_ids(), [&"atlas_auto", &"kestrel_smg"] as Array[StringName])
