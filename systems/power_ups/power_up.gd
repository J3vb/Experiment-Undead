## A power-up (or a Scavenger ammo pack) floating where a zombie died. The
## first living player to touch it collects it. It vanishes after LIFETIME seconds and
## blinks for the last BLINK_TIME. The server decides who collects it and when it
## goes; a client's copy only spins and blinks.
class_name PowerUp
extends Area3D

const LIFETIME: float = 25.0
const BLINK_TIME: float = 5.0

var data: PowerUpData
var drops: PowerUpDrops
var age: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitoring = multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	($Visual/Label as Label3D).text = data.display_name.to_upper()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME and multiplayer.is_server():
		queue_free()


func _process(delta: float) -> void:
	_visual.rotate_y(delta * 1.5)
	_visual.visible = age < LIFETIME - BLINK_TIME or fmod(age, 0.4) < 0.25


## Only called on the server.
func collect(player: Player) -> void:
	if is_queued_for_deletion() or not multiplayer.is_server():
		return
	if drops:
		drops.on_collected(self, player)
	else:
		apply_effect(player, data)
	play_collect_sound()
	Events.power_up_collected.emit(player, data)
	queue_free()


## The chime outlives the pickup.
func play_collect_sound() -> void:
	var sound: AudioStreamPlayer = get_node_or_null("CollectSound") as AudioStreamPlayer
	if sound == null or get_parent() == null:
		return
	sound.reparent(get_parent())
	sound.finished.connect(sound.queue_free)
	sound.play()


## Runs on the PC that owns player's guns.
static func apply_effect(player: Player, power_up: PowerUpData) -> void:
	for weapon: Weapon in player.weapons.weapons:
		if power_up.effect == PowerUpData.Effect.RESUPPLY:
			weapon.instance.refill_all()
		else:
			weapon.instance.add_reserve(weapon.data.magazine_size)
		weapon.ammo_changed.emit(weapon.instance.ammo_in_mag, weapon.instance.ammo_reserve)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player and player.is_alive() and multiplayer.is_server():
		collect(player)
