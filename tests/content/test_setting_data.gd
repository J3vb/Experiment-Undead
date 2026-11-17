## Every SettingData row can be drawn and edits a real Settings key; no two rows share a key.
extends GutTest

const PAGES: Array[StringName] = [&"controls", &"aim", &"graphics", &"audio", &"accessibility", &"comfort"]
const KINDS: Array[StringName] = [&"toggle", &"slider", &"choice"]


func test_every_row_is_complete() -> void:
	var seen: Dictionary[String, StringName] = {}
	var ids: Array = Content.ids(&"settings")
	assert_gt(ids.size(), 0)
	for id: StringName in ids:
		var row: SettingData = Content.get_item(&"settings", id) as SettingData
		assert_not_null(row, "%s is a SettingData" % id)
		if row == null:
			continue
		assert_has(PAGES, row.page, "%s page" % id)
		assert_has(KINDS, row.kind, "%s kind" % id)
		assert_false(row.label.is_empty(), "%s label" % id)
		assert_false(row.hint.is_empty(), "%s hint" % id)
		assert_true(Settings.DEFAULTS.get(row.section, {}).has(row.key), "%s key exists in Settings" % id)
		var full_key: String = "%s/%s" % [row.section, row.key]
		assert_false(seen.has(full_key), "%s and %s share %s" % [id, seen.get(full_key, &""), full_key])
		seen[full_key] = id
		if row.kind == &"slider":
			assert_lt(row.min_value, row.max_value, "%s min < max" % id)
			assert_gt(row.step, 0.0, "%s step" % id)
		if row.kind == &"choice":
			assert_gt(row.options.size(), 1, "%s has options" % id)
			if not row.option_values.is_empty():
				assert_eq(row.option_values.size(), row.options.size(), "%s one value per option" % id)
