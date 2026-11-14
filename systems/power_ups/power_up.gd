## A power-up (or a Scavenger ammo pack) floating where a zombie died. The
## first living player to touch it collects it. It vanishes after LIFETIME seconds and
## blinks for the last BLINK_TIME.
class_name PowerUp
extends Area3D

const LIFETIME: float = 25.0
const BLINK_TIME: float = 5.0

var data: PowerUpData
var age: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	($Visual/Label as Label3D).text = data.display_name.to_upper()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()


func _process(delta: float) -> void:
	_visual.rotate_y(delta * 1.5)
	_visual.visible = age < LIFETIME - BLINK_TIME or fmod(age, 0.4) < 0.25


## Only called where Net.is_authority() is true.
func collect(player: Player) -> void:
	if is_queued_for_deletion():
		return
	match data.id:
		&"resupply":
			for node: Node in get_tree().get_nodes_in_group(&"players"):
				for weapon: Weapon in (node as Player).weapons.weapons:
					weapon.instance.refill_all()
					weapon.ammo_changed.emit(weapon.instance.ammo_in_mag, weapon.instance.ammo_reserve)
		&"ammo_pack":
			for weapon: Weapon in player.weapons.weapons:
				weapon.instance.add_reserve(weapon.data.magazine_size)
				weapon.ammo_changed.emit(weapon.instance.ammo_in_mag, weapon.instance.ammo_reserve)
	Events.power_up_collected.emit(player, data)
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player and player.is_alive() and Net.is_authority():
		collect(player)
