## Top-right squad cards in co-op: each teammate's name, health and down state
## with the bleed-out timer. Hidden in solo. Refreshes four times a second.
class_name SquadCards
extends VBoxContainer

const REFRESH: float = 0.25
const DEAD_GREY: Color = Color(0.55, 0.57, 0.58, 0.7)

var local_player: Player
var _cards: Dictionary[int, VBoxContainer] = {}
var _wait: float = 0.0


func _ready() -> void:
	name = "SquadCards"
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -260.0
	offset_right = -24.0
	offset_top = 128.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 10)
	visible = false


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = REFRESH
		refresh()


func refresh() -> void:
	var team: Array[Player] = teammates()
	var ids: Array[int] = []
	for player: Player in team:
		ids.append(player.net_id)
	for net_id: int in _cards.keys():
		if not ids.has(net_id):
			_cards[net_id].queue_free()
			_cards.erase(net_id)
	for player: Player in team:
		if not _cards.has(player.net_id):
			_cards[player.net_id] = _make_card()
			add_child(_cards[player.net_id])
		show_player(_cards[player.net_id], player)
	visible = not team.is_empty()


func teammates() -> Array[Player]:
	var out: Array[Player] = []
	if not is_instance_valid(local_player) or local_player.session == null or not local_player.state_sync.is_coop():
		return out
	for player: Player in local_player.session.get_players():
		if player != local_player:
			out.append(player)
	return out


static func show_player(card: VBoxContainer, player: Player) -> void:
	var title: Label = card.get_child(0) as Label
	var bar: ProgressBar = card.get_child(1) as ProgressBar
	var status: Label = card.get_child(2) as Label
	title.text = player.display_name if not player.display_name.is_empty() else "Teammate"
	bar.value = clampf(player.health.current / maxf(player.health.max_health, 1.0), 0.0, 1.0)
	status.visible = player.is_dead or player.is_downed
	if player.is_dead:
		status.text = "Respawn next round"
	elif player.is_downed:
		var seconds: int = ceili(player.state_sync.bleed_left)
		status.text = "DOWN %d:%02d" % [floori(seconds / 60.0), seconds % 60]
	card.modulate = DEAD_GREY if player.is_dead else Color.WHITE
	status.modulate = Hud.BLOOD_RED if player.is_downed else Hud.OFF_WHITE


func _make_card() -> VBoxContainer:
	var card: VBoxContainer = VBoxContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.modulate = Hud.OFF_WHITE
	var status: Label = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.theme_type_variation = &"LabelMono"
	for child: Control in [title, bar, status]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(child)
	return card
