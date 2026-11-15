## Code-built gun parts share recoil and reload poses; scope lenses render only
## while aiming and shotgun shots fire every pellet.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"
const SHOTGUN: String = "res://content/weapons/brenner_trench.tres"
const KESTREL: String = "res://content/weapons/kestrel_smg.tres"
const TALON: String = "res://content/weapons/talon_dmr.tres"
const BASTION: String = "res://content/weapons/bastion_lmg.tres"
const WEAPON: String = "res://systems/weapons/weapon.tscn"


func _gun(path: String = RIFLE) -> Weapon:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var weapon: Weapon = (load(WEAPON) as PackedScene).instantiate() as Weapon
	weapon.setup(WeaponInstance.new(load(path) as WeaponData), null, camera)
	camera.add_child(weapon)
	weapon.set_active(true)
	return weapon


func _part(weapon: Weapon, part: String) -> Node3D:
	return weapon.find_child(part, true, false) as Node3D


func test_flash_is_on_the_model_muzzle() -> void:
	var weapon: Weapon = _gun()
	var flash: Node3D = _part(weapon, "FlashLight")
	assert_not_null(flash, "rifle has a muzzle flash light")
	if flash:
		assert_eq(flash.get_parent().name, &"Muzzle", "flash sits on the model's Muzzle")
	weapon.fire()
	assert_true(flash.visible, "flash shows on a shot")


func test_bolt_kicks_back_on_fire() -> void:
	for path: String in [RIFLE, KESTREL, TALON, BASTION]:
		_check_bolt_kick(path)


func _check_bolt_kick(path: String) -> void:
	var weapon: Weapon = _gun(path)
	var bolt: Node3D = _part(weapon, "Bolt")
	var receiver: Node3D = _part(weapon, "Receiver")
	var receiver_rest: Transform3D = receiver.transform
	var mag_rest: Vector3 = _part(weapon, "Magazine").position
	var handle: Node3D = _part(weapon, "ChargingHandle")
	var handle_rest: Vector3 = receiver.to_local(handle.global_position) if handle else Vector3.ZERO
	var rest: float = bolt.position.z
	weapon.fire()
	weapon._process(0.001)
	assert_gt(bolt.position.z, rest + 0.02, "bolt moves back (+Z) after a shot")
	if handle:
		var travel: Vector3 = receiver.to_local(handle.global_position) - handle_rest
		assert_almost_eq(travel.z, bolt.position.z - rest, 0.001, path + " charging handle rides with the bolt")
	for i: int in 30:
		weapon._process(0.05)
	assert_almost_eq(bolt.position.z, rest, 0.002, "bolt returns")
	assert_eq(receiver.transform, receiver_rest, path + " receiver does not move with the bolt")
	assert_eq(_part(weapon, "Magazine").position, mag_rest, path + " magazine stays seated on fire")
	if handle:
		var reset: Vector3 = receiver.to_local(handle.global_position)
		assert_almost_eq(reset.distance_to(handle_rest), 0.0, 0.002, path + " charging handle returns")


func test_magazine_drops_and_returns_on_reload() -> void:
	for path: String in [RIFLE, KESTREL, TALON, BASTION]:
		_check_magazine_reload(path)


func _check_magazine_reload(path: String) -> void:
	var weapon: Weapon = _gun(path)
	var mag: Node3D = _part(weapon, "Magazine")
	var rest: Vector3 = mag.position
	var receiver: Node3D = _part(weapon, "Receiver")
	var receiver_rest: Transform3D = receiver.transform
	weapon.instance.ammo_in_mag = 5
	assert_true(weapon.start_reload())
	var half: float = weapon.data.reload_time * 0.5
	weapon.tick(half)
	weapon._process(0.001)
	assert_lt(mag.position.y, rest.y - 0.15, "magazine is out mid-reload")
	weapon.tick(half + 0.01)
	weapon._process(0.001)
	assert_false(weapon.is_reloading())
	assert_almost_eq(mag.position.distance_to(rest), 0.0, 0.001, "magazine back in after reload")
	assert_eq(receiver.transform, receiver_rest, path + " receiver stays independent of the magazine")


func test_empty_reload_holds_the_bolt_open_then_resets() -> void:
	for path: String in [RIFLE, KESTREL, TALON, BASTION]:
		var weapon: Weapon = _gun(path)
		var bolt: Node3D = _part(weapon, "Bolt")
		var rest: Vector3 = bolt.position
		weapon.instance.ammo_in_mag = 0
		assert_true(weapon.start_reload(), path)
		weapon.tick(weapon.data.empty_reload_time * 0.5)
		weapon._process(0.001)
		assert_almost_eq(bolt.position.z, rest.z + 0.035, 0.001, path + " bolt held open")
		weapon.tick(weapon.data.empty_reload_time)
		weapon._process(0.001)
		assert_almost_eq(bolt.position.distance_to(rest), 0.0, 0.001, path + " bolt closes after reload")
		assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size, path + " refilled")


