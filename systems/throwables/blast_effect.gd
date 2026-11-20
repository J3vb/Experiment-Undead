## What a frag blast looks and sounds like: a short warm flash, a fireball puff, a smoke
## cloud, a near and a far bang, and screen shake for local players within SHAKE_RANGE.
## The newest MAX_ALIVE blasts are reused. Visual only: skipped on a dedicated server.
class_name BlastEffect
extends Node3D

const MAX_ALIVE: int = 4
const LIFETIME: float = 2.6
const FLASH_TIME: float = 0.18
const FLASH_ENERGY: float = 10.0
const FLASH_RANGE: float = 9.0
## Muzzle flash light colour from look-rules.md.
const FLASH_COLOR: Color = Color("ffd9a0")
const SMOKE_COLOR: Color = Color(0.3, 0.31, 0.3, 0.55)
## Trauma at the blast, falling linearly to 0 at SHAKE_RANGE (game-feel.md shake table).
const SHAKE_MAX: float = 0.6
const SHAKE_RANGE: float = 15.0
const NEAR_SOUND: AudioStream = preload("res://assets/audio/grenade_blast_near.wav")
const FAR_SOUND: AudioStream = preload("res://assets/audio/grenade_blast_far.wav")

static var _ring: Array[BlastEffect] = []
static var _next: int = 0
static var _fire_mesh: QuadMesh
static var _smoke_mesh: QuadMesh
static var _soft_dot: GradientTexture2D

var _flash: OmniLight3D
var _fire: CPUParticles3D
var _smoke: CPUParticles3D
var _near: AudioStreamPlayer3D
var _far: AudioStreamPlayer3D
var _age: float = 0.0


## Shows a blast at point and shakes every local player's camera near it.
static func spawn(parent: Node, point: Vector3) -> BlastEffect:
	if parent == null or Build.is_server():
		return null
	var blast: BlastEffect = _take(parent)
	blast.global_position = point
	blast._start()
	shake_local_players(parent.get_tree(), point)
	return blast


static func shake_at(distance: float) -> float:
	return SHAKE_MAX * clampf(1.0 - distance / SHAKE_RANGE, 0.0, 1.0)


static func shake_local_players(tree: SceneTree, point: Vector3) -> void:
	for node: Node in tree.get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.camera and player.camera.current:
			var amount: float = shake_at(player.camera.global_position.distance_to(point))
			if amount > 0.0:
				player.camera_rig.add_trauma(amount, false)


static func _take(parent: Node) -> BlastEffect:
	if _ring.size() < MAX_ALIVE:
		var fresh: BlastEffect = BlastEffect.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next
	_next = (_next + 1) % MAX_ALIVE
	var blast: BlastEffect = _ring[index]
	if not is_instance_valid(blast) or blast.is_queued_for_deletion():
		blast = BlastEffect.new()
		_ring[index] = blast
		parent.add_child(blast)
	elif blast.get_parent() != parent:
		blast.reparent(parent, false)
	return blast


## Shared meshes, for ShaderWarmUp to draw once at match start.
static func warm_up_meshes() -> Array[Mesh]:
	_shared_meshes()
	return [_fire_mesh, _smoke_mesh]


static func _shared_meshes() -> void:
	if _fire_mesh:
		return
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_soft_dot = GradientTexture2D.new()
	_soft_dot.gradient = fade
	_soft_dot.fill = GradientTexture2D.FILL_RADIAL
	_soft_dot.fill_from = Vector2(0.5, 0.5)
	_soft_dot.fill_to = Vector2(0.5, 0.0)
	_fire_mesh = _particle_quad(1.0, FLASH_COLOR)
	_fire_mesh.material.render_priority = 1  # fire draws over the smoke it sits in
	_smoke_mesh = _particle_quad(1.4, SMOKE_COLOR)


## A soft round puff, unshaded so it reads in a dark room without lighting it.
static func _particle_quad(size: float, tint: Color) -> QuadMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = _soft_dot
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	return quad


func _init() -> void:
	_shared_meshes()
	_flash = OmniLight3D.new()
	_flash.light_color = FLASH_COLOR
	_flash.omni_range = FLASH_RANGE
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.light_bake_mode = Light3D.BAKE_DISABLED
	_flash.position = Blast.LIFT
	add_child(_flash)
	_fire = _burst(_fire_mesh, 16, 0.35, Vector2(3.0, 7.0), Vector3.ZERO)
	_smoke = _burst(_smoke_mesh, 18, 1.8, Vector2(1.0, 2.5), Vector3(0.0, 0.5, 0.0))
	_near = _sound(NEAR_SOUND, 12.0, 70.0, 0.0)
	_far = _sound(FAR_SOUND, 40.0, 160.0, -6.0)
	visible = false
	set_process(false)


func _burst(mesh: Mesh, amount: int, lifetime: float, speed: Vector2, gravity: Vector3) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.damping_min = speed.y * 0.8
	particles.damping_max = speed.y * 1.2
	particles.gravity = gravity
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.6
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = fade
	particles.mesh = mesh
	particles.position = Blast.LIFT
	add_child(particles)
	return particles


func _sound(stream: AudioStream, unit_size: float, max_distance: float, volume_db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"Weapons"
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.volume_db = volume_db
	add_child(player)
	return player


func _start() -> void:
	_age = 0.0
	visible = true
	_flash.light_energy = FLASH_ENERGY
	_fire.restart()
	_smoke.restart()
	_near.play()
	_far.play()
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	_flash.light_energy = FLASH_ENERGY * clampf(1.0 - _age / FLASH_TIME, 0.0, 1.0)
	if _age >= LIFETIME:
		visible = false
		set_process(false)
