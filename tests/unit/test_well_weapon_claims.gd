## A well opens for any gun whose effect is WELL, from a client too, and for no other gun.
extends "res://tests/unit/well_claims_fixture.gd"


func port() -> int:
	return 24666


func _test_gun(id: StringName, effect: WeaponData.Effect) -> WeaponData:
	var gun: WeaponData = Content.weapon(SIPHON).duplicate() as WeaponData
	gun.id = id
	gun.effect = effect
	for claims: HitClaims in [_server_claims, _client_claims]:
		claims._weapons[id] = gun
	return gun


func test_any_well_gun_opens_a_well_from_a_client() -> void:
	_test_gun(&"test_well", WeaponData.Effect.WELL)
	_client_claims.request_well(Vector3.ZERO, &"test_well")
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "server accepted test well")
	var well: GravityWell = _wells(_server)[0]
	assert_eq(well.weapon_data.id, &"test_well", "the well keeps the gun that fired it")


func test_a_client_well_request_with_a_non_well_gun_is_refused() -> void:
	_test_gun(&"test_plain", WeaponData.Effect.NONE)
	var reasons: Array[StringName] = (_server_claims as RecordingClaims).reasons
	for weapon_id: StringName in [&"rifle_ar", &"test_plain", &"no_such_gun"]:
		reasons.clear()
		_client_claims.request_well(Vector3.ZERO, weapon_id)
		await wait_until(func() -> bool: return not reasons.is_empty(), 3.0, "wrong weapon rejection reached server")
		assert_eq(reasons, Array([&"well_wrong_weapon"], TYPE_STRING_NAME, &"", null), String(weapon_id))
	assert_eq(_wells(_server).size(), 0)
	assert_eq(_wells(_client).size(), 0)


func test_a_client_orb_with_a_non_well_gun_is_not_relayed() -> void:
	var reasons: Array[StringName] = (_server_claims as RecordingClaims).reasons
	var player: Player = _client.players.find_player(_peer_id)
	_client_claims.send_well_orb(player.camera.global_position, Vector3.FORWARD, &"rifle_ar")
	await wait_until(func() -> bool: return not reasons.is_empty(), 3.0, "wrong weapon orb reached server")
	assert_eq(reasons, Array([&"well_wrong_weapon"], TYPE_STRING_NAME, &"", null))
	assert_false(_server_claims._well_launches.has(_peer_id))
