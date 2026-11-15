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

GRIP_HALVES = {0.032: (0.026, 0.0185), 0.045: (0.033, 0.033)}
FINGER_RADII = (0.010, 0.010, 0.0105, 0.010, 0.009, 0.009, 0.008, 0.007, 0.005, 0.002)
FINGER_SCALES = (0.98, 1.0, 0.96, 0.86)


def _materials():
    from build_models import material, srgb

    return {
        "suit": material("BodySuit", srgb("#5F6D68"), roughness=0.88),
        "knit": material("BodyKnit", srgb("#2F393B"), roughness=0.96),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
    }


def _sleeves(mats):
    """Cut the body's actual sleeve surface halfway down each upper arm."""
    source = body.sleeve_surface(mats["suit"])
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
    """Index-to-little, wrist-to-fingers and palm inward; each hand keeps its chirality."""
    across = Vector((-sign, 0, -1)).normalized()
    along = Vector((sign, 0, -1)).normalized()
    inward = Vector((0, -1, 0))
    return across, along, inward


def _grip_axes(sign, gap):
    """Weapon axis and depth direction in a naturally oblique grasp frame."""
    across, along, inward = _frame(sign)
    if gap == 0.045:
        return -across * 0.8 + along * (0.6 * math.sqrt(0.96)) - inward * 0.12, along
    angle = math.atan2(0.34, 0.94) + math.pi / 6
    return across * math.cos(angle) - along * math.sin(angle), across * math.sin(angle) + along * math.cos(angle)


def _grip_centre(root, sign, gap):
    across, _along, _inward = _frame(sign)
    axis, _depth = _grip_axes(sign, gap)
    centre = Vector((sign * 0.675, -0.045 if gap == 0.032 else -0.057, 0.985))
    return centre + axis * ((root - centre).dot(across) / axis.dot(across))


def _bore_point(centre, sign, gap, angle, radius):
    """Offset a fingertip or phalanx from the actual grip cross section."""
    across, along, inward = _frame(sign)
    axis, depth = _grip_axes(sign, gap)
    half_length, half_depth = GRIP_HALVES[gap]
    direction = along * math.cos(angle) + inward * math.sin(angle)
    if gap == 0.045:
        radial = direction - axis * direction.dot(axis)
        surface = direction * (half_length / radial.length)
        normal = radial.normalized()
    else:
        u, v = direction.dot(depth) / half_length, direction.dot(inward) / half_depth
        distance = (abs(u) ** 8 + abs(v) ** 8) ** (-1 / 8)
        surface = direction * distance
        normal = (
            depth * ((u * distance) ** 7 / half_length) + inward * ((v * distance) ** 7 / half_depth)
        ).normalized()
    outward = (normal - across * normal.dot(across)).normalized()
    return centre + surface + outward * ((radius + 0.0015) / outward.dot(normal))


def _finger_path(root, sign, diameter, index):
    """Curl around the grip while leaving the fingertips opposed to the thumb."""
    _across, along, _inward = _frame(sign)
    centre = _grip_centre(root, sign, diameter)
    low, high = -math.pi, 0.0
    for _step in range(24):
        angle = (low + high) / 2
        start = _bore_point(centre, sign, diameter, angle, FINGER_RADII[0] * FINGER_SCALES[index])
        if (start - root).dot(along) > 0:
            high = angle
        else:
            low = angle
    start_angle = (low + high) / 2
    end_angle = 0.65 + (0, 0.20, 0.15, -0.12)[index]
    fractions = (0, 0.13, 0.27, 0.40, 0.50, 0.61, 0.72, 0.83, 0.94, 1.0)
    angles = [start_angle + (end_angle - start_angle) * fraction for fraction in fractions]
    if diameter == 0.032:
        axis, _depth = _grip_axes(sign, diameter)
        across, _along, _inward = _frame(sign)
        corner = math.atan(GRIP_HALVES[diameter][1] * axis.dot(across) / GRIP_HALVES[diameter][0])
        angles = [start_angle, (start_angle - corner - 0.18) / 2]
        angles += [-corner + offset for offset in (-0.18, -0.08, 0, 0.08, 0.18)]
        angles += [0] + [corner + offset for offset in (-0.18, -0.08, 0, 0.08, 0.18)] + [end_angle]
    points = [
        _bore_point(centre, sign, diameter, angle, radius)
        for angle, radius in zip(angles, _finger_radii(diameter, index), strict=True)
    ]
    return _firing_curl(points, sign, index) if diameter == 0.032 else points


def _firing_curl(points, sign, index):
    """Separate the trigger finger from the three curls beneath the guard."""
    across, along, _inward = _frame(sign)
    axis, _depth = _grip_axes(sign, 0.032)
    shift = (across * math.sqrt(0.75) - along * 0.5) * 0.018 if index == 0 else axis * 0.027
    result = []
    for row, point in enumerate(points):
        blend = min(1.0, row / 4)
        result.append(point + shift * blend * blend * (3 - 2 * blend))
    return result


def _finger_radii(gap, index):
    radii = FINGER_RADII
    if gap == 0.032:
        radii = (0.010, 0.010, 0.0105, 0.0105, 0.010, 0.0097, 0.0095, 0.009, 0.0085, 0.008, 0.007, 0.006, 0.004, 0.002)
    return [radius * FINGER_SCALES[index] for radius in radii]


