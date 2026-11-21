## The field ability one player brings into a run (plans/field-abilities.md): the owner
## presses the key, the server runs the effect and owns the cooldown. Each kill by the
## player takes KILL_CREDIT off; Gadgeteer and the Implant affix shorten it (capped).
class_name FieldAbility
extends Node

const KILL_CREDIT: float = 0.5

var ability: AbilityData
var cooldown_left: float = 0.0
## Adrenal Rush: seconds left and the fraction it adds to move speed and fire rate.
var rush_left: float = 0.0
var rush: float = 0.0
var _player: Player


func _init() -> void:
	name = "FieldAbility"


func _ready() -> void:
	_player = get_parent() as Player
	Events.enemy_killed.connect(_on_enemy_killed)


## Counts down on every peer: the server's copy of a client player runs no physics of its own.
func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	rush_left = 0.0 if _player.is_downed else maxf(rush_left - delta, 0.0)


## Adrenal Rush on this copy of the player: on the server by the effect, on the owner by show_use.
func start_rush(data: AbilityData) -> void:
	rush_left = data.duration
	rush = data.amount


## What Player.get_stat multiplies stat by, outside the caps: Adrenal Rush only.
func multiplier(stat: StringName) -> float:
	if rush_left <= 0.0:
		return 1.0
	if stat == &"move_speed":
		return 1.0 + rush
	if stat == &"fire_interval":
		return 1.0 / (1.0 + rush)
	return 1.0


## The highest ability this level has unlocked, or null below the first unlock.
static func pick_for_level(level: int) -> AbilityData:
	var best: AbilityData = null
	for id: StringName in Content.sorted_ids(&"abilities"):
		var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData
		if data and data.unlock_level <= level and (best == null or data.unlock_level > best.unlock_level):
			best = data
	return best


## The saved pick when it exists and the level has unlocked it, else the highest unlocked.
static func pick_for(saved_id: String, level: int) -> AbilityData:
	if not saved_id.is_empty() and Content.has(&"abilities", StringName(saved_id)):
		var saved: AbilityData = Content.get_item(&"abilities", StringName(saved_id)) as AbilityData
		if saved.unlock_level <= level:
			return saved
	return pick_for_level(level)


## Every ability, lowest unlock first.
static func all_by_unlock() -> Array[AbilityData]:
	var list: Array[AbilityData] = []
	for id: StringName in Content.sorted_ids(&"abilities"):
		list.append(Content.get_item(&"abilities", id) as AbilityData)
	list.sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.unlock_level < b.unlock_level)
	return list


## Called from the owner's Player.apply_frame each physics tick. In a session the
## request goes through AbilityClaims, which checks it on the server.
func tick(frame: InputFrame) -> void:
	if not frame.has(InputFrame.FIELD_ABILITY) or not can_use():
		return
	var claims: AbilityClaims = _claims()
	if claims:
		claims.request_use(_player, aim_point())
	elif multiplayer.is_server():
		use(aim_point())


## Owner: where the ability goes off. The user's feet, or for the Decoy Siren the floor under
## what the eyes look at, at most amount metres out.
func aim_point() -> Vector3:
	if ability == null or ability.effect != AbilityData.Effect.DECOY_SIREN or _player.camera == null:
		return _player.global_position
	var eyes: Vector3 = _player.camera.global_position
	var end: Vector3 = eyes - _player.camera.global_basis.z * ability.amount
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eyes, end, Layers.WORLD))
	var point: Vector3 = hit.position + hit.normal * 0.3 if hit else end
	var floor_hit: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 30.0, Layers.WORLD)
	)
	return floor_hit.position if floor_hit else point


func _claims() -> AbilityClaims:
	return _player.session.get_node_or_null(^"AbilityClaims") as AbilityClaims if _player.session else null


func can_use() -> bool:
	var session: GameSession = _player.session
	if ability == null or cooldown_left > 0.0 or (session and (session.is_hub or session.is_over)):
		return false
	return _player.input_enabled and _player.is_alive() and not _player.is_downed


## The design cooldown, shortened by the ability_cooldown stat (capped at 40% in stat_caps).
func full_cooldown() -> float:
	return ability.cooldown * (2.0 - _player.get_stat(&"ability_cooldown")) if ability else 0.0


## Server, without a session's AbilityClaims: checks, then runs. False when it cannot be used now.
## at: the aim point (Decoy Siren); left out, the user's feet.
func use(at: Vector3 = Vector3.INF) -> bool:
	if not multiplayer.is_server() or not can_use():
		return false
	run(at)
	return true


## Server, after the checks: starts the cooldown, runs the effect, shows it and tells the owner.
func run(at: Vector3 = Vector3.INF) -> void:
	if ability.effect != AbilityData.Effect.DECOY_SIREN or not at.is_finite():
		at = _player.global_position
	cooldown_left = full_cooldown()
	AbilityEffects.run(ability, _player, _player.session.spawner if _player.session else null, at)
	PulseRing.play(_player.session if _player.session else _player.get_parent(), ability, at)
	var claims: AbilityClaims = _claims()
	if claims:
		claims.relay_use(_player.net_id, ability, at)
	_publish()


func _on_enemy_killed(_enemy: Node3D, info: DamageInfo) -> void:
	if multiplayer.is_server() and info and info.attacker == _player and cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - KILL_CREDIT, 0.0)
		_publish()


func _publish() -> void:
	if _player.state_sync:
		_player.state_sync.queue_publish()
