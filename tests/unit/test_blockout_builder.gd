## Layout loading in the blockout builder: bad input gives an empty layout, never a crash.
extends GutTest

const BUILDER: String = "res://tools/blockout_builder.gd"

var builder: GDScript


func before_all() -> void:
	builder = load(BUILDER)


func test_missing_layout_is_empty() -> void:
	assert_eq(builder.load_layout("no_such_map"), {})


func test_invalid_json_is_empty() -> void:
	assert_eq(builder.parse_layout("{ rooms: [ broken"), {})


func test_layout_without_rooms_is_empty() -> void:
	assert_eq(builder.parse_layout("[1, 2]"), {})
	assert_eq(builder.parse_layout('{"props": []}'), {})
	assert_eq(builder.parse_layout('{"rooms": "lobby"}'), {})


func test_halcyon_layout_loads() -> void:
	var layout: Dictionary = builder.load_layout("halcyon_labs")
	assert_false((layout["rooms"] as Array).is_empty())
