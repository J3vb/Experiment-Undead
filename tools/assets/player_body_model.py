"""Lantern Post survivor: field jacket and trousers on one continuous body, bearded head, bare hands."""

import math

import body_parts as soft
import bpy
import character_rig as rig
import gear_paint as paint
import player_clips
import player_head_model as head
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
    """Identical tailored surface for the world body and the first-person sleeves."""
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


def _suit(armature, mats):
    obj = sleeve_surface(mats["suit"])
    for sign in (-1, 1):
        soft.refine_patch(obj, (sign * 0.11, 0, 0.53), 0.13)
        for z, depth in ((0.47, 0.006), (0.53, 0.008), (0.59, 0.005), (0.24, 0.004)):
            soft.fabric_fold(obj, (sign * 0.11, 0, z), (sign * 0.16, 0.22, 1), 0.030, depth, 0.105)
    for z in (1.045, 1.085):
        soft.fabric_fold(obj, (0, 0, z), (0, 0.12, 1), 0.024, 0.005, 0.19)
    head.sculpt(obj)
    # Projected channels follow the surface rather than sitting above it like wires.
    soft.groove(obj, [(0, z) for z in (1.07, 1.14, 1.22, 1.30, 1.38, 1.46, 1.53)], 0.004)
    for sign in (-1, 1):
        soft.groove(obj, [(sign * 0.14, z) for z in (0.86, 0.78, 0.70, 0.62, 0.55, 0.47, 0.38, 0.29)])
    obj.data.materials.append(mats["hair"])
    obj.data.materials.append(mats["skin"])
    soft.clean(obj)
    _paint_bind(obj, armature, paint.ZONE_MAIN)
    head.paint_head(obj, skin_index=2, hair_index=1)
    return obj


def _belt(armature, mats):
    for name, z, rx, ry, height in (("WaistBelt", 1.00, 0.163, 0.118, 0.044),):
        rings = []
        for dz, expansion in (
            (-height / 2, 0),
            (-height / 2 + 0.005, 0.004),
            (height / 2 - 0.005, 0.004),
            (height / 2, 0),
        ):
            rings.append(
                [
                    (math.cos(a) * (rx + expansion), math.sin(a) * (ry + expansion), z + dz)
                    for a in (2 * math.pi * j / 24 for j in range(24))
                ]
            )
        obj = soft.loft(name, rings, mats["suit"])
        _paint_bind(obj, armature, paint.ZONE_MAIN)
    buckle = soft.pad("BuckleBelt", (0.055, 0.017, 0.035), (0, -0.132, 1.00), mats["rubber"])
    _paint_bind(buckle, armature, paint.ZONE_TRIM, "pelvis")
    for x in (-0.019, 0.019):
        keeper = soft.pad("BuckleInset", (0.008, 0.006, 0.020), (x, -0.143, 1.00), mats["suit"])
        _paint_bind(keeper, armature, paint.ZONE_TRIM, "pelvis")
    for z in (1.13, 1.19, 1.25, 1.31, 1.37, 1.43):
        hit, point, _n, _i = bpy.data.objects["Undersuit"].ray_cast(Vector((0.008, -0.6, z)), Vector((0, 1, 0)))
        if hit:
            tab = soft.pad("ZipperTeeth", (0.011, 0.003, 0.004), tuple(point), mats["rubber"])
            _paint_bind(tab, armature, paint.ZONE_MAIN)


def _patches(armature, mats):
    for side, sign in (("L", 1), ("R", -1)):
        knee = soft.pad("KneePatch" + side, (0.113, 0.017, 0.116), (sign * 0.11, -0.067, 0.54), mats["rubber"], 0.007)
        for vertex in knee.data.vertices:
            vertex.co.x *= 0.78 + 0.22 * (1 - abs(vertex.co.z) / 0.058)
            vertex.co.y += 0.012 * (vertex.co.x / 0.0565) ** 2
        _paint_bind(knee, armature, paint.ZONE_ACCENT)
        elbow = soft.pad("ElbowPatch" + side, (0.098, 0.018, 0.105), (sign * 0.41, 0.052, 1.25), mats["knit"], 0.008)
        elbow.rotation_euler.y = -sign * math.pi / 4
        _paint_bind(elbow, armature, paint.ZONE_ACCENT)
        for z in (0.510, 0.535, 0.560):
            stitch = soft.pad("KneeStitch", (0.084, 0.003, 0.004), (sign * 0.11, -0.077, z), mats["knit"])
            _paint_bind(stitch, armature, paint.ZONE_MAIN)
        _cargo_pocket(armature, mats, side, sign)


def _cargo_pocket(armature, mats, side, sign):
    """Bellows pocket and flap on the outer thigh, rigid on the thigh."""
    hit, point, _normal, _index = bpy.data.objects["Undersuit"].ray_cast(
        Vector((sign * 0.6, -0.01, 0.71)), Vector((-sign, 0, 0))
    )
    if not hit:
        raise ValueError("cargo pocket must sit on the thigh")
    at = point + Vector((sign * 0.012, 0, 0))
    pocket = soft.pad("CargoPocket" + side, (0.026, 0.105, 0.125), tuple(at), mats["suit"], 0.008)
    _paint_bind(pocket, armature, paint.ZONE_MAIN, "thigh_" + side)
    flap = soft.pad(
        "CargoFlap" + side, (0.032, 0.112, 0.032), tuple(at + Vector((sign * 0.004, 0, 0.058))), mats["suit"], 0.006
    )
    _paint_bind(flap, armature, paint.ZONE_ACCENT, "thigh_" + side)


