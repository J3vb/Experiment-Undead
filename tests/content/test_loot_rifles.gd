## Loot rifles follow roster numbers, preserve existing firing rules and import with usable model parts.
extends GutTest

const IDS: Array[StringName] = [&"sentry_br3", &"nightjar_sd", &"rampart_br"]
const ROSTER: String = "res://docs/design/balance/roster.csv"
const MODEL: String = "res://assets/models/weapons/%s.glb"
const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")
const LENGTHS: Dictionary = {
	&"sentry_br3": Vector2(0.85, 1.15),
	&"nightjar_sd": Vector2(0.65, 0.95),
	&"rampart_br": Vector2(1.0, 1.25),
}


func _roster_row(id: StringName) -> Dictionary:
	var csv: FileAccess = FileAccess.open(ROSTER, FileAccess.READ)
	assert_not_null(csv, "gun roster opens")
	if csv == null:
		return {}
	var headings: PackedStringArray = []
	while not csv.eof_reached():
		var cells: PackedStringArray = csv.get_csv_line()
		if cells[0] == "id":
			headings = cells
		elif cells[0] == String(id):
			var row: Dictionary = {}
			for column: int in headings.size():
				row[headings[column]] = cells[column]
			return row
	fail_test(String(id) + " exists in roster.csv")
	return {}


func test_loot_rifles_match_roster_numbers() -> void:
	for id: StringName in IDS:
		var row: Dictionary = _roster_row(id)
		var gun: WeaponData = Content.weapon(id)
		assert_not_null(gun, String(id) + " is discoverable through Content")
		if gun == null or row.is_empty():
			continue
		_check_roster_numbers(gun, row)
		assert_eq(gun.display_name, row["Name"])
		assert_eq(gun.cost, int(row["Wall cost"]), String(id) + " retains its planned wall cost")
		assert_eq(gun.loot_tags, _tags(row["Loot tags"]), String(id) + " loot tags")
		assert_eq(gun.fire_mode, WeaponData.FireMode.BURST if id == &"sentry_br3" else WeaponData.FireMode.AUTO)


func _tags(cell: String) -> Array[StringName]:
	var tags: Array[StringName] = []
	for tag: String in cell.split(";"):
		tags.append(StringName(tag))
	return tags


func _check_roster_numbers(gun: WeaponData, row: Dictionary) -> void:
	var label: String = String(gun.id) + " "
	var head: float = float(row["Head mult override"]) if row["Head mult override"] != "" else 2.5
	assert_almost_eq(gun.damage, float(row["Damage / pellet"]) * 0.57, 0.001, label + "damage x0.57")
	assert_lt(gun.min_damage, gun.damage, label + "has range falloff")
	assert_gt(gun.min_damage, 0.0, label + "falloff damage stays positive")
	assert_eq(gun.pellets, int(row["Pellets"]), label + "pellets")
	assert_eq(gun.head_multiplier, head, label + "head multiplier")
	assert_eq(gun.rounds_per_minute, float(row["RPM"]), label + "rpm")
	assert_eq(gun.magazine_size, int(row["Mag"]), label + "magazine")
	assert_eq(gun.starting_reserve, int(row["Reserve"]), label + "starting reserve")
	assert_eq(gun.max_reserve, int(row["Reserve"]), label + "max reserve")
	assert_eq(gun.reload_time, float(row["Reload s"]), label + "reload")
	assert_eq(gun.ads_time, float(row["ADS s"]), label + "ADS")
	assert_eq(gun.move_speed_multiplier, float(row["Move mult"]), label + "movement")
	assert_almost_eq(gun.crate_weight, float(row["Drop weight"]) / 100.0, 0.001, label + "Vault weight")


