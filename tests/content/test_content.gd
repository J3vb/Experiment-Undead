## Validates every content file: loads, id matches file name, and
## everything it references exists. Bad data fails here, not in game.
extends GutTest


func _files(type: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open("res://content/" + type)
	assert_not_null(dir, "content/%s exists" % type)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.trim_suffix(".remap").get_extension() == "tres":
			out.append("res://content/%s/%s" % [type, f.trim_suffix(".remap")])
	return out


func test_content_autoload_indexes_every_type() -> void:
	for type: StringName in [&"weapons", &"enemies", &"waves", &"economy"]:
		assert_gt(Content.ids(type).size(), 0, "Content has %s" % type)


func test_weapons_are_valid() -> void:
	for path: String in _files("weapons"):
		var w: WeaponData = load(path) as WeaponData
		assert_not_null(w, path + " is WeaponData")
		if w == null:
			continue
		assert_eq(String(w.id), path.get_file().get_basename(), path + " id matches file name")
		assert_not_null(w.viewmodel_scene, path + " has viewmodel")
		assert_not_null(w.fire_sound, path + " has fire sound")
		assert_not_null(w.recoil, path + " has recoil")
		assert_gt(w.magazine_size, 0, path + " magazine")
		assert_gt(w.rounds_per_minute, 0.0, path + " rpm")
		assert_true(w.min_damage <= w.damage, path + " min_damage <= damage")
		if w.viewmodel_scene:
			var vm: Node = w.viewmodel_scene.instantiate()
			assert_not_null(vm.find_child("Muzzle", true, false), path + " viewmodel has Muzzle")
			vm.free()


func test_enemies_are_valid() -> void:
	for path: String in _files("enemies"):
		var e: EnemyData = load(path) as EnemyData
		assert_not_null(e, path + " is EnemyData")
		if e == null:
			continue
		assert_eq(String(e.id), path.get_file().get_basename(), path + " id matches file name")
		assert_not_null(e.scene, path + " has scene")
		assert_gt(e.max_health, 0.0, path + " health")
		if e.scene:
			var z: Node = e.scene.instantiate()
			assert_true(z is Zombie, path + " scene root is Zombie")
			z.free()


func test_wave_rules_are_valid() -> void:
	for path: String in _files("waves"):
		var r: WaveRules = load(path) as WaveRules
		assert_not_null(r, path + " is WaveRules")
		if r == null:
			continue
		assert_gt(r.enemy_mix.size(), 0, path + " has an enemy mix")
		for entry: EnemySpawnEntry in r.enemy_mix:
			assert_not_null(entry.enemy, path + " mix entry has an enemy")
		assert_not_null(r.pick_enemy(1, RandomNumberGenerator.new()), path + " can spawn something in round 1")
