## Legendary trait effects that run where the server applies hits, and the per-player state they need.
## Lives on every peer (later RPCs need the same path); state and effects run on the server only.
class_name LegendaryTraits
extends Node

## Trait stats with code. tests/content/test_legendaries.gd fails on a Legendary naming any other.
const STATS: Array[StringName] = [&"tidewater"]
const TIDEWATER_MAX_STACKS: int = 10

var session: GameSession

## Per attacker net id: [zombie instance id, stacks].
var _tidewater: Dictionary[int, Array] = {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_peer)


## Server: scales one validated hit by the attacker's gun trait before it lands.
func on_hit(zombie: Zombie, info: DamageInfo) -> void:
	if not multiplayer.is_server() or info.item_uid.is_empty():
		return
	var player: Player = info.attacker as Player
	var item: ItemInstance = player.item_guns.get(info.item_uid) if player else null
	if item == null:
		return
	var tidewater: float = item.stats.value(&"tidewater", 0.0)
	if tidewater > 0.0:
		info.amount *= 1.0 + _tidewater_stacks(player.net_id, zombie) * tidewater / 100.0


## Stacks before this hit, then one more for it. A new target keeps half, rounded down.
func _tidewater_stacks(peer_id: int, zombie: Zombie) -> int:
	var state: Array = _tidewater.get(peer_id, [0, 0])
	var stacks: int = int(state[1])
	if int(state[0]) != zombie.get_instance_id():
		stacks /= 2
	_tidewater[peer_id] = [zombie.get_instance_id(), mini(stacks + 1, TIDEWATER_MAX_STACKS)]
	return stacks


func _forget_peer(peer_id: int) -> void:
	_tidewater.erase(peer_id)
