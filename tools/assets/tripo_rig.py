"""Puts a Tripo character mesh on our shared 22-bone skeleton with the existing player clips.

Tripo's own rig is not reused: its bone names and rest pose differ from ours, so its skin would not
play our clips. When the source has a Mixamo-named skeleton, its joint positions move our bones; otherwise our
1.80 m rest rig is used as is. Weights come from `character_rig.bind`.
"""

import bpy

# isort: split
import character_rig
from mathutils import Matrix, Vector

# Our bone -> Mixamo bone (Tripo's "Mixamo" preset), "{s}" = Left / Right.
MIXAMO = {
    "pelvis": "Hips",
    "neck": "Neck",
    "head": "Head",
    "upperarm": "{s}Arm",
    "forearm": "{s}ForeArm",
    "hand": "{s}Hand",
    "thigh": "{s}UpLeg",
    "shin": "{s}Leg",
    "foot": "{s}Foot",
}
SIDES = {"L": "Left", "R": "Right"}
EYE_HEIGHT = 1.682
EYE_FRONT = 0.115


def _plain(name: str) -> str:
    return name.split(":")[-1].lower()


def _targets() -> dict:
    """Our bone name -> the plain lower-case Mixamo name it takes its head joint from."""
    targets = {}
    for ours, theirs in MIXAMO.items():
        if "{s}" not in theirs:
            targets[ours] = theirs.lower()
            continue
        for side, word in SIDES.items():
            targets[f"{ours}_{side}"] = theirs.format(s=word).lower()
    return targets


def _aim(arm, pbone, world_dir: Vector) -> None:
    """Turns a pose bone about its head so it points along `world_dir`."""
    to_arm = arm.matrix_world.to_3x3().inverted()
    current = pbone.matrix.to_3x3() @ Vector((0.0, 1.0, 0.0))
    turn = current.rotation_difference((to_arm @ world_dir).normalized()).to_matrix().to_4x4()
    head = pbone.matrix.translation.copy()
    pbone.matrix = Matrix.Translation(head) @ turn @ Matrix.Translation(-head) @ pbone.matrix
    bpy.context.view_layer.update()


def a_pose(arm, meshes: list) -> None:
    """Swings a T-posed Mixamo body's arms down to our rest angle with Tripo's own skin, then keeps that
    pose as the mesh and the rest. Our clips are made for our A-pose rest, so a T-pose rest raises the arms."""
    bones = {_plain(b.name): b for b in arm.pose.bones}
    bpy.context.view_layer.objects.active = arm
    for side, word in SIDES.items():
        rest = character_rig.BONES[f"upperarm_{side}"]
        direction = Vector(rest[2]) - Vector(rest[1])
        for part in ("arm", "forearm"):
            pbone = bones.get(f"{word.lower()}{part}")
            if pbone is not None:
                _aim(arm, pbone, direction)
    for obj in meshes:
        for mod in [m for m in obj.modifiers if m.type == "ARMATURE"]:
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def source_joints(armature, placed: Matrix) -> dict:
    """Our bone name -> head position from a Mixamo-named source skeleton, in the placed space."""
    if armature is None:
        return {}
    by_name = {_plain(bone.name): bone for bone in armature.data.bones}
    joints = {}
    for ours, theirs in _targets().items():
        bone = by_name.get(theirs)
        if bone is not None:
            joints[ours] = placed @ (armature.matrix_world @ bone.head_local)
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


# Mixamo bones with no twin in our 22 -> the bone that takes their weight.
EXTRA = {
    "spine": "spine_01",
    "spine1": "spine_02",
    "spine2": "spine_03",
    "{s}shoulder": "clavicle_{S}",
    "{s}toebase": "foot_{S}",
}


def _our_bone(group: str) -> str | None:
    """Our deforming bone for a Mixamo vertex group name; fingers go to the hand."""
    plain = _plain(group)
    for ours, theirs in _targets().items():
        if plain == theirs:
            return ours
    for side, word in SIDES.items():
        if plain.startswith(f"{word.lower()}hand"):
            return f"hand_{side}"
        for theirs, ours in EXTRA.items():
            if plain == theirs.format(s=word.lower()):
                return ours.format(S=side)
    return EXTRA.get(plain)


def keep_source_weights(low, arm) -> bool:
    """Renames and merges Tripo's own Mixamo skin weights onto our bones; False when the mesh has none."""
    mapping = {g.index: _our_bone(g.name) for g in low.vertex_groups}
    if not any(mapping.values()):
        return False
    merged = [{} for _ in low.data.vertices]
    for vertex in low.data.vertices:
        for element in vertex.groups:
            bone = mapping.get(element.group)
            if bone is not None:
                merged[vertex.index][bone] = merged[vertex.index].get(bone, 0.0) + element.weight
    low.vertex_groups.clear()
    groups = {b.name: low.vertex_groups.new(name=b.name) for b in arm.data.bones if b.use_deform}
    for index, weights in enumerate(merged):
        total = sum(weights.values()) or 1.0
        for bone, weight in weights.items():
            groups[bone].add([index], weight / total, "REPLACE")
    modifier = low.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm
    return all(merged)


def rig(low, source_armature, placed: Matrix) -> list:
    """Skeleton, skinned mesh, Eyes and clips; returns the objects to export."""
    import player_clips

    joints = source_joints(source_armature, placed)
    if source_armature is not None:
        bpy.data.objects.remove(source_armature)
    arm = character_rig.build_armature()
    moved = fit(arm, joints)
    print(f"rig: {moved} joints taken from the source skeleton")
    if keep_source_weights(low, arm):
        print("rig: kept the source skin weights")
    else:
        character_rig.bind(low, arm, blend=0.08)
    low.parent = arm
    eyes = eyes_marker(arm, low)
    player_clips.build_clips(arm)
    return [arm, low, eyes]
