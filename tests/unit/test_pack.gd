## Pack capacity, refused pickups and ownership of nested item dictionaries.
extends GutTest

var pack: Pack


func before_each() -> void:
	pack = Pack.new()


func test_six_slots_and_full_refuses_without_changing_items() -> void:
	assert_eq(pack.items.size(), 0)
	assert_false(pack.is_full())
	for index: int in 6:
		assert_true(pack.add({"uid": str(index), "base": "rifle_ar"}))
	assert_eq(pack.items.size(), 6)
	assert_true(pack.is_full())
	var before: Array[Dictionary] = pack.items
	assert_false(pack.add({"uid": "seventh", "base": "rifle_ar"}))
	assert_eq(pack.items, before)


func test_removal_returns_item_and_frees_one_slot() -> void:
	for index: int in 6:
		pack.add({"uid": str(index)})
	assert_eq(pack.remove(2), {"uid": "2"})
	assert_eq(pack.items.size(), 5)
	assert_eq(pack.items[2], {"uid": "3"})
	assert_false(pack.is_full())
	assert_true(pack.add({"uid": "replacement"}))
	assert_true(pack.is_full())


func test_empty_items_and_invalid_removals_do_not_change_pack() -> void:
	assert_false(pack.add({}))
	assert_eq(pack.remove(0), {})
	pack.add({"uid": "one"})
	assert_eq(pack.remove(-1), {})
	assert_eq(pack.remove(1), {})
	assert_eq(pack.items, [{"uid": "one"}])


func test_adding_and_reading_copy_nested_roll_data() -> void:
	var item: Dictionary = {"uid": "one", "aff": [["dmg_pct", 1, 0.25]], "craft": {"rolls": 0}}
	assert_true(pack.add(item))
	item.aff[0][2] = 0.99
	item.craft.rolls = 5
	var snapshot: Array[Dictionary] = pack.items
	assert_eq(snapshot[0].aff[0][2], 0.25)
	assert_eq(snapshot[0].craft.rolls, 0)
	snapshot[0].aff[0][2] = 0.5
	snapshot.clear()
	assert_eq(pack.items.size(), 1)
	assert_eq(pack.items[0].aff[0][2], 0.25)


func test_changes_signal_only_after_successful_mutations() -> void:
	watch_signals(pack)
	pack.add({})
	pack.remove(0)
	assert_signal_not_emitted(pack, "changed")
	for index: int in 6:
		pack.add({"uid": str(index)})
	pack.add({"uid": "seventh"})
	pack.remove(-1)
	assert_signal_emit_count(pack, "changed", 6)
	pack.remove(0)
	assert_signal_emit_count(pack, "changed", 7)
