## How one weapon class moves the camera: view kick, shake and FOV punch on a shot,
## hitstop on a kill. Cosmetic only; RecoilData decides where bullets go.
class_name FeelData
extends Resource

@export_group("View kick")
## Degrees the camera pitches up per shot (camera only, not the aim).
@export_range(0.0, 3.0) var view_kick_pitch: float = 0.5
@export_range(40.0, 250.0) var view_kick_return_ms: float = 75.0

@export_group("Camera")
## Trauma added per shot (0-1); shake = trauma squared.
@export_range(0.0, 0.35) var fire_trauma: float = 0.0
@export_range(-4.0, 4.0) var fov_punch_deg: float = 0.0
@export_range(0.0, 500.0) var fov_punch_ms: float = 0.0

@export_group("Kills")
@export_range(0.0, 100.0) var kill_hitstop_ms: float = 0.0
