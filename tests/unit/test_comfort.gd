## Comfort settings scale only visuals (bob, sprint widening, damage effects, centre dot) and the preset.
extends GutTest

const PATH: String = "user://test_comfort.cfg"

var _old_path: String
var _old_values: Dictionary


func before_each() -> void:
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	Settings.reset_to_defaults()


func after_each() -> void:
	Settings._values = _old_values
	Settings._apply_all()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _camera() -> PlayerCamera:
	var body: CharacterBody3D = CharacterBody3D.new()
	var head: PlayerCamera = PlayerCamera.new()
	var pivot: Node3D = Node3D.new()
	pivot.name = "RecoilPivot"
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	pivot.add_child(camera)
	head.add_child(pivot)
	body.add_child(head)
	add_child_autofree(body)
	body.velocity = Vector3(4.0, 0.0, 0.0)
	return head


func test_head_bob_zero_keeps_the_camera_still_while_walking() -> void:
	var head: PlayerCamera = _camera()
	head.update_feel(0.016, false, false, 0.0, 50.0, 4.0)
	assert_gt(head.camera.position.length(), 0.0, "default bob moves the camera")
	Settings.set_value(&"comfort", &"head_bob", 0.0)
	head.update_feel(0.016, false, false, 0.0, 50.0, 4.0)
	assert_eq(head.camera.position, Vector3.ZERO)


func test_comfort_values_never_change_the_aim_direction() -> void:
	var head: PlayerCamera = _camera()
	head.update_feel(0.016, false, true, 0.0, 50.0, 4.0)
	var aim: Basis = head.camera.global_basis
	Settings.apply_comfort_preset()
	head.update_feel(0.016, false, true, 0.0, 50.0, 4.0)
	assert_true(head.camera.global_basis.is_equal_approx(aim), "bullets follow the same direction")


func test_sprint_fov_off_keeps_the_fov() -> void:
	var head: PlayerCamera = _camera()
	Settings.set_value(&"comfort", &"sprint_fov", false)
	for i: int in range(60):
		head.update_feel(0.05, false, true, 0.0, 50.0, 4.0)
	assert_almost_eq(head.camera.fov, head.base_fov, 0.01)
	Settings.set_value(&"comfort", &"sprint_fov", true)
	for i: int in range(60):
		head.update_feel(0.05, false, true, 0.0, 50.0, 4.0)
	assert_almost_eq(head.camera.fov, head.base_fov + head.sprint_fov_bonus, 0.01)


func test_weapon_bob_scales_the_viewmodel() -> void:
	var holder: WeaponHolder = WeaponHolder.new()
	add_child_autofree(holder)
	holder.setup(null, null)
	holder._move_factor = 1.0
	holder._bob_time = 1.0
	holder._process(0.0)
	var full: float = holder.position.length()
	Settings.set_value(&"comfort", &"weapon_bob", 0.5)
	holder._bob_time = 1.0
	holder._process(0.0)
	assert_almost_eq(holder.position.length(), full * 0.5, 0.0001)


func test_preset_writes_the_comfort_column_and_skips_unknown_keys() -> void:
	Settings.apply_comfort_preset()
	assert_eq(Settings.get_value(&"comfort", &"head_bob"), 0.0)
	assert_eq(Settings.get_value(&"comfort", &"weapon_bob"), 0.5)
	assert_eq(Settings.get_value(&"comfort", &"sprint_fov"), false)
	assert_eq(Settings.get_value(&"comfort", &"damage_effects"), 0.5)
	assert_eq(Settings.get_value(&"comfort", &"centre_dot"), true)
	for key: StringName in Settings.COMFORT_PRESET:
		if not Settings.DEFAULTS[&"comfort"].has(key):
			assert_null(Settings.get_value(&"comfort", key), "%s waits for its own thread" % key)


func test_centre_dot_follows_the_setting() -> void:
	var crosshair: Crosshair = Crosshair.new()
	add_child_autofree(crosshair)
	assert_false(crosshair.centre_dot)
	Settings.set_value(&"comfort", &"centre_dot", true)
	assert_true(crosshair.centre_dot)


func test_damage_effects_scale_the_vignette() -> void:
	var hud: Hud = preload("res://systems/ui/hud.tscn").instantiate() as Hud
	add_child_autofree(hud)
	hud._hurt = 0.8
	hud._process(0.0)
	var shade: ShaderMaterial = hud.vignette.material as ShaderMaterial
	var full: float = shade.get_shader_parameter("intensity")
	Settings.set_value(&"comfort", &"damage_effects", 0.5)
	hud._hurt = 0.8
	hud._process(0.0)
	assert_almost_eq(float(shade.get_shader_parameter("intensity")), full * 0.5, 0.0001)
	assert_gt(full, 0.0)
