"""Shared 1.80 m character rest rig and deterministic segment-based skin weights.

Blender +Z is up and characters face -Y (Godot +Z). BONES maps each name to
(parent, head, tail), in metres. Socket bones carry attachments, never weights.
"""

import bpy

BONES = {
    "pelvis": (None, (0.0, 0.0, 0.94), (0.0, 0.0, 1.06)),
    "spine_01": ("pelvis", (0.0, 0.0, 1.06), (0.0, 0.0, 1.20)),
    "spine_02": ("spine_01", (0.0, 0.0, 1.20), (0.0, 0.0, 1.35)),
    "spine_03": ("spine_02", (0.0, 0.0, 1.35), (0.0, 0.0, 1.49)),
    "neck": ("spine_03", (0.0, 0.0, 1.49), (0.0, 0.0, 1.61)),
    "head": ("neck", (0.0, 0.0, 1.61), (0.0, 0.0, 1.80)),
    "clavicle_L": ("spine_03", (0.0, 0.0, 1.47), (0.19, 0.0, 1.47)),
    "upperarm_L": ("clavicle_L", (0.19, 0.0, 1.47), (0.41, 0.0, 1.25)),
    "forearm_L": ("upperarm_L", (0.41, 0.0, 1.25), (0.61, 0.0, 1.05)),
    "hand_L": ("forearm_L", (0.61, 0.0, 1.05), (0.72, 0.0, 0.94)),
    "thigh_L": ("pelvis", (0.11, 0.0, 0.98), (0.11, 0.0, 0.53)),
    "shin_L": ("thigh_L", (0.11, 0.0, 0.53), (0.11, 0.0, 0.09)),
    "foot_L": ("shin_L", (0.11, 0.0, 0.09), (0.11, -0.19, 0.0)),
    "clavicle_R": ("spine_03", (0.0, 0.0, 1.47), (-0.19, 0.0, 1.47)),
    "upperarm_R": ("clavicle_R", (-0.19, 0.0, 1.47), (-0.41, 0.0, 1.25)),
    "forearm_R": ("upperarm_R", (-0.41, 0.0, 1.25), (-0.61, 0.0, 1.05)),
    "hand_R": ("forearm_R", (-0.61, 0.0, 1.05), (-0.72, 0.0, 0.94)),
    "thigh_R": ("pelvis", (-0.11, 0.0, 0.98), (-0.11, 0.0, 0.53)),
    "shin_R": ("thigh_R", (-0.11, 0.0, 0.53), (-0.11, 0.0, 0.09)),
    "foot_R": ("shin_R", (-0.11, 0.0, 0.09), (-0.11, -0.19, 0.0)),
    "sock_thigh_R": ("thigh_R", (-0.20, 0.0, 0.78), (-0.20, 0.0, 0.73)),
    "sock_back": ("spine_03", (0.0, 0.12, 1.43), (0.0, 0.12, 1.48)),
}


def build_armature(name="Skeleton"):
    """Creates exactly the shared bones, with no operator-generated root bone."""
    bpy.ops.object.select_all(action="DESELECT")
    armature = bpy.data.objects.new(name, bpy.data.armatures.new(name))
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, (parent, head, tail) in BONES.items():
        bone = armature.data.edit_bones.new(bone_name)
        bone.head, bone.tail = head, tail
        bone.use_deform = not bone_name.startswith("sock_")
        if parent:
            bone.parent = armature.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def _distance(point, head, tail):
    direction = tail - head
    along = max(0.0, min(1.0, (point - head).dot(direction) / direction.length_squared))
    return (point - (head + direction * along)).length


def _joint(first, second):
    if first[1].parent == second[1]:
        return first[2]
    if second[1].parent == first[1]:
        return second[2]
    return None


def _weights(point, segments, blend):
    ranked = sorted(((_distance(point, head, tail), bone.name, bone, head, tail) for bone, head, tail in segments))
    nearest = ranked[0]
    if blend <= 0.0:
        return {nearest[1]: 1.0}
    for candidate in ranked[1:]:
        joint = _joint(nearest[1:], candidate[1:])
        if joint is None or (point - joint).length >= blend:
            continue
        primary = max(0.0, blend - nearest[0])
        secondary = max(0.0, blend - candidate[0])
        if secondary > 0.0:
            total = primary + secondary
            return {nearest[1]: primary / total, candidate[1]: secondary / total}
    return {nearest[1]: 1.0}


def _prepare_binding(mesh_obj, armature):
    mesh_obj.vertex_groups.clear()
    for modifier in list(mesh_obj.modifiers):
        if modifier.type == "ARMATURE":
            mesh_obj.modifiers.remove(modifier)
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature


def bind(mesh_obj, armature, blend=0.06):
    """Weights the nearest segment and a neighbouring segment near their joint.

    Replaces existing groups and armature modifiers. Distances use world metres,
    so translated, rotated or scaled meshes need no applied transforms.
    """
    bpy.context.view_layer.update()
    world = armature.matrix_world
    segments = [
        (bone, world @ bone.head_local, world @ bone.tail_local)
        for bone in armature.data.bones
        if bone.use_deform and not bone.name.startswith("sock_")
    ]
    if not segments:
        raise ValueError("armature has no deforming bones")
    _prepare_binding(mesh_obj, armature)
    groups = {bone.name: mesh_obj.vertex_groups.new(name=bone.name) for bone, _head, _tail in segments}
    for vertex in mesh_obj.data.vertices:
        for bone, weight in _weights(mesh_obj.matrix_world @ vertex.co, segments, blend).items():
            groups[bone].add([vertex.index], weight, "REPLACE")


def bind_rigid(mesh_obj, armature, bone):
    """Assigns every vertex fully to one deforming bone; sockets are attachments."""
    target = armature.data.bones.get(bone)
    if target is None or not target.use_deform or bone.startswith("sock_"):
        raise ValueError(f"'{bone}' is not a deforming bone")
    _prepare_binding(mesh_obj, armature)
    group = mesh_obj.vertex_groups.new(name=bone)
    vertices = [vertex.index for vertex in mesh_obj.data.vertices]
    if vertices:
        group.add(vertices, 1.0, "REPLACE")
