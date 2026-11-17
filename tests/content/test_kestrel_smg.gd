## Locks the provisional Kestrel balance scale and red-dot presentation.
extends GutTest


func test_kestrel_uses_scaled_balance_sheet_damage() -> void:
	var gun: WeaponData = Content.weapon(&"kestrel_smg")
	assert_not_null(gun)
	if gun == null:
		return
	assert_almost_eq(gun.damage, 45.0 * 0.57, 0.001, "sheet 45 x 0.57, scaled once")
	assert_almost_eq(gun.min_damage, 17.0, 0.001)
	assert_eq(gun.fire_mode, WeaponData.FireMode.AUTO)
	assert_eq(gun.rounds_per_minute, 850.0)
	assert_eq(gun.starting_reserve, 180)
	assert_eq(gun.upgraded.starting_reserve, 360)
	var vm: Node3D = gun.viewmodel_scene.instantiate() as Node3D
	assert_null(vm.find_child("ScopeLens", true, false), "a red dot has no scope camera")
	assert_not_null(vm.find_child("Reticle", true, false), "the red dot shows its reticle")
	for part: String in ["HandRight", "HandLeft", "FlashLight", "FlashMesh"]:
		assert_not_null(vm.find_child(part, true, false), part)
	assert_almost_eq(gun.ads_position.y + 0.077, 0.0, 0.001, "red dot window at eye height")
	assert_eq(gun.ads_position.x, 0.0)
	vm.free()