def _gloves(armature, mats):
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


def _boot(armature, mats, side, sign):
    from build_models import join_into

    # Eight-point last: broad rounded toe, narrow heel, flared stitched welt.
    outline = [(-0.72, -1), (0.72, -1), (1, -0.72), (0.86, 0.65), (0.62, 1), (-0.62, 1), (-0.86, 0.65), (-1, -0.72)]
    rings = []
    for z, width, length, cy in (
        (0.012, 0.073, 0.152, -0.061),
        (0.036, 0.076, 0.156, -0.061),
        (0.055, 0.070, 0.148, -0.061),
        (0.083, 0.067, 0.140, -0.061),
        (0.110, 0.060, 0.123, -0.045),
        (0.155, 0.052, 0.063, 0),
        (0.210, 0.052, 0.060, 0),
    ):
        rings.append([(sign * 0.11 + x * width, cy + y * length, z) for x, y in outline])
    boot = soft.loft("Boot" + side, rings, mats["rubber"])
    boot.data.materials.append(mats["knit"])
    for face in boot.data.polygons:
        z = sum(boot.data.vertices[index].co.z for index in face.vertices) / len(face.vertices)
        if 0.036 < z < 0.055 or z > 0.15:
            face.material_index = 1
    parts = _boot_details(boot, mats, sign)
    join_into(boot, parts)
    _paint_bind(boot, armature, paint.ZONE_ACCENT, "foot_" + side)


def _boot_details(boot, mats, sign):
    """Crossed lacing on the sloped vamp and a raised rubber toe reinforcement."""
    parts = []
    for y in (-0.175, -0.125, -0.075, -0.025, 0.04):
        for x in (-0.042, 0.042):
            parts.append(soft.pad("Tread", (0.049, 0.033, 0.019), (sign * 0.11 + x, y, 0.0095), mats["rubber"], 0.004))
    for z in (0.124, 0.145, 0.166, 0.188):
        for diagonal in (-1, 1):
            points = []
            for x in (-0.025, 0, 0.025):
                hit, point, normal, _face = boot.ray_cast(
                    Vector((sign * 0.11 + x, -0.4, z + diagonal * x * 0.22)), Vector((0, 1, 0))
                )
                if not hit:
                    raise ValueError("boot lace must follow the vamp")
                points.append(point + normal * 0.0015)
            parts.append(soft.tube("BootLace", points, [0.0028] * len(points), mats["knit"], 6))
    toe = soft.pad("ToeGuard", (0.119, 0.073, 0.019), (sign * 0.11, -0.152, 0.092), mats["rubber"], 0.007)
    bpy.context.view_layer.update()
    for vertex in toe.data.vertices:
        point = toe.matrix_world @ vertex.co
        hit, surface, _normal, _face = boot.ray_cast(Vector((point.x, point.y, 0.3)), Vector((0, 0, -1)))
        if not hit:
            raise ValueError("toe reinforcement must follow the boot")
        vertex.co.z = surface.z - toe.location.z + 0.001 + (vertex.co.z + 0.0095) * 0.3
    parts.append(toe)
    cuff = soft.pad("BootCuff", (0.109, 0.119, 0.026), (sign * 0.11, 0, 0.204), mats["knit"], 0.011)
    parts.append(cuff)
    return parts


def _join_details():
    """Keep one continuous body; batch overlay parts that share the same rig."""
    from build_models import join_into

    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    face = [obj for obj in objects if obj.name.startswith("Face")]
    belt = [obj for obj in objects if obj.name.startswith(("BuckleBelt", "BuckleInset"))]
    retained = {bpy.data.objects[name] for name in ("Undersuit", "BootL", "BootR")}
    details = [obj for obj in objects if obj not in retained and obj not in face and obj not in belt]
    for name, parts in (("FaceDetails", face), ("BuckleBelt", belt), ("FieldDetails", details)):
        join_into(parts[0], parts[1:])
        parts[0].name = name


def build_player():
    """Build the shared 22-bone body in metres, facing Blender -Y / Godot +Z."""
    from build_models import material, srgb

    mats = {
        "suit": material("BodySuit", srgb("#4A4A3B"), roughness=0.9),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
        "skin": material("BodySkin", srgb("#8A6650"), roughness=0.6),
        "hair": material("BodyHair", srgb("#3A2C22"), roughness=0.85),
    }
    # Field clothes have no separate knit: cuffs and patches are jacket fabric.
    mats["knit"] = mats["suit"]
    armature = rig.build_armature()
    suit = _suit(armature, mats)
    _belt(armature, mats)
    head.details(armature, mats, suit)
    _patches(armature, mats)
    _gloves(armature, {**mats, "rubber": mats["skin"]})
    for knuckle in [obj for obj in bpy.context.scene.objects if obj.name.startswith("KnucklePad")]:
        bpy.data.objects.remove(knuckle, do_unlink=True)
    for side, sign in (("L", 1), ("R", -1)):
        _boot(armature, mats, side, sign)
    _join_details()
    bpy.context.view_layer.update()
    player_clips.build_clips(armature)
