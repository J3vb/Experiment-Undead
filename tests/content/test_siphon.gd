## Locks Siphon's fixed Prototype content to its roster row and the shared model pipeline.
extends GutTest

const ROSTER: String = "res://docs/design/balance/roster.csv"
const MODEL: String = "res://assets/models/weapons/siphon.glb"
const DAMAGE_SCALE: float = 0.57


func _roster_row() -> Dictionary:
	var file: FileAccess = FileAccess.open(ROSTER, FileAccess.READ)
	var header: PackedStringArray = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row.is_empty() and row[0] == "id":
			header = row
		elif not header.is_empty() and row.size() == header.size() and row[0] == "siphon":
			var values: Dictionary = {}
			for index: int in range(header.size()):
				values[header[index]] = row[index]
			return values
	return {}


func test_siphon_uses_the_roster_numbers() -> void:
	var row: Dictionary = _roster_row()
	assert_false(row.is_empty(), "Siphon has a roster row")
	var gun: WeaponData = Content.weapon(&"siphon")
	assert_not_null(gun, "Content discovers Siphon by filename")
	if gun == null or row.is_empty():
		return
	assert_eq(gun.display_name, row["Name"])
	assert_almost_eq(gun.damage, float(row["Damage / pellet"]) * DAMAGE_SCALE, 0.001)
	assert_eq(gun.min_damage, gun.damage, "a well deals its total independently of orb travel")
	assert_eq(gun.pellets, int(row["Pellets"]))
	assert_eq(gun.rounds_per_minute, float(row["RPM"]))
	assert_eq(gun.magazine_size, int(row["Mag"]))
	assert_eq(gun.starting_reserve, int(row["Reserve"]))
	assert_eq(gun.max_reserve, int(row["Reserve"]))
	assert_eq(gun.reload_time, float(row["Reload s"]))
	assert_eq(gun.empty_reload_time, gun.reload_time)
	assert_eq(gun.ads_time, float(row["ADS s"]))
	assert_eq(gun.move_speed_multiplier, float(row["Move mult"]))
	assert_eq(gun.fire_mode, WeaponData.FireMode.SEMI)
	assert_eq(gun.max_range, 25.0)
	assert_eq(gun.head_multiplier, 1.0, "gravity damage has no headshot bonus")
	assert_eq(gun.limb_multiplier, 1.0)


func test_siphon_is_a_fixed_prototype_with_a_low_vault_weight() -> void:
	var row: Dictionary = _roster_row()
	var gun: WeaponData = Content.weapon(&"siphon")
	assert_eq(row["Vault rarity floor"], "Prototype")
	assert_eq(row["Drop weight"], "0", "Siphon stays out of random drops")
	assert_eq(row["Legendary"], "fixed signature")
	assert_eq(row["New mechanic"], "gravity well projectile")
	var tags: Array[StringName] = [&"prototype"]
	assert_eq(gun.loot_tags, tags)
	assert_null(gun.upgraded, "fixed signature does not roll a Reforged variant")
	assert_eq(gun.cost, 0, "Siphon has no wall buy")
	assert_eq(gun.crate_weight, 0.05)
	var packed: PackedScene = load("res://levels/halcyon_labs/map.tscn") as PackedScene
	var map: Node = packed.instantiate()
	var vault: SpecimenVault = map.find_child("SpecimenVault", true, false) as SpecimenVault
	assert_has(vault.pool, gun)
	for other: WeaponData in vault.pool:
		if not other.loot_tags.has(&"prototype"):
			assert_lt(gun.crate_weight, other.crate_weight, "Prototypes are rare Vault offers")
	map.free()


func test_viewmodel_has_animated_parts_and_an_energy_flash() -> void:
	var gun: WeaponData = Content.weapon(&"siphon")
	var vm: Node = gun.viewmodel_scene.instantiate()
	for part: String in ["Magazine", "Bolt", "Muzzle", "FlashLight", "FlashMesh", "HandLeft", "HandRight"]:
		assert_not_null(vm.find_child(part, true, false), part + " is present")
	var light: OmniLight3D = vm.find_child("FlashLight", true, false) as OmniLight3D
	assert_almost_eq(light.light_color.g, 1.0, 0.001, "bio-green experiment pulse")
	assert_false(light.shadow_enabled, "the pulse adds no shadowed light")
	assert_eq(light.light_bake_mode, Light3D.BAKE_DISABLED)
	assert_not_null(gun.recoil)
	assert_false(gun.recoil.pattern.is_empty())
	assert_not_null(gun.fire_sound)
	assert_eq(gun.fire_sound.resource_path, "res://assets/audio/siphon_fire.wav")
	assert_between(gun.fire_sound.get_length(), 0.7, 0.9, "short designed energy pulse")
	vm.free()


func _bounds(node: Node, parent_transform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = parent_transform * (node as Node3D).transform if node is Node3D else parent_transform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func test_model_is_forward_facing_and_within_budget() -> void:
	var packed: PackedScene = load(MODEL) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var gun: Node3D = packed.instantiate() as Node3D
	for part: String in ["Receiver", "Magazine", "Bolt", "Emitter", "Core", "Muzzle"]:
		assert_not_null(gun.find_child(part, true, false), part + " is present")
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	assert_lt(muzzle.position.z, -0.3, "orb leaves the front of the gun (-Z)")
	var bounds: Array[AABB] = [AABB()]
	_bounds(gun, Transform3D.IDENTITY, bounds)
	assert_between(bounds[0].size.z, 0.8, 1.0, "compact experimental primary")
	assert_between(bounds[0].size.x, 0.1, 0.2, "wide enough for the containment coil")
	var meshes: Array[Node] = gun.find_children("*", "MeshInstance3D", true, false)
	assert_lte(meshes.size(), 12, "few model draw calls")
	var triangles: int = 0
	for node: Node in meshes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		triangles += int(mesh.mesh.get_faces().size() / 3.0)
		assert_eq(mesh.gi_mode, GeometryInstance3D.GI_MODE_DYNAMIC, "moving model uses dynamic lighting")
	assert_lte(triangles, 8000, "weapon geometry budget")
	gun.free()
