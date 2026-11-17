## Presents replicated co-op states and samples the held revive key into InputFrames.
class_name CoopHud
extends Control

var _player: Player
var _blocked: bool = false

@onready var hold_bar: ProgressBar = $Hold


func get_prompt(player: Player, blocked: bool) -> String:
	_player = player
	_blocked = blocked or (is_instance_valid(player) and player.session and player.session.is_over)
	hold_bar.hide()
	if not is_instance_valid(player) or not player.is_inside_tree() or _blocked:
		return ""
	if player.is_dead:
		return "Spectating · Respawn next round"
	if player.is_downed and player.state_sync.is_coop():
		return "You are down · Waiting for a revive"
	var target: Player = player.revive.nearest_target()
	if target:
		hold_bar.show()
		hold_bar.value = player.revive.progress
		return "Hold to revive %s [F]" % target.name
	return player.focus.get_prompt(player) if player.focus else ""


func apply_frame(frame: InputFrame, delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	if _blocked or get_tree().paused or not _player.input_enabled:
		frame.buttons = 0
	_player.revive.apply_frame(frame, delta)
