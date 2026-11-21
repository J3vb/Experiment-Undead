## Damage numbers follow the Off / Crits only / All setting, merge per target and never show a teammate's hits.
extends GutTest

const NUMBERS: PackedScene = preload("res://systems/ui/damage_numbers.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var numbers: DamageNumbers
var player: Player
var camera: Camera3D
var target: Node3D
var _saved: Variant


func before_each() -> void:
	_saved = Settings.get_value(&"accessibility", &"damage_numbers")
	camera = Camera3D.new()
	add_child_autofree(camera)
	numbers = NUMBERS.instantiate() as DamageNumbers
	add_child_autofree(numbers)
	numbers.set_process(false)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	target = Node3D.new()
	add_child_autofree(target)
	camera.make_current()
	numbers.mode = "all"


func after_each() -> void:
	Settings.set_value(&"accessibility", &"damage_numbers", _saved)


func _hit(amount: float, head: bool = false, on: Node3D = target, by: Player = player) -> void:
	var info: DamageInfo = DamageInfo.create(amount, by)
	info.hit_zone = DamageInfo.Zone.HEAD if head else DamageInfo.Zone.BODY
	info.position = Vector3(0, 1, -5)
	Events.damage_dealt.emit(by, on, info)


func _shown() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in numbers._labels:
		if label.visible:
			texts.append(label.text)
	return texts


func test_default_setting_is_off() -> void:
	assert_eq(Settings.DEFAULTS[&"accessibility"][&"damage_numbers"], "off")


func test_off_shows_nothing() -> void:
	numbers.mode = "off"
	_hit(34.0)
	assert_eq(numbers.visible_count(), 0)


func test_unknown_setting_reads_as_off() -> void:
	Settings.set_value(&"accessibility", &"damage_numbers", "loud")
	_hit(34.0)
	assert_eq(numbers.visible_count(), 0)


func test_all_shows_the_amount_in_white_over_the_hit() -> void:
	Settings.set_value(&"accessibility", &"damage_numbers", "all")
	_hit(34.4)
	assert_eq(_shown(), ["34"] as Array[String])
	var label: Label = numbers._labels[0]
	assert_eq(label.get_theme_color(&"font_color"), DamageNumbers.WHITE)
	assert_eq(label.get_theme_font_size(&"font_size"), 14)
	var expected: Vector2 = camera.unproject_position(Vector3(0, 1.3, -5))
	assert_almost_eq(label.position + label.size * 0.5, expected, Vector2(1, 1), "drawn at the hit point")


func test_crits_only_shows_headshots_in_gold() -> void:
	numbers.mode = "crits"
	_hit(34.0)
	assert_eq(numbers.visible_count(), 0, "a body hit is skipped")
	_hit(102.0, true)
	assert_eq(_shown(), ["102"] as Array[String])
	assert_eq(numbers._labels[0].get_theme_color(&"font_color"), DamageNumbers.HEAD_GOLD)


func test_hits_on_one_target_merge_within_120_ms() -> void:
	_hit(20.0)
	numbers._process(0.05)
	_hit(20.0)
	assert_eq(_shown(), ["40"] as Array[String], "50 ms apart: one label with the sum")
	numbers._process(0.2)
	_hit(20.0)
	assert_eq(numbers.visible_count(), 2, "200 ms later: a new label")
	numbers._process(0.05)
	_hit(5.0)
	assert_has(_shown(), "25", "merges into the newest label, not the old one")


func test_different_targets_get_their_own_labels_and_the_13th_reuses_the_oldest() -> void:
	var others: Array[Node3D] = []
	for index: int in 13:
		var other: Node3D = Node3D.new()
		add_child_autofree(other)
		others.append(other)
		_hit(float(index + 1), false, other)
	assert_eq(numbers.visible_count(), 12, "never more than 12")
	assert_eq(numbers._labels[0].text, "13", "the oldest label was reused")


func test_labels_fade_out_after_their_lifetime() -> void:
	_hit(20.0)
	numbers._process(DamageNumbers.LIFETIME + 0.01)
	assert_eq(numbers.visible_count(), 0)


func test_a_teammates_hit_shows_nothing() -> void:
	var mate: Player = PLAYER.instantiate() as Player
	mate.set_multiplayer_authority(2)
	add_child_autofree(mate)
	mate.set_physics_process(false)
	_hit(34.0, false, target, mate)
	assert_eq(numbers.visible_count(), 0)


## Plan budget: under 0.1 ms per frame with 24 zombies and an LMG firing. A hit lands every
## 4th frame (15 a second, faster than any LMG) while all 12 labels are in the air.
func test_a_busy_frame_stays_under_the_budget_and_makes_no_labels() -> void:
	var zombies: Array[Node3D] = []
	for index: int in 24:
		var zombie: Node3D = Node3D.new()
		add_child_autofree(zombie)
		zombies.append(zombie)
	for warmup: int in 24:
		_hit(30.0, false, zombies[warmup])
	var children: int = numbers.get_child_count()
	var frames: int = 600
	var started: int = Time.get_ticks_usec()
	for frame: int in frames:
		if frame % 4 == 0:
			_hit(30.0, frame % 5 == 0, zombies[frame % zombies.size()])
		numbers._process(1.0 / 60.0)
	var per_frame_ms: float = float(Time.get_ticks_usec() - started) / frames / 1000.0
	gut.p("damage numbers: %.4f ms per frame" % per_frame_ms)
	assert_lt(per_frame_ms, 0.1, "under 0.1 ms per frame")
	assert_eq(numbers.get_child_count(), children, "the 12 pooled labels are reused, none made")
	assert_eq(numbers.visible_count(), DamageNumbers.MAX_LABELS, "the pool is full the whole time")
