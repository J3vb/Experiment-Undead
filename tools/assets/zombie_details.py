"""Skinned facial planes, hands and outbreak clothing details for all three zombies."""

import body_parts as soft
import bpy


def carve_mouth(body, mats):
    """A closed, recessed mouth cavity rather than a separate lip-shaped blob."""
    cutter = soft.ellipsoid("MouthCutter", (0.003, -0.082, 1.655), (0.043, 0.038, 0.018), mats["decay"])
    for _index in range(4):
        cutter.data.materials.append(mats["decay"])
    for face in cutter.data.polygons:
        face.material_index = 4
    soft.select(body)
    modifier = body.modifiers.new("Recessed mouth", "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    soft.clean(body)


def _face(armature, mats, bind):
    for sign in (-1, 1):
        ear = soft.ellipsoid("Ear", (sign * 0.093, -0.005, 1.696), (0.014, 0.014, 0.027), mats["head"], (8, 6))
        bind(ear, armature, "head")
        brow = soft.tube(
            "Brow",
            [(sign * 0.018, -0.092, 1.720), (sign * 0.044, -0.099, 1.725), (sign * 0.073, -0.079, 1.712)],
            [0.009, 0.010, 0.006],
            mats["head"],
            6,
        )
        bind(brow, armature, "head")
        eye = soft.ellipsoid(
            "EyeL" if sign > 0 else "EyeR",
            (sign * 0.041, -0.095, 1.705),
            (0.013, 0.008, 0.009),
            mats["glow"],
            (8, 6),
        )
        bind(eye, armature, "head")
    nose = soft.ellipsoid("Nose", (0, -0.099, 1.687), (0.014, 0.023, 0.026), mats["head"], (8, 6))
    bind(nose, armature, "head")
    jaw = soft.ellipsoid("Jaw", (0.004, -0.045, 1.632), (0.048, 0.035, 0.024), mats["head"], (10, 6))
    bind(jaw, armature, "head")


def _hands(armature, mats, kind, bind):
    skin = mats["dark" if kind == "bloater" else "skin"]
    for sign in (-1, 1):
        palm = soft.tube(
            "Palm",
            [(sign * 0.60, 0, 1.055), (sign * 0.644, -0.005, 1.012), (sign * 0.675, -0.008, 0.985)],
            [0.032, 0.036, 0.026],
            skin,
            8,
        )
        bind(palm, armature)
        for index, length in enumerate((0.046, 0.064, 0.057, 0.043)):
            x = sign * (0.666 - (index - 1.5) * 0.013)
            z = 1.001 - (index - 1.5) * 0.013
            finger = soft.tube(
                "Finger",
                [
                    (x, -0.006, z),
                    (x + sign * length * 0.6, -0.016, z - length * 0.6),
                    (x + sign * length * 0.7, -0.04, z - length * 0.7),
                ],
                [0.010, 0.008, 0.0045],
                skin,
                6,
            )
            bind(finger, armature, "hand_L" if sign > 0 else "hand_R")
        thumb = soft.tube(
            "Thumb",
            [(sign * 0.650, -0.008, 1.035), (sign * 0.676, -0.04, 1.037), (sign * 0.684, -0.05, 1.017)],
            [0.013, 0.01, 0.006],
            skin,
            6,
        )
        bind(thumb, armature, "hand_L" if sign > 0 else "hand_R")


def _feet(armature, mats, kind, bind):
    if kind == "crawler":
        return
    for side, sign in (("L", 1), ("R", -1)):
        shoe = kind == "bloater" or side == "R"
        foot = soft.ellipsoid(
            "Shoe" + side if shoe else "BareFoot",
            (sign * 0.11, -0.07, 0.065),
            (0.069, 0.14, 0.063),
            mats["shoe" if shoe else "skin"],
        )
        bind(foot, armature, "foot_" + side)
        if shoe:
            sole = soft.pad("WornSole", (0.13, 0.26, 0.022), (sign * 0.11, -0.07, 0.014), mats["shoe"], 0.008)
            bind(sole, armature, "foot_" + side)


def _badge(armature, mats, kind, bind):
    x, y, z = (-0.20, -0.26, 1.38) if kind == "bloater" else (-0.14, -0.122, 1.34)
    for name, size, at, mat in (
        ("Badge", (0.06, 0.012, 0.078), (x, y, z), mats["coat"]),
        ("BadgeInset", (0.04, 0.006, 0.028), (x, y - 0.009, z - 0.01), mats["shirt"]),
        ("BadgeClip", (0.012, 0.018, 0.025), (x, y, z + 0.042), mats["trousers"]),
    ):
        card = soft.pad(name, size, at, mat, 0.003)
        bind(card, armature, "spine_02")


def build(armature, mats, kind, bind):
    _face(armature, mats, bind)
    _hands(armature, mats, kind, bind)
    _feet(armature, mats, kind, bind)
    _badge(armature, mats, kind, bind)
