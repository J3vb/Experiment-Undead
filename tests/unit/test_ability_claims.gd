## Co-op field ability use (docs/plans/field-abilities.md, step 2): two ENet peers prove the
## server runs a client's Shock Pulse, owns the cooldown, refuses bad requests and shows each use to every peer.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const SHOCK_PULSE: AbilityData = preload("res://content/abilities/shock_pulse.tres")
const ADRENAL_RUSH: AbilityData = preload("res://content/abilities/adrenal_rush.tres")
const DECOY_SIREN: AbilityData = preload("res://content/abilities/decoy_siren.tres")
const WATCHDOG: AbilityData = preload("res://content/abilities/watchdog.tres")

var _port: int
var _server: GameSession
var _client: GameSession
var _peer_id: int


class RecordingClaims:
	extends HitClaims

	var reasons: Array[StringName] = []

	func reject(sender: int, reason: StringName) -> void:
		reasons.append(reason)
		super(sender, reason)


## Every peer reports this level, so a test can lock an ability without a real hello.
class LevelStub:
	extends Handshake

	var level: int = 50

	func player_level(_peer_id: int) -> int:
		return level


func before_each() -> void:
	_port = TwoPeers.next_port()
	_server = _make_side("AbilityServer")
	_client = _make_side("AbilityClient")
	assert_eq(TwoPeers.host(_server, _port, 2), OK)
	assert_eq(TwoPeers.join(_client, _port), OK)
	await wait_until(
		func() -> bool: return _client.multiplayer.get_unique_id() > 1 and _server.multiplayer.get_peers().size() == 1,
		5.0,
		"ability peers connected"
	)
	_peer_id = _client.multiplayer.get_unique_id()
	for session: GameSession in [_server, _client]:
		_add_player(session, 1)
		_add_player(session, _peer_id)


func after_each() -> void:
	for session: GameSession in [_client, _server]:
		if session.handshake is LevelStub:
			session.handshake.free()
			session.handshake = null
		CoopSide.close(session)


func _make_side(side_name: String) -> GameSession:
	var session: GameSession = CoopSide.make(self, side_name, [&"ability_claims"], null, RecordingClaims.new())
	CoopSide.add_spawn_point(session)
	session.hit_claims.set_physics_process(false)
	return session


func _add_player(session: GameSession, peer_id: int) -> void:
	var player: Player = CoopSide.add_player(session, peer_id)
	player.local_input.enabled = false
	player.abilities.ability = SHOCK_PULSE


func _claims(session: GameSession) -> AbilityClaims:
	return session.get_node("AbilityClaims") as AbilityClaims


func _reasons() -> Array[StringName]:
	return (_server.hit_claims as RecordingClaims).reasons


func _client_player() -> Player:
	return _client.players.find_player(_peer_id)


func _server_copy() -> Player:
	return _server.players.find_player(_peer_id)


func _press(player: Player) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = InputFrame.FIELD_ABILITY
	player.abilities.tick(frame)


func _zombie_near(player: Player) -> Zombie:
	var zombie: Zombie = _server.spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = player.global_position + Vector3(3, 0, 0)
	zombie.state = Zombie.State.CHASING
	return zombie


func test_client_shock_pulse_stuns_a_server_zombie() -> void:
	var zombie: Zombie = _zombie_near(_server_copy())
	_press(_client_player())
	await wait_until(func() -> bool: return zombie.stun_left > 0.0, 3.0, "the server ran the pulse")
	assert_eq(_server_copy().abilities.cooldown_left, 60.0, "the server owns the cooldown")


func test_cooldown_reaches_the_client_in_its_snapshot() -> void:
	_press(_client_player())
	await wait_until(
		func() -> bool: return _client_player().abilities.cooldown_left > 50.0, 3.0, "cooldown synced to the owner"
	)


func test_second_use_inside_the_cooldown_is_refused() -> void:
	_server_copy().abilities.cooldown_left = 30.0
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().has(&"ability_cooling"), 3.0, "refused")
	assert_eq(_server_copy().abilities.cooldown_left, 30.0)


func test_use_is_accepted_again_once_the_server_cooldown_runs_out() -> void:
	_server_copy().abilities.cooldown_left = 0.5
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().has(&"ability_cooling"), 3.0, "refused while cooling")
	_server_copy().abilities._physics_process(0.5)
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _server_copy().abilities.cooldown_left > 50.0, 3.0, "accepted")


func test_press_a_few_ticks_early_is_allowed() -> void:
	_server_copy().abilities.cooldown_left = 0.1
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _server_copy().abilities.cooldown_left > 50.0, 3.0, "within the slack")


func test_downed_client_is_refused() -> void:
	_server_copy().is_downed = true
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().has(&"ability_not_alive"), 3.0, "refused")
	assert_eq(_server_copy().abilities.cooldown_left, 0.0)


