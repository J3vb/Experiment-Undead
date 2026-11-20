## A free Specimen Vault roll left by the Supply Crate power-up. Anyone may open it (a 2.5 s
## roll from the level Vault's pool); only the opener can take the gun, within 10 s. Unopened
## it is gone after LIFETIME seconds (the clock stops once it is opened). The server rolls
## and frees it; the pickups' MultiplayerSpawner removes it on every peer. Its state goes
## out only after it is opened, so it never reaches a client before the crate does.
class_name SupplyCrate
extends Interactable

enum State { IDLE, ROLLING, OFFERING }

const ROLL_TIME: float = 2.5
const OFFER_TIME: float = 10.0
const NAME_CYCLE: float = 0.12
const LIFETIME: float = 25.0

var pool: Array[WeaponData] = []
var session: GameSession
var state: State = State.IDLE
var offer: WeaponData
## Net id of the player who opened it; only they can take the gun. 0 = nobody yet.
var opener_id: int = 0
## Seconds spent unopened.
var age: float = 0.0
var _timer: float = 0.0
var _cycle: float = 0.0


func get_prompt(player: Player) -> String:
	match state:
		State.OFFERING:
			return "Take %s [F]" % offer.display_name if player.net_id == opener_id else ""
		State.IDLE:
			if _has_choice(player):
				return "Open the Supply Crate [F]"
	return ""


func interact(player: Player, facts: Dictionary = {}) -> void:
	if facts.is_empty():
		facts = owner_facts(player)
	if state == State.OFFERING and player.net_id == opener_id:
		_grant(player, InteractionSync.Grant.GIVE, offer, &"", facts.slot)
		queue_free()
	elif state == State.IDLE:
		var choices: Array[WeaponData] = _choices_for(facts.held)
		if not choices.is_empty():
			_start_roll(player, choices)


## held: ids of the owner's guns; slot: the gun in hand, the one a full holder gives up.
func owner_facts(player: Player) -> Dictionary:
	var held: Array[StringName] = []
	for weapon: Weapon in player.weapons.weapons:
		held.append(weapon.data.id)
	return {"held": held, "slot": player.weapons.weapons.find(player.weapons.current)}


func check_facts(facts: Dictionary) -> bool:
	if not (facts.get("held") is Array and facts.get("slot") is int):
		return false
	for id: Variant in facts.held:
		if not (id is StringName and Content.has(&"weapons", id as StringName)):
			return false
	return true


func net_state() -> Dictionary:
	if state == State.IDLE:
		return {}
	return {"state": state, "offer": offer.id if offer else &"", "opener": opener_id}


## Client side: clients run no timers, only the label.
func apply_net_state(net: Dictionary) -> void:
	state = net.get("state", state)
	var offer_id: StringName = net.get("offer", &"")
	offer = Content.weapon(offer_id) if Content.has(&"weapons", offer_id) else null
	opener_id = net.get("opener", 0)


func _start_roll(player: Player, choices: Array[WeaponData]) -> void:
	var weights: PackedFloat32Array = []
	for gun: WeaponData in choices:
		weights.append(gun.crate_weight)
	offer = choices[session.rng.rand_weighted(weights)]
	opener_id = player.net_id
	state = State.ROLLING
	_timer = ROLL_TIME
	play_result(true)
	state_changed.emit()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if state == State.IDLE:
		age += delta
		if age >= LIFETIME:
			Log.warn(&"power_ups", &"crate_expired_unopened", {"name": String(name)})
			queue_free()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if state == State.ROLLING:
		state = State.OFFERING
		_timer = OFFER_TIME
		state_changed.emit()
	else:
		queue_free()


func _choices_for(held: Array) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for gun: WeaponData in pool:
		if gun.crate_weight > 0.0 and not held.has(gun.id) and not (gun.upgraded and held.has(gun.upgraded.id)):
			out.append(gun)
	return out


## Same test as _choices_for() without building a list: the prompt runs every frame.
func _has_choice(player: Player) -> bool:
	for gun: WeaponData in pool:
		if gun.crate_weight > 0.0 and not _holds(player, gun):
			return true
	return false


func _holds(player: Player, gun: WeaponData) -> bool:
	for held: Weapon in player.weapons.weapons:
		if held.data.id == gun.id or (gun.upgraded != null and held.data.id == gun.upgraded.id):
			return true
	return false


## Visual only: the label flicks through gun names while rolling.
func _process(delta: float) -> void:
	var label: Label3D = $Label as Label3D
	match state:
		State.ROLLING:
			_cycle += delta
			if not pool.is_empty():
				label.text = pool[int(_cycle / NAME_CYCLE) % pool.size()].display_name
		State.OFFERING:
			label.text = offer.display_name if offer else ""
		State.IDLE:
			label.text = "SUPPLY CRATE"
