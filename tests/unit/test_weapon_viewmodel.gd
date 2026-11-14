## The rifle and shotgun viewmodels are code-built models: muzzle flash sits on
## the Muzzle, the bolt (or pump) kicks back on a shot, the magazine drops on
## reload, and a shotgun shot fires every pellet.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"
const SHOTGUN: String = "res://content/weapons/brenner_trench.tres"
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
	var weapon: Weapon = _gun()
	var bolt: Node3D = _part(weapon, "Bolt")
	var rest: float = bolt.position.z
	weapon.fire()
	weapon._process(0.001)
	assert_gt(bolt.position.z, rest + 0.02, "bolt moves back (+Z) after a shot")
	for i: int in 30:
		weapon._process(0.05)
	assert_almost_eq(bolt.position.z, rest, 0.002, "bolt returns")


func test_magazine_drops_and_returns_on_reload() -> void:
	var weapon: Weapon = _gun()
	var mag: Node3D = _part(weapon, "Magazine")
	var rest: Vector3 = mag.position
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
