## Sends a server zombie's pose and state to clients. Clients run no AI:
## their copy only shows what the server's zombie is doing.
class_name ZombieSync
extends MultiplayerSynchronizer

const SYNCED: Array[NodePath] = [
	^".:position",
	^".:rotation",
	^".:velocity",
	^".:state",
	^".:state_time",
	^".:entry:vault_time",
	^".:frozen",
	^".:head_popped"
]
## Seconds between updates; the visual rig smooths the gaps.
const INTERVAL: float = 1.0 / 30.0

var _zombie: Zombie
var _shown_dead: bool = false
var _seen_alive: bool = false


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
	_zombie.ready.connect(_wait_for_first_sync, CONNECT_ONE_SHOT)


## The copy's voice ignores state changes until the first sync, so a late
## joiner hears no death for a corpse that was already down.
func _wait_for_first_sync() -> void:
	_zombie.voice.waiting_for_sync = true
	synchronized.connect(func() -> void: _zombie.voice.start_state(_zombie.state), CONNECT_ONE_SHOT)


func _physics_process(_delta: float) -> void:
	if _zombie.voice.waiting_for_sync or _shown_dead:
		return
	if _zombie.state != Zombie.State.DEAD:
		_seen_alive = true
		return
	_shown_dead = true
	show_death(_zombie, _seen_alive)


## The client half of Zombie._on_died: no events, no freeing (the server
## despawns the zombie once its corpse has sunk). `fresh` is false for a corpse
## that was already down when this peer first saw it.
static func show_death(zombie: Zombie, fresh: bool = true) -> void:
	zombie.collision_layer = 0
	for zone: HitZone in zombie.hit_zones:
		zone.set_enabled(false)
	zombie.visual.fall_over(zombie.head_popped, fresh)
