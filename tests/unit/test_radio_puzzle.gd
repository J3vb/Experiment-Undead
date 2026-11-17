## The Signal in the Static puzzle on one machine: tones roll at power-on from the
## session RNG, presses lowest to highest open the freezer, a wrong press resets.
extends GutTest

const RADIO: PackedScene = preload("res://systems/interactables/wall_radio.tscn")
const DOOR: PackedScene = preload("res://systems/interactables/door.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")


class QuietSession:
	extends GameSession

	func _init() -> void:
		var parts: Dictionary[StringName, Node] = {
			&"WaveDirector": WaveDirector.new(),
			&"Economy": Economy.new(),
			&"Progression": ProgressionService.new(),
			&"PowerUpDrops": PowerUpDrops.new(),
			&"Hud": HUD.instantiate(),
		}
		for part: StringName in parts:
			parts[part].name = part
			add_child(parts[part])

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


func _puzzle(rng_seed: int = 7) -> RadioPuzzle:
	var session: QuietSession = QuietSession.new()
	session.rng.seed = rng_seed
	var level: Level = Level.new()
	session.add_child(level)
	var door: Door = DOOR.instantiate() as Door
	door.opens_area = &"test_cold_room"
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.name = "Blocker"
	door.add_child(blocker)
	level.add_child(door)
	var puzzle: RadioPuzzle = RadioPuzzle.new()
	for i: int in 3:
		puzzle.add_child(RADIO.instantiate())
	puzzle.door = door
	level.add_child(puzzle)
	add_child_autofree(session)
	return puzzle


func _by_pitch(puzzle: RadioPuzzle) -> Array[WallRadio]:
	var out: Array[WallRadio] = puzzle.radios.duplicate()
	out.sort_custom(func(a: WallRadio, b: WallRadio) -> bool: return a.pitch < b.pitch)
	return out


func _pitches(puzzle: RadioPuzzle) -> Array[int]:
	var out: Array[int] = []
	for radio: WallRadio in puzzle.radios:
		out.append(radio.pitch)
	return out


func _power(puzzle: RadioPuzzle) -> void:
	(puzzle.get_parent() as Level).turn_power_on()


func test_radios_are_silent_until_power() -> void:
	var puzzle: RadioPuzzle = _puzzle()
	for radio: WallRadio in puzzle.radios:
		assert_eq(radio.pitch, -1)
		assert_eq(radio.get_prompt(null), "")
		radio.interact(null)
	assert_false(puzzle.is_solved())
	_power(puzzle)
	var sorted: Array[int] = _pitches(puzzle)
	sorted.sort()
	assert_eq(sorted, [0, 1, 2] as Array[int], "each tone handed out once")
	assert_eq(puzzle.radios[0].get_prompt(null), "Tune radio [F]")


func test_lowest_to_highest_opens_the_freezer() -> void:
	var puzzle: RadioPuzzle = _puzzle()
	_power(puzzle)
	var order: Array[WallRadio] = _by_pitch(puzzle)
	order[0].interact(null)
	order[1].interact(null)
	assert_true(order[0].lit and order[1].lit)
	assert_false(puzzle.is_solved())
	order[2].interact(null)
	assert_true(puzzle.is_solved())
	assert_true(puzzle.door.is_open)


func test_wrong_press_resets_every_radio() -> void:
	var puzzle: RadioPuzzle = _puzzle()
	_power(puzzle)
	var order: Array[WallRadio] = _by_pitch(puzzle)
	order[0].interact(null)
	order[2].interact(null)
	for radio: WallRadio in puzzle.radios:
		assert_false(radio.lit)
	assert_eq(order[2].net_state().fails, 1, "static on the wrong radio")
	assert_eq(order[0].net_state().fails, 0)
	assert_false(puzzle.is_solved())
	for radio: WallRadio in order:
		radio.interact(null)
	assert_true(puzzle.is_solved(), "a fresh try still works")


func test_same_seed_gives_the_same_order() -> void:
	var a: RadioPuzzle = _puzzle(42)
	var b: RadioPuzzle = _puzzle(42)
	_power(a)
	_power(b)
	assert_eq(_pitches(a), _pitches(b))


func test_net_state_round_trip() -> void:
	var puzzle: RadioPuzzle = _puzzle()
	_power(puzzle)
	var source: WallRadio = _by_pitch(puzzle)[0]
	source.interact(null)
	var copy: WallRadio = RADIO.instantiate() as WallRadio
	add_child_autofree(copy)
	copy.apply_net_state(source.net_state())
	assert_eq(copy.net_state(), source.net_state())
	assert_true((copy.get_node("Lamp") as Node3D).visible)
	assert_true((copy.get_node("Tone") as AudioStreamPlayer3D).playing, "the press plays on the copy too")


func test_map_without_a_session_stays_silent_at_power() -> void:
	var level: Level = Level.new()
	var puzzle: RadioPuzzle = RadioPuzzle.new()
	puzzle.add_child(RADIO.instantiate())
	level.add_child(puzzle)
	add_child_autofree(level)
	level.turn_power_on()
	assert_eq(puzzle.radios[0].pitch, -1)
