## A thrown grenade: flies and bounces off the world, then goes off when its fuse
## runs out. Only the server's real copy does damage (Blast.apply).
class_name Grenade
extends RigidBody3D

## Below this height a grenade fell out of the map.
const LOST_HEIGHT: float = -50.0
## Bounces slower than this make no sound.
const BOUNCE_SPEED: float = 1.5
const BOUNCE_SOUND: AudioStream = preload("res://assets/audio/grenade_bounce.wav")
## Twin Pin child frags (provisional, no design numbers): fuse, radius share, sideways and up speed.
const TWIN_PIN_FUSE: float = 0.4
const TWIN_PIN_RADIUS: float = 0.5
const TWIN_PIN_SPEED: Vector3 = Vector3(2.5, 3.0, 0.0)

var data: ThrowableData
var thrower: Player
var fuse_left: float = 0.0
## True on the copy that does damage; false on what other peers see.
var gameplay: bool = true
var went_off: bool = false
## A Twin Pin child: it never splits again.
var split_child: bool = false
## The session's GrenadeClaims on the server's real grenade, so the blast reaches everyone.
var claims: Node
var _bounce: AudioStreamPlayer3D


static func spawn(
	parent: Node, p_data: ThrowableData, p_thrower: Player, origin: Vector3, velocity: Vector3, fuse: float
) -> Grenade:
	var grenade: Grenade = p_data.scene.instantiate() as Grenade
	grenade.data = p_data
	grenade.thrower = p_thrower
	grenade.fuse_left = fuse
	grenade.collision_layer = 0
	grenade.collision_mask = Layers.WORLD
	parent.add_child(grenade)
	grenade.global_position = origin
	grenade.linear_velocity = velocity
	return grenade


func _ready() -> void:
	if Build.is_server():
		return
	_bounce = AudioStreamPlayer3D.new()
	_bounce.stream = BOUNCE_SOUND
	_bounce.bus = &"Weapons"
	_bounce.unit_size = 4.0
	_bounce.max_distance = 30.0
	add_child(_bounce)
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	if linear_velocity.length() > BOUNCE_SPEED:
		_bounce.play()


func _physics_process(delta: float) -> void:
	if went_off:
		return
	fuse_left -= delta
	if fuse_left <= 0.0:
		go_off()
	elif global_position.y < LOST_HEIGHT:
		Log.warn(&"throwables", &"grenade_lost", {"at": global_position})
		went_off = true
		queue_free()


func go_off() -> void:
	went_off = true
	if gameplay and multiplayer.is_server():
		# The thrower may have left or been freed while the fuse burned.
		var by: Player = thrower if is_instance_valid(thrower) else null
		Blast.apply(self, global_position, data, by)
		if is_instance_valid(claims):
			claims.call("broadcast_blast", by.net_id if by else 0, global_position)
		if by and not split_child:
			_twin_pin(by)
	queue_free()


## Twin Pin (implant Legendary): the frag splits into 2 smaller frags at the trait's share of its damage.
func _twin_pin(by: Player) -> void:
	var share: float = by.stats.value(&"twin_pin", 0.0) / 100.0
	if share <= 0.0:
		return
	var child_data: ThrowableData = data.duplicate() as ThrowableData
	child_data.centre_damage = data.centre_damage * share
	child_data.self_damage_max = data.self_damage_max * share
	child_data.radius = data.radius * TWIN_PIN_RADIUS
	child_data.full_radius = data.full_radius * TWIN_PIN_RADIUS
	for side: float in [-1.0, 1.0]:
		var speed: Vector3 = Vector3(TWIN_PIN_SPEED.x * side, TWIN_PIN_SPEED.y, 0.0)
		var child: Grenade = spawn(get_parent(), child_data, by, global_position, speed, TWIN_PIN_FUSE)
		child.split_child = true
		child.claims = claims
