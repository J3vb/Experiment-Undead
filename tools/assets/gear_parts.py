"""Sewn gear, swept webbing and bevelled hardware with recessed inspection marks."""

import math

import bpy

# isort: split
import bmesh
import gear_paint as paint
from body_parts import loft, mesh, select
from gun_parts import rounded, slab
from mathutils import Vector


def _join(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def _finish(obj, at, zone=paint.ZONE_MAIN):
    obj.location = at
    paint.zone(obj, zone)
    return obj


def plate(name, size, at, mat, radius=0.01, bevel=0.002):
    """Extruded rounded X/Z plate; depth is Y and the visible face points toward -Y."""
    width, depth, height = size
    radius = min(radius, width * 0.45, height * 0.45)
    outline = rounded(-width / 2, -height / 2, width / 2, height / 2, radius, steps=2)
    obj = slab(name, outline, depth, mat, bevel=min(bevel, depth * 0.24))
    obj.rotation_euler.z = -math.pi / 2
    return _finish(obj, at)


def _inset_outline(outline, amount):
    points = [Vector(point) for point in outline]
    area = sum(a.x * b.y - b.x * a.y for a, b in zip(points, points[1:] + points[:1], strict=True))
    if abs(area) < 1e-12:
        raise ValueError("a plate outline must enclose an area")
    winding = 1 if area > 0 else -1
    inset = []
    for index, point in enumerate(points):
        before = (point - points[index - 1]).normalized()
        after = (points[(index + 1) % len(points)] - point).normalized()
        normal_a = Vector((-before.y, before.x)) * winding
        normal_b = Vector((-after.y, after.x)) * winding
        bisector = normal_a + normal_b
        divisor = bisector.dot(normal_a)
        if divisor < 1e-6:
            raise ValueError("a plate outline cannot double back along an edge")
        inset.append(point + bisector * (amount / divisor))
    return inset


def outlined_plate(name, outline, depth, at, mat, bevel=0.0004):
    """Closed X/Z outline with one chamfer per face; coordinates are local to `at`.

    Simple concave outlines are supported. Keep the bevel smaller than the narrowest
    outline feature; eight corners cost 60 triangles with bevel or 28 without it.
    """
    if len(outline) < 3 or depth <= 0 or bevel < 0:
        raise ValueError("a plate needs an outline, positive depth and a non-negative bevel")
    edge = min(bevel, depth * 0.24)
    inset = _inset_outline(outline, edge)
    sections = ((-depth / 2, outline), (depth / 2, outline))
    if edge:
        sections = ((-depth / 2, inset), (-depth / 2 + edge, outline), (depth / 2 - edge, outline), (depth / 2, inset))
    obj = loft(name, [[(x, y, z) for x, z in ring] for y, ring in sections], mat)
    return _finish(obj, at)


def engrave(obj, strokes, depth, mat):
    """Cut rectangular stamps into a flat local -Y face, leaving its outer bounds intact.

    Strokes are local (centre X, centre Z, width, height), inside the flat face.
    Existing paint stays on original faces; recessed walls/floors use accent and `mat`.
    """
    front = min(vertex.co.y for vertex in obj.data.vertices)
    thickness = max(vertex.co.y for vertex in obj.data.vertices) - front
    if not 0 < depth < thickness - 1e-5:
        raise ValueError("an engraving must be shallower than the plate")
    if any(width <= 0 or height <= 0 for _x, _z, width, height in strokes):
        raise ValueError("stamp widths and heights must be positive")
    if mat.name not in obj.data.materials:
        obj.data.materials.append(mat)
    material_index = obj.data.materials.find(mat.name)
    bpy.context.view_layer.update()
    for x, z, width, height in strokes:
        outline = [
            (x - width / 2, z - height / 2),
            (x + width / 2, z - height / 2),
            (x + width / 2, z + height / 2),
            (x - width / 2, z + height / 2),
        ]
        cutter = loft("StampCutter", [[(px, y, pz) for px, pz in outline] for y in (front - depth, front + depth)], mat)
        cutter.matrix_world = obj.matrix_world.copy()
        cutter.data.materials.clear()
        for slot in obj.data.materials:
            cutter.data.materials.append(slot)
        for face in cutter.data.polygons:
            face.material_index = material_index
            face.use_smooth = False
        paint.zone(cutter, paint.ZONE_ACCENT)
        select(obj)
        modifier = obj.modifiers.new("Recessed stamp", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    return obj


def refine_face(obj, pitch=0.006):
    """Split flat -Y caps without displacement so vertex AO stays near stamps and seams."""
    if pitch <= 0:
        raise ValueError("face refinement pitch must be positive")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    for axis in (0, 2):
        low = min(vertex.co[axis] for vertex in bm.verts)
        high = max(vertex.co[axis] for vertex in bm.verts)
        for index in range(1, math.ceil((high - low) / pitch)):
            faces = [face for face in bm.faces if face.normal.y < -0.999]
            face_edges = {edge for face in faces for edge in face.edges}
            face_vertices = {vertex for face in faces for vertex in face.verts}
            edges = [edge for edge in bm.edges if edge in face_edges]
            vertices = [vertex for vertex in bm.verts if vertex in face_vertices]
            origin, normal = Vector(), Vector()
            origin[axis], normal[axis] = low + index * pitch, 1.0
            bmesh.ops.bisect_plane(bm, geom=[*faces, *edges, *vertices], dist=1e-8, plane_co=origin, plane_no=normal)
            bm.normal_update()
    # Keep the valid tessellation: glTF's n-gon path can connect three collinear grid vertices.
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def strap(name, path, section, mat, axis=(1, 0, 0)):
    """A solid webbing band swept through a curve; section is (width, thickness).

    Axis sets the width direction: X across shoulder straps, Z around a torso.
    The path is in world metres and does not need a separate attachment origin.
    """
    points = [Vector(point) for point in path]
    width, thickness = section
    vertices = []
    for i, point in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]).normalized()
        across = Vector(axis) - tangent * Vector(axis).dot(tangent)
        if across.length < 0.001:
            raise ValueError("webbing width axis must not run along its path")
        across.normalize()
        normal = tangent.cross(across).normalized()
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vertices.append(point + across * width * a / 2 + normal * thickness * b / 2)
    faces = [(3, 2, 1, 0)]
    for start in range(0, len(vertices) - 4, 4):
        for i in range(4):
            faces.append((start + i, start + (i + 1) % 4, start + 4 + (i + 1) % 4, start + 4 + i))
    faces.append(tuple(range(len(vertices) - 4, len(vertices))))
    obj = mesh(name, vertices, faces, mat)
    for face in obj.data.polygons:
        face.use_smooth = False
    paint.zone(obj, paint.ZONE_ACCENT)
    return obj


