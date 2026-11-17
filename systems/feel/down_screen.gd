## Local player's downed, revived and death screen: desaturation and vignette while
## down, a short flash on revive, and a fade to black with world sound dropping out
## on death. Reads the local player's synced flags; presentation only.
class_name DownScreen
extends ColorRect

enum State { UP, DOWN, DEAD }

const QUIET_DB: float = -60.0
const COLOUR_FADE_S: float = 0.3

@export var rules: FeedbackRules

var state: State = State.UP
var _player: Player
var _shade: ShaderMaterial
var _tween: Tween
var _amplify: AudioEffectAmplify


func _ready() -> void:
	if rules == null:
		rules = FeedbackRules.new()
	_shade = material as ShaderMaterial
	_amplify = _find_world_fade()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_look(1.0, 0.0, 0.0, 0.0)


func _exit_tree() -> void:
	_set_world_db(0.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = _find_local_player()
		if _player == null:
			return
	var next: State = state_of(_player)
	if next != state:
		_enter(next)


## DEAD also covers a co-op squad wipe: the match ends with everyone still downed.
static func state_of(player: Player) -> State:
	var over: bool = player.session != null and player.session.is_over
	if player.is_dead or (over and player.is_downed):
		return State.DEAD
	return State.DOWN if player.is_downed else State.UP


func set_player(player: Player) -> void:
	_player = player


func world_db() -> float:
	return _amplify.volume_db if _amplify else 0.0


func _enter(next: State) -> void:
	var previous: State = state
	state = next
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	match next:
		State.DOWN:
			_fade_look(rules.downed_saturation, rules.downed_vignette, 0.0, COLOUR_FADE_S)
		State.DEAD:
			_tween.tween_method(_set_black, _black(), 1.0, rules.death_fade_s)
			_tween.tween_method(_set_world_db, world_db(), QUIET_DB, rules.death_fade_s)
			if _spectates():
				_tween.chain().tween_callback(_back_to_spectate)
		State.UP:
			_fade_look(1.0, 0.0, 0.0, COLOUR_FADE_S)
			_set_world_db(0.0)
			if previous == State.DOWN:
				_revive_flash()


## Runs from the death tween's own callback, so it needs a fresh tween.
func _back_to_spectate() -> void:
	_set_world_db(0.0)
	_tween = create_tween().set_parallel()
	_fade_look(1.0, 0.0, 0.0, rules.death_fade_s)


func _spectates() -> bool:
	return _player.state_sync.is_coop() and not (_player.session and _player.session.is_over)


func _revive_flash() -> void:
	if Settings.get_value(&"comfort", &"flash_reduction"):
		return
	_set_param(&"flash", rules.revive_flash_alpha)
	_tween.tween_method(_set_flash, rules.revive_flash_alpha, 0.0, rules.revive_flash_s)


func _fade_look(saturation: float, vignette: float, black: float, seconds: float) -> void:
	_tween.tween_method(_set_saturation, _param(&"saturation", 1.0), saturation, seconds)
	_tween.tween_method(_set_vignette, _param(&"vignette", 0.0), vignette, seconds)
	_tween.tween_method(_set_black, _black(), black, seconds)


func _set_look(saturation: float, vignette: float, flash: float, black: float) -> void:
	_set_param(&"saturation", saturation)
	_set_param(&"vignette", vignette)
	_set_param(&"flash", flash)
	_set_black(black)


func _set_saturation(value: float) -> void:
	_set_param(&"saturation", value)


func _set_vignette(value: float) -> void:
	_set_param(&"vignette", value)


func _set_flash(value: float) -> void:
	_set_param(&"flash", value)


func _set_black(value: float) -> void:
	_set_param(&"black", value)


func _black() -> float:
	return _param(&"black", 0.0)


func _set_param(key: StringName, value: float) -> void:
	if _shade:
		_shade.set_shader_parameter(key, value)
	visible = not _is_neutral()


func _param(key: StringName, fallback: float) -> float:
	var value: Variant = _shade.get_shader_parameter(key) if _shade else null
	return float(value) if value != null else fallback


## Hidden when nothing shows, so the screen-texture read costs nothing.
func _is_neutral() -> bool:
	return (
		_param(&"saturation", 1.0) >= 0.999
		and _param(&"vignette", 0.0) <= 0.001
		and _param(&"flash", 0.0) <= 0.001
		and _param(&"black", 0.0) <= 0.001
	)


func _set_world_db(value: float) -> void:
	if _amplify:
		_amplify.volume_db = value


func _find_world_fade() -> AudioEffectAmplify:
	var bus: int = AudioServer.get_bus_index(&"SFX")
	if bus < 0:
		return null
	for i: int in AudioServer.get_bus_effect_count(bus):
		var effect: AudioEffectAmplify = AudioServer.get_bus_effect(bus, i) as AudioEffectAmplify
		if effect:
			return effect
	return null


func _find_local_player() -> Player:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.is_multiplayer_authority():
			return player
	return null
