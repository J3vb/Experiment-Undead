## Research: spend skill points in three branch lanes. Ranks stay pending until Confirm saves them.
class_name ResearchScreen
extends Control

signal closed

const BRANCHES: Array[StringName] = [&"Marksman", &"Survivor", &"Tinkerer"]
## Rows 0-2 hold the regular skills, 3 the keystone, 4 the capstone (content/skills).
const ROWS: int = 5

var profile: CharacterProfile
var saved: Dictionary[StringName, int] = {}
var pending: Dictionary[StringName, int] = {}
var tiles: Dictionary[StringName, SkillTile] = {}
var _branch_labels: Dictionary[StringName, Label] = {}
## Set by the first Back with unsaved ranks; the second Back discards them.
var _warned: bool = false

@onready var lanes: VBoxContainer = %Lanes
@onready var links: SkillLinks = %Links
@onready var glow: TextureRect = %TankGlow
@onready var points_label: Label = %Points
@onready var detail: Label = %Detail
@onready var status: Label = %Status


func _ready() -> void:
	_build_lanes()
	lanes.resized.connect(links.queue_redraw)
	_pulse_glow()
	%Confirm.pressed.connect(confirm)
	%Reset.pressed.connect(reset_all)
	%Back.pressed.connect(back)


func open(character: CharacterProfile) -> void:
	profile = character
	saved = SkillEffects.ranks_from(profile.skill_ranks)
	pending = saved.duplicate()
	_warned = false
	status.text = ""
	if SkillTree.points_available(profile.level, saved) < 0:
		Log.warn(&"progression", &"skill_ranks_over_budget", {"level": profile.level, "ranks": saved.size()})
		status.text = "This character holds more ranks than its level allows. Reset all to spend again."
	show()
	_refresh()
	first_tile().grab_focus()


## The top-left tile of the first lane, where focus starts.
func first_tile() -> SkillTile:
	var lane: HBoxContainer = lanes.get_child(0) as HBoxContainer
	return lane.get_child(1).get_child(0) as SkillTile


func _build_lanes() -> void:
	var all_rows: Array = []
	for branch: StringName in BRANCHES:
		var lane: HBoxContainer = HBoxContainer.new()
		lane.name = String(branch)
		lane.add_theme_constant_override(&"separation", 36)
		lanes.add_child(lane)
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(160, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", SkillTile.TEAL)
		lane.add_child(label)
		_branch_labels[branch] = label
		var rows: Array[VBoxContainer] = []
		for row: int in ROWS:
			var column: VBoxContainer = VBoxContainer.new()
			column.alignment = BoxContainer.ALIGNMENT_CENTER
			lane.add_child(column)
			rows.append(column)
		for node_id: StringName in Content.sorted_ids(&"skills"):
			var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
			if node.branch == branch:
				_add_tile(node, rows[clampi(node.row, 0, ROWS - 1)])
		var lane_rows: Array = []
		for column: VBoxContainer in rows:
			lane_rows.append(column.get_children())
		all_rows.append(lane_rows)
	links.set_rows(all_rows)


## The Fenlight tank glow breathes slowly; Reduce motion holds it still.
func _pulse_glow() -> void:
	glow.modulate.a = 0.8
	if Settings.get_value(&"accessibility", &"reduce_motion"):
		return
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(glow, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 0.6, 2.4).set_trans(Tween.TRANS_SINE)


func _add_tile(node: SkillNodeData, column: VBoxContainer) -> void:
	var tile: SkillTile = SkillTile.new(node)
	tile.pressed.connect(add_rank.bind(node.id))
	tile.focus_entered.connect(_show_detail.bind(node.id))
	tile.mouse_entered.connect(tile.grab_focus)
	tile.gui_input.connect(_tile_input.bind(node.id))
	tile.item_rect_changed.connect(links.queue_redraw)
	column.add_child(tile)
	var index: int = 0
	while index < column.get_child_count() - 1:
		var other: SkillTile = column.get_child(index) as SkillTile
		if other.node.column > node.column:
			column.move_child(tile, index)
			break
		index += 1
	tiles[node.id] = tile


func add_rank(node_id: StringName) -> void:
	if profile == null:
		return
	pending = SkillTree.rank_up(pending, node_id, profile.level)
	_changed()


func remove_rank(node_id: StringName) -> void:
	if profile == null:
		return
	pending = SkillTree.rank_down(pending, saved, node_id)
	_changed()


func reset_all() -> void:
	pending = SkillTree.respec()
	_changed()


func confirm() -> void:
	if profile == null:
		return
	var ranks: Dictionary = {}
	for node_id: StringName in pending:
		ranks[String(node_id)] = pending[node_id]
	var before: Dictionary = profile.skill_ranks
	profile.skill_ranks = ranks
	var error: Error = profile.save()
	if error != OK:
		profile.skill_ranks = before
		status.text = "Could not save (%s). Back twice closes without saving." % error_string(error)
		return
	saved = pending.duplicate()
	_warned = false
	status.text = "Saved."
	_refresh()


func back() -> void:
	if profile == null:
		return
	if pending != saved and not _warned:
		_warned = true
		status.text = "Your new ranks are not saved. Confirm saves them, Back again discards them."
		%Back.text = "Discard changes"
		return
	hide()
	closed.emit()


func has_unsaved_changes() -> bool:
	return pending != saved


func _changed() -> void:
	_warned = false
	%Back.text = "Back"
	if status.text != "" and not status.text.begins_with("This character"):
		status.text = ""
	_refresh()


func _refresh() -> void:
	var left: int = SkillTree.points_available(profile.level, pending)
	points_label.text = "Level %d    Points left: %d" % [profile.level, left]
	for branch: StringName in BRANCHES:
		_branch_labels[branch].text = "%s\n%d points" % [branch.to_upper(), SkillTree.points_in_branch(pending, branch)]
	for node_id: StringName in tiles:
		var tile: SkillTile = tiles[node_id]
		var rank: int = pending.get(node_id, 0)
		var gate_met: bool = (
			SkillTree.points_in_branch(pending, tile.node.branch) - rank >= tile.node.branch_points_needed
		)
		tile.show_rank(rank, not gate_met)
	links.queue_redraw()
	%Confirm.disabled = pending == saved
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused is SkillTile:
		_show_detail((focused as SkillTile).node.id)


func _show_detail(node_id: StringName) -> void:
	var node: SkillNodeData = tiles[node_id].node
	var rank: int = pending.get(node_id, 0)
	var text: String = node.description.replace("{v}", String.num(node.per_rank))
	var lines: PackedStringArray = [node.display_name, text, "Rank %d of %d" % [rank, node.max_ranks]]
	if node.branch_points_needed > 0:
		lines.append("Needs %d points in %s" % [node.branch_points_needed, node.branch])
	if SkillTree.can_rank_down(pending, saved, node_id):
		lines.append("Right-click, Backspace or X removes a new rank")
	detail.text = "\n".join(lines)


func _tile_input(event: InputEvent, node_id: StringName) -> void:
	var remove: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X)
		or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_BACKSPACE, KEY_DELETE])
	)
	if remove:
		remove_rank(node_id)
		accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or profile == null:
		return
	var escape: bool = event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE
	if event.is_action_pressed(&"ui_cancel") or escape:
		back()
		get_viewport().set_input_as_handled()
