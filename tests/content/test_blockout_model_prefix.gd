## Checks the blockout builder's "model" folder prefix (prop library plan F-77 step 1):
## a plain name still loads from props/ or dressing/, and "folder/name" loads from that
## folder, so layouts can place props_large/ and town models.
extends GutTest

const BUILDER: String = "res://tools/blockout_builder.gd"
const LAYOUT: Dictionary = {
	"rooms": [{"id": "yard", "rect": [-10, -10, 10, 10], "floor": 0, "height": 4.0, "lights": false}],
	"props":
	[
		{"id": "plain", "room": "yard", "box": [-4, 0, -4, 2, 1, 1], "model": "barricade"},
		{"id": "large", "room": "yard", "box": [4, 0, 4, 6, 4, 6], "model": "town_large/radio_mast"},
	],
	"dressing":
	[
		{"id": "pipe", "room": "yard", "at": [0, 0, -6], "model": "pipe_run_3"},
		{"id": "lamp", "room": "yard", "at": [0, 0, 6], "model": "town/street_lamp"},
	],
}

var _built: Node3D


func before_all() -> void:
	_built = (load(BUILDER) as GDScript).build(LAYOUT.duplicate(true))


func after_all() -> void:
	_built.free()


func _scene_of(path: String) -> String:
	return (_built.get_node(NodePath(path)) as Node).scene_file_path


func test_plain_names_keep_their_default_folder() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	assert_eq(builder.model_path("barricade", "props"), "res://assets/models/props/barricade.glb")
	assert_eq(_scene_of("yard/Props/plain/Model"), "res://assets/models/props/barricade.glb")
	assert_eq(_scene_of("yard/Dressing/pipe"), "res://assets/models/dressing/pipe_run_3.glb")


func test_folder_prefix_loads_from_that_folder() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	assert_eq(builder.model_path("props_large/train_car", "props"), "res://assets/models/props_large/train_car.glb")
	assert_eq(_scene_of("yard/Props/large/Model"), "res://assets/models/town_large/radio_mast.glb")
	assert_eq(_scene_of("yard/Dressing/lamp"), "res://assets/models/town/street_lamp.glb")


func test_prefixed_prop_keeps_its_box_collider() -> void:
	var body: StaticBody3D = _built.get_node("yard/Props/large") as StaticBody3D
	var shape: BoxShape3D = (body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	assert_eq(shape.size, Vector3(6, 4, 6))
