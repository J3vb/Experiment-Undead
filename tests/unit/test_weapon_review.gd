## Review captures use actual weapon poses, preserve shared materials and restrict rarity to supported finishes.
extends GutTest

const BOOTH: GDScript = preload("res://tools/weapon_review.gd")
const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")


func test_review_includes_every_exported_weapon() -> void:
	for file: String in DirAccess.get_files_at("res://assets/models/weapons"):
		if file.ends_with(".glb"):
			assert_true(BOOTH.GUNS.has(file.get_basename()), file + " needs a matching review capture")


func test_review_poses_match_content_and_player_camera() -> void:
	for content: String in BOOTH.GUNS.values():
		var camera: Camera3D = Camera3D.new()
		add_child_autofree(camera)
		var weapon: Weapon = WEAPON.instantiate() as Weapon
		var data: WeaponData = load("res://content/weapons/%s.tres" % content) as WeaponData
		weapon.setup(WeaponInstance.new(data), null, camera)
		camera.add_child(weapon)
		weapon.set_active(true)
		weapon.set_process(false)
		BOOTH.configure_view(camera, weapon, false)
		assert_eq(weapon.position, data.hip_position, content + " hip position")
		assert_eq(weapon.ads_progress, 0.0)
		assert_almost_eq(camera.near, 0.03, 0.00001)
		var horizontal: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(camera.fov) / 2.0) * 16.0 / 9.0))
		assert_almost_eq(horizontal, 110.0, 0.001, "matches default player setting")
		BOOTH.configure_view(camera, weapon, true)
		assert_eq(weapon.position, data.ads_position, content + " ADS position")
		assert_eq(weapon.ads_progress, 1.0)
		assert_eq(camera.fov, data.ads_fov)
		var scope: ScopeLens = weapon.find_child("ScopeLens", true, false) as ScopeLens
		if scope:
			camera.current = true
			scope._process(0.016)
			assert_true(scope.is_rendering(), content + " captures live picture-in-picture")


func test_rarity_preview_preserves_shared_materials() -> void:
	var shader: Shader = Shader.new()
	shader.code = "shader_type spatial; instance uniform vec4 rarity_color : source_color = vec4(1.0);"
	var finish: ShaderMaterial = ShaderMaterial.new()
	finish.shader = shader
	var standard: StandardMaterial3D = StandardMaterial3D.new()
	standard.albedo_color = Color("#5F6D68")
	var gun: Node3D = Node3D.new()
	add_child_autofree(gun)
	var coated: MeshInstance3D = _mesh(gun, finish)
	var plain: MeshInstance3D = _mesh(gun, standard)
	BOOTH.apply_rarity(gun, Color("#FF8A1C"))
	assert_eq(coated.get_active_material(0), finish, "shared imported material is unchanged")
	assert_null(coated.get_surface_override_material(0))
	assert_eq(coated.get_instance_shader_parameter(&"rarity_color"), Color("#FF8A1C"))
	assert_eq(plain.get_active_material(0), standard, "body materials are never recoloured")
	assert_null(plain.get_surface_override_material(0))


func test_unsupported_baseline_keeps_optic_glass_unchanged() -> void:
	var gun: Node3D = Node3D.new()
	add_child_autofree(gun)
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.resource_name = "OpticGlass"
	glass.albedo_color = Color("#CDEEE8")
	var mesh: MeshInstance3D = _mesh(gun, glass)
	BOOTH.apply_rarity(gun, Color("#FF8A1C"))
	assert_eq(mesh.get_active_material(0), glass, "pre-rarity builds remain honest baseline captures")
	assert_null(mesh.get_surface_override_material(0))


func _mesh(parent: Node3D, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.material = material
	instance.mesh = box
	parent.add_child(instance)
	return instance
