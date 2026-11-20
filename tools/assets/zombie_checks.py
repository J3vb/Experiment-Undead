"""Zombie rules on the shared character skeleton: Tripo-baked body, HeadCenter, budget, Crawler without legs."""

import character_checks

JOINTS = {
    "shambler": {},
    "shambler_guard": {},
    "crawler": {},
    "bloater": {},
    "glower": {},
    "stalker": {},
    "brute": {},
}
TRIANGLES = {
    "shambler": (6_000, 9_000),
    "shambler_guard": (6_000, 9_000),
    "crawler": (5_000, 9_000),  # the Tripo Shambler with its legs cut off
    "bloater": (6_000, 9_000),
    "glower": (6_000, 9_000),
    "stalker": (6_000, 9_000),
    "brute": (6_000, 9_000),
}
## Tripo zombies (tripo_intake.py --kind zombie): one baked mesh `Body`, eyes and pale head painted in its texture.
BAKED = "ZombieBaked"


def _is_baked(meshes) -> bool:
    return any(mat and mat.name.startswith(BAKED) for obj in meshes for mat in obj.data.materials)


def _check_baked(objects, meshes) -> list:
    """One `Body` mesh with only the ZombieBaked material. The head-lighter and zone rules are skipped: the head
    tone is in the baked texture and zombies have no dye zones (DECISIONS "Gear looks")."""
    errors = []
    if [obj.name for obj in meshes] != ["Body"]:
        errors.append(f"baked zombies are one mesh named 'Body', found {sorted(obj.name for obj in meshes)}")
    for obj in meshes:
        for material in obj.data.materials:
            if material is None or not material.name.startswith(BAKED):
                errors.append(f"{obj.name}: baked zombies use only the {BAKED} material")
    center = next((obj for obj in objects if obj.name == "HeadCenter"), None)
    if center is None or center.type != "EMPTY" or center.parent_type != "BONE" or center.parent_bone != "head":
        errors.append("baked zombies need a HeadCenter empty on the head bone (ZombieRig hangs the head zone on it)")
    return errors


def _weights(obj, vertex):
    return {obj.vertex_groups[item.group].name: item.weight for item in vertex.groups if item.weight > 0.0}


def check(objects: list, stem: str) -> list:
    """Character bone/weight checks plus the baked-zombie, budget and Crawler rules."""
    meshes = [obj for obj in objects if obj.type == "MESH"]
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    errors = character_checks._check_skin(meshes, armatures, "characters")
    errors += character_checks._check_facing(objects, armatures)
    if _is_baked(meshes):
        errors += _check_baked(objects, meshes)
    else:
        errors.append(f"zombies come from tripo_intake.py --kind zombie (one {BAKED} material)")
    triangles = sum(len(face.vertices) - 2 for obj in meshes for face in obj.data.polygons)
    low, high = TRIANGLES[stem]
    if not low <= triangles <= high:
        errors.append(f"{triangles} triangles, '{stem}' must have {low}-{high}")
    if stem == "crawler":
        for obj in meshes:
            if any(
                name.startswith(("thigh_", "shin_", "foot_")) for v in obj.data.vertices for name in _weights(obj, v)
            ):
                errors.append(f"{obj.name}: Crawler must have no vertices weighted to leg bones")
    return errors
