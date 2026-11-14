## Rejects invalid content numbers and contradictory gameplay rules before play.
extends GutTest


func _files(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return paths
	for subdirectory: String in dir.get_directories():
		paths.append_array(_files(directory.path_join(subdirectory)))
	for file: String in dir.get_files():
		var clean: String = file.trim_suffix(".remap")
		if clean.get_extension() == "tres":
			paths.append(directory.path_join(clean))
	return paths


func test_weapon_rules() -> void:
	for path: String in _files("res://content/weapons"):
		var weapon: WeaponData = load(path) as WeaponData
		if weapon == null:
			continue
		assert_lt(weapon.falloff_start, weapon.falloff_end, path + " falloff_start < falloff_end")
		assert_lte(weapon.falloff_end, weapon.max_range, path + " falloff_end <= max_range")
		assert_gt(weapon.damage, 0.0, path + " damage > 0")
		assert_gte(weapon.pellets, 1, path + " pellets >= 1")
		assert_gt(weapon.reload_time, 0.0, path + " reload_time > 0")
		assert_gte(weapon.empty_reload_time, weapon.reload_time, path + " empty_reload_time >= reload_time")
		assert_lte(weapon.starting_reserve, weapon.max_reserve, path + " starting_reserve <= max_reserve")
		assert_lte(weapon.ads_spread, weapon.hip_spread, path + " ads_spread <= hip_spread")
		assert_lte(weapon.hip_spread, weapon.max_spread, path + " hip_spread <= max_spread")
		assert_between(weapon.ads_fov, 30.0, 90.0, path + " ads_fov between 30 and 90")
		assert_has(WeaponData.FireMode.values(), weapon.fire_mode, path + " fire_mode is a defined mode")
		if weapon.fire_mode == WeaponData.FireMode.BURST:
			assert_gte(weapon.burst_count, 2, path + " burst_count >= 2 for BURST")
		if weapon.upgraded != null:
			assert_ne(weapon.upgraded, weapon, path + " upgraded is a different WeaponData")


func test_recoil_rules() -> void:
	for path: String in _files("res://content/weapons"):
		var weapon: WeaponData = load(path) as WeaponData
		if weapon == null or weapon.recoil == null:
			continue
		var recoil: RecoilData = weapon.recoil
		assert_false(recoil.pattern.is_empty(), path + " recoil.pattern must not be empty")
		assert_gte(recoil.random_spread.x, 0.0, path + " recoil.random_spread.x >= 0")
		assert_gte(recoil.random_spread.y, 0.0, path + " recoil.random_spread.y >= 0")
		assert_between(recoil.permanent_ratio, 0.0, 1.0, path + " recoil.permanent_ratio between 0 and 1")
		assert_gte(recoil.repeat_last, 1, path + " recoil.repeat_last >= 1")


func test_enemy_rules() -> void:
	var seen: Dictionary[StringName, String] = {}
	for path: String in _files("res://content/enemies"):
		var enemy: EnemyData = load(path) as EnemyData
		if enemy == null:
			continue
		assert_false(
			seen.has(enemy.id), "%s id '%s' must be unique (also %s)" % [path, enemy.id, seen.get(enemy.id, "")]
		)
		seen[enemy.id] = path
		for field: StringName in [
			&"move_speed",
			&"acceleration",
			&"turn_speed",
			&"attack_damage",
			&"attack_range",
			&"attack_cooldown",
			&"body_scale"
		]:
			assert_gt(float(enemy.get(field)), 0.0, "%s %s > 0" % [path, field])


func test_wave_rules() -> void:
	var enemy_ids: Array = Content.ids(&"enemies")
	for path: String in _files("res://content/waves"):
		var rules: WaveRules = load(path) as WaveRules
		if rules == null:
			continue
		assert_gt(rules.base_count, 0, path + " base_count > 0")
		assert_gt(rules.max_alive, 0, path + " max_alive > 0")
		assert_gt(rules.spawn_interval_min, 0.0, path + " spawn_interval_min > 0")
		assert_gte(
			rules.spawn_interval_start, rules.spawn_interval_min, path + " spawn_interval_start >= spawn_interval_min"
		)
		assert_gte(rules.max_speed_multiplier, 1.0, path + " max_speed_multiplier >= 1")
		for index: int in range(rules.enemy_mix.size()):
			var entry: EnemySpawnEntry = rules.enemy_mix[index]
			var field: String = "%s enemy_mix[%d]" % [path, index]
			if entry == null:
				assert_not_null(entry, field + " must be a spawn entry")
				continue
			if entry.enemy != null:
				assert_has(enemy_ids, entry.enemy.id, field + ".enemy.id exists in Content.ids(enemies)")
			assert_gt(entry.weight, 0.0, field + ".weight > 0")
			assert_gte(entry.first_round, 1, field + ".first_round >= 1")
			if entry.last_round != 0:
				assert_gte(
					entry.last_round, entry.first_round, field + ".last_round >= first_round (or 0 for no limit)"
				)


func test_exported_numbers_are_finite_and_nonnegative() -> void:
	for path: String in _files("res://content"):
		_check_numbers(load(path), path, [])


func _check_numbers(value: Variant, field: String, visited: Array[Resource]) -> void:
	if value is float:
		assert_true(is_finite(value), field + " must be finite")
		assert_gte(value, 0.0, field + " must be >= 0")
	elif value is int:
		assert_gte(value, 0, field + " must be >= 0")
	elif value is Vector2 or value is Vector3:
		# Positions and recoil kicks can be signed, but never NaN or infinite.
		assert_true(value.is_finite(), field + " components must be finite")
	elif value is Array:
		for index: int in range(value.size()):
			_check_numbers(value[index], "%s[%d]" % [field, index], visited)
	elif value is Dictionary:
		for key: Variant in value:
			_check_numbers(value[key], "%s[%s]" % [field, key], visited)
	elif value is Resource:
		_check_resource_numbers(value, field, visited)


func _check_resource_numbers(resource: Resource, field: String, visited: Array[Resource]) -> void:
	# Inspect data exports, not engine properties of scenes, sounds or scripts.
	if resource.get_script() == null or resource in visited:
		return
	visited.append(resource)
	for property: Dictionary in resource.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_EDITOR == 0 or usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = property["name"]
		_check_numbers(resource.get(name), field + "." + name, visited)
