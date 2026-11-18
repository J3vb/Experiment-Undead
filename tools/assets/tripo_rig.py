"""Puts a Tripo character mesh on our shared 22-bone skeleton with the existing player clips.

Tripo's own rig is not reused: its bone names and rest pose differ from ours, so its skin would not
play our clips. When the source has a skeleton, its joint positions move our bones; otherwise our
1.80 m rest rig is used as is. Weights come from `character_rig.bind`.
"""

import bpy

# isort: split
import character_rig
from mathutils import Matrix, Vector

# Our bone -> name fragments Tripo / Mixamo-style rigs use for the bone's head joint (lower case).
JOINT_NAMES = {
    "pelvis": ("hips", "pelvis"),
    "neck": ("neck",),
    "head": ("head",),
    "upperarm": ("upperarm", "upper_arm", "arm"),
    "forearm": ("forearm", "lowerarm", "lower_arm"),
    "hand": ("hand", "wrist"),
    "thigh": ("upleg", "thigh", "upperleg", "upper_leg"),
    "shin": ("leg", "shin", "calf", "lowerleg", "lower_leg", "knee"),
    "foot": ("foot", "ankle"),
}
SIDES = {"L": ("left", "_l", ".l", "l_"), "R": ("right", "_r", ".r", "r_")}
EYE_HEIGHT = 1.682
EYE_FRONT = 0.115


def _match(names: list, fragments: tuple, side: str | None) -> str | None:
    """Longest source bone name that holds a fragment (and the side tag), skipping finger/twist bones."""
    skip = ("thumb", "index", "middle", "ring", "pinky", "twist", "toe", "end", "top", "base")
    hits = []
    for name in names:
        low = name.lower().replace("mixamorig:", "")
        if any(word in low for word in skip):
            continue
        if side is not None and not any(tag in low for tag in SIDES[side]):
            continue
        if side is None and any(tag in low for tags in SIDES.values() for tag in tags if tag[0] in "lr"):
            continue
        for fragment in fragments:
            if low.endswith(fragment) or f"{fragment}" == low.split("_")[-1]:
                hits.append((len(fragment), name))
    return max(hits)[1] if hits else None


def source_joints(armature, placed: Matrix) -> dict:
    """Our bone name -> head position from the Tripo skeleton, in the placed (scaled, turned) space."""
    if armature is None:
        return {}
    names = [bone.name for bone in armature.data.bones]
    joints = {}
    for ours, fragments in JOINT_NAMES.items():
        for side in ("L", "R") if ours not in ("pelvis", "neck", "head") else (None,):
            found = _match(names, fragments, side)
            if found is not None:
                head = armature.matrix_world @ armature.data.bones[found].head_local
                joints[f"{ours}_{side}" if side else ours] = placed @ head
    return joints


def fit(arm, joints: dict) -> int:
    """Moves our bone heads to the matched joints, keeps tails on the child heads; returns bones moved."""
    if not joints:
        return 0
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bones = arm.data.edit_bones
    for name, at in joints.items():
        bones[name].head = at
    for bone in bones:
        children = [c for c in bone.children if not c.name.startswith("sock_") and c.name in joints]
        if children:
            bone.tail = children[0].head
        elif bone.name in joints and bone.parent is not None and bone.name.startswith(("hand", "head")):
            bone.tail = bone.head + (bone.head - bone.parent.head).normalized() * 0.12
    bpy.ops.object.mode_set(mode="OBJECT")
    return len(joints)


def eyes_marker(arm, low) -> object:
    """The `Eyes` empty the checks and the camera need, on the head bone at the face front."""
    eyes = bpy.data.objects.new("Eyes", None)
    bpy.context.collection.objects.link(eyes)
    eyes.parent, eyes.parent_type, eyes.parent_bone = arm, "BONE", "head"
    head = arm.data.bones["head"].head_local
    front = min(
        (v.co.y for v in low.data.vertices if abs(v.co.z - EYE_HEIGHT) < 0.03 and abs(v.co.x) < 0.04),
        default=head.y - EYE_FRONT,
    )
    bpy.context.view_layer.update()
    eyes.matrix_world = Matrix.Translation(Vector((0.0, min(front, head.y - 0.02), EYE_HEIGHT)))
    return eyes


def rig(low, source_armature, placed: Matrix) -> list:
    """Skeleton, skinned mesh, Eyes and clips; returns the objects to export."""
    import player_clips

    joints = source_joints(source_armature, placed)
    if source_armature is not None:
        bpy.data.objects.remove(source_armature)
    arm = character_rig.build_armature()
    moved = fit(arm, joints)
    print(f"rig: {moved} joints taken from the source skeleton")
    character_rig.bind(low, arm, blend=0.08)
    low.parent = arm
    eyes = eyes_marker(arm, low)
    player_clips.build_clips(arm)
    return [arm, low, eyes]
