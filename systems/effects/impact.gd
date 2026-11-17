## One-shot hit effect: a burst of particles plus a short-lived mark, and a
## flesh or bone-crack sound on zombie hits. The newest MAX_ALIVE impacts and
## MAX_SOUNDS hit sounds are kept and reused; meshes and materials are shared.
class_name Impact
extends Node3D

enum Kind { SURFACE, FLESH, HEAD }

const MAX_ALIVE: int = 48
const LIFETIME: float = 6.0
const FLESH_LIFETIME: float = 1.0
## Impacts and gore voice cap from sound.md; the oldest sound is stolen.
const MAX_SOUNDS: int = 4
## Blood from game-feel.md "Blood and gore": 12 particles, 0.4 s, gravity on.
const BLOOD_COLOR: Color = Color("5a0f0f")
const BLOOD_PARTICLES: int = 12
const BLOOD_TIME: float = 0.4
const FLESH_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/impact_flesh_1.wav"),
	preload("res://assets/audio/impact_flesh_2.wav"),
	preload("res://assets/audio/impact_flesh_3.wav"),
	preload("res://assets/audio/impact_flesh_4.wav"),
]
const HEAD_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/hit_head_1.wav"),
	preload("res://assets/audio/hit_head_2.wav"),
]

static var _ring: Array[Impact] = []
static var _next: int = 0
static var _sounds: Array[AudioStreamPlayer3D] = []
static var _next_sound: int = 0
static var _flesh_mesh: QuadMesh
static var _surface_mesh: QuadMesh
static var _mark_mesh: QuadMesh

var _flesh: CPUParticles3D
var _surface: CPUParticles3D
var _mark: MeshInstance3D
var _left: float = 0.0


static func spawn(parent: Node, point: Vector3, normal: Vector3, kind: Kind) -> Impact:
	if parent == null:
		return null
	var impact: Impact = _take(parent)
	impact.global_position = point + normal * 0.01
	impact._show(normal, kind)
	if kind != Kind.SURFACE:
		_play_hit_sound(parent, impact.global_position, kind)
	return impact


## Decided at trace time, so a killing hit keeps its kind after the zones turn off.
static func kind_for(hit_zone: HitZone) -> Kind:
	if hit_zone == null:
		return Kind.SURFACE
	return Kind.HEAD if hit_zone.zone == DamageInfo.Zone.HEAD else Kind.FLESH


## Plays a flesh hit or a headshot crack on the next of MAX_SOUNDS reused players.
static func _play_hit_sound(parent: Node, point: Vector3, kind: Kind) -> void:
	var player: AudioStreamPlayer3D = _take_sound()
	if not player.is_inside_tree():
		parent.add_child(player)
	elif player.get_parent() != parent:
		player.reparent(parent, false)
	var sounds: Array[AudioStream] = HEAD_SOUNDS if kind == Kind.HEAD else FLESH_SOUNDS
	player.stream = sounds[randi() % sounds.size()]  # cosmetic
	player.pitch_scale = randf_range(0.92, 1.08)  # cosmetic
	player.global_position = point
	player.play()


static func _take_sound() -> AudioStreamPlayer3D:
	if _sounds.size() < MAX_SOUNDS:
		_sounds.append(_new_sound_player())
		return _sounds[-1]
	var index: int = _next_sound
	_next_sound = (_next_sound + 1) % MAX_SOUNDS
	if not is_instance_valid(_sounds[index]) or _sounds[index].is_queued_for_deletion():
		_sounds[index] = _new_sound_player()
	return _sounds[index]


static func _new_sound_player() -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.bus = &"Enemies"
	player.unit_size = 2.0
	player.max_distance = 20.0
	return player


## A new impact until MAX_ALIVE exist, then the oldest one, moved under `parent`.
static func _take(parent: Node) -> Impact:
	if _ring.size() < MAX_ALIVE:
		var fresh: Impact = Impact.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next
	_next = (_next + 1) % MAX_ALIVE
	var impact: Impact = _ring[index]
	if not is_instance_valid(impact) or impact.is_queued_for_deletion():
		impact = Impact.new()
		_ring[index] = impact
		parent.add_child(impact)
	elif impact.get_parent() != parent:
		impact.reparent(parent, false)
	return impact


static func _shared_meshes() -> void:
	if _mark_mesh:
		return
	_flesh_mesh = _quad(0.04, BLOOD_COLOR, true)
	# Lit, so blood stays dark red-brown under bright lights (look-rules: never bright red).
	(_flesh_mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_surface_mesh = _quad(0.04, Color(0.55, 0.5, 0.45), true)
	_mark_mesh = _quad(0.07, Color(0.03, 0.03, 0.03), false)


static func _quad(size: float, color: Color, particle: bool) -> QuadMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if particle:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	else:
		material.roughness = 1.0
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(size, size)
	mesh.material = material
	return mesh


func _init() -> void:
	_shared_meshes()
	_flesh = _particles(_flesh_mesh, BLOOD_PARTICLES)
	_flesh.lifetime = BLOOD_TIME
	_surface = _particles(_surface_mesh, 8)
	_mark = MeshInstance3D.new()
	_mark.mesh = _mark_mesh
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark)
	set_process(false)


func _particles(mesh: QuadMesh, amount: int) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.spread = 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.mesh = mesh
	add_child(particles)
	return particles


func _show(normal: Vector3, kind: Kind) -> void:
	var flesh: bool = kind != Kind.SURFACE
	var particles: CPUParticles3D = _flesh if flesh else _surface
	_flesh.visible = flesh
	_surface.visible = not flesh
	particles.direction = normal
	particles.restart()
	_mark.visible = not flesh
	if not flesh:
		var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		_mark.look_at(global_position - normal, up)
	visible = true
	_left = FLESH_LIFETIME if flesh else LIFETIME
	set_process(true)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		visible = false
		set_process(false)
