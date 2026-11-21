## What every peer sees and hears when a field ability goes off (plans/field-abilities.md step 3):
## the ability's sound where it went off and, for Shock Pulse, a pale ring that grows to the radius
## and fades; the Decoy Siren places its canister instead. Cosmetic only: skipped on a dedicated
## server; frees itself when done.
class_name PulseRing
extends Node3D

const GROW_TIME: float = 0.35
const LIFETIME: float = 2.0
const LIFT: float = 0.2
## Fluorescent (look-rules.md palette).
const RING_COLOR: Color = Color(0.804, 0.933, 0.91, 0.8)

static var _mesh: TorusMesh
static var _material: StandardMaterial3D


## Shows data's use at point under parent; null on a dedicated server.
static func play(parent: Node, data: AbilityData, point: Vector3) -> PulseRing:
	if parent == null or data == null or Build.is_server() or not parent.is_inside_tree():
		return null
	if data.effect == AbilityData.Effect.DECOY_SIREN:
		DecoySiren.place(parent, data, point)
		return null
	var effect: PulseRing = PulseRing.new()
	parent.add_child(effect)
	effect.global_position = point
	effect._start(data)
	return effect


func _start(data: AbilityData) -> void:
	if data.sound:
		var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		sound.stream = data.sound
		sound.bus = &"SFX"
		sound.unit_size = 6.0
		sound.max_distance = 60.0
		add_child(sound)
		sound.play()
	if data.effect == AbilityData.Effect.SHOCK_PULSE and data.radius > 0.0:
		_grow_ring(data.radius)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _grow_ring(radius: float) -> void:
	if _mesh == null:
		_mesh = TorusMesh.new()
		_mesh.inner_radius = 0.92
		_mesh.outer_radius = 1.0
		_mesh.rings = 48
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = RING_COLOR
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _mesh
	ring.material_override = _material.duplicate()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, LIFT, 0.0)
	ring.scale = Vector3.ONE * 0.2
	add_child(ring)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3(radius, 1.0, radius), GROW_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring.material_override, ^"albedo_color:a", 0.0, GROW_TIME * 1.6)
