## The Decoy Siren canister every peer sees (plans/field-abilities.md step 5): a grey-box canister
## with a blinking alarm light that wails its sound until it is freed after the lure time.
## Cosmetic only; the lure itself is AbilityEffects.decoy_siren on the server.
class_name DecoySiren
extends Node3D

const BLINK: float = 0.25
## Blood / alarm (look-rules.md palette).
const ALARM: Color = Color("c3201b")
const CASING: Color = Color("5f6d68")

var _light: OmniLight3D
var _time: float = 0.0


static func place(parent: Node, data: AbilityData, point: Vector3) -> DecoySiren:
	var siren: DecoySiren = DecoySiren.new()
	parent.add_child(siren)
	siren.global_position = point
	siren._build(data)
	parent.get_tree().create_timer(data.duration).timeout.connect(siren.queue_free)
	return siren


func _build(data: AbilityData) -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	var can: CylinderMesh = CylinderMesh.new()
	can.top_radius = 0.12
	can.bottom_radius = 0.14
	can.height = 0.45
	body.mesh = can
	body.position.y = can.height * 0.5
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = CASING
	paint.metallic = 0.6
	paint.roughness = 0.5
	body.material_override = paint
	add_child(body)
	_light = OmniLight3D.new()
	_light.light_color = ALARM
	_light.omni_range = 4.0
	_light.position.y = can.height + 0.1
	add_child(_light)
	if data.sound:
		var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		sound.stream = data.sound
		sound.bus = &"SFX"
		sound.unit_size = 8.0
		sound.max_distance = 70.0
		sound.finished.connect(sound.play)
		add_child(sound)
		sound.play()


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = 3.0 if fmod(_time, BLINK * 2.0) < BLINK else 0.0
