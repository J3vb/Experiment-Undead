## Stats for one gun. A new gun = a new .tres in content/weapons/.
## Never change these at runtime: live state goes in WeaponInstance.
class_name WeaponData
extends Resource

enum FireMode { SEMI, BURST, AUTO }
enum Slot { PRIMARY, SIDEARM }
## What a hit does beyond damage. The server applies CHAIN and FROST; WELL fires an orb instead of a trace.
enum Effect { NONE, CHAIN, FROST, WELL }

@export_group("Identity")
@export var id: StringName = &""
@export var slot: Slot = Slot.PRIMARY
@export var loot_tags: Array[StringName] = []
@export var display_name: String = "Weapon"
@export var cost: int = 0
@export var crate_weight: float = 1.0
@export var upgraded: WeaponData

@export_group("Damage")
@export var damage: float = 30.0
@export var min_damage: float = 20.0
@export var falloff_start: float = 25.0
@export var falloff_end: float = 60.0
@export var max_range: float = 200.0
@export var pellets: int = 1
@export var head_multiplier: float = 2.0
@export var limb_multiplier: float = 0.8
@export var pierce_count: int = 0
@export var effect: Effect = Effect.NONE

@export_group("Handling")
@export var fire_mode: FireMode = FireMode.AUTO
@export var rounds_per_minute: float = 600.0
@export var spin_up_time: float = 0.0
@export var burst_count: int = 3
@export var magazine_size: int = 30
@export var starting_reserve: int = 120
@export var max_reserve: int = 240
@export var reload_time: float = 2.2
@export var empty_reload_time: float = 2.8
@export var reload_per_round: bool = false
@export var per_round_time: float = 0.5
@export var ads_time: float = 0.2
@export var ads_fov: float = 55.0
@export var sprint_to_fire_time: float = 0.18
@export var move_speed_multiplier: float = 1.0

@export_group("Accuracy")
## Cone half-angle in degrees.
@export var hip_spread: float = 2.5
@export var ads_spread: float = 0.15
@export var move_spread: float = 2.0
@export var spread_per_shot: float = 0.35
@export var max_spread: float = 6.0
@export var spread_recovery: float = 8.0

@export_group("Recoil")
@export var recoil: RecoilData
@export var viewmodel_kick: float = 0.045

@export_group("Presentation")
@export var no_muzzle_flash: bool = false
@export var hip_position: Vector3 = Vector3(0.22, -0.2, -0.45)
@export var ads_position: Vector3 = Vector3(0.0, -0.118, -0.32)
@export var viewmodel_scene: PackedScene
## How the first-person hands hold this gun; a Reforged copy shares its base grip.
@export var grip: GripData
@export var fire_sound: AudioStream
@export var dry_fire_sound: AudioStream
@export var reload_sound: AudioStream


func get_fire_interval() -> float:
	return 60.0 / maxf(rounds_per_minute, 1.0)


func get_damage_at(distance: float) -> float:
	if distance <= falloff_start:
		return damage
	if distance >= falloff_end:
		return min_damage
	var t: float = (distance - falloff_start) / maxf(falloff_end - falloff_start, 0.001)
	return lerpf(damage, min_damage, t)


func get_zone_multiplier(zone: DamageInfo.Zone) -> float:
	match zone:
		DamageInfo.Zone.HEAD:
			return head_multiplier
		DamageInfo.Zone.LIMB:
			return limb_multiplier
	return 1.0
