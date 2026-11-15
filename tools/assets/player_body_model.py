"""Lantern Post salvager: one continuous thermal undersuit with sewn winter details."""

import math

import body_parts as soft
import bpy
import character_rig as rig
import gear_paint as paint
from mathutils import Matrix, Vector


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
            (0.77, 0.104, 0.105),
            (0.64, 0.085, 0.085),
            (0.53, 0.071, 0.077),
            (0.41, 0.079, 0.079),
            (0.29, 0.065, 0.068),
            (0.17, 0.047, 0.051),
            (0.10, 0.042, 0.044),
        ):
            nodes.append((parent, (sign * 0.11, 0, z), (rx, ry)))
            parent = len(nodes) - 1
    return nodes


def _paint_bind(obj, armature, zone, bone=None):
    paint.zone(obj, zone)
    if bone:
        rig.bind_rigid(obj, armature, bone)
    else:
        rig.bind(obj, armature, blend=0.14)
    return obj


def _suit(armature, mats):
    obj = soft.skin_body(_body_nodes(), mats["suit"])
    # Projected channels follow the surface rather than sitting above it like wires.
    soft.groove(obj, [(0, z) for z in (1.07, 1.14, 1.22, 1.30, 1.38, 1.46, 1.53)], 0.004)
    for sign in (-1, 1):
        soft.groove(obj, [(sign * x, z) for x, z in ((0.05, 1.48), (0.10, 1.44), (0.15, 1.40), (0.18, 1.34))])
        soft.groove(obj, [(sign * 0.14, z) for z in (0.86, 0.78, 0.70, 0.62, 0.55, 0.47, 0.38, 0.29)])
    obj.data.materials.append(mats["knit"])
    soft.clean(obj)
    _paint_bind(obj, armature, paint.ZONE_MAIN)
    for face in obj.data.polygons:
        if sum(obj.data.vertices[i].co.z for i in face.vertices) / len(face.vertices) > 1.57:
            face.material_index = 1
            paint.zone(obj, paint.ZONE_ACCENT, [face])
    return obj


def _collar_belt(armature, mats):
    for name, z, rx, ry, height in (("Collar", 1.535, 0.086, 0.082, 0.052), ("WaistBelt", 1.00, 0.163, 0.118, 0.044)):
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
    zip_pull = soft.ellipsoid("BuckleZipPull", (0, -0.092, 1.55), (0.0045, 0.0028, 0.0105), mats["rubber"])
    _paint_bind(zip_pull, armature, paint.ZONE_TRIM, "neck")
    for z in (1.13, 1.19, 1.25, 1.31, 1.37, 1.43):
        hit, point, _n, _i = bpy.data.objects["Undersuit"].ray_cast(Vector((0.008, -0.6, z)), Vector((0, 1, 0)))
        if hit:
            tab = soft.pad("ZipperTeeth", (0.011, 0.003, 0.004), tuple(point), mats["rubber"])
            _paint_bind(tab, armature, paint.ZONE_MAIN)


def _goggles(armature, mats):
    for sign in (-1, 1):
        at = (sign * 0.048, -0.099, 1.704)
        frame = soft.ellipse_ring("GoggleFrame", at, (0.043, 0.029), 0.008, mats["rubber"])
        _paint_bind(frame, armature, paint.ZONE_ACCENT, "head")
        lens = soft.ellipsoid("GoggleLens", (at[0], -0.108, at[2]), (0.038, 0.010, 0.025), mats["lens"])
        _paint_bind(lens, armature, paint.ZONE_GLOW, "head")
        buckle = soft.pad("BuckleGoggle", (0.016, 0.024, 0.028), (sign * 0.099, -0.045, 1.702), mats["rubber"])
        _paint_bind(buckle, armature, paint.ZONE_TRIM, "head")
    bridge = soft.pad("GoggleBridge", (0.022, 0.019, 0.015), (0, -0.102, 1.704), mats["rubber"])
    _paint_bind(bridge, armature, paint.ZONE_ACCENT, "head")
    rings = [
        [(0.100 * math.cos(a), 0.104 * math.sin(a), z) for a in (2 * math.pi * j / 32 for j in range(32))]
        for z in (1.692, 1.711)
    ]
    strap = soft.loft("GoggleStrap", rings, mats["rubber"])
    _paint_bind(strap, armature, paint.ZONE_ACCENT, "head")
    eyes = bpy.data.objects.new("Eyes", None)
    bpy.context.collection.objects.link(eyes)
    eyes.parent, eyes.parent_type, eyes.parent_bone = armature, "BONE", "head"
    bpy.context.view_layer.update()
    eyes.matrix_world = Matrix.Translation((0, -0.115, 1.704))