func test_reforging_preserves_handling_and_doubles_damage_and_reserve() -> void:
	for id: StringName in IDS:
		var gun: WeaponData = Content.weapon(id)
		var up: WeaponData = gun.upgraded
		assert_not_null(up, String(id) + " has Tier I")
		if up == null:
			continue
		assert_eq(up.id, StringName(String(id) + "_reforged"))
		assert_almost_eq(up.damage, gun.damage * 2.0, 0.001)
		assert_almost_eq(up.min_damage, gun.min_damage * 2.0, 0.001)
		assert_eq(up.magazine_size, int(gun.magazine_size * 1.5))
		assert_eq(up.starting_reserve, gun.starting_reserve * 2)
		assert_eq(up.max_reserve, gun.max_reserve * 2)
		assert_eq(up.fire_mode, gun.fire_mode)
		assert_eq(up.burst_count, gun.burst_count)
		assert_eq(up.no_muzzle_flash, gun.no_muzzle_flash)
		assert_eq(up.head_multiplier, gun.head_multiplier)
		assert_eq(up.rounds_per_minute, gun.rounds_per_minute)
		assert_eq(up.ads_time, gun.ads_time)
		assert_eq(up.move_speed_multiplier, gun.move_speed_multiplier)
		assert_eq(up.loot_tags, gun.loot_tags)
		assert_eq(up.viewmodel_scene, gun.viewmodel_scene)
		assert_eq(up.fire_sound, gun.fire_sound)
		assert_null(up.upgraded, "Tier I has no unbuilt upgrade")


func _gun(id: StringName) -> Weapon:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var gun: Weapon = WEAPON.instantiate() as Weapon
	gun.setup(WeaponInstance.new(Content.weapon(id)), null, camera)
	gun._rng.seed = 77
	camera.add_child(gun)
	gun.set_active(true)
	return gun


func test_sentry_fires_exactly_three_rounds_per_press() -> void:
	var gun: Weapon = _gun(&"sentry_br3")
	assert_eq(gun.data.burst_count, 3)
	gun.trigger_held = true
	for tick: int in range(18):
		gun.tick(1.0 / 60.0)
	assert_eq(gun.instance.ammo_in_mag, 27, "one press fires three rounds")
	for tick: int in range(30):
		gun.tick(1.0 / 60.0)
	assert_eq(gun.instance.ammo_in_mag, 27, "holding does not start another burst")
	gun.trigger_held = false
	gun.tick(1.0 / 60.0)
	gun.trigger_held = true
	for tick: int in range(18):
		gun.tick(1.0 / 60.0)
	assert_eq(gun.instance.ammo_in_mag, 24, "a fresh press fires the next burst")


func test_set_flash_never_shows_nightjar_light_or_mesh() -> void:
	var gun: Weapon = autofree(Weapon.new()) as Weapon
	gun._rng = RandomNumberGenerator.new()
	gun._rng.seed = 77
	var pose: WeaponPose = WeaponPose.attach_to(gun)
	pose._flash_light = OmniLight3D.new()
	pose._flash_mesh = Node3D.new()
	gun.add_child(pose._flash_light)
	gun.add_child(pose._flash_mesh)
	for id: StringName in [&"nightjar_sd", &"nightjar_sd_reforged"]:
		gun.instance = WeaponInstance.new(Content.weapon(id))
		assert_true(gun.data.no_muzzle_flash, String(id) + " suppresses the flash")
		pose._flash_light.visible = true
		pose._flash_mesh.visible = true
		pose.set_flash(true)
		assert_false(pose._flash_light.visible, "even a visible light is hidden on a shot")
		assert_false(pose._flash_mesh.visible, "even a visible flash mesh is hidden on a shot")
		pose.set_flash(false)
		assert_false(pose._flash_light.visible)
		assert_false(pose._flash_mesh.visible)
	gun.instance = WeaponInstance.new(Content.weapon(&"sentry_br3"))
	assert_false(gun.data.no_muzzle_flash, "ordinary guns keep their flash")
	pose.set_flash(true)
	assert_true(pose._flash_light.visible)
	assert_true(pose._flash_mesh.visible)
	pose.set_flash(false)
	assert_false(pose._flash_light.visible)
	assert_false(pose._flash_mesh.visible)


