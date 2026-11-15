"""First-person thermal sleeves and reinforced grip gloves on the shared body rig."""

import math

import bpy

# isort: split
import bmesh
import body_parts as soft
import character_rig as rig
import gear_paint as paint
import player_body_model as body
from mathutils import Matrix, Vector


def _materials():
    from build_models import material, srgb

    return {
        "suit": material("BodySuit", srgb("#5F6D68"), roughness=0.88),
        "knit": material("BodyKnit", srgb("#2F393B"), roughness=0.96),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
    }


def _sleeves(mats):
    """Cut the body's actual sleeve surface halfway down each upper arm."""
    source = soft.skin_body(body._body_nodes(), mats["suit"])
    for side, sign in (("L", 1), ("R", -1)):
        data = source.data.copy()
        obj = bpy.data.objects.new("Sleeve" + side, data)
        bpy.context.collection.objects.link(obj)
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.bisect_plane(
            bm,
            geom=[*bm.verts, *bm.edges, *bm.faces],
            plane_co=(sign * 0.30, 0, 0),
            plane_no=(sign, 0, 0),
            clear_inner=True,
            dist=1e-6,
        )
        bmesh.ops.holes_fill(bm, edges=[edge for edge in bm.edges if edge.is_boundary])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(data)
        bm.free()
        paint.zone(obj, paint.ZONE_MAIN)
    bpy.data.objects.remove(source, do_unlink=True)


def _frame(sign):
    across = Vector((sign, 0, 1)).normalized()
    along = Vector((sign, 0, -1)).normalized()
    inward = Vector((0, -1, 0))
    return across, along, inward


def _finger_path(root, sign, diameter, index):
    """Wrap the glove around the clear inner grip diameter, without finger bones."""
    _across, along, inward = _frame(sign)
    radius = diameter / 2 + 0.009
    end_angle = math.pi / 2 + (0.10, 0.32, 0.27, 0.04)[index]
    points = []
    for step in range(10):
        angle = -math.pi / 2 + (end_angle + math.pi / 2) * step / 9
        points.append(root + along * (radius * math.cos(angle)) + inward * (radius * (1 + math.sin(angle))))
    return points


def _tip_marker(name, point, armature, side):
    obj = bpy.data.objects.new(name + "_" + side, None)
    bpy.context.collection.objects.link(obj)
    obj.parent, obj.parent_type, obj.parent_bone = armature, "BONE", "hand_" + side
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Translation(point)


def _fingers(armature, mats, side, sign):
    across, along, inward = _frame(sign)
    diameter = 0.032 if side == "R" else 0.045
    for index in range(4):
        offset = (index - 1.5) * 0.016
        root = Vector((sign * (0.675 + offset * 0.707), -0.004, 0.985 + offset * 0.707))
        points = _finger_path(root, sign, diameter, index)
        finger = soft.tube(
            "GripFinger" + side,
            points,
            [0.010, 0.010, 0.010, 0.010, 0.0095, 0.009, 0.008, 0.007, 0.005, 0.002],
            mats["rubber"],
            12,
        )
        paint.zone(finger, paint.ZONE_ACCENT)
        for joint in (3, 6):
            pad = soft.pad(
                "FingerPad" + side, (0.018, 0.005, 0.020), points[joint] - inward * 0.008, mats["knit"], 0.002
            )
            pad.rotation_euler.y = -sign * math.pi / 4
            paint.zone(pad, paint.ZONE_ACCENT)
        if index == 0:
            index_tip = points[-1]
            _tip_marker("GripIndexTip", index_tip, armature, side)
    thumb_tip = index_tip - inward * diameter
    start = Vector((sign * 0.641, -0.01, 0.983))
    points = [
        start,
        start - across * 0.012 + inward * 0.006,
        start - across * 0.017 + inward * 0.019,
        thumb_tip - across * 0.018 + along * 0.004,
        thumb_tip - across * 0.009,
        thumb_tip,
    ]
    thumb = soft.tube("GripThumb" + side, points, [0.014, 0.014, 0.013, 0.011, 0.008, 0.002], mats["rubber"], 12)
    paint.zone(thumb, paint.ZONE_ACCENT)
    _tip_marker("GripThumbTip", thumb_tip, armature, side)


def _wrist_details(mats, side, sign):
    _across, along, inward = _frame(sign)
    centre = Vector((sign * 0.603, 0, 1.057))
    # Same round knitted cuff as the body, with a narrow rubber retention strap.
    rib = soft.ellipse_ring("CuffRib" + side, (0, 0, 0), (0.047, 0.047), 0.0015, mats["knit"])
    rib.rotation_euler = Vector((0, 1, 0)).rotation_difference(along).to_euler()
    rib.location = centre + along * 0.008
    paint.zone(rib, paint.ZONE_ACCENT)
    strap = soft.pad("WristStrap" + side, (0.054, 0.009, 0.021), centre - inward * 0.046, mats["rubber"], 0.003)
    strap.rotation_euler.y = -sign * math.pi / 4
    paint.zone(strap, paint.ZONE_ACCENT)
    keeper = soft.pad("StrapKeeper" + side, (0.010, 0.004, 0.027), centre - inward * 0.052, mats["knit"], 0.002)
    keeper.rotation_euler.y = -sign * math.pi / 4
    paint.zone(keeper, paint.ZONE_TRIM)


def _stitching(mats, side, sign):
    across, along, inward = _frame(sign)
    palm = Vector((sign * 0.649, 0, 1.011))
    lines = [
        ("GloveStitch", edge * 0.031, [(index - 4) * 0.007 + delta for delta in (0, 0.0035)], 0.0008)
        for edge in (-1, 1)
        for index in range(9)
    ]
    lines += [("BackSeam", (index - 1.5) * 0.016, [-0.020, 0.0025, 0.025], 0.0012) for index in range(4)]
    for name, u, distances, radius in lines:
        points = []
        for v in distances:
            depth = 0.027 * math.sqrt(max(0, 1 - (u / 0.046) ** 2 - (v / 0.055) ** 2))
            points.append(palm + across * u + along * v - inward * (depth + 0.0003))
        seam = soft.tube(name + side, points, [radius] * len(points), mats["knit"], 5)
        paint.zone(seam, paint.ZONE_ACCENT)


def build_player_arms():
    """Keep the body's A-pose rest rig; a later viewmodel task supplies the arm pose."""
    from build_models import join_into

    mats = _materials()
    armature = rig.build_armature()
    _sleeves(mats)
    body._gloves(armature, mats)
    # Preserve the world body's palms, knit cuffs and knuckle pads; replace only curls.
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith(("GloveFinger", "GloveThumb")):
            bpy.data.objects.remove(obj, do_unlink=True)
    for side, sign in (("L", 1), ("R", -1)):
        _fingers(armature, mats, side, sign)
        _wrist_details(mats, side, sign)
        _stitching(mats, side, sign)
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    target = objects[0]
    join_into(target, objects[1:])
    target.name = "PlayerArms"
    soft.clean(target)
    rig.bind(target, armature, blend=0.08)
    bpy.context.view_layer.update()
