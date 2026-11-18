"""First-person sleeve surface and gloves, from the earlier salvager body (F-70 step 6 replaces them)."""

import math

import body_parts as soft
import character_rig as rig
import gear_paint as paint
from mathutils import Vector


def _body_nodes():
    nodes = [(None, (0, 0, 0.99), (0.145, 0.108))]
    for z, rx, ry in (
        (1.10, 0.15, 0.095),
        (1.25, 0.195, 0.112),
        (1.43, 0.215, 0.105),
        (1.53, 0.068, 0.068),
        (1.61, 0.078, 0.084),
        (1.70, 0.10, 0.102),
        (1.81, 0.067, 0.075),
    ):
        nodes.append((len(nodes) - 1, (0, 0, z), (rx, ry)))
    for sign in (-1, 1):
        parent = 3
        for x, z, rx, ry in (
            (0.23, 1.46, 0.10, 0.095),
            (0.32, 1.35, 0.077, 0.075),
            (0.41, 1.25, 0.059, 0.062),
            (0.49, 1.17, 0.067, 0.063),
            (0.60, 1.06, 0.042, 0.044),
            (0.63, 1.03, 0.036, 0.038),
        ):
            nodes.append((parent, (sign * x, 0, z), (rx, ry)))
            parent = len(nodes) - 1
        parent = 0
        for z, rx, ry in (
            (0.90, 0.105, 0.105),
            (0.77, 0.112, 0.112),
            (0.64, 0.082, 0.089),
            (0.53, 0.071, 0.077),
            (0.41, 0.082, 0.087),
            (0.29, 0.065, 0.068),
            (0.17, 0.047, 0.051),
            (0.10, 0.042, 0.044),
        ):
            y = 0.012 if z == 0.41 else (-0.008 if z == 0.53 else 0)
            nodes.append((parent, (sign * 0.11, y, z), (rx, ry)))
            parent = len(nodes) - 1
    return nodes


def _paint_bind(obj, armature, zone, bone=None):
    paint.zone(obj, zone)
    if bone:
        rig.bind_rigid(obj, armature, bone)
    else:
        rig.bind(obj, armature, blend=0.14)
    return obj


def sleeve_surface(mat):
    """Tailored sleeve surface the first-person arms are cut from."""
    obj = soft.skin_body(_body_nodes(), mat)
    for sign in (-1, 1):
        soft.refine_patch(obj, (sign * 0.43, 0, 1.23), 0.18)
        axis = (sign, 0.18, -1)
        for offset, depth in ((-0.038, 0.004), (0, 0.007), (0.038, 0.004)):
            centre = (sign * (0.41 + offset), 0, 1.25 - offset)
            soft.fabric_fold(obj, centre, axis, 0.030, depth, 0.095)
        for x in (0.49, 0.58):
            soft.fabric_fold(obj, (sign * x, 0, 1.66 - x), (sign, 0.35, -1), 0.018, 0.004, 0.080)
    return obj


def gloves(armature, mats):
    for side, sign in (("L", 1), ("R", -1)):
        across, along = Vector((-sign, 0, -1)).normalized(), Vector((sign, 0, -1)).normalized()
        inward, centre = Vector((0, -1, 0)), Vector((sign * 0.649, 0, 1.011))
        palm = soft.ellipsoid(
            "GlovePalm" + side, (sign * 0.649, 0, 1.011), (0.046, 0.027, 0.055), mats["rubber"], (20, 12)
        )
        palm.rotation_euler.y = -sign * math.pi / 4
        _paint_bind(palm, armature, paint.ZONE_ACCENT)
        cuff = soft.tube(
            "GloveCuff" + side, [(sign * 0.598, 0, 1.062), (sign * 0.621, 0, 1.039)], [0.047, 0.046], mats["knit"], 12
        )
        _paint_bind(cuff, armature, paint.ZONE_ACCENT)
        for i, length in enumerate((0.046, 0.061, 0.057, 0.043)):
            offset = (i - 1.5) * 0.016
            root = Vector((sign * 0.675, -0.004, 0.985)) + across * offset
            points = [
                root,
                root + along * length * 0.5 + inward * 0.005,
                root + along * length * 0.78 + inward * 0.022,
                root + along * length * 0.82 + inward * 0.039,
            ]
            finger = soft.tube("GloveFinger" + side, points, [0.010, 0.010, 0.009, 0.006], mats["rubber"])
            _paint_bind(finger, armature, paint.ZONE_ACCENT)
            knuckle = soft.pad(
                "KnucklePad", (0.014, 0.008, 0.022), tuple(root + Vector((0, 0.018, 0))), mats["knit"], 0.003
            )
            knuckle.rotation_euler.y = -sign * math.pi / 4
            _paint_bind(knuckle, armature, paint.ZONE_ACCENT)
        thumb = soft.tube(
            "GloveThumb" + side,
            [
                centre + across * u + along * v + inward * w
                for u, v, w in ((-0.0255, 0.0141, 0.010), (-0.0297, 0.0283, 0.039), (-0.0148, 0.0516, 0.044))
            ],
            [0.014, 0.013, 0.008],
            mats["rubber"],
        )
        _paint_bind(thumb, armature, paint.ZONE_ACCENT)
