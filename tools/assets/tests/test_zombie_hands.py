"""Anatomically mirrored hands keep skin contact through the runtime pose extremes."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import character_rig
import pytest
import zombie_details
import zombie_model
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree


@pytest.fixture(params=["crawler"])
def hands(request):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    skeleton = character_rig.build_armature()
    materials = zombie_model._materials()
    body = zombie_model._body(skeleton, materials, request.param)
    zombie_details._hands(skeleton, materials, request.param, zombie_model._bind)
    pieces = {}
    for side, sign in (("L", 1), ("R", -1)):
        pieces[side] = [
            obj
            for obj in bpy.context.scene.objects
            if obj.name.startswith(("Palm", "Finger", "Thumb"))
            and sum(vertex.co.x for vertex in obj.data.vertices) * sign > 0
        ]
    return request.param, skeleton, body, pieces


def test_thumb_side_matches_finger_curl_and_left_right_anatomy(hands):
    _kind, skeleton, _body, pieces = hands
    for side, handedness in (("L", 1), ("R", -1)):
        bone = skeleton.data.bones["hand_" + side]
        distal = (bone.tail_local - bone.head_local).normalized()
        palm_normal = Vector((0, -1, 0))
        thumb_side = palm_normal.cross(distal) * handedness
        thumb = next(obj for obj in pieces[side] if obj.name.startswith("Thumb"))
        center = sum((vertex.co for vertex in thumb.data.vertices), Vector()) / len(thumb.data.vertices)
        assert (center - bone.head_local).dot(thumb_side) > 0.01, "thumb is on the little-finger side"
        fingers = [obj for obj in pieces[side] if obj.name.startswith("Finger")]
        assert len(fingers) == 4
        for finger in fingers:
            vertices = sorted((vertex.co for vertex in finger.data.vertices), key=lambda point: point.dot(distal))
            root = sum(vertices[:6], Vector()) / 6
            tip = sum(vertices[-6:], Vector()) / 6
            assert (tip - root).dot(palm_normal) > 0.015, "fingers must curl toward the palm"
            for vertex in finger.data.vertices:
                weights = {finger.vertex_groups[group.group].name for group in vertex.groups if group.weight > 0}
                assert weights == {"hand_" + side}, "fingers must follow their own hand bone"


def surface(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        return BVHTree.FromPolygons(
            [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices],
            [tuple(face.vertices) for face in mesh.polygons],
        )
    finally:
        evaluated.to_mesh_clear()


def pose(skeleton, name, crawling=False):
    # The actual runtime captures accompany this geometric contact check. These
    # offsets exercise the same 1.3-radian windup and 0.7-radian strike envelope.
    left, right, elbow, lean, roll = {
        "rest": (0, 0, 0, 0, 0),
        "walk": (-0.286, 0.056, -0.195, 0.125, -0.07),
        "windup": (-1.3, -1.3, -0.35, -0.15, 0),
        "strike": (0.7, 0.7, -0.35, 0.3, 0),
    }[name]
    elbow_left = elbow_right = elbow
    if crawling and name == "walk":
        left, right, elbow_left, elbow_right, lean, roll = -0.32, -0.08, -0.33, -0.15, -0.025, -0.025
    elif crawling and name in {"windup", "strike"}:
        lift = 1.0 if name == "windup" else 0.0
        left = right = -0.75 * lift
        elbow_left = elbow_right = -0.14 - 0.18 * lift
        lean, roll = -0.10 * lift, 0.0
    for bone in skeleton.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = Quaternion()
    angles = {
        "upperarm_L": left,
        "upperarm_R": right,
        "forearm_L": elbow_left,
        "forearm_R": elbow_right,
        "spine_02": lean,
    }
    for bone_name, angle in angles.items():
        axes = skeleton.data.bones[bone_name].matrix_local.to_quaternion()
        rotation = Matrix.Rotation(angle, 4, "X")
        if bone_name == "spine_02":
            rotation @= Matrix.Rotation(roll, 4, "Y")
        skeleton.pose.bones[bone_name].rotation_quaternion = axes.inverted() @ rotation.to_quaternion() @ axes
    bpy.context.view_layer.update()


@pytest.mark.parametrize("position", ["rest", "walk", "windup", "strike"])
def test_palms_overlap_wrists_and_every_digit_in_all_poses(hands, position):
    kind, skeleton, body, pieces = hands
    zombie_model._rest_pose(skeleton, kind)
    pose(skeleton, position, kind == "crawler")
    body_surface = surface(body)
    for side in ("L", "R"):
        palm = next(obj for obj in pieces[side] if obj.name.startswith("Palm"))
        palm_surface = surface(palm)
        assert palm_surface.overlap(body_surface), (kind, side, position, "detached palm at wrist")
        for digit in (obj for obj in pieces[side] if obj != palm):
            assert palm_surface.overlap(surface(digit)), (kind, side, position, digit.name, "detached digit")
