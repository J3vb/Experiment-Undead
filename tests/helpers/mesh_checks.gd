## Test helper for model checks: does any mesh under a node cross a line, such as a
## sight line or a bore. Points are in the node's own space.
class_name MeshChecks
extends RefCounted

const FAR: float = 100.0


static func blocks_segment(node: Node, start: Vector3, end: Vector3) -> bool:
	return _hits(node, Transform3D.IDENTITY, start, end)


## blocks_segment from start along direction for FAR metres.
static func blocks_ray(node: Node, start: Vector3, direction: Vector3) -> bool:
	return _hits(node, Transform3D.IDENTITY, start, start + direction * FAR)


static func _hits(node: Node, parent: Transform3D, start: Vector3, end: Vector3) -> bool:
	var here: Transform3D = parent * (node as Node3D).transform if node is Node3D else parent
	if node is MeshInstance3D:
		var faces: PackedVector3Array = (node as MeshInstance3D).mesh.get_faces()
		for index: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(
				start, end, here * faces[index], here * faces[index + 1], here * faces[index + 2]
			)
			if hit != null:
				return true
	for child: Node in node.get_children():
		if _hits(child, here, start, end):
			return true
	return false
