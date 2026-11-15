"""Soft sewn shapes: continuous Skin bodies, swept cuffs and carved fabric seams."""

import math

import bpy

# isort: split
import bmesh
from mathutils import Vector


def select(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(data)
    bm.free()
    for face in data.polygons:
        face.use_smooth = True
    return obj


def skin_body(nodes, mat):
    """A tree of (parent index, centre, elliptical radius), surfaced without joint seams."""
    data = bpy.data.meshes.new("ThermalTopology")
    data.from_pydata([n[1] for n in nodes], [(n[0], i) for i, n in enumerate(nodes) if n[0] is not None], [])
    obj = bpy.data.objects.new("Undersuit", data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    select(obj)
    skin = obj.modifiers.new("Continuous fabric", "SKIN")
    skin.branch_smoothing = 0.5
    skin.use_smooth_shade = True
    for vertex, node in zip(data.skin_vertices[0].data, nodes, strict=True):
        vertex.radius = node[2]
    data.skin_vertices[0].data[0].use_root = True
    bpy.ops.object.modifier_apply(modifier=skin.name)
    sub = obj.modifiers.new("Soft thermal volume", "SUBSURF")
    sub.levels = 2
    bpy.ops.object.modifier_apply(modifier=sub.name)
    return obj


def fabric_fold(obj, centre, axis, width, depth, reach):
    """Compress a local cloth band inward without changing topology or its outer fit.

    Width is the half-length along the axis; reach limits the affected radius.
    A cosine falloff leaves the surrounding surface and painted zones intact.
    """
    if width <= 0 or depth < 0 or reach <= depth or Vector(axis).length < 1e-6:
        raise ValueError("fold needs positive width/reach, a nonzero axis and depth below reach")
    centre, axis = Vector(centre), Vector(axis).normalized()
    for vertex in obj.data.vertices:
        offset = vertex.co - centre
        distance = offset.dot(axis)
        radial = offset - axis * distance
        radius = radial.length
        if abs(distance) >= width or radius <= depth or radius >= reach:
            continue
        falloff = (0.5 + 0.5 * math.cos(math.pi * distance / width)) ** 2
        vertex.co -= radial.normalized() * depth * falloff
    obj.data.update()


def refine_patch(obj, centre, radius):
    """Add cloth support edges locally, retaining fitted bounds without smoothing."""
    if radius <= 0:
        raise ValueError("patch radius must be positive")
    centre = Vector(centre)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edges = [edge for edge in bm.edges if all((vertex.co - centre).length < radius for vertex in edge.verts)]
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def loft(name, rings, mat):
    """Closed soft shell through arbitrary equal-sized cross sections."""
    count = len(rings[0])
    points = [point for ring in rings for point in ring]
    faces = [tuple(reversed(range(count)))]
    for ring in range(len(rings) - 1):
        for i in range(count):
            a, b = ring * count + i, ring * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces.append(tuple(range(len(points) - count, len(points))))
    return mesh(name, points, faces, mat)


def tube(name, points, radii, mat, sides=8):
    """Swept rounded fingers, rolled fabric edges or a closed seam cutter."""
    points = [Vector(p) for p in points]
    rings = []
    for i, (point, radius) in enumerate(zip(points, radii, strict=True)):
        tangent = points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]
        across = tangent.normalized().cross(Vector((0, 1, 0)))
        if across.length < 0.1:
            across = tangent.normalized().cross(Vector((1, 0, 0)))
        across.normalize()
        other = tangent.normalized().cross(across)
        rings.append(
            [
                point
                + radius * (across * math.cos(2 * math.pi * j / sides) + other * math.sin(2 * math.pi * j / sides))
                for j in range(sides)
            ]
        )
    return loft(name, rings, mat)


def ellipse_ring(name, centre, size, thickness, mat):
    """Padded oval frame or cuff with a real open centre; axis is Blender Y."""
    cx, cy, cz = centre
    rx, rz = size
    rings = []
    for i in range(24):
        angle = 2 * math.pi * i / 24
        rings.append(
            [
                (
                    cx + (rx + thickness * math.cos(t)) * math.cos(angle),
                    cy + thickness * math.sin(t),
                    cz + (rz + thickness * math.cos(t)) * math.sin(angle),
                )
                for t in (2 * math.pi * j / 6 for j in range(6))
            ]
        )
    faces = []
    for i in range(24):
        for j in range(6):
            faces.append((i * 6 + j, i * 6 + (j + 1) % 6, ((i + 1) % 24) * 6 + (j + 1) % 6, ((i + 1) % 24) * 6 + j))
    return mesh(name, [p for ring in rings for p in ring], faces, mat)


def groove(obj, path, width=0.003):
    """Project a sewing line onto the suit front and cut a shallow inset channel."""
    points = []
    for x, z in path:
        hit, location, _normal, _index = obj.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)))
        if hit:
            points.append((x, location.y - width * 0.45, z))
    if len(points) < 2:
        raise ValueError("seam must cross the fabric surface")
    cutter = tube("SeamCutter", points, [width] * len(points), obj.data.materials[0], 6)
    select(obj)
    modifier = obj.modifiers.new("Inset sewn channel", "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def pad(name, size, at, mat, bevel=None):
    """Soft bevelled reinforcement patch, buckle or rubber tread."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.active_object
    obj.name, obj.scale = name, size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Sewn rounded edge", "BEVEL")
    mod.width = bevel or min(size) * 0.4
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    return obj


def ellipsoid(name, at, size, mat, segments=12, rings=8):
    """Small padded details need fewer rings than the main body."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=at)
    obj = bpy.context.active_object
    obj.name, obj.scale = name, size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def clean(obj):
    """Remove collapsed seam edges and paired internal faces left by Boolean tessellation."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-5)
    groups = {}
    for face in bm.faces:
        groups.setdefault(frozenset(face.verts), []).append(face)
    paired = [face for group in groups.values() if len(group) > 1 for face in group]
    bmesh.ops.delete(bm, geom=paired, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[vertex for vertex in bm.verts if not vertex.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
