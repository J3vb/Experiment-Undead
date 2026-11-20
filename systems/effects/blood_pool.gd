## A blood pool on the floor under a fallen zombie: a flat quad just above the
## floor (works in every renderer, unlike Decal in Compatibility). The newest
## MAX_ALIVE pools are kept and reused; all share one mesh and material. Each
## lasts LIFETIME seconds and fades out over the last FADE_TIME (game-feel.md gore table).
## The Gore setting picks the look: Full is the owner's "Stronger" pick, Reduced
## keeps fewer and shorter pools, Off lays none.
class_name BloodPool
extends MeshInstance3D

const MAX_ALIVE: int = 24
const LIFETIME: float = 45.0
const FADE_TIME: float = 5.0
const SIZE: float = 1.3
const REDUCED_ALIVE: int = 8
const REDUCED_LIFETIME: float = 20.0
const FULL_SCALE: float = 1.6
## Small extra splats around each pool on Full.
const SPLATS: int = 2

static var _ring: Array[BloodPool] = []
static var _next: int = 0
static var _mesh: PlaneMesh

var _left: float = 0.0


## The pools under a zombie that just fell, as this peer's Gore setting wants them.
static func lay_death(parent: Node, point: Vector3) -> void:
	var level: Impact.Gore = Impact.gore()
	if level == Impact.Gore.OFF:
		return
	if level == Impact.Gore.REDUCED:
		spawn(parent, point, 1.0, REDUCED_ALIVE, REDUCED_LIFETIME)
		return
	spawn(parent, point, FULL_SCALE)
	for index: int in SPLATS:
		var angle: float = randf() * TAU  # cosmetic
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.9, 1.4)  # cosmetic
		spawn(parent, point + offset, randf_range(0.3, 0.45))  # cosmetic


## Lays one pool on the floor below `point`. Skipped on a dedicated server.
static func spawn(
	parent: Node, point: Vector3, size: float = 1.0, cap: int = MAX_ALIVE, lifetime: float = LIFETIME
) -> BloodPool:
	if parent == null or Build.is_server():
		return null
	var pool: BloodPool = _take(parent, cap)
	pool.global_position = point + Vector3.UP * 0.02
	pool.rotation.y = randf() * TAU  # cosmetic
	var spread: float = randf_range(0.8, 1.2) * size  # cosmetic
	pool.scale = Vector3(spread, 1.0, spread * randf_range(0.8, 1.0))  # cosmetic
	pool.transparency = 0.0
	pool.visible = true
	pool._left = lifetime
	pool.set_process(true)
	return pool


## A new pool until `cap` exist, then the oldest of the first `cap`, moved under `parent`.
static func _take(parent: Node, cap: int) -> BloodPool:
	if _ring.size() < cap:
		var fresh: BloodPool = BloodPool.new()
		_ring.append(fresh)
		parent.add_child(fresh)
		return fresh
	var index: int = _next % cap
	_next = (index + 1) % cap
	var pool: BloodPool = _ring[index]
	if not is_instance_valid(pool) or pool.is_queued_for_deletion():
		pool = BloodPool.new()
		_ring[index] = pool
		parent.add_child(pool)
	elif pool.get_parent() != parent:
		pool.reparent(parent, false)
	return pool


## Shared meshes, for ShaderWarmUp to draw once at match start.
static func warm_up_meshes() -> Array[Mesh]:
	return [_shared_mesh()]


static func _shared_mesh() -> PlaneMesh:
	if _mesh:
		return _mesh
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(Impact.BLOOD_COLOR, 0.95))
	gradient.set_color(1, Color(Impact.BLOOD_COLOR, 0.0))
	gradient.add_point(0.6, Color(Impact.BLOOD_COLOR.darkened(0.2), 0.85))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.55, 0.55)
	material.roughness = 0.35
	material.metallic_specular = 0.4
	_mesh = PlaneMesh.new()
	_mesh.size = Vector2(SIZE, SIZE)
	_mesh.material = material
	return _mesh


func _init() -> void:
	mesh = _shared_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)


func _process(delta: float) -> void:
	_left -= delta
	transparency = 1.0 - clampf(_left / FADE_TIME, 0.0, 1.0)
	if _left <= 0.0:
		visible = false
		set_process(false)
