## Field ability use in co-op (docs/MULTIPLAYER.md pattern 2): the owner asks, the server
## checks the player, the cooldown and the unlock level from the handshake, then runs the
## same FieldAbility.run() solo uses. The cooldown reaches the owner in its state snapshot;
## show_use tells every other peer to play the ring and sound.
class_name AbilityClaims
extends Node

## The owner shows its own countdown, so its press may beat the server's by a few ticks.
const COOLDOWN_SLACK: float = 0.25
## Two uses closer than this are refused whatever the cooldown says.
const MIN_GAP: float = 0.5

var session: GameSession

var _time: float = 0.0
var _last_use: Dictionary[int, float] = {}


func _init() -> void:
	name = "AbilityClaims"


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void: _last_use.erase(peer_id))


func _physics_process(delta: float) -> void:
	_time += delta


## Owner: use the ability. The server runs it directly; a client asks.
func request_use(player: Player) -> void:
	if multiplayer.is_server():
		_accept(player.net_id)
	else:
		use_on_server.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func use_on_server() -> void:
	if not multiplayer.is_server():
		return
	_accept(multiplayer.get_remote_sender_id())


## Empty when the use is fine, else the reason to refuse it.
func check(peer_id: int, player: Player) -> StringName:
	if player == null or not player.is_alive() or player.is_downed:
		return &"ability_not_alive"
	if session.is_hub or session.is_over or player.abilities.ability == null:
		return &"ability_not_now"
	return _timing_problem(peer_id, player.abilities)


func _timing_problem(peer_id: int, ability: FieldAbility) -> StringName:
	if ability.cooldown_left > COOLDOWN_SLACK:
		return &"ability_cooling"
	if _last_use.has(peer_id) and _time - _last_use[peer_id] < MIN_GAP:
		return &"ability_too_fast"
	if session.handshake and session.handshake.player_level(peer_id) < ability.ability.unlock_level:
		return &"ability_locked"
	return &""


func _accept(peer_id: int) -> void:
	var player: Player = session.players.find_player(peer_id) if session.players else null
	var reason: StringName = check(peer_id, player)
	if reason != &"":
		if session.hit_claims:
			session.hit_claims.reject(peer_id, reason)
		return
	_last_use[peer_id] = _time
	player.abilities.run()


## Server, after a use: every client plays the ring and sound (the server already did).
func relay_use(peer_id: int, data: AbilityData, at: Vector3) -> void:
	if multiplayer.is_server() and Net.is_coop(multiplayer):
		show_use.rpc(peer_id, data.id, at)


@rpc("authority", "call_remote", "reliable")
func show_use(peer_id: int, ability_id: StringName, at: Vector3) -> void:
	if not Content.has(&"abilities", ability_id):
		return
	var data: AbilityData = Content.get_item(&"abilities", ability_id) as AbilityData
	PulseRing.play(session, data, at)
	var user: Player = session.players.find_player(peer_id) if session.players else null
	if user and data.effect == AbilityData.Effect.ADRENAL_RUSH:
		user.abilities.start_rush(data)
