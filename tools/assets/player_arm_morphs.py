"""Attach code-built grip variants to matching arm parts without changing their rest mesh."""

import bpy


def _topology(mesh):
    return [(tuple(face.vertices), face.material_index) for face in mesh.polygons]


def _coordinates(base, variant, name):
    if base.type != "MESH" or variant.type != "MESH":
        raise ValueError("arm morph parts must be meshes")
    first, second = base.data, variant.data
    if len(first.vertices) != len(second.vertices):
        raise ValueError("arm morph vertex counts differ")
    if _topology(first) != _topology(second):
        raise ValueError("arm morph topology or material indices differ")
    keys = first.shape_keys
    if keys and (not keys.use_relative or name in keys.key_blocks):
        raise ValueError("arm morph needs relative keys and a new name")
    if abs(base.matrix_world.determinant()) < 1e-12:
        raise ValueError("arm morph base transform must be invertible")
    transform = base.matrix_world.inverted() @ variant.matrix_world
    return [transform @ vertex.co for vertex in second.vertices]


def add_variant(base_parts, variant_parts, name):
    """Copy matched parts in creation order into a zero-weight relative shape key."""
    if not name or name == "Basis":
        raise ValueError("arm morph needs a nonempty variant name distinct from Basis")
    if not base_parts or len(base_parts) != len(variant_parts):
        raise ValueError("arm morph part counts differ or are empty")
    objects = [*base_parts, *variant_parts]
    if any(obj.type != "MESH" for obj in objects):
        raise ValueError("arm morph parts must be meshes")
    if len({obj.as_pointer() for obj in objects}) != len(objects):
        raise ValueError("arm morph parts must be distinct objects")
    if len({obj.data.as_pointer() for obj in base_parts}) != len(base_parts):
        raise ValueError("arm morph base parts must have distinct meshes")
    bpy.context.view_layer.update()
    coordinates = [_coordinates(base, variant, name) for base, variant in zip(base_parts, variant_parts, strict=True)]
    for base, points in zip(base_parts, coordinates, strict=True):
        if base.data.shape_keys is None:
            base.shape_key_add(name="Basis", from_mix=False)
        key = base.shape_key_add(name=name, from_mix=False)
        key.relative_key = base.data.shape_keys.reference_key
        key.value = 0.0
        for vertex, point in zip(key.data, points, strict=True):
            vertex.co = point
    for variant in variant_parts:
        bpy.data.objects.remove(variant, do_unlink=True)
