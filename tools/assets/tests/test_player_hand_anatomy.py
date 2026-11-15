"""Actual glove geometry has anatomical handedness and clears each weapon grip."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import build_models
import character_rig
import player_arms_model as arms
import player_body_model as body
import pytest
import rifle_model
from mathutils import Vector
from mathutils.kdtree import KDTree


def hands(version):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = arms._materials()
    skeleton = character_rig.build_armature()
    body._gloves(skeleton, mats)
    if version == "first_person":
        for obj in list(bpy.context.scene.objects):
            if obj.name.startswith(("GloveFinger", "GloveThumb")):
                bpy.data.objects.remove(obj, do_unlink=True)
        for side, sign in (("L", 1), ("R", -1)):
            arms._fingers(skeleton, mats, side, sign)
    bpy.context.view_layer.update()
    return {obj.name: obj for obj in bpy.context.scene.objects}


def ring_centre(obj, count, last=False):
    vertices = list(obj.data.vertices)[-count:] if last else list(obj.data.vertices)[:count]
    return sum((obj.matrix_world @ vertex.co for vertex in vertices), Vector()) / count


@pytest.mark.parametrize(("side", "expected"), [("R", -1), ("L", 1)])
@pytest.mark.parametrize("version", ["world", "first_person"])
def test_mesh_finger_order_palm_direction_and_thumb_side_are_anatomical(version, side, expected):
    nodes = hands(version)
    prefix, ring_size = ("Grip", 12) if version == "first_person" else ("Glove", 8)
    fingers = [nodes[name] for name in sorted(nodes) if name.startswith(prefix + "Finger" + side)]
    roots = [ring_centre(finger, ring_size) for finger in fingers]
    centre = sum(roots, Vector()) / len(roots)
    across = (roots[-1] - roots[0]).normalized()
    wrist = Vector(character_rig.BONES["hand_" + side][1])
    along = (centre - wrist).normalized()
    curl = ring_centre(fingers[1], ring_size, last=True) - roots[1]
    inward = (curl - across * curl.dot(across) - along * curl.dot(along)).normalized()
    assert across.cross(along).dot(inward) * expected > 0.95, "mirrored anatomy cannot be fixed with bone rotation"
    thumb = nodes[prefix + "Thumb" + side]
    thumb_centre = sum((thumb.matrix_world @ vertex.co for vertex in thumb.data.vertices), Vector()) / len(
        thumb.data.vertices
    )
    assert (thumb_centre - centre).dot(across) < -0.015, "the thumb belongs beside the index finger"
    assert all(component > 0 for component in thumb.scale), "geometry must not rely on negative scale"


def test_world_gloves_are_true_mirror_pairs_with_positive_object_scales():
    nodes = hands("world")
    vertices = [
        obj.matrix_world @ vertex.co for obj in nodes.values() if obj.type == "MESH" for vertex in obj.data.vertices
    ]
    left = [point for point in vertices if point.x > 0]
    right = [point for point in vertices if point.x < 0]
    assert len(left) == len(right)
    tree = KDTree(len(left))
    for index, point in enumerate(left):
        tree.insert(point, index)
    tree.balance()
    for point in right:
        _nearest, _index, distance = tree.find(Vector((-point.x, point.y, point.z)))
        assert distance < 1e-6
    assert all(component > 0 for obj in nodes.values() for component in obj.scale)


def test_relaxed_world_finger_rings_do_not_twist_at_the_fingertips():
    nodes = hands("world")
    for name, finger in nodes.items():
        if not name.startswith("GloveFinger"):
            continue
        reference = None
        for start in range(0, len(finger.data.vertices), 8):
            ring = list(finger.data.vertices)[start : start + 8]
            centre = sum((vertex.co for vertex in ring), Vector()) / len(ring)
            radial = (ring[0].co - centre).normalized()
            if reference is None:
                reference = radial
            assert radial.dot(reference) > 0.99, "a flipped sweep ring crosses the finger interior"


@pytest.mark.parametrize(("side", "sign", "y"), [("R", -1, -0.045), ("L", 1, -0.057)])
def test_first_person_palms_and_curls_clear_the_grip_volume(side, sign, y):
    nodes = hands("first_person")
    _across, _along, inward = arms._frame(sign)
    axis, depth = arms._grip_axes(sign, 0.032 if side == "R" else 0.045)
    centre = Vector((sign * 0.675, y, 0.985))
    parts = [
        obj
        for name, obj in nodes.items()
        if name.startswith(("GripFinger" + side, "GripThumb" + side, "GlovePalm" + side))
    ]
    for obj in parts:
        points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        points += [
            sum((points[index] for index in face.vertices), Vector()) / len(face.vertices) for face in obj.data.polygons
        ]
        for point in points:
            offset = point - centre
            clearance = (
                max(abs(offset.dot(depth)) - 0.0245, abs(offset.dot(inward)) - 0.016)
                if side == "R"
                else (offset - axis * offset.dot(axis)).length - 0.033
            )
            assert clearance >= -0.0001, (obj.name, clearance)


@pytest.mark.parametrize("side", ("R", "L"))
def test_oblique_finger_bases_and_thumb_remain_embedded_in_the_shared_palm(side):
    nodes = hands("first_person")
    palm = nodes["GlovePalm" + side]
    parts = [obj for name, obj in nodes.items() if name.startswith(("GripFinger" + side, "GripThumb" + side))]
    for obj in parts:
        distances = []
        for vertex in list(obj.data.vertices)[:12]:
            point = palm.matrix_world.inverted() @ (obj.matrix_world @ vertex.co)
            hit, nearest, normal, _face = palm.closest_point_on_mesh(point)
            assert hit
            distances.append((point - nearest).dot(normal))
        assert min(distances) < -0.001, (obj.name, "the finger root must overlap the palm by at least 1 mm")


def outline_distance(point, outline):
    inside, distance = False, float("inf")
    for index, start in enumerate(outline):
        end = outline[(index + 1) % len(outline)]
        edge = end - start
        fraction = max(0, min(1, (point - start).dot(edge) / edge.length_squared))
        distance = min(distance, (point - start - edge * fraction).length)
        if (start.y > point.y) != (end.y > point.y):
            crossing = start.x + (end.x - start.x) * (point.y - start.y) / (end.y - start.y)
            if point.x < crossing:
                inside = not inside
    return -distance if inside else distance


def test_firing_curls_clear_the_actual_rifle_grip_guard_trigger_and_receiver(monkeypatch):
    nodes = hands("first_person")
    profiles, original = {}, rifle_model.g.slab

    def capture(name, outline, width, mat, **options):
        if name in ("Grip", "TriggerGuard", "Trigger", "Lower"):
            profiles[name] = ([Vector(point) for point in outline], width / 2)
        return original(name, outline, width, mat, **options)

    monkeypatch.setattr(rifle_model.g, "slab", capture)
    mat = arms._materials()["rubber"]
    rifle_model.lower(build_models, mat, mat)
    bpy.context.view_layer.update()
    across, along, inward = arms._frame(-1)
    minimum = {name: float("inf") for name in profiles}
    for obj in nodes.values():
        if obj.type != "MESH" or not obj.name.split(".")[0].endswith("R"):
            continue
        points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        points += [
            sum((points[index] for index in face.vertices), Vector()) / len(face.vertices) for face in obj.data.polygons
        ]
        for point in points:
            relative = point - Vector((-0.675, -0.045, 0.985))
            gun = Vector((0, -0.129, -0.111))
            gun += Vector((0, 0.5, -math.sqrt(0.75))) * relative.dot(across)
            gun += Vector((0, math.sqrt(0.75), 0.5)) * relative.dot(along)
            gun += Vector((-1, 0, 0)) * relative.dot(inward)
            for name, (outline, half_width) in profiles.items():
                clearance = max(abs(gun.x) - half_width, outline_distance(Vector((gun.y, gun.z)), outline))
                assert clearance >= 0, (obj.name, name, clearance)
                minimum[name] = min(minimum[name], clearance)
    assert minimum["Grip"] < 0.006, "clearing the guard must not pull the hand away from its grip"
