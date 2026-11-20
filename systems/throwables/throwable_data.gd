## One kind of throwable for the lethal slot. A new grenade = a new .tres in
## content/throwables/; the file name is the id.
class_name ThrowableData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Grenade"
## How many a player carries; refilled to this at each round start and by Resupply.
@export var carry: int = 2
## Seconds from pin pull to the blast. Cooking spends it in the hand.
@export var fuse: float = 3.0
@export var throw_speed: float = 15.0
## The throw leaves this many degrees above the aim line.
@export var throw_lift_degrees: float = 10.0
## Blast radius in metres; damage falls linearly from full_radius to 0 here.
@export var radius: float = 7.0
@export var full_radius: float = 1.5
## Damage inside full_radius. Fixed, so frags fade in late rounds unless gear raises it (person's pick, 2026-11-20).
@export var centre_damage: float = 1000.0
## Most damage the thrower's own grenade can do to the thrower.
@export var self_damage_max: float = 60.0
## Seconds the gun stays down after a throw.
@export var recover_time: float = 0.5
@export var scene: PackedScene
