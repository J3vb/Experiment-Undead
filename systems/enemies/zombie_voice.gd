## A zombie's mouth and feet: groans on a random timer, one-off sounds (attack,
## death) and footsteps. Presentation only. Shared caps (sound.md voice limits)
## keep at most MAX_VOCALS mouths and MAX_STEPS feet playing; a closer zombie
## steals the farthest one, a farther one stays quiet.
class_name ZombieVoice
extends AudioStreamPlayer3D

const MAX_VOCALS: int = 8
const MAX_STEPS: int = 6
const STEP_RANGE: float = 15.0

static var _vocals: Array[AudioStreamPlayer3D] = []
static var _steps: Array[AudioStreamPlayer3D] = []

var groans: Array[AudioStream] = []
var deaths: Array[AudioStream] = []
var footsteps: Array[AudioStream] = []
var attack: AudioStream
## A client copy waits for its first state sync before it reacts to changes.
var waiting_for_sync: bool = false
var feet: AudioStreamPlayer3D
var _timer: float = 0.0
var _shown_state: Zombie.State = Zombie.State.SPAWNING
var _state_seen: bool = false


func _ready() -> void:
	_timer = randf_range(1.0, 5.0)  # cosmetic
	feet = AudioStreamPlayer3D.new()
	feet.name = "Feet"
	feet.bus = bus
	feet.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	feet.unit_size = 2.0
	feet.max_distance = STEP_RANGE
	feet.position = Vector3.DOWN * position.y
	add_child(feet)


func _exit_tree() -> void:
	_vocals.erase(self)
	_steps.erase(feet)


func _process(delta: float) -> void:
	if groans.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.0, 8.0)  # cosmetic
		say(groans[randi() % groans.size()])  # cosmetic


func setup(data: EnemyData) -> void:
	groans = data.groan_sounds
	deaths = data.death_sounds
	footsteps = data.footstep_sounds
	attack = data.attack_sound


## Plays the sound for a zombie state change, on every peer (clients run no AI
## but see the state through ZombieSync). The first look only records the
## state, so a late joiner hears no death for a corpse that was already down.
func show_state(state: Zombie.State) -> void:
	if waiting_for_sync:
		return
	if not _state_seen:
		start_state(state)
		return
	if state == _shown_state:
		return
	_shown_state = state
	if state == Zombie.State.ATTACKING:
		say(attack)
	elif state == Zombie.State.DEAD:
		say_death()


## Records `state` as already shown, without a sound.
func start_state(state: Zombie.State) -> void:
	waiting_for_sync = false
	_state_seen = true
	_shown_state = state
	if state == Zombie.State.DEAD:
		silence()


func say(sound: AudioStream) -> void:
	if sound == null or not _claim(_vocals, MAX_VOCALS, self):
		return
	stream = sound
	pitch_scale = randf_range(0.85, 1.15)  # cosmetic
	play()


func say_death() -> void:
	silence()
	if not deaths.is_empty():
		say(deaths[randi() % deaths.size()])  # cosmetic


## One footstep, from the rig's walk cycle.
func step() -> void:
	if footsteps.is_empty() or _listener_distance(feet) > STEP_RANGE or not _claim(_steps, MAX_STEPS, feet):
		return
	feet.stream = footsteps[randi() % footsteps.size()]  # cosmetic
	feet.pitch_scale = randf_range(0.9, 1.1)  # cosmetic
	feet.play()


## Stops the groan timer and any sound still playing.
func silence() -> void:
	set_process(false)
	stop()


## True when `player` may play: already counted, a free slot, or closer to the
## listener than the farthest playing voice (which is stopped and replaced).
static func _claim(active: Array[AudioStreamPlayer3D], cap: int, player: AudioStreamPlayer3D) -> bool:
	for index: int in range(active.size() - 1, -1, -1):
		var other: AudioStreamPlayer3D = active[index]
		if not is_instance_valid(other) or not other.is_inside_tree() or not other.playing:
			active.remove_at(index)
	if active.has(player):
		return true
	if active.size() < cap:
		active.append(player)
		return true
	var farthest: int = 0
	for index: int in range(1, active.size()):
		if _listener_distance(active[index]) > _listener_distance(active[farthest]):
			farthest = index
	if _listener_distance(active[farthest]) <= _listener_distance(player):
		return false
	active[farthest].stop()
	active[farthest] = player
	return true


static func _listener_distance(player: AudioStreamPlayer3D) -> float:
	var camera: Camera3D = player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	var listener: Vector3 = camera.global_position if camera else Vector3.ZERO
	return player.global_position.distance_to(listener)
