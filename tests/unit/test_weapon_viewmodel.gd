## The rifle viewmodel is the code-built model: muzzle flash sits on its
## Muzzle, the bolt kicks back on a shot and the magazine drops on reload.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"
const WEAPON: String = "res://systems/weapons/weapon.tscn"


func _rifle() -> Weapon:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var weapon: Weapon = (load(WEAPON) as PackedScene).instantiate() as Weapon
	weapon.setup(WeaponInstance.new(load(RIFLE) as WeaponData), null, camera)
	camera.add_child(weapon)
	weapon.set_active(true)
	return weapon


func _part(weapon: Weapon, part: String) -> Node3D:
	return weapon.find_child(part, true, false) as Node3D


func test_flash_is_on_the_model_muzzle() -> void:
	var weapon: Weapon = _rifle()
	var flash: Node3D = _part(weapon, "FlashLight")
	assert_not_null(flash, "rifle has a muzzle flash light")
	if flash:
		assert_eq(flash.get_parent().name, &"Muzzle", "flash sits on the model's Muzzle")
	weapon.fire()
	assert_true(flash.visible, "flash shows on a shot")


func test_bolt_kicks_back_on_fire() -> void:
	var weapon: Weapon = _rifle()
	var bolt: Node3D = _part(weapon, "Bolt")
	var rest: float = bolt.position.z
	weapon.fire()
	weapon._process(0.001)
	assert_gt(bolt.position.z, rest + 0.02, "bolt moves back (+Z) after a shot")
	for i: int in 30:
		weapon._process(0.05)
	assert_almost_eq(bolt.position.z, rest, 0.002, "bolt returns")


func test_magazine_drops_and_returns_on_reload() -> void:
	var weapon: Weapon = _rifle()
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
	var weapon: Weapon = _rifle()
	var lens: ScopeLens = _part(weapon, "ScopeLens") as ScopeLens
	assert_not_null(lens, "rifle has a scope lens")
	if lens == null:
		return
	lens._process(0.016)
	assert_false(lens.is_rendering(), "no extra render at the hip")
	weapon.ads_progress = 1.0
	lens._process(0.016)
	assert_true(lens.is_rendering(), "scope renders while aiming")
	var main: Camera3D = get_viewport().get_camera_3d()
	assert_almost_eq(lens.camera.fov, main.fov / lens.zoom, 0.01, "scope view is zoomed")
	assert_eq(lens.camera.cull_mask & ScopeLens.VIEWMODEL_LAYER, 0, "scope camera does not see the gun")
	for mesh: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		assert_eq((mesh as MeshInstance3D).layers, ScopeLens.VIEWMODEL_LAYER, mesh.name + " is on the viewmodel layer")
