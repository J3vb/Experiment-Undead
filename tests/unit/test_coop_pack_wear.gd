## Two ENet peers: a client wears a vest from its Pack mid-run and the server's copy of
## that player gets the vest's max health.
extends "res://tests/unit/coop_interaction_fixture.gd"

const HEALTH_AFFIX: String = "res://tests/fixtures/loot/test_max_health.tres"

var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = HEALTH_AFFIX
	await super.before_each()


func after_each() -> void:
	super.after_each()
	Content._by_type[&"loot"] = _loot_before


func test_client_wearing_a_pack_vest_raises_max_health_on_the_server() -> void:
	client.profile = CharacterProfile.from_dict({"id": "test_coop_pack_wear"})
	client.loot.player = on_client()
	client.loot.pack.add(
		{"uid": "pack_vest", "base": "vest_medium", "rar": "rare", "aff": [["test_max_health", 1, 1.0]]}
	)
	assert_eq(on_server().health.max_health, 100.0)
	client.loot.request_equip("pack_vest")
	await wait_until(func() -> bool: return on_server().health.max_health == 140.0, 3.0, "the server applied the vest")
	await wait_until(func() -> bool: return on_client().health.max_health == 140.0, 3.0, "the owner got it back")
	assert_eq(on_client().health.max_health, 140.0, "the owner shows the same max health")
	assert_eq(client.profile.loadout["vest"]["uid"], "pack_vest", "worn on the client's character")
	assert_true(client.loot.pack.items.is_empty(), "no vest was worn before, so the Pack slot is freed")
