## Checks content values and relationships before they are used in a match.
extends GutTest


func _paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return paths
	for subdir: String in dir.get_directories():
		paths.append_array(_paths(directory.path_join(subdir)))
	for file: String in dir.get_files():
		var clean: String = file.trim_suffix(".remap")
		if clean.get_extension() == "tres":
			paths.append(directory.path_join(clean))
	return paths


func test_weapon_ranges() -> void:
	for path: String in _paths("res://content/weapons"):
		var weapon: WeaponData = load(path) as WeaponData
		if weapon == null:
			continue
		assert_lt(weapon.falloff_start, weapon.falloff_end, path + ": falloff_start < falloff_end")
		assert_lte(weapon.falloff_end, weapon.max_range, path + ": falloff_end <= max_range")
		assert_gt(weapon.damage, 0.0, path + ": damage > 0")
		assert_gte(weapon.pellets, 1, path + ": pellets >= 1")
		assert_gt(weapon.reload_time, 0.0, path + ": reload_time > 0")
		assert_gte(weapon.empty_reload_time, weapon.reload_time, path + ": empty_reload_time >= reload_time")
		assert_lte(weapon.starting_reserve, weapon.max_reserve, path + ": starting_reserve <= max_reserve")
		assert_lte(weapon.ads_spread, weapon.hip_spread, path + ": ads_spread <= hip_spread")
		assert_lte(weapon.hip_spread, weapon.max_spread, path + ": hip_spread <= max_spread")
		assert_gte(weapon.ads_fov, 30.0, path + ": ads_fov >= 30")
		assert_lte(weapon.ads_fov, 90.0, path + ": ads_fov <= 90")
		if weapon.fire_mode == WeaponData.FireMode.BURST:
			assert_gte(weapon.burst_count, 2, path + ": burst_count >= 2 for burst fire")
		if weapon.recoil != null:
			assert_false(weapon.recoil.pattern.is_empty(), path + ": recoil.pattern must not be empty")
		if weapon.upgraded != null:
			assert_true(weapon.upgraded != weapon, path + ": upgraded must be a different weapon")


func test_enemy_ranges_and_unique_ids() -> void:
	var seen: Dictionary = {}
	for path: String in _paths("res://content/enemies"):
		var enemy: EnemyData = load(path) as EnemyData
		if enemy == null:
			continue
		assert_false(seen.has(enemy.id), path + ": id must be unique (also in %s)" % seen.get(enemy.id, ""))
		seen[enemy.id] = path
		assert_gt(enemy.move_speed, 0.0, path + ": move_speed > 0")
		assert_gt(enemy.acceleration, 0.0, path + ": acceleration > 0")
		assert_gt(enemy.turn_speed, 0.0, path + ": turn_speed > 0")
		assert_gt(enemy.attack_damage, 0.0, path + ": attack_damage > 0")
		assert_gt(enemy.attack_range, 0.0, path + ": attack_range > 0")


func test_wave_entries() -> void:
	var enemy_ids: Array = Content.ids(&"enemies")
	for path: String in _paths("res://content/waves"):
		var rules: WaveRules = load(path) as WaveRules
		if rules == null:
			continue
		for index: int in range(rules.enemy_mix.size()):
			var entry: EnemySpawnEntry = rules.enemy_mix[index]
			var field: String = "%s: enemy_mix[%d]" % [path, index]
			assert_not_null(entry, field + " must exist")
			if entry == null:
				continue
			assert_gt(entry.weight, 0.0, field + ".weight > 0")
			if entry.enemy != null:
				assert_has(enemy_ids, entry.enemy.id, field + ".enemy.id must exist in enemies")


func test_numeric_content_values() -> void:
	for path: String in _paths("res://content"):
		var resource: Resource = load(path)
		if resource == null:
			continue
		_check_numbers(resource, path, "")
		if resource is WeaponData:
			var weapon: WeaponData = resource as WeaponData
			if weapon.recoil != null:
				_check_numbers(weapon.recoil, path, "recoil.")
		if resource is WaveRules:
			var rules: WaveRules = resource as WaveRules
			for index: int in range(rules.enemy_mix.size()):
				if rules.enemy_mix[index] != null:
					_check_numbers(rules.enemy_mix[index], path, "enemy_mix[%d]." % index)


func _check_numbers(resource: Resource, path: String, prefix: String) -> void:
	for property: Dictionary in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (int(property.usage) & PROPERTY_USAGE_EDITOR) == 0:
			continue
		if property.type != TYPE_FLOAT and property.type != TYPE_INT:
			continue
		var field: String = prefix + str(property.name)
		var value: float = float(resource.get(property.name))
		assert_true(is_finite(value), "%s: %s must be finite" % [path, field])
		if not (resource is EnemySpawnEntry and property.name == "weight_per_round"):
			assert_gte(value, 0.0, "%s: %s must be nonnegative" % [path, field])
