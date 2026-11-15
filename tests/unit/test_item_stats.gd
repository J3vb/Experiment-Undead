## Equipped gear changes player stats, while item guns keep their own affix multipliers.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HEALTH_AFFIX: String = "res://tests/fixtures/loot/test_max_health.tres"

var player: Player
var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = HEALTH_AFFIX
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func after_each() -> void:
	Content._by_type[&"loot"] = _loot_before


func _item(base: String, affixes: Array, uid: String = "test_item") -> Dictionary:
	return {"v": 1, "uid": uid, "base": base, "rar": "rare", "ilvl": 30, "aff": affixes}


func _vest() -> Dictionary:
	return _item("vest_medium", [["test_max_health", 1, 1.0]], "vest")


func _serum(stat: StringName, multiplier: float) -> SerumData:
	var serum: SerumData = SerumData.new()
	serum.multipliers[stat] = multiplier
	return serum


func _gun(affixes: Array) -> Weapon:
	var weapon: Weapon = player.weapons.give(Content.weapon(&"pistol_service"))
	weapon.item = ItemInstance.new(_item("pistol_service", affixes))
	return weapon


func test_vest_increases_maximum_and_current_health() -> void:
	player.equip_gear([_vest()])
	assert_eq(player.health.max_health, 140.0)
	assert_eq(player.health.current, 140.0)
	assert_eq(player.get_stat(&"max_health", 100.0), 140.0)


func test_replacing_or_removing_gear_restores_health_without_duplicate_bonuses() -> void:
	player.equip_gear([_vest()])
	player.equip_gear([_vest()])
	assert_eq(player.health.max_health, 140.0)
	player.equip_gear([])
	assert_eq(player.health.max_health, 100.0)
	assert_lte(player.health.current, player.health.max_health)


func test_health_affixes_add_across_gear_slots() -> void:
	var charm: Dictionary = _item("charm", [["test_max_health", 1, 1.0]], "charm")
	player.equip_gear([_vest(), charm])
	assert_eq(player.health.max_health, 180.0)


func test_serums_still_multiply_with_flat_gear_added_last() -> void:
	player.equip_gear([_vest()])
	player.add_serum(_serum(&"max_health", 1.5))
	player.add_serum(_serum(&"max_health", 2.0))
	assert_eq(player.health.max_health, 340.0)
	assert_eq(player.health.current, 340.0)
	player.equip_gear([])
	assert_eq(player.health.max_health, 300.0)


func test_reload_affix_shortens_the_actual_reload() -> void:
	var weapon: Weapon = _gun([["reload_pct", 5, 1.0]])
	weapon.instance.ammo_in_mag -= 1
	watch_signals(weapon)
	assert_true(weapon.start_reload())
	var duration: float = get_signal_parameters(weapon, "reload_started")[0]
	assert_almost_eq(duration, weapon.data.reload_time / 1.2, 0.0001)
	assert_lt(duration, weapon.data.reload_time)
	weapon.tick(duration - 0.001)
	assert_true(weapon.is_reloading())
	weapon.tick(0.002)
	assert_false(weapon.is_reloading())


func test_reload_affix_and_serums_stack_without_affecting_the_other_gun() -> void:
	var item_gun: Weapon = _gun([["reload_pct", 5, 1.0]])
	var plain_gun: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	player.add_serum(_serum(&"reload_time", 0.8))
	player.add_serum(_serum(&"reload_time", 0.5))
	assert_almost_eq(item_gun._stat(&"reload_time"), 0.4 / 1.2, 0.0001)
	assert_almost_eq(plain_gun._stat(&"reload_time"), 0.4, 0.0001)
	assert_almost_eq(player.get_stat(&"reload_time"), 0.4, 0.0001)


func test_gun_health_affix_does_not_apply_to_the_player() -> void:
	_gun([["test_max_health", 1, 1.0]])
	assert_eq(player.health.max_health, 100.0)
	assert_eq(player.get_stat(&"max_health", 100.0), 100.0)


func test_loadout_replaces_the_start_pistol_with_only_the_sidearm() -> void:
	player.weapons.give(Content.weapon(&"pistol_service"))
	var loadout: Dictionary = {
		"sidearm": _item("hollis_44", [["reload_pct", 5, 1.0]], "sidearm"),
		"primary": _item("rifle_ar", [["reload_pct", 5, 1.0]], "primary"),
		"vest": _vest(),
		"pack": [_item("mako_pdw", [["reload_pct", 5, 1.0]], "pack")],
	}
	ItemLoadout.apply(player, loadout)
	assert_eq(player.weapons.weapons.size(), 1)
	assert_eq(player.weapons.current.data.id, &"hollis_44")
	assert_not_null(player.weapons.current.item)
	assert_almost_eq(player.weapons.current._stat(&"reload_time"), 1.0 / 1.2, 0.0001)
	assert_eq(player.health.max_health, 140.0)