def buckle(name, size, at, mat):
    """Open rounded buckle frame with a chamfered lip and a central locking bar."""
    width, depth, height = size
    inset = min(width, height) * 0.20
    rings = []
    for shrink, y in ((0.001, -depth / 2), (0, 0), (0.001, depth / 2), (inset, depth / 2), (inset, -depth / 2)):
        outline = rounded(
            -width / 2 + shrink, -height / 2 + shrink, width / 2 - shrink, height / 2 - shrink, inset * 0.45, 2
        )
        rings.append([(x, y, z) for x, z in outline])
    count = len(rings[0])
    faces = []
    for ring in range(len(rings)):
        following = (ring + 1) % len(rings)
        for i in range(count):
            j = (i + 1) % count
            faces.append((ring * count + i, ring * count + j, following * count + j, following * count + i))
    frame = mesh(name, [point for ring in rings for point in ring], faces, mat)
    frame.location = at
    paint.zone(frame, paint.ZONE_ACCENT)
    cx, cy, cz = at
    bar = strap(name + "Lock", [(cx, cy, cz - height * 0.27), (cx, cy, cz + height * 0.27)], (inset * 0.65, depth), mat)
    return _join(name, [frame, bar])


def pouch(name, size, at, mats):
    """Rounded fabric pocket, overlapping flap, raised stitched border and pull tab."""
    width, depth, height = size
    x, y, z = at
    body = plate(name, size, at, mats["fabric"], radius=min(width, height) * 0.13)
    flap = plate(
        name + "Flap",
        (width * 0.96, 0.005, height * 0.30),
        (x, y - depth / 2 - 0.002, z + height * 0.31),
        mats["webbing"],
        radius=width * 0.08,
        bevel=0.001,
    )
    edge = strap(
        name + "Stitch",
        [(x - width * 0.41, y - depth / 2 - 0.005, z + height * f) for f in (0.38, 0.21)]
        + [
            (x + width * 0.41, y - depth / 2 - 0.005, z + height * 0.21),
            (x + width * 0.41, y - depth / 2 - 0.005, z + height * 0.38),
        ],
        (0.0018, 0.001),
        mats["webbing"],
        axis=(0, 1, 0),
    )
    tab = plate(
        name + "Pull",
        (width * 0.20, 0.006, height * 0.20),
        (x, y - depth / 2 - 0.007, z + height * 0.17),
        mats["polymer"],
        radius=0.003,
        bevel=0.001,
    )
    for obj in (body, flap, edge, tab):
        paint.zone(obj, paint.ZONE_ACCENT)
    return _join(name, [body, flap, edge, tab])


