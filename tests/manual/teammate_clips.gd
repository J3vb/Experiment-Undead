## Renders frames of every third-person player clip on the geared body, holding a gun the way
## BodyAnimator mounts it (default the AR-17).
## xvfb-run godot --path . --rendering-driver opengl3 res://tests/manual/teammate_clips.tscn -- --gun=kestrel_smg
extends Node3D

const BOOTH: PackedScene = preload("res://tools/gear_booth.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const SIZE: Vector2i = Vector2i(480, 540)
const FRAMES: int = 12
const OUT: String = "res://tests/artifacts/teammate_clips/"
const LOADOUT: Dictionary = {
	"vest": {"base": "vest_medium", "rar": "rare"},
	"charm": {"base": "charm_dog_tags", "rar": "epic"},
	"implant": {"base": "implant_reflex", "rar": "legendary"},
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_window().size = SIZE
	get_window().content_scale_size = SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var booth: Node3D = BOOTH.instantiate() as Node3D
	booth.set_script(null)
	add_child(booth)
	(booth.get_node("Caption/Label") as Label).hide()
	var player: Player = PLAYER.instantiate() as Player
	player.set_multiplayer_authority(2)
	(player.get_node("Body/BodyAnimator") as BodyAnimator).headless = true
	booth.add_child(player)
	player.set_physics_process(false)
	player.camera.current = false
	player.camera_rig.set_process(false)
	(player.get_node("Head/RecoilPivot/Camera3D/Flashlight") as SpotLight3D).hide()
	player.gear_rig.set_owner_view(false)
	player.gear_rig.apply(LookBuilder.from_equipped(LOADOUT))
	player.gear_rig.set_process(false)
	var gun: StringName = &"rifle_ar"
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--clips="):
			only = arg.trim_prefix("--clips=").split(",")
		elif arg.begins_with("--gun="):
			gun = StringName(arg.trim_prefix("--gun="))
	_hold_gun(player.gear_rig.skeleton, Content.weapon(gun))
	var anim: AnimationPlayer = player.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for clip: StringName in anim.get_animation_list():
		if only.is_empty() or String(clip) in only:
			await _render_clip(booth, player, anim, clip)
	get_tree().quit()


func _hold_gun(skeleton: Skeleton3D, data: WeaponData) -> void:
	var hand: BoneAttachment3D = BoneAttachment3D.new()
	hand.bone_name = &"hand_R"
	skeleton.add_child(hand)
	var gun: Node3D = data.world_model.instantiate() as Node3D
	hand.add_child(gun)
	gun.transform = BodyAnimator.hold_transform(data.grip)


func _render_clip(booth: Node3D, player: Player, anim: AnimationPlayer, clip: StringName) -> void:
	anim.play(clip)
	anim.pause()
	var length: float = anim.get_animation(clip).length
	for view: int in 2:
		_frame(booth, player, view)
		for index: int in FRAMES:
			anim.seek(length * index / FRAMES, true)
			for _warmup: int in 3:
				await RenderingServer.frame_post_draw
			var shot: Image = get_viewport().get_texture().get_image()
			shot.save_png(OUT + "%s_%d_%02d.png" % [clip, view, index])


func _frame(booth: Node3D, player: Player, view: int) -> void:
	var turntable: Node3D = booth.get_node("Turntable") as Node3D
	var camera: Camera3D = turntable.get_node("Camera3D") as Camera3D
	turntable.position = Vector3(0.0, 0.85, 0.0)
	turntable.rotation.y = deg_to_rad(145.0 if view == 0 else 80.0)
	camera.position = Vector3(0.0, 0.0, 3.0)
	camera.fov = 38.0
	camera.current = true
	camera.look_at(turntable.global_position)
	player.rotation.y = 0.0
