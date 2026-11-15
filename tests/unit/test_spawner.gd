extends GutTest


func test_missing_spawn_group_is_recorded_in_the_structured_log() -> void:
	var spawner: Spawner = Spawner.new()
	spawner.spawn_group = &"test_missing_spawn_points"
	add_child_autofree(spawner)
	var before: int = Log.event_counts.get("waves.spawn_points_missing", 0)
	assert_null(spawner._pick_marker(0.0))
	assert_eq(Log.event_counts.get("waves.spawn_points_missing", 0), before + 1)
	var record: Dictionary = Log.problems["waves.spawn_points_missing|"]["first"]
	assert_eq(record["level"], "warn")
	assert_eq(record["data"]["spawn_group"], String(spawner.spawn_group))