def _grip_tube(name, points, radii, mat, sign):
    """Keep the sweep frame continuous while fingers bend past the grip centre."""
    across, _along, _inward = _frame(sign)
    rings = []
    for index, (point, radius) in enumerate(zip(points, radii, strict=True)):
        tangent = (points[min(index + 1, len(points) - 1)] - points[max(0, index - 1)]).normalized()
        width = (across - tangent * across.dot(tangent)).normalized()
        normal = tangent.cross(width)
        rings.append(
            [
                point + radius * (width * math.cos(angle) + normal * math.sin(angle))
                for angle in (2 * math.pi * step / 12 for step in range(12))
            ]
        )
    return soft.loft(name, rings, mat)


def _finger_pad(points, radii, joint, sign, mat):
    """A thin curved reinforcement seats into the rubber around a knuckle."""
    across, _along, _inward = _frame(sign)
    rings = []
    outline = [
        (-1, -0.0005),
        (-0.75, -0.0012),
        (0.75, -0.0012),
        (1, -0.0005),
        (0.75, 0.0012),
        (0, 0.0012),
        (-0.75, 0.0012),
    ]
    for index, width in ((joint - 1, 0.72), (joint, 1.0), (joint + 1, 0.72)):
        tangent = (points[index + 1] - points[index - 1]).normalized()
        width_axis = (across - tangent * across.dot(tangent)).normalized()
        outward = tangent.cross(width_axis) * sign
        half_width = min(0.008, radii[index] * 0.82) * width
        rings.append(
            [
                points[index]
                + outward * (math.sqrt(radii[index] ** 2 - (side * half_width) ** 2) + depth)
                + width_axis * side * half_width
                for side, depth in outline
            ]
        )
    return soft.loft("FingerPad" + ("L" if sign == 1 else "R"), rings, mat)


def _tip_marker(name, point, armature, side):
    obj = bpy.data.objects.new(name + "_" + side, None)
    bpy.context.collection.objects.link(obj)
    obj.parent, obj.parent_type, obj.parent_bone = armature, "BONE", "hand_" + side
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Translation(point)


def _fingers(armature, mats, side, sign):
    across, _along, _inward = _frame(sign)
    diameter = 0.032 if side == "R" else 0.045
    for index in range(4):
        offset = (index - 1.5) * 0.016
        root = Vector((sign * 0.675, -0.017 if side == "R" else -0.012, 0.985)) + across * offset
        points = _finger_path(root, sign, diameter, index)
        radii = _finger_radii(diameter, index)
        finger = _grip_tube("GripFinger" + side, points, radii, mats["rubber"], sign)
        paint.zone(finger, paint.ZONE_ACCENT)
        for joint in (4, 10) if side == "R" else (3, 6):
            pad = _finger_pad(points, radii, joint, sign, mats["knit"])
            paint.zone(pad, paint.ZONE_ACCENT)
        if index == 0:
            index_tip = points[-1]
            centre = _grip_centre(root, sign, diameter)
            _tip_marker("GripIndexTip", index_tip, armature, side)
    points = _thumb_path(index_tip, centre, sign, diameter)
    radii = [0.014, 0.014, 0.013, 0.011, 0.008, 0.002]
    if side == "R":
        radii = [0.014, 0.014, 0.013, 0.012, 0.011, 0.010, 0.008, 0.006, 0.004, 0.002]
    thumb = _grip_tube("GripThumb" + side, points, radii, mats["rubber"], sign)
    paint.zone(thumb, paint.ZONE_ACCENT)
    _tip_marker("GripThumbTip", points[-1], armature, side)


def _thumb_path(index_tip, centre, sign, gap):
    """Oppose the thumb around the clear bore; tip spacing is a chord, not its diameter."""
    across, along, inward = _frame(sign)
    if gap == 0.032:
        index_tip = index_tip - (across * math.sqrt(0.75) - along * 0.5) * 0.018
    high = 0.65
    low = high - math.pi
    for _step in range(32):
        angle = (low + high) / 2
        tip = _bore_point(centre, sign, gap, angle, 0.002)
        if (tip - index_tip).length > gap:
            low = angle
        else:
            high = angle
    angle = (low + high) / 2
    start = Vector((sign * 0.649, 0, 1.011)) - across * 0.034 - along * 0.006 + inward * 0.008
    axis, _depth = _grip_axes(sign, gap)
    points = [start]
    sections = [
        (-2.62, 0.014, 0.009),
        (-1.92, 0.013, 0.014),
        (-1.31, 0.011, 0.010),
        ((-1.31 + angle) / 2, 0.008, 0.004),
        (angle, 0.002, 0),
    ]
    if gap == 0.032:
        corner = math.atan(GRIP_HALVES[gap][1] * axis.dot(across) / GRIP_HALVES[gap][0])
        sections = [(-2.62, 0.014, 0.009), (-1.92, 0.013, 0.014), (-1.31, 0.012, 0.012)]
        sections += [((-1.31 - corner - 0.18) / 2, 0.011, 0.010)]
        sections += [
            (-corner + delta, radius, offset)
            for delta, radius, offset in [
                (-0.18, 0.010, 0.008),
                (-0.08, 0.008, 0.006),
                (0, 0.006, 0.004),
                (0.08, 0.004, 0.002),
            ]
        ]
        sections += [(angle, 0.002, 0)]
    for theta, radius, offset in sections:
        row = centre - axis * (offset / axis.dot(across))
        points.append(_bore_point(row, sign, gap, theta, radius))
    return _firing_curl(points, sign, 0) if gap == 0.032 else points


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
    lines += [("BackSeam", (index - 1.5) * 0.016, [-0.020, 0.0025, 0.025], 0.0007) for index in range(4)]
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
