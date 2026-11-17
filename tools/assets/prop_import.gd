## Post-import script for Halcyon prop and dressing models: maps each named glb
## slot to the shared textured material in levels/materials (SHARED), after the
## embedded materials take the baked AO vertex colour (grime reads it too).
@tool
extends "res://tools/assets/vertex_shading_import.gd"

const SHARED: Dictionary = {
	"Steel": "res://levels/materials/steel.tres",
	"Dark": "res://levels/materials/rubber.tres",
	"Paint": "res://levels/materials/panel_paint.tres",
	"Laminate": "res://levels/materials/panel_trim.tres",
	"Olive": "res://levels/materials/rust.tres",
	"Wood": "res://levels/materials/wood.tres",
	"Glass": "res://levels/materials/glass.tres",
	"Fluid": "res://levels/materials/specimen_tank.tres",
	"JarFluid": "res://levels/materials/jar_fluid.tres",
	"Paper": "res://levels/materials/paper.tres",
	"Alarm": "res://levels/materials/alarm_paint.tres",
	"SodiumPaint": "res://levels/materials/sodium_paint.tres",
	"Hazard": "res://levels/materials/hazard_paint.tres",
	"Concrete": "res://levels/materials/raw_concrete.tres",
	"Vine": "res://levels/materials/fenlight_vine.tres",
	"Screen": "res://systems/effects/monitor_screen.tres",
}


func _post_import(scene: Node) -> Object:
	super._post_import(scene)
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: Material = mesh.surface_get_material(i)
			if material and SHARED.has(material.resource_name):
				mesh.surface_set_material(i, load(SHARED[material.resource_name]) as Material)
	return scene
