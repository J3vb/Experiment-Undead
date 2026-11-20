"""Puts a Tripo character mesh on our shared 22-bone skeleton with the player clips or the stall keeper clips.

When the source has a Mixamo-named skeleton (Tripo's Mixamo preset), its arms are swung to our A-pose with the
forearms twisted and fingers curled like our player hand, its joint positions move our bones and its skin weights
are kept. Otherwise our 1.80 m rest rig and `character_rig.bind` weights are used.
"""

import math

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
# The code-built zombies put HeadCenter 8 cm behind and just under the Eyes (zombie_model.py).
HEAD_CENTER_BEHIND_EYES = (0.0, 0.08, -0.005)
# Our player body's rest thumb, measured off player.glb: up and out along the arm's side, 31 degrees forward.
THUMB_OUT = 0.86
THUMB_FORWARD = 0.51
FORWARD = Vector((0.0, -1.0, 0.0))
# Degrees per finger joint (base, middle, tip), like the player body's relaxed hand.
FINGER_CURL = (25.0, 35.0, 25.0)


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


def _turn_thumb_up(arm, bones: dict, word: str, direction: Vector) -> None:
    """Twists the forearm about the arm so the thumb points where our player body's rest thumb does: up and out,
    a little forward (palm facing forward and in). Without it the clips turn her hands the wrong way."""
    forearm, hand = bones.get(f"{word}forearm"), bones.get(f"{word}hand")
    thumb = bones.get(f"{word}handthumb2") or bones.get(f"{word}handthumb1")
    if forearm is None or hand is None or thumb is None:
        return
    axis = direction.normalized()
    up = Vector((0.0, 0.0, 1.0))
    want = (up - axis * up.dot(axis)).normalized() * THUMB_OUT + FORWARD * THUMB_FORWARD
    want = (want - axis * want.dot(axis)).normalized()
    world = arm.matrix_world.to_3x3()
    have = world @ (thumb.head - hand.head)
    have = (have - axis * have.dot(axis)).normalized()
    angle = math.atan2(axis.dot(have.cross(want)), have.dot(want))
    turn = Matrix.Rotation(angle, 4, (world.inverted() @ axis).normalized())
    head = forearm.matrix.translation.copy()
    forearm.matrix = Matrix.Translation(head) @ turn @ Matrix.Translation(-head) @ forearm.matrix
    bpy.context.view_layer.update()


def _curl_fingers(arm, bones: dict, word: str, direction: Vector) -> None:
    """Bends Tripo's flat, spread fingers into the relaxed curl our player hand is modelled with. Our skeleton has
    no finger bones, so the curl has to be in the mesh before the swing is applied."""
    hand = bones.get(f"{word}hand")
    if hand is None:
        return
    world = arm.matrix_world.to_3x3()
    axis = direction.normalized()
    palm = axis.cross(FORWARD.cross(axis)).normalized()
    for finger in ("index", "middle", "ring", "pinky"):
        for joint, angle in enumerate(FINGER_CURL, start=1):
            pbone = bones.get(f"{word}hand{finger}{joint}")
            if pbone is None:
                continue
            along = (world @ (pbone.tail - pbone.head)).normalized()
            turn_axis = along.cross(palm)
            if turn_axis.length < 1e-4:
                continue
            turn = Matrix.Rotation(math.radians(angle), 4, (world.inverted() @ turn_axis).normalized())
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
        _turn_thumb_up(arm, bones, word.lower(), direction)
        _curl_fingers(arm, bones, word.lower(), direction)
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
    eye_z = head.z + EYE_HEIGHT - character_rig.BONES["head"][1][2]
    front = min(
        (v.co.y for v in low.data.vertices if abs(v.co.z - eye_z) < 0.03 and abs(v.co.x) < 0.04),
        default=head.y - EYE_FRONT,
    )
    bpy.context.view_layer.update()
    eyes.matrix_world = Matrix.Translation(Vector((0.0, min(front, head.y - 0.02), eye_z)))
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


def head_center_marker(arm, eyes) -> object:
    """The `HeadCenter` empty ZombieRig hangs the head hit zone on: on the head bone, behind the eyes."""
    center = bpy.data.objects.new("HeadCenter", None)
    bpy.context.collection.objects.link(center)
    center.parent, center.parent_type, center.parent_bone = arm, "BONE", "head"
    bpy.context.view_layer.update()
    center.matrix_world = Matrix.Translation(eyes.matrix_world.translation + Vector(HEAD_CENTER_BEHIND_EYES))
    return center


def rig(low, source_armature, placed: Matrix, clips: str | None = "player") -> list:
    """Skeleton, skinned mesh, Eyes and clips ("player", "keeper" or None for zombies, which ZombieRig poses in
    code); returns [armature, mesh, Eyes]."""
    import npc_clips
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
    if clips:
        {"player": player_clips, "keeper": npc_clips}[clips].build_clips(arm)
    return [arm, low, eyes]