func test_nightjar_shots_keep_the_flash_hidden_during_presentation() -> void:
	var gun: Weapon = _gun(&"nightjar_sd")
	var light: Node3D = gun.find_child("FlashLight", true, false) as Node3D
	var mesh: Node3D = gun.find_child("FlashMesh", true, false) as Node3D
	assert_not_null(light)
	assert_not_null(mesh)
	if light == null or mesh == null:
		return
	gun.fire()
	assert_false(light.visible, "fire presentation respects suppression")
	assert_false(mesh.visible)
	gun._process(0.01)
	assert_false(light.visible, "suppression also holds before the flash timer expires")
	assert_false(mesh.visible)
	gun._process(0.1)
	assert_false(light.visible)
	assert_false(mesh.visible)


func test_remote_shots_honor_no_muzzle_flash_without_losing_sound_or_tracers() -> void:
	var effects: RemoteShotEffects = RemoteShotEffects.new()
	add_child_autofree(effects)
	var points: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -10)])
	effects.play(Content.weapon(&"sentry_br3"), Vector3.ZERO, points)
	assert_true(effects._flash.visible, "ordinary remote shots flash")
	assert_true(effects._light.visible)
	for id: StringName in [&"nightjar_sd", &"nightjar_sd_reforged"]:
		var data: WeaponData = Content.weapon(id)
		effects.play(data, Vector3.ZERO, points)
		assert_false(effects._flash.visible, String(id) + " hides an already visible remote flash")
		assert_false(effects._light.visible)
		effects._process(0.01)
		assert_false(effects._flash.visible, "the remote flash timer cannot restore it")
		assert_false(effects._light.visible)
		assert_eq(effects._audio.stream, data.fire_sound, "suppressed remote shots keep their own sound")
		var tracers: MeshInstance3D = effects.get_node("Tracers") as MeshInstance3D
		assert_true(tracers.visible, "suppressed shots still draw their tracer")
		assert_eq(tracers.mesh.get_surface_count(), 1)
	effects.play(Content.weapon(&"sentry_br3"), Vector3.ZERO, points)
	assert_true(effects._flash.visible, "ordinary remote shots can flash again")
	assert_true(effects._light.visible)


func test_recoil_and_sounds_fit_the_classes() -> void:
	var sentry: WeaponData = Content.weapon(&"sentry_br3")
	var nightjar: WeaponData = Content.weapon(&"nightjar_sd")
	var rampart: WeaponData = Content.weapon(&"rampart_br")
	assert_lt(nightjar.recoil.pattern[0].y, Content.weapon(&"kestrel_smg").recoil.pattern[0].y)
	assert_lt(nightjar.recoil.pattern[0].y, sentry.recoil.pattern[0].y)
	assert_gt(rampart.recoil.pattern[0].y, sentry.recoil.pattern[0].y)
	assert_gt(rampart.ads_time, sentry.ads_time)
	assert_lt(rampart.move_speed_multiplier, sentry.move_speed_multiplier)
	var sounds: Array[AudioStream] = []
	for id: StringName in IDS:
		var sound: AudioStream = Content.weapon(id).fire_sound
		assert_not_null(sound, String(id) + " has a generated shot")
		assert_false(sounds.has(sound), String(id) + " has its own shot")
		sounds.append(sound)
	assert_lt(nightjar.fire_sound.get_length(), Content.weapon(&"kestrel_smg").fire_sound.get_length())
	assert_lt(nightjar.fire_sound.get_length(), sentry.fire_sound.get_length())


func test_nightjar_generated_shot_is_quieter() -> void:
	var quiet: Vector2 = _wav_levels("res://assets/audio/nightjar_fire.wav")
	var ordinary: Vector2 = _wav_levels("res://assets/audio/kestrel_fire.wav")
	assert_gt(quiet.x, 0.0, "suppressed shot remains audible")
	assert_lt(quiet.x, ordinary.x * 0.5, "suppressed peak is lower than an ordinary SMG")
	assert_lt(quiet.y, ordinary.y * 0.5, "suppressed RMS is lower than an ordinary SMG")


