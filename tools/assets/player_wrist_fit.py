"""Compress gun-facing wrist fabric inside the authored grip morphs, preserving rest fit."""

import math

import body_parts as soft
import bpy
from mathutils import Matrix, Vector
from player_arm_morphs import add_variant
from player_grip_profiles import PROFILES


def press_fabric(obj, centre, axis, normal, limit, width):
    """Flatten one cuff side toward a plane, tapering inward pressure along the wrist."""
    centre, axis, normal = Vector(centre), Vector(axis), Vector(normal)
    if width <= 0 or limit <= 0 or axis.length < 1e-6:
        raise ValueError("fabric press needs positive width/limit and a nonzero axis")
    axis.normalize()
    normal -= axis * normal.dot(axis)
    if normal.length < 1e-6:
        raise ValueError("fabric press normal must be perpendicular to its axis")
    normal.normalize()
    for vertex in obj.data.vertices:
        offset = vertex.co - centre
        distance = offset.dot(axis)
        if abs(distance) >= width:
            continue
        pressure = max(0.0, offset.dot(normal) - limit)
        falloff = (0.5 + 0.5 * math.cos(math.pi * distance / width)) ** 2
        vertex.co -= normal * pressure * falloff
    obj.data.update()


def _copy_world(obj):
    variant = obj.copy()
    variant.data = obj.data.copy()
    bpy.context.collection.objects.link(variant)
    variant.shape_key_clear()
    variant.data.transform(obj.matrix_world)
    variant.matrix_world = Matrix.Identity(4)
    return variant


def add_wrist_variants(parts):
    """Keep key ordering and rest fit; only three grips compress wrist fabric."""
    settings = {
        "atlas_auto": ("L", None, 0.004),
        "rampart_br": ("L", (-0.69636424, 0.17364818, -0.69636424), 0.031),
        "siphon": ("R", (0.40557979, -0.81915204, -0.40557979), 0.027),
    }
    names = {
        name + side for name in ("GloveCuff", "CuffRib", "Sleeve", "WristStrap", "StrapKeeper") for side in ("L", "R")
    }
    base = [obj for obj in parts if obj.name in names]
    bpy.context.view_layer.update()
    for obj in base:
        if obj.data.shape_keys is None:
            obj.shape_key_add(name="Basis", from_mix=False)
    for profile in PROFILES[1:]:
        side, normal, limit = settings.get(profile, ("", None, 0))
        selected = [obj for obj in base if side and obj.name.endswith(side)]
        for obj in base:
            if obj not in selected:
                key = obj.shape_key_add(name="grip_" + profile, from_mix=False)
                key.relative_key = obj.data.shape_keys.reference_key
                key.value = 0.0
        if not selected:
            continue
        sign = 1 if side == "L" else -1
        centre, axis = (sign * 0.61, 0, 1.05), (sign, 0, -1)
        variants = [_copy_world(obj) for obj in selected]
        for variant in variants:
            if normal is None:
                soft.fabric_fold(variant, centre, axis, 0.08, limit, 0.075)
            else:
                press_fabric(variant, centre, axis, normal, limit, 0.08)
        meshes = [variant.data for variant in variants]
        add_variant(selected, variants, "grip_" + profile)
        for mesh in meshes:
            bpy.data.meshes.remove(mesh)
