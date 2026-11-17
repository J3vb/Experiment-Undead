## A blood pool decal on the floor under a fallen zombie. The newest MAX_ALIVE
## pools are kept and reused; all share one radial texture. Each lasts
## LIFETIME seconds and fades out over the last FADE_TIME (game-feel.md gore table).
class_name BloodPool
extends Decal

const MAX_ALIVE: int = 24
const LIFETIME: float = 45.0
const FADE_TIME: float = 5.0
const SIZE: float = 1.3

static var _ring: Array[BloodPool] = []
static var _next: int = 0
static var _texture: GradientTexture2D

var _left: float = 0.0


## Lays a pool on the floor below `point`. Skipped on a dedicated server.
static func spawn(parent: Node, point: Vector3) -> BloodPool:
	if parent == null or Build.is_server():
		return null
	var pool: BloodPool = _take(parent)
	pool.global_position = point + Vector3.UP * 0.3
	pool.rotation.y = randf() * TAU  # cosmetic
	var spread: float = randf_range(0.8, 1.2)  # cosmetic
	pool.size = Vector3(SIZE * spread, 1.0, SIZE * spread)
	pool.modulate.a = 1.0
	pool.visible = true
	pool._left = LIFETIME
	pool.set_process(true)
	return pool


## A new pool until MAX_ALIVE exist, then the oldest one, moved under `parent`.
static func _take(parent: Node) -> BloodPool:
	if _ring.size() < MAX_ALIVE:
		var fresh: BloodPool = BloodPool.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next
	_next = (_next + 1) % MAX_ALIVE
	var pool: BloodPool = _ring[index]
	if not is_instance_valid(pool) or pool.is_queued_for_deletion():
		pool = BloodPool.new()
		_ring[index] = pool
		parent.add_child(pool)
	elif pool.get_parent() != parent:
		pool.reparent(parent, false)
	return pool


static func _shared_texture() -> GradientTexture2D:
	if _texture:
		return _texture
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(Impact.BLOOD_COLOR, 0.95))
	gradient.set_color(1, Color(Impact.BLOOD_COLOR, 0.0))
	gradient.add_point(0.55, Color(Impact.BLOOD_COLOR.darkened(0.2), 0.85))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(0.5, 0.0)
	_texture.width = 128
	_texture.height = 128
	return _texture


func _init() -> void:
	texture_albedo = _shared_texture()
	cull_mask = 1
	upper_fade = 0.2
	lower_fade = 0.2
	set_process(false)


func _process(delta: float) -> void:
	_left -= delta
	modulate.a = clampf(_left / FADE_TIME, 0.0, 1.0)
	if _left <= 0.0:
		visible = false
		set_process(false)
