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
	for type: StringName in [
		&"weapons", &"enemies", &"waves", &"economy", &"serums", &"power_ups", &"loot", &"gear_visuals", &"vendors"
	]:
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


func test_weapons_have_a_world_model_for_teammates() -> void:
	for path: String in _files("weapons"):
		var w: WeaponData = load(path) as WeaponData
		assert_not_null(w.world_model, path + " has a world_model")
		if w.world_model == null:
			continue
		var gun: Node = w.world_model.instantiate()
		assert_not_null(gun.find_child("Muzzle", true, false), path + " world_model has Muzzle")
		gun.free()
		if w.upgraded:
			assert_eq(w.upgraded.world_model, w.world_model, path + " Reforged copy keeps the same gun model")


func test_reforged_guns_follow_tier_one() -> void:
	for path: String in _files("weapons"):
		var w: WeaponData = load(path) as WeaponData
		if w == null or w.upgraded == null:
			continue
		var up: WeaponData = w.upgraded
		assert_ne(up.id, w.id, path + " upgrades into another gun")
		assert_almost_eq(up.damage, w.damage * 2.0, 0.01, path + " Tier I: damage x2")
		var capacity: int = 2 if w.loot_tags.has(&"double") else int(w.magazine_size * 1.5)
		assert_eq(up.magazine_size, capacity, path + " Tier I: magazine +50%, fixed two-barrel exception")
		assert_eq(up.max_reserve, w.max_reserve * 2, path + " Tier I: reserve x2")


func test_enemies_are_valid() -> void:
	for path: String in _files("enemies"):
		var e: EnemyData = load(path) as EnemyData
		assert_not_null(e, path + " is EnemyData")
		if e == null:
			continue
		assert_eq(String(e.id), path.get_file().get_basename(), path + " id matches file name")
		assert_not_null(e.scene, path + " has scene")
		assert_gt(e.max_health, 0.0, path + " health")
		assert_gt(e.death_sounds.size(), 0, path + " has death sounds")
		assert_gt(e.footstep_sounds.size(), 0, path + " has footstep sounds")
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


func test_serums_are_valid() -> void:
	for path: String in _files("serums"):
		var serum: SerumData = load(path) as SerumData
		assert_not_null(serum, path + " is SerumData")
		if serum == null:
			continue
		assert_eq(String(serum.id), path.get_file().get_basename(), path + " id matches file name")
		assert_gt(serum.cost, 0, path + " cost")
		if not SerumData.EFFECTS.has(serum.id):
			assert_gt(serum.multipliers.size(), 0, path + " changes at least one stat")
		for stat: StringName in serum.multipliers:
			assert_has(SerumData.STATS, stat, "%s: '%s' is a stat code reads" % [path, stat])
			assert_gt(serum.multipliers[stat], 0.0, path + " multiplier above 0")


func test_power_ups_are_valid() -> void:
	var colors: Array[Color] = []
	for path: String in _files("power_ups"):
		var power_up: PowerUpData = load(path) as PowerUpData
		assert_not_null(power_up, path + " is PowerUpData")
		if power_up:
			assert_does_not_have(colors, power_up.color, path + " has its own colour")
			colors.append(power_up.color)
			assert_eq(String(power_up.id), path.get_file().get_basename(), path + " id matches file name")
			assert_true(PowerUpData.Effect.values().has(power_up.effect), path + " has a known effect")
			assert_false(power_up.display_name.is_empty(), path + " has a name for the HUD flash")
			assert_gte(power_up.duration, 0.0, path + " duration is 0 (instant) or more")
			if power_up.effect in [PowerUpData.Effect.PAYDAY, PowerUpData.Effect.OVERKILL, PowerUpData.Effect.STASIS]:
				assert_gt(power_up.duration, 0.0, path + " is timed, so it needs a duration")
	var ammo: PowerUpData = load("res://content/power_ups/ammo_pack.tres") as PowerUpData
	assert_eq(ammo.effect, PowerUpData.Effect.AMMO_PACK, "the Scavenger pack adds a magazine, not a full refill")


func test_enemy_loot_fields_are_valid() -> void:
	for path: String in _files("enemies"):
		var enemy: EnemyData = load(path) as EnemyData
		var chance: float = enemy.loot_drop_chance
		assert_true(chance == -1.0 or (chance >= 0.0 and chance <= 1.0), path + " loot chance is -1 or 0..1")
		assert_has(ItemRoller.RARITIES, enemy.loot_min_rarity, path + " loot floor is a rarity")
	assert_eq((load("res://content/enemies/zombie_bloater.tres") as EnemyData).loot_drop_chance, 0.05)


func test_serum_badges_are_short_and_unique() -> void:
	var badges: Array[String] = []
	for path: String in _files("serums"):
		var serum: SerumData = load(path) as SerumData
		assert_between(serum.badge.length(), 1, 2, path + " badge is 1 or 2 letters")
		assert_false(badges.has(serum.badge), path + " badge is unique")
		badges.append(serum.badge)
	assert_eq(badges.size(), 8)