func test_primary_and_pack_alone_do_not_change_the_start_gun_or_player() -> void:
	player.weapons.give(Content.weapon(&"pistol_service"))
	(
		ItemLoadout
		. apply(
			player,
			{
				"primary": _item("rifle_ar", [["test_max_health", 1, 1.0]]),
				"pack": [_vest(), _item("hollis_44", [["reload_pct", 5, 1.0]])],
			}
		)
	)
	assert_eq(player.weapons.weapons.size(), 1)
	assert_eq(player.weapons.current.data.id, &"pistol_service")
	assert_null(player.weapons.current.item)
	assert_eq(player.health.max_health, 100.0)


func test_gear_and_gun_reload_increases_add_before_serums_multiply() -> void:
	player.equip_gear([_item("charm", [["reload_pct", 5, 1.0]], "charm")])
	var weapon: Weapon = _gun([["reload_pct", 5, 1.0]])
	player.add_serum(_serum(&"reload_time", 0.8))
	player.add_serum(_serum(&"reload_time", 0.5))
	assert_almost_eq(weapon._stat(&"reload_time"), 0.4 / 1.4, 0.0001)
	assert_almost_eq(player.get_stat(&"reload_time"), 0.4 / 1.2, 0.0001)


func test_loadout_applies_damage_magazine_and_reserve_to_the_live_gun_only() -> void:
	var base: WeaponData = Content.weapon(&"pistol_service")
	var base_damage: float = base.damage
	var base_min_damage: float = base.min_damage
	var base_magazine: int = base.magazine_size
	var base_reserve: int = base.starting_reserve
	var base_max_reserve: int = base.max_reserve
	var item: Dictionary = _item("pistol_service", [["dmg_pct", 5, 1.0], ["mag_pct", 5, 1.0]])
	item["imp"] = ["deep_reserve", 1.0]
	ItemLoadout.apply(player, {"sidearm": item})
	var weapon: Weapon = player.weapons.current
	assert_ne(weapon.data, base)
	assert_almost_eq(weapon.data.damage, base_damage * 1.15, 0.0001)
	assert_almost_eq(weapon.data.min_damage, base_min_damage * 1.15, 0.0001)
	assert_eq(weapon.data.magazine_size, roundi(base_magazine * 1.3))
	assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size)
	assert_eq(weapon.instance.ammo_reserve, base_reserve * 2)
	assert_eq(weapon.data.max_reserve, base_max_reserve * 2)
	assert_eq(base.damage, base_damage)
	assert_eq(base.min_damage, base_min_damage)
	assert_eq(base.magazine_size, base_magazine)
	assert_eq(base.starting_reserve, base_reserve)
	assert_eq(base.max_reserve, base_max_reserve)


func test_item_hit_pays_points_and_leech() -> void:
	var item: Dictionary = _item("pistol_service", [["points_per_hit", 5, 1.0], ["leech", 5, 1.0]])
	ItemLoadout.apply(player, {"sidearm": item})
	var points_before: int = player.wallet.points
	player.health.current = 50.0
	player.weapons.current.hit_landed.emit(false, false)
	assert_eq(player.wallet.points, points_before + 3)
	assert_eq(player.health.current, 53.0)


func test_leech_cap_combines_gun_and_all_gear() -> void:
	var item: Dictionary = _item("pistol_service", [["leech", 5, 1.0]])
	var vest: Dictionary = _item("vest_medium", [["leech", 5, 1.0]], "vest")
	var charm: Dictionary = _item("charm", [["leech", 5, 1.0]], "charm")
	ItemLoadout.apply(player, {"sidearm": item, "vest": vest, "charm": charm})
	player.health.current = 50.0
	player.weapons.current.hit_landed.emit(true, true)
	assert_eq(player.health.current, 56.0)


func test_move_speed_cap_includes_serums_and_gear_relative_to_original_base() -> void:
	player.stats.add_modifier(&"move_speed", "increased", 0.1, &"vest")
	player.add_serum(_serum(&"move_speed", 1.2))
	assert_almost_eq(player.get_stat(&"move_speed", 5.0), 5.75, 0.0001)


func test_slowing_serum_does_not_lower_the_original_move_speed_cap() -> void:
	player.stats.add_modifier(&"move_speed", "increased", 0.3, &"vest")
	player.add_serum(_serum(&"move_speed", 0.9))
	assert_almost_eq(player.get_stat(&"move_speed", 5.0), 5.75, 0.0001)


func test_regen_delay_reduction_keeps_regeneration_enabled() -> void:
	assert_gt(player.health.regen_delay, 0.0)
	player.stats.add_modifier(&"regen_delay", "flat", -100.0, &"vest")
	player._refresh_stats()
	assert_gt(player.health.regen_delay, 0.0)
	assert_lt(player.health.regen_delay, 0.01)
