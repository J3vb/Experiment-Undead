## Post-import script for the code-built models: lets each material multiply its
## albedo by the baked AO/cavity vertex colour from tools/assets/finish.py.
@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
			if material and mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
				material.vertex_color_use_as_albedo = true
	return scene
