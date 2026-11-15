"""Character and gear rules, with explicit model registration for future builds."""

import math
from fnmatch import fnmatchcase

import character_rig
import gear_paint
from mathutils import Vector

BUDGETS = {"characters": (12_000, 4), "gear": (6_000, 4)}
TRIANGLE_CAPS = {"player_arms": 8_000, "charm_*": 800, "implant_*": 1_500}
# Add each new model stem here alongside its character_models.MODELS entry.
JOINTS = {"player": {"Eyes": None}}
TOLERANCE = 0.01


def _bounds(objects: list) -> tuple:
    points = [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]
    return Vector(map(min, zip(*points, strict=True))), Vector(map(max, zip(*points, strict=True)))


def _check_armature(armature) -> list:
    bones = armature.data.bones
    expected = set(character_rig.BONES)
    actual = set(bones.keys())
    errors = []
    if expected - actual:
        errors.append(f"{armature.name}: missing bones {', '.join(sorted(expected - actual))}")
    if actual - expected:
        errors.append(f"{armature.name}: unexpected bones {', '.join(sorted(actual - expected))}")
    for name in expected & actual:
        parent = bones[name].parent
        if (parent.name if parent else None) != character_rig.BONES[name][0]:
            errors.append(f"{armature.name}: bone '{name}' has the wrong parent")
    return errors


def _check_vertex(obj, vertex, armature) -> list:
    influences = [(obj.vertex_groups[item.group].name, item.weight) for item in vertex.groups if item.weight > 0.0]
    errors = []
    if len(influences) > 4:
        errors.append(f"{obj.name}: vertex {vertex.index} has more than 4 bone weights")
    total = sum(weight for _name, weight in influences)
    if not math.isfinite(total) or abs(total - 1.0) > TOLERANCE:
        errors.append(f"{obj.name}: vertex {vertex.index} weights sum to {total:.3f}, must be 1 (+/-0.01)")
    if any(name.startswith("sock_") or name not in armature.data.bones for name, _weight in influences):
        errors.append(f"{obj.name}: vertex {vertex.index} has weights on a socket or unknown bone")
    return errors


def _check_mesh_skin(obj, armatures: list, folder: str) -> list:
    armature = next(
        (modifier.object for modifier in obj.modifiers if modifier.type == "ARMATURE" and modifier.object is not None),
        None,
    )
    if armature is None:
        attached = obj.parent in armatures and obj.parent_type == "BONE" and obj.parent_bone in obj.parent.data.bones
        if folder == "characters" and not attached:
            return [f"{obj.name}: character mesh must be skinned or attached to a character rig bone"]
        return []
    errors = []
    if armature not in armatures:
        errors.append(f"{obj.name}: skin armature is missing from the model")
    for vertex in obj.data.vertices:
        errors += _check_vertex(obj, vertex, armature)
    return errors


def _check_skin(meshes: list, armatures: list, folder: str) -> list:
    errors = []
    if folder == "characters" and len(armatures) != 1:
        errors.append("characters need exactly one armature with the 22 character bones")
    for armature in armatures:
        errors += _check_armature(armature)
    for obj in meshes:
        errors += _check_mesh_skin(obj, armatures, folder)
    return errors


def _check_facing(objects: list, armatures: list) -> list:
    eyes = next((obj for obj in objects if obj.name == "Eyes"), None)
    if eyes is None or eyes.type != "EMPTY":
        return ["characters need an empty named 'Eyes' parented to the head bone"]
    if len(armatures) != 1:
        return []
    armature = armatures[0]
    if eyes.parent != armature or eyes.parent_type != "BONE" or eyes.parent_bone != "head":
        return ["Eyes must be a child of the head bone"]
    head = armature.data.bones.get("head")
    if head and eyes.matrix_world.translation.y >= (armature.matrix_world @ head.head_local).y:
        return ["Eyes must sit in front of the head bone (Blender -Y / Godot +Z)"]
    return []


def _surface_area(obj) -> float:
    mesh = obj.data
    mesh.calc_loop_triangles()
    area = 0.0
    for triangle in mesh.loop_triangles:
        a, b, c = (obj.matrix_world @ mesh.vertices[index].co for index in triangle.vertices)
        area += (b - a).cross(c - a).length / 2
    return area


def _check_zones(meshes: list) -> list:
    errors, total_area, glow_area = [], 0.0, 0.0
    for obj in meshes:
        try:
            shares = gear_paint.zone_shares(obj)
        except ValueError as error:
            errors.append(f"{obj.name}: every face needs a zone: {error}")
            continue
        area = _surface_area(obj)
        total_area += area
        glow_area += shares[gear_paint.ZONE_GLOW] * area
    if total_area > 0 and glow_area / total_area > 0.05 + 1e-6:
        errors.append(f"glow zone covers {glow_area / total_area:.1%} of surface area, maximum is 5%")
    return errors


def _check_materials(meshes: list) -> list:
    errors = []
    for obj in meshes:
        for material in filter(None, obj.data.materials):
            if not material.name.startswith(("Body", "Gear")):
                errors.append(f"{obj.name}: material '{material.name}' must map to a Body* or Gear* finish")
    return errors


def check(objects: list, folder: str, stem: str) -> list:
    """Extra checks for character/gear folders; existing model folders are untouched."""
    if folder not in BUDGETS:
        return []
    if stem not in JOINTS:
        return [f"no rules for '{stem}', add it to character_checks.py"]
    meshes = [obj for obj in objects if obj.type == "MESH"]
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    if not meshes or not any(obj.data.vertices for obj in meshes):
        return ["character/gear model needs a mesh"]
    errors = _check_skin(meshes, armatures, folder) + _check_materials(meshes)
    tris = sum(sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in meshes)
    cap = min((cap for pattern, cap in TRIANGLE_CAPS.items() if fnmatchcase(stem, pattern)), default=BUDGETS[folder][0])
    if tris > cap:
        errors.append(f"{tris} triangles, budget for '{stem}' is {cap}")
    lo, hi = _bounds(meshes)
    if folder == "gear":
        if Vector(max(lo[i], -hi[i], 0.0) for i in range(3)).length > 0.05:
            errors.append("gear origin must be inside the piece's bounds or within 0.05 m")
        errors += _check_zones(meshes)
    else:
        if abs(lo.z) > TOLERANCE:
            errors.append(f"lowest point is at height {lo.z:.3f}, feet must be at z = 0")
        errors += _check_facing(objects, armatures)
    return errors
