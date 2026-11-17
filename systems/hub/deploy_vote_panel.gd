## Town panel for the ready-up vote: the place, every player with a ready tick,
## and the countdown. Hidden while no vote runs. Changes only on
## Events.deploy_vote_changed; the countdown ticks down locally between updates.
class_name DeployVotePanel
extends CanvasLayer

const READY_MARK: String = "[x]"
const WAITING_MARK: String = "[ ]"

var _countdown: float = 0.0

@onready var _box: Control = $Box
@onready var _title: Label = $Box/Rows/Title
@onready var _names: Label = $Box/Rows/Names
@onready var _status: Label = $Box/Rows/Status


func _ready() -> void:
	_box.visible = false
	Events.deploy_vote_changed.connect(show_vote)


func _process(delta: float) -> void:
	if _box.visible and _countdown > 0.0:
		_countdown = maxf(_countdown - delta, 0.0)
		_status.text = "Deploying in %d" % ceili(_countdown)


func show_vote(place: StringName, ready_ids: Array[int], countdown_left: float) -> void:
	_box.visible = not place.is_empty()
	if place.is_empty():
		return
	_title.text = "Deploy: %s" % _label_for(place)
	var lines: PackedStringArray = []
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player == null:
			continue
		total += 1
		var shown: String = player.display_name if not player.display_name.is_empty() else "Player %d" % player.net_id
		lines.append("%s  %s" % [READY_MARK if ready_ids.has(player.net_id) else WAITING_MARK, shown])
	_names.text = "\n".join(lines)
	_countdown = countdown_left
	if countdown_left > 0.0:
		_status.text = "Deploying in %d" % ceili(countdown_left)
	else:
		_status.text = "Waiting for everyone: %d of %d ready" % [ready_ids.size(), total]


## The name on the deploy board for place, so the panel and the board always agree.
func _label_for(place: StringName) -> String:
	for node: Node in get_tree().get_nodes_in_group(&"deploy_board"):
		var board: DeployBoard = node as DeployBoard
		if board and board.place == place:
			return board.label
	return String(place)