def molle_row(name, at, count, mat, pitch=0.035):
    """One row of raised webbing tunnels with narrow stitched-down separators."""
    x, y, z = at
    path = []
    for i in range(count):
        left = x + (i - count / 2) * pitch
        path.extend(((left, y, z), (left + pitch * 0.15, y - 0.003, z), (left + pitch * 0.85, y - 0.003, z)))
    path.append((x + count * pitch / 2, y, z))
    return strap(name, path, (0.015, 0.002), mat, axis=(0, 0, 1))


def velcro_patch(name, size, at, mat):
    """Rounded hook-and-loop field with an inset centre and a sewn edge."""
    width, depth, height = size
    x, y, z = at
    patch = plate(name, size, at, mat, radius=min(width, height) * 0.15, bevel=0.001)
    inset = plate(
        name + "Field",
        (width * 0.88, depth * 0.5, height * 0.78),
        (x, y - depth * 0.6, z),
        mat,
        radius=min(width, height) * 0.10,
        bevel=0.0005,
    )
    paint.zone(patch, paint.ZONE_ACCENT)
    paint.zone(inset, paint.ZONE_ACCENT)
    return _join(name, [patch, inset])


def shoulder_cap(name, profile, depth, mat, sign=1, thickness=0.016):
    """Closed padded cap: crowned across the arm, rolled down at front and back."""
    rings = []
    cross = ((-1, -0.027), (-0.85, -0.012), (0, 0), (0.85, -0.012), (1, -0.027))
    for x, z, taper in profile:
        top = [(sign * x, y * depth * taper / 2, z + drop) for y, drop in cross]
        bottom = [(px, py, pz - thickness) for px, py, pz in reversed(top)]
        rings.append(top + bottom)
    cap = loft(name, rings, mat)
    paint.zone(cap, paint.ZONE_MAIN)
    edges = [1 + ring * 10 + face for ring in range(len(rings) - 1) for face in (0, 3, 4, 9)]
    paint.zone(cap, paint.ZONE_TRIM, edges)
    return cap


def rear_band(width, mats, light=False):
    """Sewn identification band and closure seam across the rear harness/pocket."""
    y, z = (0.156, 1.22) if light else (0.159, 1.36)
    band = plate("RearStencil", (width, 0.004, 0.052), (0, y, z), mats["webbing"], bevel=0)
    paint.zone(band, paint.ZONE_TRIM)
    seam = strap(
        "RearBinding",
        [(-width / 2, y, z + 0.032), (0, y + 0.002, z + 0.032), (width / 2, y, z + 0.032)],
        (0.006, 0.003),
        mats["webbing"],
        axis=(0, 0, 1),
    )
    return _join("RearIdentification", [band, seam])
