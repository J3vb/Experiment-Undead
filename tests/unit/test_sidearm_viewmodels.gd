## Sidearms use the existing bolt and magazine poses and the Wren sustains automatic fire.
extends GutTest

const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")
const SIDEARMS: Array[StringName] = [&"pistol_service", &"wren_mp"]


func _equip(id: StringName) -> Weapon:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var gun: Weapon = WEAPON.instantiate() as Weapon
	gun.setup(WeaponInstance.new(Content.weapon(id)), null, camera)
	camera.add_child(gun)
	gun.set_active(true)
	gun.set_process(false)
	return gun


func test_sidearm_flashes_follow_the_model_muzzle_and_clear_after_a_shot() -> void:
	var quad: QuadMesh = load("res://systems/weapons/viewmodels/flash_quad.tres") as QuadMesh
	for id: StringName in SIDEARMS:
		var gun: Weapon = _equip(id)
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		var light: Light3D = gun.find_child("FlashLight", true, false) as Light3D
		var flash: Node3D = gun.find_child("FlashMesh", true, false) as Node3D
		assert_not_null(muzzle)
		assert_not_null(light, String(id) + " retains its muzzle light")
		assert_not_null(flash, String(id) + " retains its muzzle flash geometry")
		if muzzle == null or light == null or flash == null:
			continue
		assert_eq(light.get_parent(), muzzle, String(id) + " light follows the model muzzle")
		assert_eq(flash.get_parent(), muzzle, String(id) + " flash follows the model muzzle")
		assert_false(light.visible)
		assert_false(flash.visible)
		assert_eq(flash.get_child_count(), 3)
		for node: Node in flash.get_children():
			assert_eq((node as MeshInstance3D).mesh, quad, "sidearms share the existing flash geometry")
		gun.fire()
		assert_true(light.visible, String(id) + " firing lights the muzzle")
		assert_true(flash.visible, String(id) + " firing shows the flash")
		gun._process(0.05)
		assert_false(light.visible, String(id) + " muzzle light clears after the shot")
		assert_false(flash.visible, String(id) + " flash clears after the shot")


func test_sidearm_wrappers_keep_gloved_hands_and_shared_sleeves() -> void:
	var glove: Material = load("res://systems/weapons/viewmodels/glove_material.tres") as Material
	var sleeve: Material = load("res://systems/weapons/viewmodels/sleeve_material.tres") as Material
	for id: StringName in SIDEARMS:
		var gun: Weapon = _equip(id)
		for name: String in ["HandRight", "HandLeft", "SleeveRight"]:
			var mesh: MeshInstance3D = gun.find_child(name, true, false) as MeshInstance3D
			assert_not_null(mesh, "%s retains %s" % [id, name])
			if mesh:
				assert_eq(mesh.mesh.surface_get_material(0), sleeve if name == "SleeveRight" else glove)
				assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				assert_eq(mesh.layers, ScopeLens.VIEWMODEL_LAYER, "hands and sleeves stay on the viewmodel layer")


func test_firing_moves_the_slide_while_frame_and_magazine_stay_seated() -> void:
	for id: StringName in SIDEARMS:
		var gun: Weapon = _equip(id)
		var slide: Node3D = gun.find_child("Slide", true, false) as Node3D
		var magazine: Node3D = gun.find_child("Magazine", true, false) as Node3D
		var receiver: Node3D = gun.find_child("Receiver", true, false) as Node3D
		var slide_rest: Vector3 = receiver.to_local(slide.global_position)
		var magazine_rest: Transform3D = magazine.transform
		var receiver_rest: Transform3D = receiver.transform
		gun.fire()
		gun._process(0.001)
		var travel: Vector3 = receiver.to_local(slide.global_position) - slide_rest
		assert_gt(travel.z, 0.02, String(id) + " slide recoils toward the player")
		assert_eq(magazine.transform, magazine_rest, String(id) + " magazine stays in the grip")
		assert_eq(receiver.transform, receiver_rest, String(id) + " fixed frame stays still")
		for frame: int in 30:
			gun._process(0.05)
		assert_almost_eq(receiver.to_local(slide.global_position).distance_to(slide_rest), 0.0, 0.002)


func test_empty_reload_holds_slide_open_and_returns_the_magazine() -> void:
	for id: StringName in SIDEARMS:
		var gun: Weapon = _equip(id)
		var slide: Node3D = gun.find_child("Slide", true, false) as Node3D
		var magazine: Node3D = gun.find_child("Magazine", true, false) as Node3D
		var receiver: Node3D = gun.find_child("Receiver", true, false) as Node3D
		var slide_rest: Vector3 = receiver.to_local(slide.global_position)
		var magazine_rest: Vector3 = magazine.position
		gun.instance.ammo_in_mag = 0
		assert_true(gun.start_reload())
		gun.tick(gun.data.empty_reload_time * 0.5)
		gun._process(0.001)
		assert_almost_eq(receiver.to_local(slide.global_position).z - slide_rest.z, 0.035, 0.001)
		assert_lt(magazine.position.y, magazine_rest.y - 0.15, String(id) + " magazine drops out")
		gun.tick(gun.data.empty_reload_time)
		gun._process(0.001)
		assert_false(gun.is_reloading())
		assert_almost_eq(magazine.position.distance_to(magazine_rest), 0.0, 0.001)
		assert_almost_eq(receiver.to_local(slide.global_position).distance_to(slide_rest), 0.0, 0.001)
		assert_eq(gun.instance.ammo_in_mag, gun.data.magazine_size)


func test_wren_empties_its_twenty_round_magazine_on_one_held_press() -> void:
	var gun: Weapon = _equip(&"wren_mp")
	watch_signals(gun)
	gun.trigger_held = true
	for tick: int in 70:
		gun.tick(1.0 / 60.0)
	assert_signal_emit_count(gun, "fired", 20, "automatic fire continues after the first three rounds")
	assert_eq(gun.instance.ammo_in_mag, 0)
	assert_true(gun.is_reloading(), "empty magazine starts the existing reload flow")
	gun.trigger_held = false
	gun.tick(gun.data.empty_reload_time)
	assert_eq(gun.instance.ammo_in_mag, 20)
	assert_eq(gun.instance.ammo_reserve, 100)
