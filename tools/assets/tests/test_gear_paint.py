"""Small in-memory meshes exercise gear zone painting and alpha-safe AO masks."""

import os
import struct
import sys

import bpy
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import finish
import gear_paint as paint


@pytest.fixture(autouse=True)
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def cube():
    bpy.ops.mesh.primitive_cube_add()
    obj = bpy.context.active_object
    mat = bpy.data.materials.new("GearTest")
    mat.use_nodes = True
    obj.data.materials.append(mat)
    return obj


def test_zone_initializes_unpainted_faces_to_main():
    obj = cube()
    paint.zone(obj, paint.ZONE_TRIM, faces=[1, 4])
    attr = obj.data.color_attributes["Color"]
    assert attr.domain == "CORNER"
    for face in obj.data.polygons:
        expected = paint.ZONE_TRIM if face.index in {1, 4} else paint.ZONE_MAIN
        for index in face.loop_indices:
            assert tuple(attr.data[index].color) == pytest.approx((1, 1, 1, expected))


def test_zone_changes_only_selected_faces_and_preserves_rgb():
    obj = cube()
    paint.zone(obj, paint.ZONE_MAIN)
    attr = obj.data.color_attributes["Color"]
    for color in attr.data:
        color.color = (0.2, 0.4, 0.6, paint.ZONE_MAIN)
    paint.zone(obj, paint.ZONE_ACCENT, faces=[obj.data.polygons[2]])
    for face in obj.data.polygons:
        expected = paint.ZONE_ACCENT if face.index == 2 else paint.ZONE_MAIN
        for index in face.loop_indices:
            assert tuple(attr.data[index].color) == pytest.approx((0.2, 0.4, 0.6, expected))
    paint.zone(obj, paint.ZONE_TRIM)
    assert all(color.color[3] == pytest.approx(paint.ZONE_TRIM) for color in attr.data)


def test_zone_shares_use_surface_area_with_object_scale():
    obj = cube()
    obj.scale = (1, 2, 3)
    bpy.context.view_layer.update()
    paint.zone(obj, paint.ZONE_MAIN)
    face = next(face for face in obj.data.polygons if face.normal.x > 0.9)
    paint.zone(obj, paint.ZONE_ACCENT, faces=[face.index])
    shares = paint.zone_shares(obj)
    assert sum(shares.values()) == pytest.approx(1)
    assert shares[paint.ZONE_ACCENT] == pytest.approx(24 / 88)
    assert shares[paint.ZONE_MAIN] == pytest.approx(64 / 88)
    assert shares[paint.ZONE_GLOW] == shares[paint.ZONE_TRIM] == 0


def test_zone_shares_accept_quantized_alpha():
    obj = cube()
    attr = obj.data.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
    for color in attr.data:
        color.color = (1, 1, 1, paint.ZONE_ACCENT)
    assert paint.zone_shares(obj)[paint.ZONE_ACCENT] == pytest.approx(1)


def test_zone_shares_reject_missing_or_mixed_zones():
    obj = cube()
    with pytest.raises(ValueError, match="every face needs a zone"):
        paint.zone_shares(obj)
    paint.zone(obj, paint.ZONE_MAIN)
    obj.data.color_attributes["Color"].data[0].color[3] = paint.ZONE_GLOW
    with pytest.raises(ValueError, match="mixes gear zones"):
        paint.zone_shares(obj)


@pytest.mark.parametrize("alpha", [float("nan"), float("inf"), float("-inf"), 0.5])
def test_zone_shares_reject_invalid_alpha(alpha):
    obj = cube()
    paint.zone(obj, paint.ZONE_MAIN)
    colors = obj.data.color_attributes["Color"].data
    values = [component for color in colors for component in color.color]
    values[3] = alpha
    colors.foreach_set("color", values)
    with pytest.raises(ValueError, match="unknown zone alpha"):
        paint.zone_shares(obj)


@pytest.mark.parametrize("glowing", [False, True])
def test_finish_mask_keeps_all_zone_alphas(glowing):
    obj = cube()
    obj.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = (
        2.0 if glowing else 0.0
    )
    paint.zone(obj, paint.ZONE_MAIN)
    for index, value in enumerate(paint.ZONES):
        paint.zone(obj, value, faces=[index])
    attr = obj.data.color_attributes["Color"]
    alphas = [color.color[3] for color in attr.data]
    for color in attr.data:
        color.color = (0.25, 0.25, 0.25, color.color[3])
    finish.apply_mask(obj)
    assert [color.color[3] for color in attr.data] == alphas
    expected = 1.0 if glowing else 1.0 - finish.AO_STRENGTH + finish.AO_STRENGTH * 0.25
    assert all(tuple(color.color[:3]) == pytest.approx((expected,) * 3) for color in attr.data)


@pytest.mark.parametrize("glowing", [False, True])
def test_finish_keeps_all_zones_through_real_ao_bake(glowing):
    obj = cube()
    obj.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = (
        2.0 if glowing else 0.0
    )
    paint.zone(obj, paint.ZONE_MAIN)
    for index, value in enumerate(paint.ZONES):
        paint.zone(obj, value, faces=[index])
    attr = obj.data.color_attributes["Color"]
    alphas = [color.color[3] for color in attr.data]
    for color in attr.data:
        color.color = (0.17, 0.17, 0.17, color.color[3])
    shares = paint.zone_shares(obj)
    finish.finish()
    colors = obj.data.color_attributes["Color"].data
    assert [color.color[3] for color in colors] == alphas
    assert paint.zone_shares(obj) == pytest.approx(shares)
    assert any(color.color[0] > 0.9 for color in colors)


def test_finish_without_existing_colors_keeps_legacy_alpha_one():
    obj = cube()
    finish.finish()
    assert all(color.color[3] == 1.0 for color in obj.data.color_attributes["Color"].data)


@pytest.mark.parametrize("glowing", [False, True])
def test_alpha_one_mask_is_byte_identical_to_previous_formula(glowing):
    obj = cube()
    obj.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = (
        2.0 if glowing else 0.0
    )
    paint.zone(obj, paint.ZONE_MAIN)
    attr = obj.data.color_attributes["Color"]
    for index, color in enumerate(attr.data):
        value = (index % 7) / 6
        color.color = (value, value, value, 1.0)
    cavities = finish.cavity(obj.data)
    expected = bytearray()
    for loop in obj.data.loops:
        value = 1.0
        if not glowing:
            ao = attr.data[loop.index].color[0]
            value = (1.0 - finish.AO_STRENGTH + finish.AO_STRENGTH * ao) * (
                1.0 - finish.CAVITY_STRENGTH * cavities[loop.vertex_index]
            )
        expected.extend(struct.pack("<4f", value, value, value, 1.0))
    finish.apply_mask(obj)
    actual = b"".join(struct.pack("<4f", *color.color) for color in attr.data)
    assert actual == bytes(expected)
