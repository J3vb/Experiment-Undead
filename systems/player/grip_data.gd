## How the first-person hands hold one gun. A new gun = a new .tres in content/grips/.
## The id is the file name and the key in assets/models/characters/player_arm_grips.json.
class_name GripData
extends Resource

@export var id: StringName = &""

@export_group("Hands")
## Weapon-local grip points in the Blender frame of player_grip_profiles.py.
@export var right_anchor: Vector3 = Vector3.ZERO
@export var left_anchor: Vector3 = Vector3.ZERO
@export var right_forward: Vector3 = Vector3(0, 0.8660254037844386, 0.5)
@export var right_dorsal: Vector3 = Vector3.RIGHT
@export var left_forward: Vector3 = Vector3(0.7838367176906169, 0.5878775382679627, 0.2)
@export var left_dorsal: Vector3 = Vector3(0.16, 0.12, -0.9797958971132712)

@export_group("Shoulders")
@export var right_shoulder: Vector3 = Vector3(0.19, -0.115, -0.234)
@export var left_shoulder: Vector3 = Vector3(-0.14, 0.03, -0.234)
## Maximum vertical and fore/aft accommodation while the weapon rises.
@export var right_shoulder_lift: Vector2 = Vector2(0.07, 0.112)
@export var left_shoulder_lift: Vector2 = Vector2(0.07, 0.112)
## Lateral response to weapon height: x when lowering, y when raising.
@export var left_shoulder_sway: Vector2 = Vector2.ZERO
## Camera-space shoulder offset blended by the weapon's sprint progress.
@export var right_sprint_offset: Vector3 = Vector3.ZERO

@export_group("Weapon")
## Viewmodel part the left hand follows (the Brenner's pump).
@export var support_part: NodePath = NodePath()
## The contact check also exports the moment just after a shot.
@export var shot_peak: bool = false
