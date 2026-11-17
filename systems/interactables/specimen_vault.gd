## The Specimen Vault: pay to roll a random gun from its pool, then take it
## before the offer runs out. It sits on one of the map's vault_spot markers.
## After a few rolls the specimen is gone: that roll is refunded and the Vault
## moves to another spot. Needs power.
class_name SpecimenVault
extends Interactable

enum State { IDLE, ROLLING, OFFERING }

const ROLL_TIME: float = 2.5
const OFFER_TIME: float = 10.0
const NAME_CYCLE: float = 0.12

@export var cost: int = 950
@export var pool: Array[WeaponData] = []
## The Vault moves after a random number of rolls in this range.
@export var min_rolls_before_move: int = 4
@export var max_rolls_before_move: int = 8

var state: State = State.IDLE
## The gun on offer. Null while rolling means this roll moves the Vault.
var offer: WeaponData
var spot: Node3D
var rolls_left: int = 0
var _buyer: Player
var _timer: float = 0.0
var _cycle: float = 0.0


func _ready() -> void:
	super()
	add_to_group(&"specimen_vault")
	spot = _nearest_spot()
	_level().power_turned_on.connect(func() -> void: ($Glow as Node3D).visible = true)


func get_prompt(player: Player) -> String:
	if not _level().power_on:
		return "Needs power"
	match state:
		State.OFFERING:
			return "Take %s [F]" % offer.display_name if player == _buyer else ""
		State.IDLE:
			if _has_choice(player):
				return "Roll the Specimen Vault [F]  %d" % cost
	return ""


func interact(player: Player, _facts: Dictionary = {}) -> void:
	if not _level().power_on:
		return
	if state == State.OFFERING and player == _buyer:
		player.weapons.give(offer)
		_close()
	elif state == State.IDLE:
		var choices: Array[WeaponData] = _choices(player)
		if not choices.is_empty() and _pay(player, cost):
			_start_roll(player, choices)


func _start_roll(player: Player, choices: Array[WeaponData]) -> void:
	var rng: RandomNumberGenerator = _session().rng
	if rolls_left <= 0:
		rolls_left = rng.randi_range(min_rolls_before_move, max_rolls_before_move)
	rolls_left -= 1
	offer = null
	if rolls_left > 0:
		var weights: PackedFloat32Array = []
		for gun: WeaponData in choices:
			weights.append(gun.crate_weight)
		offer = choices[rng.rand_weighted(weights)]
	_buyer = player
	state = State.ROLLING
	_timer = ROLL_TIME


func _physics_process(delta: float) -> void:
	if state == State.IDLE or not Net.is_authority():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if state == State.OFFERING:
		_close()
	elif offer:
		state = State.OFFERING
		_timer = OFFER_TIME
	else:
		if is_instance_valid(_buyer):
			_buyer.wallet.add(cost)
		_move()
		_close()


## Guns in the pool that the player does not hold yet (base or Reforged).
func _choices(player: Player) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for gun: WeaponData in pool:
		if gun.crate_weight > 0.0 and not _holds(player, gun):
			out.append(gun)
	return out


## Same test as _choices() without building a list: the prompt runs every frame.
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


func _move() -> void:
	var others: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"vault_spot"):
		if node != spot:
			others.append(node as Node3D)
	if others.is_empty():
		return
	spot = others[_session().rng.randi_range(0, others.size() - 1)]
	global_transform = spot.global_transform


func _close() -> void:
	state = State.IDLE
	offer = null
	_buyer = null


func _nearest_spot() -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"vault_spot"):
		var distance: float = (node as Node3D).global_position.distance_to(global_position)
		if distance < best_distance:
			best = node as Node3D
			best_distance = distance
	return best


func _session() -> GameSession:
	return get_tree().get_first_node_in_group(&"game_session") as GameSession


## Visual only: the label flicks through gun names while rolling.
func _process(delta: float) -> void:
	var label: Label3D = $Label as Label3D
	match state:
		State.ROLLING:
			_cycle += delta
			if not pool.is_empty():
				label.text = pool[int(_cycle / NAME_CYCLE) % pool.size()].display_name
		State.OFFERING:
			label.text = offer.display_name
		State.IDLE:
			label.text = "Specimen Vault"
