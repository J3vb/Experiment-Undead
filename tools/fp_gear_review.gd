## First-person gear review: hip and ADS shots of the arms, cuffs, charm and implant per rarity (F-42 look-check).
## xvfb-run -a godot --path . --rendering-driver vulkan --rendering-method forward_plus
##   res://tools/fp_gear_review.tscn -- --out /tmp/fp-gear [--guns rifle_ar,talon_dmr] [--vest vest_heavy]
extends "res://tools/weapon_review.gd"

const FP_RARITIES: Array[StringName] = [&"", &"common", &"rare", &"legendary"]


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = arguments.find("--out")
	_output = arguments[out_index + 1] if out_index >= 0 and out_index + 1 < arguments.size() else _output + "_fp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var vest_index: int = arguments.find("--vest")
	var vest: StringName = StringName(arguments[vest_index + 1]) if vest_index >= 0 else &"vest_heavy"
	_setup()
	_stage.add_child(_target())
	for model: String in selected_models(arguments):
		for rarity: StringName in FP_RARITIES:
			await _capture_gear(model, vest, rarity)
	get_tree().quit()


func _capture_gear(model: String, vest: StringName, rarity: StringName) -> void:
	_camera.transform = Transform3D.IDENTITY
	var holder: WeaponHolder = WeaponHolder.new()
	_camera.add_child(holder)
	holder.setup(null, _camera)
	holder.set_process(false)
	var weapon: Weapon = holder.give(load("res://content/weapons/%s.tres" % GUNS[model]) as WeaponData)
	weapon.set_process(false)
	var look: CharacterLook = CharacterLook.new()
	if not rarity.is_empty():
		look.slots[&"vest"] = {"visual_id": vest, "rarity": rarity}
		look.slots[&"charm"] = {"visual_id": &"charm_dog_tags", "rarity": rarity}
		look.slots[&"implant"] = {"visual_id": &"implant_reflex", "rarity": rarity}
	holder.arm_view.apply_look(look)
	var label: String = String(rarity) if not rarity.is_empty() else "no_vest"
	for aimed: bool in [false, true]:
		configure_view(_camera, weapon, aimed)
		holder.arm_view.update_pose()
		await _save(model, label, "ads" if aimed else "hip", "First-person gear / %s" % vest)
	holder.free()
