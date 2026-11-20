## Stall keeper data (content/vendors, F-76): every keeper has a name, title, a model that loads with its idle
## clip and the greet, four short lines, and a stall of their own.
extends GutTest

const STALLS: Array[StringName] = [&"MISSIONS", &"TRADER", &"GUNSMITH", &"TECHNICIAN"]
const LINES: int = 4
const LINE_MAX: int = 90


func test_content_indexes_the_four_keepers() -> void:
	assert_eq(Content.sorted_ids(&"vendors"), [&"cordon_liaison", &"gunsmith", &"quartermaster", &"technician"])


func test_every_keeper_is_complete() -> void:
	for id: StringName in Content.sorted_ids(&"vendors"):
		var data: VendorData = Content.get_item(&"vendors", id) as VendorData
		assert_not_null(data, String(id) + " is VendorData")
		if data == null:
			continue
		assert_false(data.display_name.is_empty(), String(id) + " name")
		assert_false(data.title.is_empty(), String(id) + " title")
		assert_eq(data.lines.size(), LINES, String(id) + " has four lines")
		for text: String in data.lines:
			assert_between(text.length(), 1, LINE_MAX, String(id) + " line fits over the head: " + text)
		assert_not_null(data.model, String(id) + " model")
		if data.model == null:
			continue
		var model: Node = data.model.instantiate()
		var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, String(id) + " model has clips")
		if players.size() == 1:
			var anim: AnimationPlayer = players[0] as AnimationPlayer
			assert_true(anim.has_animation(data.idle_clip), String(id) + " has its idle " + String(data.idle_clip))
			assert_true(anim.has_animation(Vendor.GREET), String(id) + " has the greet")
		model.free()


func test_each_stall_has_one_keeper() -> void:
	var taken: Array[StringName] = []
	for id: StringName in Content.sorted_ids(&"vendors"):
		var data: VendorData = Content.get_item(&"vendors", id) as VendorData
		assert_has(STALLS, data.stall, String(id) + " stands at a market stall")
		assert_does_not_have(taken, data.stall, String(id) + " has the stall to themselves")
		taken.append(data.stall)
	assert_eq(taken.size(), STALLS.size())
