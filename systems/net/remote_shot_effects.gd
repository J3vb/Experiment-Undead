## A remote player's positional gun sound, short muzzle flash, pellet tracers, body kick
## and the impacts where its bullets hit.
class_name RemoteShotEffects
extends Node3D

const FLASH: Mesh = preload("res://systems/weapons/viewmodels/flash_quad.tres")
const TRACER_TIME: float = 0.06

static var _tracer_material: StandardMaterial3D

## The teammate's third-person body, which plays its fire motion on each shot.
var body: BodyAnimator
var _audio: AudioStreamPlayer3D
var _flash: MeshInstance3D
var _light: OmniLight3D
var _flash_left: float = 0.0
var _tracers: MeshInstance3D
var _tracer_lines: ImmediateMesh
var _tracer_left: float = 0.0


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
	if _tracers:
		_tracer_left = maxf(_tracer_left - delta, 0.0)
		_tracers.visible = _tracer_left > 0.0


func play(data: WeaponData, origin: Vector3, points: PackedVector3Array) -> void:
	global_position = origin
	_flash_left = 0.0 if data.no_muzzle_flash else 0.045
	_flash.visible = _flash_left > 0.0
	_light.visible = _flash_left > 0.0
	_audio.stream = data.fire_sound
	if _audio.stream:
		_audio.pitch_scale = randf_range(0.95, 1.05)  # cosmetic
		_audio.play()
	_draw_tracers(origin, points)
	if body:
		body.fire()


## Blood or dust where a remote player's bullets really landed (sent with the shot).
func show_hits(origin: Vector3, hits: PackedVector3Array, kinds: PackedByteArray) -> void:
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	for index: int in hits.size():
		var normal: Vector3 = (origin - hits[index]).normalized()
		Impact.spawn(parent, hits[index], normal, kinds[index] as Impact.Kind)


## One tracer node per remote player, made on its first shot and redrawn per shot.
func _draw_tracers(origin: Vector3, points: PackedVector3Array) -> void:
	if _tracers == null:
		_make_tracers()
	_tracer_lines.clear_surfaces()
	_tracer_lines.surface_begin(Mesh.PRIMITIVE_LINES, _tracer_material)
	for point: Vector3 in points:
		_tracer_lines.surface_add_vertex(origin)
		_tracer_lines.surface_add_vertex(point)
	_tracer_lines.surface_end()
	_tracer_left = TRACER_TIME
	_tracers.visible = true


func _make_tracers() -> void:
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.albedo_color = Color("ffe6b0")
	_tracer_lines = ImmediateMesh.new()
	_tracers = MeshInstance3D.new()
	_tracers.name = "Tracers"
	_tracers.mesh = _tracer_lines
	_tracers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tracers)
	_tracers.top_level = true
	_tracers.global_transform = Transform3D.IDENTITY
