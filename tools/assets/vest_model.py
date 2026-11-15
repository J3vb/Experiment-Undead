"""Tailored chest rig and two plate carriers on the shared salvager rest body."""

import math

import body_parts as soft
import bpy

# isort: split
import bmesh
import character_rig as rig
import gear_paint as paint
import gear_parts as parts
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _body_surfaces():
    from player_body_model import build_player

    build_player()
    bpy.context.view_layer.update()
    surfaces = []
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            surfaces.append(
                BVHTree.FromPolygons(
                    [obj.matrix_world @ v.co for v in obj.data.vertices],
                    [tuple(t.vertices) for t in obj.data.loop_triangles],
                    all_triangles=True,
                )
            )
    for obj in list(bpy.context.scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return surfaces


def _clearance(obj, surfaces):
    """Tailor against all undersuit details, leaving four millimetres of air."""
    bpy.context.view_layer.update()
    inverse = obj.matrix_world.inverted()
    for vertex in obj.data.vertices:
        point = obj.matrix_world @ vertex.co
        for _iteration in range(12):
            moved = False
            for surface in surfaces:
                nearest, normal, _face, _distance = surface.find_nearest(point)
                distance = (point - nearest).dot(normal)
                if distance < 0.0042:
                    point += normal * (0.0043 - distance)
                    moved = True
            if not moved:
                break
        vertex.co = inverse @ point
    obj.data.update()


def _add(objects, obj, zone=None, bone=None):
    if zone is not None:
        paint.zone(obj, zone)
    if bone:
        obj["rigid_bone"] = bone
    objects.append(obj)
    return obj


def _carrier(name, width, levels, depth, mat, back=False):
    rings = []
    cross = [(-1, -0.25)] + [(u, -0.5) for u in (-0.94, -0.5, 0, 0.5, 0.94)]
    cross += [(1, -0.25), (1, 0.25)] + [(u, 0.5) for u in (0.94, 0.5, 0, -0.5, -0.94)] + [(-1, 0.25)]
    for z, taper in levels:
        ring = []
        for u, v in cross:
            y = -0.123 + 0.025 * u * u + depth * v
            ring.append((u * width * taper / 2, -y if back else y, z))
        rings.append(ring)
    obj = soft.loft(name, rings, mat)
    paint.zone(obj, paint.ZONE_MAIN)
    return obj


def _face_y(frame):
    return -0.123 - (0.025 + frame * 0.012) / 2


def _mounted(obj, frame, back=False):
    """Curve hardware across the same lateral profile as its supporting fabric."""
    bpy.context.view_layer.update()
    width = (0.35, 0.39, 0.42)[frame]
    inverse = obj.matrix_world.inverted()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    for x in (-width / 4, 0, width / 4):
        bmesh.ops.bisect_plane(
            bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(x, 0, 0), plane_no=(1, 0, 0), dist=1e-6
        )
    for vertex in bm.verts:
        curve = 0.025 * (vertex.co.x / (width / 2)) ** 2
        vertex.co.y += -curve if back else curve
    bm.transform(inverse)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def _torso(objects, mats, frame):
    width = (0.35, 0.39, 0.42)[frame]
    bottom, top = (1.16, 1.42) if frame == 0 else (1.115, 1.47)
    levels = [(bottom, 0.85), (bottom + 0.012, 1), (1.23, 1), (1.34, 1), (top - 0.035, 0.90), (top, 0.68)]
    _add(objects, _carrier("CarrierFront", width, levels, 0.025 + frame * 0.012, mats["fabric"]))
    if frame:
        _add(objects, _carrier("CarrierBack", width, levels, 0.026, mats["fabric"], back=True))
        _add(
            objects,
            _mounted(parts.plate("BackPlate", (0.24, 0.014, 0.25), (0, 0.1425, 1.30), mats["plate"]), frame, back=True),
        )
    for sign in (-1, 1):
        x = sign * 0.135
        path = [
            (x, -0.15, 1.36),
            (x, -0.12, 1.48),
            (x, -0.065, 1.54),
            (x, 0.045, 1.54),
            (x, 0.13, 1.46),
            (x, 0.15, 1.25),
        ]
        _add(objects, parts.strap("ShoulderWebbing", path, (0.044, 0.008), mats["webbing"]))
        _add(objects, parts.buckle("QuickRelease", (0.040, 0.014, 0.046), (x, -0.142, 1.424), mats["polymer"]))
        path = [
            (0, -0.142, 1.19),
            (sign * 0.17, -0.115, 1.19),
            (sign * 0.205, 0, 1.19),
            (sign * 0.17, 0.13, 1.19),
            (0, 0.15, 1.19),
        ]
        _add(objects, parts.strap("Cummerbund", path, (0.068, 0.012), mats["webbing"], axis=(0, 0, 1)))
    _add(
        objects,
        _mounted(
            parts.velcro_patch("IDField", (0.12, 0.006, 0.042), (0, _face_y(frame) - 0.004, 1.386), mats["webbing"]),
            frame,
        ),
    )
    for z in (1.29, 1.325):
        _add(objects, _mounted(parts.molle_row("MOLLE", (0, _face_y(frame) - 0.002, z), 6, mats["webbing"]), frame))
    for x in (-0.085, 0.085):
        size = (0.10, 0.038 + frame * 0.009, 0.115)
        _add(
            objects,
            _mounted(parts.pouch("MagazinePouch", size, (x, _face_y(frame) - size[1] / 2 + 0.001, 1.225), mats), frame),
        )


def _trim(objects, mats, frame):
    width = (0.32, 0.35, 0.38)[frame]
    for z in (1.365, 1.145 if frame else 1.17):
        _add(
            objects,
            _mounted(
                parts.plate(
                    "StencilStripe", (width, 0.005, 0.022), (0, _face_y(frame) - 0.002, z), mats["plate"], bevel=0
                ),
                frame,
            ),
            paint.ZONE_TRIM,
        )
    for x in (-width / 2, width / 2):
        _add(
            objects,
            _mounted(
                parts.plate(
                    "PlateEdge", (0.019, 0.006, 0.22), (x, _face_y(frame) - 0.002, 1.265), mats["plate"], bevel=0
                ),
                frame,
            ),
            paint.ZONE_TRIM,
        )
    for x in (-0.036, 0.036):
        _add(
            objects,
            _mounted(
                parts.plate(
                    "StatusPip", (0.007, 0.004, 0.018), (x, _face_y(frame) - 0.010, 1.39), mats["polymer"], bevel=0
                ),
                frame,
            ),
            paint.ZONE_GLOW,
        )


def _shoulders(objects, mats, frame):
    if frame == 0:
        return
    for side, sign in (("L", 1), ("R", -1)):
        bone = "clavicle_" + side
        width, height = ((0.145, 0.058), (0.23, 0.092))[frame - 1]
        at = (sign * (0.24 if frame == 1 else 0.275), 0, 1.51)
        pad = parts.plate("ShoulderPad", (width, 0.24, height), at, mats["fabric"], radius=0.022, bevel=0.008)
        _add(objects, pad, paint.ZONE_MAIN, bone)
        at = (at[0], -0.127, 1.525)
        _add(
            objects,
            parts.plate("ShoulderLip", (width * 0.92, 0.009, 0.025), at, mats["plate"], bevel=0),
            paint.ZONE_TRIM,
            bone,
        )


def _collar(objects, mats):
    rings = []
    for i in range(23):
        a = -math.pi / 2 + 0.6 + (2 * math.pi - 1.2) * i / 22
        rings.append(
            [
                (rx * math.cos(a), ry * math.sin(a), z)
                for rx, ry, z in (
                    (0.108, 0.106, 1.482),
                    (0.131, 0.127, 1.49),
                    (0.131, 0.127, 1.626),
                    (0.125, 0.121, 1.644),
                    (0.111, 0.107, 1.644),
                    (0.103, 0.099, 1.63),
                    (0.103, 0.099, 1.495),
                    (0.108, 0.106, 1.482),
                )
            ]
        )
    # The radial section closes through loft's final edge, so avoid a duplicate corner.
    rings = [ring[:-1] for ring in rings]
    collar = soft.loft("TallCollar", rings, mats["fabric"])
    _add(objects, collar, paint.ZONE_MAIN)
    for sign in (-1, 1):
        _add(
            objects,
            parts.plate("CollarTrim", (0.018, 0.008, 0.10), (sign * 0.074, -0.115, 1.57), mats["plate"], bevel=0),
            paint.ZONE_TRIM,
        )


def _cuff(side, mats, frame):
    sign = 1 if side == "L" else -1
    centre = Vector((sign * 0.545, 0, 1.115))
    along = Vector((sign, 0, -1)).normalized()
    across = Vector((sign, 0, 1)).normalized()
    rings = []
    section = (
        (-0.026, 0.059),
        (-0.022, 0.063),
        (0.022, 0.063),
        (0.026, 0.059),
        (0.026, 0.054),
        (0.022, 0.052),
        (-0.022, 0.052),
        (-0.026, 0.054),
    )
    for i in range(16):
        a = 2 * math.pi * i / 16
        outward = across * math.cos(a) + Vector((0, math.sin(a), 0))
        rings.append([centre + along * t + outward * (radius + frame * 0.002) for t, radius in section])
    vertices = [p for ring in rings for p in ring]
    faces = []
    for i in range(16):
        for j in range(8):
            faces.append((i * 8 + j, i * 8 + (j + 1) % 8, ((i + 1) % 16) * 8 + (j + 1) % 8, ((i + 1) % 16) * 8 + j))
    cuff = soft.mesh("WorldCuff_" + side, vertices, faces, mats["fabric"])
    paint.zone(cuff, paint.ZONE_ACCENT)
    paint.zone(cuff, paint.ZONE_TRIM, [i * 8 + j for i in range(16) for j in (0, 3)])
    paint.zone(cuff, paint.ZONE_GLOW, [1])
    return cuff


def _finish(objects, armature, surfaces):
    from build_models import attach, join_into

    for obj in objects:
        _clearance(obj, surfaces)
        if obj.name.startswith("WorldCuff"):
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            duplicate.name = "CuffFP_" + obj.name[-1]
            bpy.context.collection.objects.link(duplicate)
            low = Vector(map(min, zip(*(v.co for v in duplicate.data.vertices), strict=True)))
            high = Vector(map(max, zip(*(v.co for v in duplicate.data.vertices), strict=True)))
            attach(duplicate, (low + high) / 2)
        bone = obj.get("rigid_bone")
        if bone:
            rig.bind_rigid(obj, armature, bone)
        else:
            rig.bind(obj, armature, blend=0.16)
    shell = objects[0]
    join_into(shell, objects[1:])
    shell.name = "Shell"
    attach(shell, (0, 0, 1.3))
    bpy.context.view_layer.update()


def _build(frame):
    from build_models import marker, material, srgb

    surfaces = _body_surfaces()
    mats = {
        "fabric": material("GearFabric", srgb("#5F6D68"), roughness=0.9),
        "webbing": material("GearWebbing", srgb("#2F393B"), roughness=0.96),
        "plate": material("GearPlate", srgb("#D9D9D2"), metallic=0.5, roughness=0.55),
        "polymer": material("GearPolymer", srgb("#1C2122"), roughness=0.78),
    }
    armature = rig.build_armature()
    objects = []
    _torso(objects, mats, frame)
    _trim(objects, mats, frame)
    _shoulders(objects, mats, frame)
    if frame == 2:
        _collar(objects, mats)
    for side in ("L", "R"):
        _add(objects, _cuff(side, mats, frame), bone="forearm_" + side)
    _finish(objects, armature, surfaces)
    clip = marker("CharmClip", (0.105, -0.215, 1.38))
    clip.parent, clip.parent_type, clip.parent_bone = armature, "BONE", "spine_03"
    bpy.context.view_layer.update()
    clip.matrix_world.translation = (0.105, -0.215, 1.38)
    bpy.context.view_layer.update()


def build_vest_light():
    """Flat chest rig: slim webbing harness, two pockets and open shoulders."""
    _build(0)


def build_vest_medium():
    """Plate carrier with compact clavicle pads and a low open neckline."""
    _build(1)


def build_vest_heavy():
    """Broad shoulder armour and a tall protective collar distinguish heavy gear."""
    _build(2)
