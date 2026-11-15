"""Sewn pouches, swept webbing and bevelled hardware for the three vest frames."""

import math

import bpy
import gear_paint as paint
from body_parts import mesh
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
