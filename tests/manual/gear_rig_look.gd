## Captures the actual Player GearRig with mixed rarities in the existing warm booth.
## godot --path . --rendering-driver opengl3 res://tests/manual/gear_rig_look.tscn
extends Node3D

const BOOTH: PackedScene = preload("res://tools/gear_booth.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const SIZE: Vector2i = Vector2i(1280, 720)
const OUT: String = "res://tests/artifacts/gear_rig_look.png"
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
	var player: Player = PLAYER.instantiate() as Player
	player.set_multiplayer_authority(2)
	booth.add_child(player)
	player.rotation.y = PI
	player.set_physics_process(false)
	player.camera.current = false
	player.camera_rig.set_process(false)
	(player.get_node("Head/RecoilPivot/Camera3D/Flashlight") as SpotLight3D).hide()
	player.gear_rig.set_owner_view(false)
	player.gear_rig.apply(LookBuilder.from_equipped(LOADOUT))
	var sheet: Image = Image.create(SIZE.x * 2, SIZE.y, false, Image.FORMAT_RGB8)
	for view: int in 2:
		_frame(booth, view)
		for _warmup: int in 24:
			await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, SIZE), Vector2i(view * SIZE.x, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	get_tree().quit(0 if sheet.save_png(OUT) == OK else 1)


func _frame(booth: Node3D, view: int) -> void:
	var turntable: Node3D = booth.get_node("Turntable") as Node3D
	var camera: Camera3D = turntable.get_node("Camera3D") as Camera3D
	turntable.position = Vector3(0.0, 0.94 if view == 0 else 1.25, 0.0)
	turntable.rotation.y = deg_to_rad(-15.0 if view == 0 else 32.0)
	camera.position = Vector3(0.0, 0.0, 3.25 if view == 0 else 1.9)
	camera.fov = 36.0
	camera.current = true
	camera.look_at(turntable.global_position)
	var caption: Label = booth.get_node("Caption/Label") as Label
	caption.offset_right = 1240.0
	caption.offset_bottom = 100.0
	caption.text = (
		"Rare vest / Epic charm / Legendary implant\nNeeds the person's eye / "
		+ ("standing pose" if view == 0 else "attachment detail")
	)