func test_two_uses_at_once_are_too_fast() -> void:
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().size() == 1, 3.0, "second use refused")
	assert_true(_reasons().has(&"ability_cooling") or _reasons().has(&"ability_too_fast"))


func test_ability_above_the_client_level_is_refused() -> void:
	var stub: LevelStub = LevelStub.new()
	stub.level = 2
	_server.handshake = stub
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().has(&"ability_locked"), 3.0, "refused")
	assert_eq(_server_copy().abilities.cooldown_left, 0.0)


func test_loadout_sets_the_server_copys_ability() -> void:
	_server_copy().abilities.ability = null
	_client_player().loadout_sync.send_loadout()
	await wait_until(func() -> bool: return _server_copy().abilities.ability == SHOCK_PULSE, 3.0, "ability arrived")


func test_unknown_or_locked_ability_in_a_loadout_is_dropped() -> void:
	_client_player().loadout_sync.submit_loadout.rpc_id(1, [], [], {}, "no_such_ability")
	await wait_until(func() -> bool: return _server_copy().abilities.ability == null, 3.0, "unknown dropped")
	_server_copy().abilities.ability = SHOCK_PULSE
	var stub: LevelStub = LevelStub.new()
	stub.level = 1
	_server.handshake = stub
	_client_player().loadout_sync.submit_loadout.rpc_id(1, [], [], {}, "shock_pulse")
	await wait_until(func() -> bool: return _server_copy().abilities.ability == null, 3.0, "locked dropped")


func test_host_uses_its_own_ability_without_a_message() -> void:
	var host: Player = _server.players.find_player(1)
	var zombie: Zombie = _zombie_near(host)
	_press(host)
	assert_gt(zombie.stun_left, 0.0, "ran at once on the server")
	assert_eq(host.abilities.cooldown_left, 60.0)


func _rings(session: GameSession) -> int:
	var count: int = 0
	for child: Node in session.get_children():
		if child is PulseRing:
			count += 1
	return count


func test_every_peer_sees_the_pulse_ring() -> void:
	_press(_client_player())
	await wait_until(func() -> bool: return _rings(_client) == 1, 3.0, "the client shows the ring the server relayed")
	assert_eq(_rings(_server), 1, "the server shows its own")


func test_a_refused_use_shows_nothing() -> void:
	_server_copy().abilities.cooldown_left = 30.0
	_claims(_client).use_on_server.rpc_id(1, Vector3.ZERO)
	await wait_until(func() -> bool: return _reasons().has(&"ability_cooling"), 3.0, "refused")
	await wait_physics_frames(5)
	assert_eq(_rings(_client) + _rings(_server), 0)


func test_a_clients_adrenal_rush_reaches_the_server_copy_and_the_owner() -> void:
	var rush: AbilityData = ADRENAL_RUSH
	_server_copy().abilities.ability = rush
	_client_player().abilities.ability = rush
	_press(_client_player())
	await wait_until(func() -> bool: return _client_player().abilities.rush_left > 0.0, 3.0, "the owner runs faster")
	assert_gt(_server_copy().abilities.rush_left, 0.0, "the server copy fires faster for its hit checks")


func test_a_siren_aimed_past_its_reach_is_refused() -> void:
	var siren: AbilityData = DECOY_SIREN
	_server_copy().abilities.ability = siren
	_claims(_client).use_on_server.rpc_id(1, _server_copy().global_position + Vector3(40, 0, 0))
	await wait_until(func() -> bool: return _reasons().has(&"ability_bad_aim"), 3.0, "refused")
	assert_eq(_server_copy().abilities.cooldown_left, 0.0)
	_claims(_client).use_on_server.rpc_id(1, _server_copy().global_position + Vector3(15, 0, 0))
	await wait_until(func() -> bool: return _server_copy().abilities.cooldown_left > 0.0, 3.0, "15 m is fine")


func _turrets(session: GameSession) -> Array[Watchdog]:
	var found: Array[Watchdog] = []
	for child: Node in session.get_children():
		if child is Watchdog:
			found.append(child)
	return found


func test_a_clients_watchdog_damages_only_on_the_server() -> void:
	var watchdog: AbilityData = WATCHDOG
	_server_copy().abilities.ability = watchdog
	_client_player().abilities.ability = watchdog
	_press(_client_player())
	await wait_until(func() -> bool: return _turrets(_client).size() == 1, 3.0, "the client sees the turret")
	assert_true(_turrets(_server)[0].live, "the server's turret deals the damage")
	assert_false(_turrets(_client)[0].live, "the client's only shows its shots")
	assert_eq(_turrets(_server)[0].user, _server_copy(), "kills go to the user")
