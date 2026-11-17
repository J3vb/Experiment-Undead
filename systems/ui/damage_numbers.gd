## Floating damage over enemies the local player hits, per the Damage numbers setting (game-feel.md).
## Off by default; "crits" shows headshots until a crit stat exists. Hits on one target merge for 120 ms.
class_name DamageNumbers
extends Control

const MAX_LABELS: int = 12
const MERGE_TIME: float = 0.12
const LIFETIME: float = 0.8
const RISE: float = 0.6
const LIFT: float = 0.3
const FONT_SIZE: int = 14
const WHITE: Color = Color(1, 1, 1)
const HEAD_GOLD: Color = Color("ffc845")

var mode: String = "off"
var _labels: Array[Label] = []
var _points: Array[Vector3] = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _targets: PackedInt64Array = PackedInt64Array()
var _totals: PackedFloat32Array = PackedFloat32Array()
var _last_hit: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for index: int in MAX_LABELS:
		var label: Label = Label.new()
		label.add_theme_font_size_override(&"font_size", FONT_SIZE)
		label.add_theme_constant_override(&"outline_size", 4)
		label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
		label.visible = false
		add_child(label)
		_labels.append(label)
		_points.append(Vector3.ZERO)
	_ages.resize(MAX_LABELS)
	_ages.fill(LIFETIME)
	_targets.resize(MAX_LABELS)
	_totals.resize(MAX_LABELS)
	_last_hit.resize(MAX_LABELS)
	_last_hit.fill(-1.0)
	mode = str(Settings.get_value(&"accessibility", &"damage_numbers"))
	Settings.changed.connect(_on_setting_changed)
	Events.damage_dealt.connect(_on_damage_dealt)


func visible_count() -> int:
	var count: int = 0
	for label: Label in _labels:
		count += 1 if label.visible else 0
	return count


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"accessibility" and key == &"damage_numbers":
		mode = str(value)


func _on_damage_dealt(player: Player, target: Node3D, info: DamageInfo) -> void:
	if player == null or not player.is_inside_tree() or not player.is_multiplayer_authority():
		return
	if not (mode == "all" or (mode == "crits" and info.is_headshot())):
		return
	var key: int = target.get_instance_id() if target else 0
	var index: int = _targets.find(key)
	if key == 0 or index < 0 or _time - _last_hit[index] > MERGE_TIME or _ages[index] >= LIFETIME:
		if index >= 0:
			_targets[index] = -1
		index = _next
		_next = (_next + 1) % MAX_LABELS
		_targets[index] = key
		_totals[index] = 0.0
		_labels[index].add_theme_color_override(&"font_color", WHITE)
	_totals[index] += info.amount
	_last_hit[index] = _time
	_ages[index] = 0.0
	_points[index] = info.position + Vector3.UP * LIFT
	_labels[index].text = str(roundi(_totals[index]))
	if info.is_headshot():
		_labels[index].add_theme_color_override(&"font_color", HEAD_GOLD)
	_labels[index].visible = true
	_place(index, get_viewport().get_camera_3d())


func _process(delta: float) -> void:
	_time += delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	for index: int in MAX_LABELS:
		if not _labels[index].visible:
			continue
		_ages[index] += delta
		if _ages[index] >= LIFETIME:
			_labels[index].visible = false
			_targets[index] = 0
			continue
		_place(index, camera)


func _place(index: int, camera: Camera3D) -> void:
	var label: Label = _labels[index]
	var t: float = _ages[index] / LIFETIME
	var point: Vector3 = _points[index] + Vector3.UP * RISE * t
	if camera == null or camera.is_position_behind(point):
		label.modulate.a = 0.0
		return
	label.modulate.a = 1.0 - maxf(t - 0.5, 0.0) * 2.0
	label.position = camera.unproject_position(point) - label.size * 0.5