def _patches(armature, mats):
    for side, sign in (("L", 1), ("R", -1)):
        knee = soft.pad("KneePatch" + side, (0.113, 0.017, 0.116), (sign * 0.11, -0.067, 0.54), mats["suit"], 0.007)
        _paint_bind(knee, armature, paint.ZONE_MAIN)
        elbow = soft.pad("ElbowPatch" + side, (0.098, 0.018, 0.105), (sign * 0.41, 0.052, 1.25), mats["suit"], 0.008)
        elbow.rotation_euler.y = -sign * math.pi / 4
        _paint_bind(elbow, armature, paint.ZONE_MAIN)
        for z in (0.510, 0.535, 0.560):
            stitch = soft.pad("KneeStitch", (0.084, 0.003, 0.004), (sign * 0.11, -0.077, z), mats["knit"])
            _paint_bind(stitch, armature, paint.ZONE_MAIN)


def _gloves(armature, mats):
    for side, sign in (("L", 1), ("R", -1)):
        palm = soft.ellipsoid("GlovePalm" + side, (sign * 0.649, 0, 1.011), (0.046, 0.027, 0.055), mats["rubber"])
        palm.rotation_euler.y = -sign * math.pi / 4
        _paint_bind(palm, armature, paint.ZONE_ACCENT)
        cuff = soft.tube(
            "GloveCuff" + side, [(sign * 0.598, 0, 1.062), (sign * 0.621, 0, 1.039)], [0.047, 0.046], mats["knit"], 12
        )
        _paint_bind(cuff, armature, paint.ZONE_ACCENT)
        for i, length in enumerate((0.046, 0.061, 0.057, 0.043)):
            offset = (i - 1.5) * 0.016
            root = Vector((sign * (0.675 + offset * 0.707), -0.004, 0.985 + offset * 0.707))
            direction = Vector((sign * 0.707, 0, -0.707))
            points = [
                root,
                root + direction * length * 0.5 + Vector((0, -0.005, 0)),
                root + direction * length * 0.78 + Vector((0, -0.022, 0)),
                root + direction * length * 0.66 + Vector((0, -0.039, 0)),
            ]
            finger = soft.tube("GloveFinger" + side, points, [0.010, 0.010, 0.009, 0.006], mats["rubber"])
            _paint_bind(finger, armature, paint.ZONE_ACCENT)
            knuckle = soft.ellipsoid(
                "KnucklePad", tuple(root + Vector((0, 0.019, 0))), (0.011, 0.008, 0.014), mats["knit"]
            )
            _paint_bind(knuckle, armature, paint.ZONE_ACCENT)
        thumb = soft.tube(
            "GloveThumb" + side,
            [(sign * 0.641, -0.01, 0.983), (sign * 0.648, -0.039, 0.970), (sign * 0.675, -0.044, 0.964)],
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
    parts = []
    for y in (-0.175, -0.125, -0.075, -0.025, 0.04):
        for x in (-0.042, 0.042):
            parts.append(soft.pad("Tread", (0.049, 0.033, 0.019), (sign * 0.11 + x, y, 0.0095), mats["rubber"], 0.004))
    for z, y in ((0.104, -0.105), (0.122, -0.082), (0.142, -0.060), (0.165, -0.057)):
        parts.append(soft.pad("BootLace", (0.067, 0.009, 0.007), (sign * 0.11, y, z), mats["knit"], 0.003))
    cuff = soft.pad("BootCuff", (0.109, 0.119, 0.026), (sign * 0.11, 0, 0.204), mats["knit"], 0.011)
    parts.append(cuff)
    join_into(boot, parts)
    _paint_bind(boot, armature, paint.ZONE_ACCENT, "foot_" + side)


def _join_details():
    """Keep one continuous suit; batch overlay parts that share the same rig."""
    from build_models import join_into

    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    goggles = [obj for obj in objects if obj.name.startswith(("Goggle", "BuckleGoggle"))]
    belt = [obj for obj in objects if obj.name.startswith(("BuckleBelt", "BuckleInset"))]
    retained = {bpy.data.objects[name] for name in ("Undersuit", "BootL", "BootR", "BuckleZipPull")}
    details = [obj for obj in objects if obj not in retained and obj not in goggles and obj not in belt]
    for name, parts in (("Goggles", goggles), ("BuckleBelt", belt), ("ThermalDetails", details)):
        join_into(parts[0], parts[1:])
        parts[0].name = name


def build_player():
    """Build the shared 22-bone body in metres, facing Blender -Y / Godot +Z."""
    from build_models import material, srgb

    mats = {
        "suit": material("BodySuit", srgb("#5F6D68"), roughness=0.88),
        "knit": material("BodyKnit", srgb("#2F393B"), roughness=0.96),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
        "lens": material("BodyLens", srgb("#3FE0C8"), metallic=0.45, roughness=0.16),
    }
    armature = rig.build_armature()
    _suit(armature, mats)
    _collar_belt(armature, mats)
    _goggles(armature, mats)
    _patches(armature, mats)
    _gloves(armature, mats)
    for side, sign in (("L", 1), ("R", -1)):
        _boot(armature, mats, side, sign)
    _join_details()
    bpy.context.view_layer.update()
