## RoundCounter shows "ROUND n" top right, blinks in the break and stays hidden before any round.
extends GutTest

const HUD: PackedScene = preload("res://systems/ui/hud.tscn")

var hud: Hud
var counter: RoundCounter


func before_each() -> void:
	hud = HUD.instantiate() as Hud
	add_child_autofree(hud)
	hud.set_process(false)
	counter = hud.round_counter


func test_hidden_until_a_round_or_break() -> void:
	assert_false(counter.visible, "the town never starts a round, so the counter stays hidden")
	assert_eq(counter.label.text, "")


func test_joining_between_rounds_shows_the_last_round() -> void:
	Events.intermission_started.emit(8, 12.0)
	assert_eq(counter.label.text, "ROUND 7", "a late joiner in a break sees the round just survived")
	assert_true(counter.visible)
	Events.intermission_started.emit(1, 10.0)
	assert_eq(counter.label.text, "ROUND 7", "the first break leaves the label alone")


func test_round_start_draws_the_stroke_and_break_blinks() -> void:
	Events.round_started.emit(12, 24)
	assert_eq(counter.label.text, "ROUND 12")
	assert_eq(counter.label.modulate, Color.WHITE)
	assert_eq(counter.underline, 0.0)
	counter._tween.pause()
	counter._tween.custom_step(1.1)
	assert_almost_eq(counter.underline, 1.0, 0.001)
	Events.intermission_started.emit(13, 10.0)
	counter._tween.pause()
	counter._tween.custom_step(0.8)
	assert_almost_eq(counter.label.modulate.a, RoundCounter.BLINK_ALPHA, 0.001)
	Events.round_started.emit(13, 26)
	assert_eq(counter.label.modulate.a, 1.0)