func test_scope_renders_zoomed_view_only_while_aiming() -> void:
	var weapon: Weapon = _gun()
	var lens: ScopeLens = _part(weapon, "ScopeLens") as ScopeLens
	assert_not_null(lens, "rifle has a scope lens")
	if lens == null:
		return
	lens._process(0.016)
	assert_false(lens.is_rendering(), "no extra render at the hip")
	var material: ShaderMaterial = lens.material_override as ShaderMaterial
	assert_false(material.get_shader_parameter(&"live"), "lens shows plain glass at the hip")
	weapon.ads_progress = 1.0
	lens._process(0.016)
	assert_true(lens.is_rendering(), "scope renders while aiming")
	assert_true(material.get_shader_parameter(&"live"), "lens shows the scope view while aiming")
	var main: Camera3D = get_viewport().get_camera_3d()
	assert_almost_eq(lens.camera.fov, main.fov / lens.zoom, 0.01, "scope view is zoomed")
	assert_eq(lens.camera.cull_mask & ScopeLens.VIEWMODEL_LAYER, 0, "scope camera does not see the gun")
	for mesh: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		assert_eq((mesh as MeshInstance3D).layers, ScopeLens.VIEWMODEL_LAYER, mesh.name + " is on the viewmodel layer")


func test_each_rifle_has_its_own_scope_picture() -> void:
	var first: ScopeLens = _part(_gun(), "ScopeLens") as ScopeLens
	var second: ScopeLens = _part(_gun(), "ScopeLens") as ScopeLens
	assert_ne(first.material_override, second.material_override, "lens materials are not shared")
	var view: Texture2D = (first.material_override as ShaderMaterial).get_shader_parameter(&"view")
	assert_eq(view, first.viewport.get_texture(), "first rifle still shows its own scope camera")


func test_shotgun_pump_racks_with_the_left_hand_on_it() -> void:
	var weapon: Weapon = _gun(SHOTGUN)
	var pump: Node3D = _part(weapon, "Bolt")
	assert_not_null(pump, "shotgun has a pump")
	if pump == null:
		return
	assert_eq(_part(weapon, "HandLeft").get_parent(), pump, "left hand rides on the pump")
	var rest: float = pump.position.z
	weapon.fire()
	weapon._process(0.001)
	assert_gt(pump.position.z, rest + 0.02, "pump racks back after a shot")


func test_shotgun_fires_every_pellet() -> void:
	var weapon: Weapon = _gun(SHOTGUN)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20, 20, 0.5)
	wall.add_child(shape)
	wall.position = Vector3(0, 0, -3)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	var hits: Array[Vector3] = []
	weapon.traced.connect(func(point: Vector3, _normal: Vector3, _zone: bool) -> void: hits.append(point))
	weapon.fire()
	assert_eq(hits.size(), weapon.data.pellets, "one trace per pellet")
	assert_eq(weapon.data.pellets, 8, "Brenner Trench fires 8 pellets")
	assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, "one shell per shot")


func test_scope_camera_follows_main_camera_each_frame_without_interpolation() -> void:
	var weapon: Weapon = _gun()
	var lens: ScopeLens = _part(weapon, "ScopeLens") as ScopeLens
	var mode: Node.PhysicsInterpolationMode = lens.camera.physics_interpolation_mode
	assert_eq(mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "scope camera is moved in _process")
	assert_false(lens.camera.is_physics_interpolated(), "no 'interpolated camera moved outside physics' warning")
	var main: Camera3D = get_viewport().get_camera_3d()
	main.global_position = Vector3(3.0, 1.5, -2.0)
	main.rotate_y(0.7)
	weapon.ads_progress = 1.0
	lens._process(0.016)
	var offset: float = lens.camera.global_position.distance_to(main.global_position)
	assert_almost_eq(offset, 0.0, 0.001, "scope sits on the main camera")
	assert_true(lens.camera.global_basis.is_equal_approx(main.global_basis), "scope looks where the main camera looks")


func test_talon_scope_has_three_times_zoom() -> void:
	var weapon: Weapon = _gun(TALON)
	var lens: ScopeLens = _part(weapon, "ScopeLens") as ScopeLens
	assert_eq(lens.zoom, 3.0)
	lens._process(0.016)
	assert_false(lens.is_rendering(), "Talon scope stays off at the hip")
	assert_eq(lens.get_parent(), _part(weapon, "ScopeLensMount"), "lens follows the model's eyepiece")
	assert_almost_eq(lens.position.length(), 0.0, 0.0001, "lens is centred on the eyepiece")
	weapon.ads_progress = 1.0
	lens._process(0.016)
	assert_true(lens.is_rendering())
	assert_almost_eq(lens.camera.fov, get_viewport().get_camera_3d().fov / 3.0, 0.01)
	assert_eq(_part(weapon, "FlashLight").get_parent(), _part(weapon, "Muzzle"))
	weapon.ads_progress = 0.0
	lens._process(0.016)
	assert_false(lens.is_rendering(), "Talon scope stops rendering after aiming")


func _viewmodel(name: String) -> Node3D:
	var packed: PackedScene = load("res://systems/weapons/viewmodels/%s_viewmodel.tscn" % name) as PackedScene
	return autofree(packed.instantiate()) as Node3D


