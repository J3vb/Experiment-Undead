## The Grubber's roster sidearm tag lets saved loot replace the starter slot
## without consuming the Primary slot or creating duplicate sidearms.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var primary: Weapon


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.input_enabled = false
	player.weapons.give(Content.weapon(&"pistol_service"))
	primary = player.weapons.give(Content.weapon(&"rifle_ar"))


func _loadout(uid: String, base: String = "grubber_sawnoff") -> Dictionary:
	return {"sidearm": {"uid": uid, "base": base, "rar": "common", "aff": []}}


func test_saved_grubber_equips_the_sidearm_slot_with_both_barrels() -> void:
	ItemLoadout.apply(player, _loadout("grubber_first"))
	assert_eq(player.weapons.weapons.size(), 2)
	var sidearm: Weapon = player.weapons.weapons[0]
	assert_eq(sidearm.data.id, &"grubber_sawnoff", "the sidearm tag is accepted without adding pistol")
	assert_has(sidearm.data.loot_tags, &"sidearm")
	assert_has(sidearm.data.loot_tags, &"double")
	assert_eq(sidearm.data.magazine_size, 2)
	assert_eq(sidearm.instance.ammo_in_mag, 2)
	assert_eq(player.weapons.current, sidearm)
	assert_eq(player.weapons.weapons[1], primary, "the Primary slot remains intact")
	assert_not_null(sidearm.item)
	if sidearm.item:
		assert_eq(sidearm.item.data["uid"], "grubber_first")
	assert_eq(Content.weapon(&"grubber_sawnoff").magazine_size, 2, "shared content stays unchanged")


func test_repeated_apply_replaces_the_existing_grubber_slot() -> void:
	ItemLoadout.apply(player, _loadout("grubber_first"))
	var first: Weapon = player.weapons.weapons[0]
	player.weapons.equip(1)
	ItemLoadout.apply(player, _loadout("grubber_second"))
	assert_eq(player.weapons.weapons.size(), 2, "applying again never adds another sidearm")
	var sidearm: Weapon = player.weapons.weapons[0]
	assert_eq(sidearm.data.id, &"grubber_sawnoff")
	assert_ne(sidearm, first, "the old Grubber is replaced in its own slot")
	assert_eq(player.weapons.weapons[1], primary, "holding the Primary cannot make it the replacement target")
	assert_eq(player.weapons.current, sidearm)
	assert_not_null(sidearm.item)
	if sidearm.item:
		assert_eq(sidearm.item.data["uid"], "grubber_second")


func test_primary_shotgun_is_rejected_in_the_sidearm_slot() -> void:
	var starter: Weapon = player.weapons.weapons[0]
	ItemLoadout.apply(player, _loadout("coachman_primary", "coachman_2b"))
	assert_eq(player.weapons.weapons.size(), 2)
	assert_eq(player.weapons.weapons[0], starter, "shotgun and double tags alone do not allow a Sidearm")
	assert_eq(player.weapons.weapons[1], primary)
	assert_eq(player.weapons.current, primary)
