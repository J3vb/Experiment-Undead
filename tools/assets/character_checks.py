"""Character and gear rules, with explicit model registration for future builds."""

import math
from fnmatch import fnmatchcase

import character_rig
import gear_paint
from mathutils import Vector

BUDGETS = {"characters": (12_000, 4), "gear": (6_000, 4)}
# Close inspection: round links, hollow specimen glass and distinct implant shells.
TRIANGLE_CAPS = {
    "player_arms": 8_000,
    "charm_*": 1_000,
    "charm_vial": 1_200,
    "charm_dog_tags": 1_300,
    "charm_coin": 1_200,
    "implant_*": 1_500,
    "implant_spine": 1_600,
    "implant_ocular": 1_800,
}
CHARMS = ("charm_dog_tags", "charm_vial", "charm_keycard", "charm_dosimeter", "charm_coin")
IMPLANTS = ("implant_reflex", "implant_lung", "implant_spine", "implant_ocular", "implant_relay")
CHARM_JOINTS = {"Hook": None, "Link1": "Hook", "Link2": "Link1", "Body": "Link2"}
IMPLANT_JOINTS = {"Module": None, "Port": None}
VEST_BUDGETS = {"vest_light": (3_000, 4_500), "vest_medium": (4_000, 5_500), "vest_heavy": (4_500, 6_000)}
JOINTS = {
    "player": {"Eyes": None},
    "player_arms": {},
    **dict.fromkeys(CHARMS, CHARM_JOINTS),
    **dict.fromkeys(IMPLANTS, IMPLANT_JOINTS),
    **{stem: dict.fromkeys(("Shell", "CuffFP_L", "CuffFP_R", "CharmClip")) for stem in VEST_BUDGETS},
}
ARM_BONES = {f"{part}_{side}" for part in ("clavicle", "upperarm", "forearm", "hand") for side in ("L", "R")}
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


def _check_zones(meshes: list, min_trim=0.0) -> list:
    errors, total_area, glow_area, trim_area = [], 0.0, 0.0, 0.0
    for obj in meshes:
        try:
            shares = gear_paint.zone_shares(obj)
        except ValueError as error:
            errors.append(f"{obj.name}: every face needs a zone: {error}")
            continue
        area = _surface_area(obj)
        total_area += area
        glow_area += shares[gear_paint.ZONE_GLOW] * area
        trim_area += shares[gear_paint.ZONE_TRIM] * area
    if total_area > 0 and glow_area / total_area > 0.05 + 1e-6:
        errors.append(f"glow zone covers {glow_area / total_area:.1%} of surface area, maximum is 5%")
    if total_area > 0 and trim_area / total_area + 1e-6 < min_trim:
        errors.append(f"trim zone covers {trim_area / total_area:.1%} of surface area, minimum is {min_trim:.0%}")
    return errors


def _check_vest_attachments(nodes: dict) -> list:
    errors = []
    for name in ("CuffFP_L", "CuffFP_R"):
        cuff = nodes.get(name)
        if cuff is None:
            continue
        if cuff.type != "MESH" or cuff.find_armature() is not None or cuff.parent_type == "BONE":
            errors.append(f"{name} must be a separate unskinned cuff mesh")
        elif (_bounds([cuff])[0] + _bounds([cuff])[1] - 2 * cuff.matrix_world.translation).length > 0.02:
            errors.append(f"{name} origin must sit at the cuff centre")
    clip = nodes.get("CharmClip")
    if clip is not None and clip.type != "EMPTY":
        errors.append("CharmClip must be an empty")
    return errors


def _check_vest(objects: list, armatures: list, stem: str, tris: int) -> list:
    nodes = {obj.name: obj for obj in objects}
    errors = _check_vest_attachments(nodes)
    for name in JOINTS[stem]:
        if name not in nodes:
            errors.append(f"missing node '{name}'")
    if len(armatures) != 1:
        errors.append("vests need exactly one armature with the 22 character bones")
    elif armatures[0].matrix_world.translation.length > TOLERANCE:
        errors.append("vest skeleton must use the player rig origin")
    shell = nodes.get("Shell")
    if shell is not None and (shell.type != "MESH" or shell.find_armature() not in armatures):
        errors.append("Shell must be one mesh skinned to the vest skeleton")
    low, high = VEST_BUDGETS[stem]
    if not low <= tris <= high:
        errors.append(f"{tris} triangles, '{stem}' must have {low}-{high}")
    skinned = [obj for obj in objects if obj.type == "MESH" and obj.find_armature() is not None]
    if shell is not None and skinned != [shell]:
        errors.append("Shell must be the vest's only skinned mesh")
    return errors


