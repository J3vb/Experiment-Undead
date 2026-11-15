## Applies equipped gear and the spawn Sidearm; Primary and Pack items wait outside this slice.
class_name ItemLoadout
extends RefCounted


static func apply(player: Player, loadout: Dictionary) -> void:
	var gear: Array[Dictionary] = []
	for slot: String in ["vest", "charm", "implant"]:
		var equipped: Variant = loadout.get(slot)
		if equipped is Dictionary:
			gear.append(equipped)
	player.equip_gear(gear)
	var sidearm: Variant = loadout.get("sidearm")
	if not sidearm is Dictionary:
		return
	var base: StringName = StringName(sidearm.get("base", ""))
	if not Content.ids(&"weapons").has(base):
		return
	var base_data: WeaponData = Content.weapon(base)
	if not (base_data.loot_tags.has(&"pistol") or base_data.loot_tags.has(&"sidearm")):
		return
	var item: ItemInstance = ItemInstance.new(sidearm)
	var data: WeaponData = item.weapon_data(base_data, player.stats)
	var starter: int = _pistol_slot(player)
	if starter >= 0:
		player.weapons.equip(starter)
	var weapon: Weapon = player.weapons.replace_current(data) if starter >= 0 else player.weapons.give(data)
	weapon.item = item
	weapon.hit_landed.connect(_on_hit.bind(player, item))


static func _pistol_slot(player: Player) -> int:
	for index: int in player.weapons.weapons.size():
		if (
			player.weapons.weapons[index].data.loot_tags.has(&"pistol")
			or player.weapons.weapons[index].data.loot_tags.has(&"sidearm")
		):
			return index
	return -1


static func _on_hit(_kill: bool, _headshot: bool, player: Player, item: ItemInstance) -> void:
	if not Net.is_authority():
		return
	player.wallet.add(roundi(item.stats.value(&"points_per_hit", 0.0, player.stats)))
	player.health.heal(item.stats.value(&"leech", 0.0, player.stats))
