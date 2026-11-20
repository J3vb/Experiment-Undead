## A thrown grenade: flies and bounces off the world, then goes off when its fuse
## runs out. Only the server's real copy does damage (Blast.apply).
class_name Grenade
extends RigidBody3D

## Below this height a grenade fell out of the map.
const LOST_HEIGHT: float = -50.0

var data: ThrowableData
var thrower: Player
var fuse_left: float = 0.0
## True on the copy that does damage; false on what other peers see.
var gameplay: bool = true
var went_off: bool = false


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
		Blast.apply(self, global_position, data, thrower)
	queue_free()