def _check_materials(meshes: list) -> list:
    errors = []
    for obj in meshes:
        for material in filter(None, obj.data.materials):
            if not material.name.startswith(("Body", "Gear")):
                errors.append(f"{obj.name}: material '{material.name}' must map to a Body* or Gear* finish")
    return errors


def _check_arm_weights(meshes: list) -> list:
    errors = []
    for obj in meshes:
        if not any(modifier.type == "ARMATURE" and modifier.object is not None for modifier in obj.modifiers):
            errors.append(f"{obj.name}: first-person arms must be skinned to the character armature")
        weighted = {
            obj.vertex_groups[group.group].name
            for vertex in obj.data.vertices
            for group in vertex.groups
            if group.weight > 0.0
        }
        if weighted - ARM_BONES:
            invalid = ", ".join(sorted(weighted - ARM_BONES))
            errors.append(f"{obj.name}: first-person arms have weights on non-arm bones: {invalid}")
    return errors


def _check_hanging(nodes: dict) -> list:
    errors = []
    hook = nodes.get("Hook")
    if hook is None or hook.type != "EMPTY":
        return ["charms need an empty named 'Hook'"]
    if hook.matrix_world.translation.length > 1e-5:
        errors.append("Hook must be at the model origin")
    for name, parent in CHARM_JOINTS.items():
        if name == "Hook" or name not in nodes:
            continue
        obj = nodes[name]
        if obj.type != "MESH":
            errors.append(f"{name} must be a rigid mesh")
            continue
        if obj.parent != nodes.get(parent):
            errors.append(f"{name} must be directly parented to {parent}")
        low, high = _bounds([obj])
        pivot = obj.matrix_world.translation
        if abs(pivot.z - high.z) > 0.003:
            errors.append(f"{name} pivot must be at its top end")
        if high.z > hook.matrix_world.translation.z + 0.003 or low.z >= high.z:
            errors.append(f"{name} must hang down Blender -Z below Hook")
    return errors


def _check_rigid_gear(objects: list, stem: str, triangles: int) -> list:
    if stem not in CHARMS + IMPLANTS:
        return []
    nodes = {obj.name: obj for obj in objects}
    errors = [f"missing node '{name}'" for name in JOINTS[stem] if name not in nodes]
    minimum = 600 if stem in CHARMS else 1_000
    if triangles < minimum:
        errors.append(f"{triangles} triangles, detail floor for '{stem}' is {minimum}")
    if any(obj.type == "ARMATURE" for obj in objects):
        errors.append("charms and implants must be rigid attachments without an armature")
    if stem in CHARMS:
        return errors + _check_hanging(nodes)
    for name in IMPLANT_JOINTS:
        if name in nodes and nodes[name].type != "MESH":
            errors.append(f"{name} must be a rigid mesh")
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
    fallback = min(
        (cap for pattern, cap in TRIANGLE_CAPS.items() if fnmatchcase(stem, pattern)), default=BUDGETS[folder][0]
    )
    cap = TRIANGLE_CAPS.get(stem, fallback)
    if tris > cap:
        errors.append(f"{tris} triangles, budget for '{stem}' is {cap}")
    errors += _check_rigid_gear(objects, stem, tris)
    lo, hi = _bounds(meshes)
    if folder == "gear":
        if stem in VEST_BUDGETS:
            errors += _check_vest(objects, armatures, stem, tris)
        elif Vector(max(lo[i], -hi[i], 0.0) for i in range(3)).length > 0.05:
            errors.append("gear origin must be inside the piece's bounds or within 0.05 m")
        errors += _check_zones(meshes, min_trim=0.05 if stem in VEST_BUDGETS else 0.0)
    elif stem == "player_arms":
        errors += _check_arm_weights(meshes) + _check_zones(meshes)
    else:
        if abs(lo.z) > TOLERANCE:
            errors.append(f"lowest point is at height {lo.z:.3f}, feet must be at z = 0")
        errors += _check_facing(objects, armatures)
    return errors