func test_flash_meshes_share_their_material_without_changing_each_weapon_size() -> void:
	var quad: QuadMesh = load("res://systems/weapons/viewmodels/flash_quad.tres") as QuadMesh
	var shotgun_quad: QuadMesh = load("res://systems/weapons/viewmodels/shotgun_flash_quad.tres") as QuadMesh
	assert_eq(quad.size, Vector2(0.22, 0.22))
	assert_eq(shotgun_quad.size, Vector2(0.34, 0.34))
	assert_eq(shotgun_quad.material, quad.material, "shotgun shares the same flash material")
	var material: StandardMaterial3D = quad.material as StandardMaterial3D
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(material.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)
	assert_eq(material.albedo_color, Color(1, 0.75, 0.35, 1))
	var texture: GradientTexture2D = material.albedo_texture as GradientTexture2D
	assert_eq(texture.fill, GradientTexture2D.FILL_RADIAL)
	assert_eq(texture.fill_from, Vector2(0.5, 0.5))
	assert_eq(texture.fill_to, Vector2(0.5, 0))
	assert_eq(texture.gradient.colors, PackedColorArray([Color(1, 1, 0.8, 1), Color(1, 0.5, 0.1, 0)]))
	for name: String in ["kestrel", "rifle", "shotgun", "talon", "pistol"]:
		var scene: Node3D = _viewmodel(name)
		var flash: Node3D = scene.find_child("FlashMesh", true, false) as Node3D
		assert_eq(flash.get_child_count(), 3, name)
		for node: Node in flash.get_children():
			var mesh: MeshInstance3D = node as MeshInstance3D
			assert_eq(mesh.mesh, shotgun_quad if name == "shotgun" else quad, name + " shares its flash geometry")


func test_long_guns_share_arm_geometry_and_materials() -> void:
	var first: Node3D = _viewmodel("rifle")
	var sizes: Dictionary = {
		"HandRight": Vector3(0.075, 0.09, 0.1),
		"SleeveRight": Vector3(0.09, 0.09, 0.3),
		"HandLeft": Vector3(0.09, 0.06, 0.11),
		"SleeveLeft": Vector3(0.09, 0.09, 0.32),
	}
	for name: String in ["kestrel", "rifle", "shotgun", "talon"]:
		var scene: Node3D = _viewmodel(name)
		for part: String in sizes:
			var mesh: MeshInstance3D = scene.find_child(part, true, false) as MeshInstance3D
			var original: MeshInstance3D = first.find_child(part, true, false) as MeshInstance3D
			assert_eq(mesh.mesh, original.mesh, name + " shares " + part)
			assert_eq((mesh.mesh as BoxMesh).size, sizes[part], name + " retains " + part + " dimensions")
			assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var hand: MeshInstance3D = scene.find_child("HandRight", true, false) as MeshInstance3D
		var sleeve: MeshInstance3D = scene.find_child("SleeveRight", true, false) as MeshInstance3D
		assert_eq((hand.mesh.material as StandardMaterial3D).albedo_color, Color(0.09, 0.1, 0.08, 1))
		assert_almost_eq((hand.mesh.material as StandardMaterial3D).roughness, 0.95, 0.00001)
		assert_eq((sleeve.mesh.material as StandardMaterial3D).albedo_color, Color(0.2, 0.22, 0.16, 1))
		assert_eq((sleeve.mesh.material as StandardMaterial3D).roughness, 1.0)


func test_shared_arm_scenes_preserve_weapon_specific_poses_and_pump_parenting() -> void:
	var positions: Dictionary = {
		"kestrel":
		[
			Vector3(0.015, -0.11, 0.135),
			Vector3(0.04, -0.15, 0.325),
			Vector3(-0.01, -0.035, -0.19),
			Vector3(-0.12, -0.135, -0.04)
		],
		"rifle":
		[
			Vector3(0.015, -0.11, 0.135),
			Vector3(0.04, -0.15, 0.325),
			Vector3(-0.01, -0.035, -0.32),
			Vector3(-0.12, -0.135, -0.15)
		],
		"talon":
		[
			Vector3(0.015, -0.11, 0.135),
			Vector3(0.04, -0.15, 0.325),
			Vector3(-0.01, -0.035, -0.32),
			Vector3(-0.12, -0.135, -0.15)
		],
		"shotgun":
		[
			Vector3(0.015, -0.04, 0.12),
			Vector3(0.04, -0.08, 0.31),
			Vector3(-0.01, -0.037, 0),
			Vector3(-0.11, -0.137, 0.17)
		],
	}
	var parts: Array[String] = ["HandRight", "SleeveRight", "HandLeft", "SleeveLeft"]
	for name: String in positions:
		var scene: Node3D = _viewmodel(name)
		for index: int in parts.size():
			var part: Node3D = scene.find_child(parts[index], true, false) as Node3D
			assert_eq(part.position, positions[name][index], name + " " + parts[index])
			var expected_parent: StringName = &"Bolt" if name == "shotgun" and index >= 2 else &"Viewmodel"
			assert_eq(part.get_parent().name, expected_parent, name + " " + parts[index] + " keeps its direct parent")
