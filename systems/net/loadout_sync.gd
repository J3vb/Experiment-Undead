## The owner's equipped gear, item guns and skill ranks, sent to the server on spawn and every Pack equip.
## The server checks the loadout and rebuilds the player's stats and item guns from it.
## Only the first loadout of a Player heals up to the new max health; later ones (mid-run swaps) only cap it.
class_name LoadoutSync
extends Node

## The owner's equipped gear dicts; sent to the server with its item guns.
var gear: Array[Dictionary] = []
var _player: Player
var _applied: bool = false


func _init() -> void:
	name = "LoadoutSync"
	set_multiplayer_authority(1)


func _ready() -> void:
	_player = get_parent() as Player


## Owner: tells the server what it has equipped. The server's own player applies it directly.
func send_loadout() -> void:
	if not _player.is_multiplayer_authority():
		return
	var guns: Array[Dictionary] = []
	for weapon: Weapon in _player.weapons.weapons:
		if weapon.item:
			guns.append(weapon.item.data)
	var skills: Dictionary = {}
	for node_id: StringName in _player.skill_ranks:
		skills[String(node_id)] = _player.skill_ranks[node_id]
	if multiplayer.is_server():
		_apply_loadout(gear, guns, _player.skill_ranks)
	else:
		submit_loadout.rpc_id(1, gear, guns, skills)


@rpc("any_peer", "call_remote", "reliable")
func submit_loadout(new_gear: Array, guns: Array, skills: Dictionary) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != _player.get_multiplayer_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var reason: String = _loadout_problem(new_gear, guns)
	if not reason.is_empty():
		Log.warn(&"net", &"loadout_rejected", {"peer": sender, "reason": reason})
		return
	var skill_reason: String = SkillEffects.ranks_problem(skills)
	if not skill_reason.is_empty():
		Log.warn(&"net", &"skills_rejected", {"peer": sender, "reason": skill_reason})
		return
	var typed_gear: Array[Dictionary] = []
	typed_gear.assign(new_gear)
	var typed_guns: Array[Dictionary] = []
	typed_guns.assign(guns)
	_apply_loadout(typed_gear, typed_guns, SkillEffects.ranks_from(skills))


func _loadout_problem(new_gear: Array, guns: Array) -> String:
	if new_gear.size() > CharacterProfile.GEAR_SLOTS.size():
		return "too_much_gear"
	if guns.size() > _player.weapons.max_slots:
		return "too_many_guns"
	for entry: Variant in new_gear + guns:
		if not entry is Dictionary:
			return "not_a_dictionary"
	for gun: Dictionary in guns:
		if not Content.has(&"weapons", StringName(str(gun.get("base", "")))):
			return "unknown_gun"
	return _gear_problem(new_gear)


## Each worn piece must be gear, one per slot.
func _gear_problem(new_gear: Array) -> String:
	var slots: Array[StringName] = []
	for piece: Dictionary in new_gear:
		var slot: StringName = Inventory.slot_for(piece)
		if not slot in CharacterProfile.GEAR_SLOTS:
			return "not_gear"
		if slot in slots:
			return "slot_twice"
		slots.append(slot)
	return ""


## Server: rebuilds the player's stats (gear, then skills) and item guns from scratch.
func _apply_loadout(new_gear: Array[Dictionary], guns: Array[Dictionary], ranks: Dictionary[StringName, int]) -> void:
	gear = new_gear
	_player.skill_ranks = ranks
	_player.equip_gear(new_gear, not _applied)
	_applied = true
	_player.item_guns.clear()
	for gun: Dictionary in guns:
		_player.item_guns[str(gun.get("uid", ""))] = ItemInstance.new(gun)
