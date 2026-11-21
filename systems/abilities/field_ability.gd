## The field ability one player brings into a run (plans/field-abilities.md): the owner
## presses the key, the server runs the effect and owns the cooldown. Each kill by the
## player takes KILL_CREDIT off; Gadgeteer and the Implant affix shorten it (capped).
class_name FieldAbility
extends Node

const KILL_CREDIT: float = 0.5

var ability: AbilityData
var cooldown_left: float = 0.0
var _player: Player


func _init() -> void:
	name = "FieldAbility"


func _ready() -> void:
	_player = get_parent() as Player
	Events.enemy_killed.connect(_on_enemy_killed)


## Counts down on every peer: the server's copy of a client player runs no physics of its own.
func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## The highest ability this level has unlocked, or null below the first unlock.
static func pick_for_level(level: int) -> AbilityData:
	var best: AbilityData = null
	for id: StringName in Content.sorted_ids(&"abilities"):
		var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData
		if data and data.unlock_level <= level and (best == null or data.unlock_level > best.unlock_level):
			best = data
	return best


## Called from the owner's Player.apply_frame each physics tick.
func tick(frame: InputFrame) -> void:
	if frame.has(InputFrame.FIELD_ABILITY) and can_use() and multiplayer.is_server():
		use()


func can_use() -> bool:
	var session: GameSession = _player.session
	if ability == null or cooldown_left > 0.0 or (session and (session.is_hub or session.is_over)):
		return false
	return _player.input_enabled and _player.is_alive() and not _player.is_downed


## The design cooldown, shortened by the ability_cooldown stat (capped at 40% in stat_caps).
func full_cooldown() -> float:
	return ability.cooldown * (2.0 - _player.get_stat(&"ability_cooldown")) if ability else 0.0


## Server: runs the effect and starts the cooldown. False when it cannot be used now.
func use() -> bool:
	if not multiplayer.is_server() or not can_use():
		return false
	cooldown_left = full_cooldown()
	AbilityEffects.run(ability, _player, _player.session.spawner if _player.session else null)
	return true


func _on_enemy_killed(_enemy: Node3D, info: DamageInfo) -> void:
	if multiplayer.is_server() and info and info.attacker == _player:
		cooldown_left = maxf(cooldown_left - KILL_CREDIT, 0.0)
