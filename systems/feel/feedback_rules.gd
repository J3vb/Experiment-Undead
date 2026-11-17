## Global feel numbers that do not depend on the gun: shake limits, hit and round
## trauma, kill hitstop and the downed and death screen. One file: content/feel/feedback_rules.tres.
class_name FeedbackRules
extends Resource

@export_group("Shake")
@export var trauma_decay: float = 1.6
@export var max_shake_pitch_deg: float = 2.5
@export var max_shake_yaw_deg: float = 2.5
@export var max_shake_roll_deg: float = 1.5
@export var shake_noise_hz: float = 18.0
@export var fire_trauma_cap: float = 0.35
@export var hit_trauma: float = 0.25
@export var round_start_trauma: float = 0.15
@export var ads_trauma_mult: float = 0.5
@export var ads_view_kick_mult: float = 0.6

@export_group("Kills")
@export var headshot_kill_hitstop_ms: float = 25.0
@export var max_hitstops_per_second: int = 4
## Degrees the FOV narrows (zooms in) on a headshot kill.
@export var headshot_kill_zoom_deg: float = 0.8
@export var headshot_kill_fov_ms: float = 120.0

@export_group("Downed and death")
@export var downed_drop_m: float = 0.9
@export var downed_drop_s: float = 0.3
@export var downed_roll_deg: float = 6.0
@export var downed_saturation: float = 0.2
@export var downed_vignette: float = 0.5
@export var revive_flash_alpha: float = 0.08
@export var revive_flash_s: float = 0.15
@export var death_fade_s: float = 0.6
