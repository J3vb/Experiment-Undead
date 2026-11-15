## A remote player's positional gun sound, short muzzle flash and pellet tracers.
class_name RemoteShotEffects
extends Node3D

const FLASH: QuadMesh = preload("res://systems/weapons/viewmodels/flash_quad.tres")

var _audio: AudioStreamPlayer3D
var _flash: MeshInstance3D
var _light: OmniLight3D
var _flash_left: float = 0.0


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "FireAudio"
	_audio.bus = &"Weapons"
	_audio.max_polyphony = 4
	add_child(_audio)
	_flash = MeshInstance3D.new()
	_flash.name = "Flash"
	_flash.mesh = FLASH
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)
	_light = OmniLight3D.new()
	_light.light_color = Color("ffd9a0")
	_light.light_energy = 4.0
	_light.omni_range = 6.0
	_light.visible = false
	add_child(_light)


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.visible = _flash_left > 0.0
	_light.visible = _flash_left > 0.0


func play(data: WeaponData, origin: Vector3, points: PackedVector3Array) -> void:
	global_position = origin
	_flash_left = 0.045
	_flash.visible = true
	_light.visible = true
	_audio.stream = data.fire_sound
	if _audio.stream:
		_audio.pitch_scale = randf_range(0.95, 1.05)  # cosmetic
		_audio.play()
	_draw_tracers(origin, points)


func _draw_tracers(origin: Vector3, points: PackedVector3Array) -> void:
	var lines: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe6b0")
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for point: Vector3 in points:
		lines.surface_add_vertex(origin)
		lines.surface_add_vertex(point)
	lines.surface_end()
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.name = "Tracers"
	tracer.mesh = lines
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	tracer.top_level = true
	tracer.global_transform = Transform3D.IDENTITY
	get_tree().create_timer(0.06).timeout.connect(tracer.queue_free)
