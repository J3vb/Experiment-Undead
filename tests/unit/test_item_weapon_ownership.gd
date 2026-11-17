## Item stat copies retain their base identity in Vault and wall-ammo ownership checks.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var base: WeaponData
var vault: SpecimenVault
var wall: WallBuy


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	base = Content.weapon(&"hollis_44")
	ItemLoadout.apply(player, {"sidearm": {"base": "hollis_44", "aff": [["dmg_pct", 5, 1.0]]}})
	vault = autofree(SpecimenVault.new()) as SpecimenVault
	vault.pool = [base]
	wall = autofree(WallBuy.new()) as WallBuy
	wall.weapon = base


func test_vault_excludes_owned_item_sidearm() -> void:
	assert_ne(player.weapons.current.data, base, "item stats use an independent copy")
	assert_true(vault._holds(player, base))
	assert_false(vault._choices(player).has(base))
	assert_false(vault._has_choice(player))


func test_wall_recognizes_base_item_copy_and_uses_base_ammo_price() -> void:
	assert_eq(wall._owned(player), player.weapons.current)
	assert_eq(wall.ammo_cost(player.weapons.current.data.id), int(base.cost * 0.5))


func test_reforged_item_copy_is_recognized_by_both_machines() -> void:
	var item: ItemInstance = ItemInstance.new({"aff": [["dmg_pct", 5, 1.0]]})
	var held: Weapon = player.weapons.replace_current(item.weapon_data(base.upgraded))
	assert_true(vault._holds(player, base))
	assert_false(vault._choices(player).has(base))
	assert_eq(wall._owned(player), held)
	assert_eq(wall.ammo_cost(held.data.id), wall.reforged_ammo_cost)
