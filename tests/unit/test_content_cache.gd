## Content keeps each loaded resource, answers has() without errors and starts fresh on reload().
extends GutTest


func after_all() -> void:
	Content.reload()


func test_get_item_keeps_the_instance_after_the_caller_drops_it() -> void:
	var first: Resource = Content.get_item(&"power_ups", &"resupply")
	var first_id: int = first.get_instance_id()
	first = null
	var second: Resource = Content.get_item(&"power_ups", &"resupply")
	assert_eq(second.get_instance_id(), first_id)


func test_has_finds_real_ids_only() -> void:
	assert_true(Content.has(&"weapons", &"rifle_ar"))
	assert_false(Content.has(&"weapons", &"no_such_gun"))
	assert_false(Content.has(&"no_such_type", &"rifle_ar"))
	assert_push_error_count(0)


func test_reload_lets_go_of_kept_instances() -> void:
	var item: Resource = Content.get_item(&"power_ups", &"resupply")
	var held: int = item.get_reference_count()
	Content.reload()
	assert_eq(item.get_reference_count(), held - 1)


func test_sorted_ids_are_in_name_order() -> void:
	var expected: PackedStringArray = PackedStringArray(Content.ids(&"weapons"))
	expected.sort()
	assert_eq(PackedStringArray(Content.sorted_ids(&"weapons")), expected)
	assert_eq(Content.sorted_ids(&"no_such_type"), [] as Array[StringName])