func _wav_levels(path: String) -> Vector2:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var offset: int = 12
	while offset + 8 <= bytes.size():
		var chunk: String = bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(offset + 4)
		if chunk == "fmt ":
			assert_eq(bytes.decode_u16(offset + 8), 1, path + " is PCM")
			assert_eq(bytes.decode_u16(offset + 10), 1, path + " is mono")
			assert_eq(bytes.decode_u16(offset + 22), 16, path + " is 16-bit")
		if chunk == "data":
			var peak: float = 0.0
			var sum_squares: float = 0.0
			for sample: int in range(offset + 8, offset + 8 + size, 2):
				var value: float = float(bytes.decode_s16(sample)) / 32768.0
				peak = maxf(peak, absf(value))
				sum_squares += value * value
			return Vector2(peak, sqrt(sum_squares / maxf(size / 2.0, 1.0)))
		offset += 8 + size + size % 2
	fail_test(path + " has a WAV data chunk")
	return Vector2.ZERO


func test_halcyon_vault_can_offer_each_new_gun() -> void:
	var map: Node = autofree((load("res://levels/halcyon_labs/map.tscn") as PackedScene).instantiate()) as Node
	var vault: SpecimenVault = map.find_child("SpecimenVault", true, false) as SpecimenVault
	assert_not_null(vault)
	if vault:
		for id: StringName in IDS:
			assert_has(vault.pool, Content.weapon(id), String(id) + " is in the Vault pool")


func _model(id: StringName) -> Node3D:
	var packed: PackedScene = load(MODEL % id) as PackedScene
	assert_not_null(packed, String(id) + " imports as a scene")
	return autofree(packed.instantiate()) as Node3D if packed else null


func _bounds(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func _triangles(gun: Node3D) -> int:
	var total: int = 0
	for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
		total += int((node as MeshInstance3D).mesh.get_faces().size() / 3.0)
	return total


func test_models_have_named_parts_at_gun_scale_and_face_forward() -> void:
	for id: StringName in IDS:
		var gun: Node3D = _model(id)
		if gun == null:
			continue
		for part: String in ["Receiver", "Magazine", "Bolt", "Barrel", "Muzzle", "Stock", "IronSights"]:
			assert_not_null(gun.find_child(part, true, false), "%s has %s" % [id, part])
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		assert_not_null(muzzle)
		if muzzle:
			assert_lt(muzzle.position.z, -0.3, String(id) + " faces Godot -Z")
		var bounds: Array[AABB] = [AABB()]
		_bounds(gun, Transform3D.IDENTITY, bounds)
		var length: Vector2 = LENGTHS[id]
		assert_between(bounds[0].size.z, length.x, length.y, String(id) + " length in metres")
		assert_lt(bounds[0].size.x, 0.12, String(id) + " remains narrow")
		assert_between(bounds[0].size.y, 0.15, 0.4, String(id) + " gun height")
		if id == &"nightjar_sd":
			assert_not_null(gun.find_child("Suppressor", true, false), "Nightjar has an integral suppressor")


func test_models_use_the_shared_finish_dynamic_light_baking_and_triangle_budget() -> void:
	var rifle: Node3D = _model(&"rifle_ar")
	var cap: int = mini(8000, int(_triangles(rifle) * 1.5))
	for id: StringName in IDS:
		var gun: Node3D = _model(id)
		if gun == null:
			continue
		assert_between(_triangles(gun), 4000, cap, String(id) + " detailed within the gun budget")
		var meshes: Array[Node] = gun.find_children("*", "MeshInstance3D", true, false)
		assert_lte(meshes.size(), 12, String(id) + " keeps separate draw calls bounded")
		for node: Node in meshes:
			var mesh: MeshInstance3D = node as MeshInstance3D
			assert_eq(mesh.gi_mode, GeometryInstance3D.GI_MODE_DYNAMIC, String(id) + " dynamic light baking")
			for surface: int in mesh.mesh.get_surface_count():
				var finish: ShaderMaterial = mesh.mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(finish, String(id) + " uses the procedural gun finish")
				if finish:
					assert_eq(finish.shader.resource_path, "res://assets/materials/gun_finish.gdshader")
