## Post-import script for the Halcyon Labs prop and dressing models: materials
## multiply albedo by the baked AO vertex colour (like vertex_shading_import.gd),
## and named slots are swapped for the shared materials in SHARED.
@tool
extends EditorScenePostImport

const SHARED: Dictionary = {
	"Screen": "res://systems/effects/monitor_screen.tres",
}


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: Material = mesh.surface_get_material(i)
			if material and SHARED.has(material.resource_name):
				mesh.surface_set_material(i, load(SHARED[material.resource_name]) as Material)
			elif material is BaseMaterial3D and mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
				(material as BaseMaterial3D).vertex_color_use_as_albedo = true
	return scene
