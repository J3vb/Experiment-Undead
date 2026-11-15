## Sends a server zombie's pose and state to clients. Clients run no AI:
## their copy only shows what the server's zombie is doing.
class_name ZombieSync
extends MultiplayerSynchronizer

const SYNCED: Array[NodePath] = [
	^".:position", ^".:rotation", ^".:velocity", ^".:state", ^".:state_time", ^".:_vault_time"
]
## Seconds between updates; the visual rig smooths the gaps.
const INTERVAL: float = 1.0 / 30.0

var _zombie: Zombie
var _shown_dead: bool = false


func _init() -> void:
	name = "Sync"
	replication_interval = INTERVAL
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for path: NodePath in SYNCED:
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	replication_config = config


func _ready() -> void:
	_zombie = get_parent() as Zombie
	if is_multiplayer_authority():
		set_physics_process(false)
		return
	_zombie.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_zombie.ready.connect(_zombie.set_physics_process.bind(false), CONNECT_ONE_SHOT)


func _physics_process(_delta: float) -> void:
	if _zombie.state == Zombie.State.DEAD and not _shown_dead:
		_shown_dead = true
		show_death(_zombie)


## The client half of Zombie._on_died: no events, no freeing (the server
## despawns the zombie once its corpse has sunk).
static func show_death(zombie: Zombie) -> void:
	zombie.collision_layer = 0
	for zone: HitZone in zombie.hit_zones:
		zone.set_enabled(false)
	zombie.voice.silence()
	zombie.visual.fall_over()
