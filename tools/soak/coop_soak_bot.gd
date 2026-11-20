## Co-op soak bot: joins the server as a real client, gives itself one strong gun on its own PC (guns are
## owner-side) and fights with legal claims only. It moves its own player near a chasing zombie (owners
## move themselves, ADR 0003) and claims one body hit per fire interval through the real HitClaims path.
## Once a round it throws a frag at a far zombie through the real GrenadeClaims request.
extends Node

const RUN: GDScript = preload("res://tools/soak/coop_soak.gd")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const STAND_OFF: float = 4.0  ## Metres from the zombie after a move.
const MOVE_AFTER: float = 15.0  ## Move when the target is farther than this (or half the gun's range).
const SETTLE: float = 0.3  ## Seconds after a move before claiming, so the server has the new pose.
const INTERVAL_SLACK: float = 1.2  ## Claim a little slower than the gun fires.

var _session: GameSession
var _player: Player
var _weapon: Weapon
var _gun: WeaponData
var _rounds: int = 5
var _result_path: String = ""
var _round: int = 0
var _claims: int = 0
var _moves: int = 0
var _throws: int = 0
var _throw_round: int = -1
var _cooldown: float = 0.0
var _settle: float = 0.0
var _done: bool = false
var _lost: bool = false


func _ready() -> void:
	Engine.time_scale = float(RUN.arg("timescale"))
	Engine.max_fps = Engine.physics_ticks_per_second
	_rounds = int(RUN.arg("rounds"))
	_result_path = RUN.arg("result")
	_gun = Content.weapon(StringName(RUN.arg("gun")))
	Events.round_started.connect(func(round_number: int, _count: int) -> void: _round = round_number)
	Events.round_ended.connect(_on_round_ended)
	multiplayer.server_disconnected.connect(_finish.bind(true), CONNECT_DEFERRED)
	multiplayer.connection_failed.connect(_finish.bind(true), CONNECT_DEFERRED)
	Net.pending_join = RUN.arg("join")
	_session = SESSION.instantiate() as GameSession
	_session.profile_id = &""
	# The match must sit at /root/GameSession on every peer for node paths to match.
	get_tree().root.add_child.call_deferred(_session)
	_write()


func _physics_process(delta: float) -> void:
	if _done or not is_instance_valid(_session) or _session.players == null:
		return
	if _player == null:
		_player = _session.players.find_player(multiplayer.get_unique_id())
		if _player:
			_arm()
		return
	if not _player.is_alive():
		return
	_cooldown -= delta
	_settle -= delta
	var zombie: Zombie = _nearest_chaser()
	if zombie == null:
		return
	if _player.global_position.distance_to(zombie.global_position) > minf(MOVE_AFTER, _gun.max_range * 0.5):
		_move_near(zombie)
	elif _cooldown <= 0.0 and _settle <= 0.0:
		_maybe_throw(zombie)
		_claim(zombie)


func _arm() -> void:
	_player.input_enabled = false
	_player.local_input.enabled = false
	_player.set_physics_process(false)
	_weapon = _player.weapons.give(_gun)
	_settle = SETTLE
	_write()


func _nearest_chaser() -> Zombie:
	var best: Zombie = null
	var best_distance: float = INF
	for child: Node in _session.spawner.get_children():
		var zombie: Zombie = child as Zombie
		if zombie == null or zombie.state not in [Zombie.State.CHASING, Zombie.State.ATTACKING]:
			continue
		var distance: float = _player.global_position.distance_squared_to(zombie.global_position)
		if distance < best_distance:
			best = zombie
			best_distance = distance
	return best


## One frag a round, lobbed at a zombie far enough not to hurt the bot.
func _maybe_throw(zombie: Zombie) -> void:
	var grenades: GrenadeThrower = _player.grenades
	var gap: Vector3 = zombie.global_position - _player.global_position
	if _throw_round == _round or grenades.count < 1 or gap.length() <= grenades.data.radius + 1.0:
		return
	_throw_round = _round
	grenades.fuse_left = grenades.data.fuse
	grenades.throw(gap.normalized() * grenades.data.throw_speed * 0.6 + Vector3.UP * 3.0)
	_throws += 1


## Steps back along the zombie's own path, which is walkable floor.
func _move_near(zombie: Zombie) -> void:
	var away: Vector3 = -zombie.velocity
	if Vector2(away.x, away.z).length() < 0.1:
		away = _player.global_position - zombie.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.BACK
	_player.global_position = zombie.global_position + away.normalized() * STAND_OFF
	_moves += 1
	_settle = SETTLE


func _claim(zombie: Zombie) -> void:
	for zone: HitZone in zombie.hit_zones:
		if zone.zone != DamageInfo.Zone.BODY:
			continue
		var info: DamageInfo = DamageInfo.create(_gun.damage, _player)
		info.weapon_id = _gun.id
		info.position = zone.global_position
		_session.hit_claims.submit_hit(_weapon, zone, info)
		_claims += 1
		_cooldown = 60.0 / _gun.rounds_per_minute * INTERVAL_SLACK
		return


func _on_round_ended(round_number: int) -> void:
	_round = maxi(_round, round_number)
	if round_number >= _rounds:
		_finish()


func _finish(lost: bool = false) -> void:
	if _done:
		return
	_done = true
	_lost = lost
	_write()
	# Bots leave one by one: two peers dropping in one server frame is a separate known engine race.
	if not lost:
		await get_tree().create_timer(float(RUN.arg("leave-delay", "0")), true, false, true).timeout
	Net.leave()
	get_tree().quit()


func _write() -> void:
	var data: Dictionary = {"role": "bot", "done": _done, "round": _round, "claims": _claims, "moves": _moves}
	data["joined"] = _player != null
	data["throws"] = _throws
	data["lost_server"] = _lost
	data["net_id"] = _player.net_id if _player else 0
	data["points"] = _player.wallet.points if _player else 0
	data["log"] = ProjectSettings.globalize_path(Log.log_path)
	RUN.write_result(_result_path, data)
