"""Inspect details remain closed, preserve gear paint and remove material instead of stacking plates."""

import sys
from pathlib import Path

import bpy
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import character_models
import check_models
import gear_paint as paint
from gear_parts import engrave, outlined_plate, refine_face
from mathutils import Vector


@pytest.fixture(autouse=True)
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _materials():
    return [bpy.data.materials.new(name) for name in ("GearPlate", "GearRubber")]


def _plate(outline=None, bevel=0.0004):
    plate, rubber = _materials()
    outline = outline or [(-0.02, -0.025), (0.02, -0.025), (0.02, 0.025), (-0.02, 0.025)]
    return outlined_plate("Plate", outline, 0.002, (0.03, 0.01, -0.05), plate, bevel), rubber


def _assert_closed(obj):
    bm = check_models.world_mesh(obj)
    assert all(len(edge.link_faces) == 2 for edge in bm.edges), "engraving must not punch through or leave holes"
    assert all(face.calc_area() > 1e-10 for face in bm.faces)
    assert bm.calc_volume(signed=True) > 0
    bm.free()
    assert not obj.modifiers


@pytest.mark.parametrize("reverse", [False, True])
@pytest.mark.parametrize("bevel", [0.0, 0.0004])
def test_concave_plate_keeps_its_notched_silhouette_and_closed_bevel(reverse, bevel):
    outline = [
        (-0.02, -0.025),
        (0.02, -0.025),
        (0.02, 0.025),
        (0.006, 0.025),
        (0.006, 0.008),
        (-0.006, 0.008),
        (-0.006, 0.025),
        (-0.02, 0.025),
    ]
    obj, _rubber = _plate(list(reversed(outline)) if reverse else outline, bevel)
    bpy.context.view_layer.update()
    assert obj.ray_cast(Vector((0, -0.01, 0.018)), Vector((0, 1, 0)))[0] is False
    assert obj.ray_cast(Vector((0.012, -0.01, 0.018)), Vector((0, 1, 0)))[0] is True
    low, high = check_models.bounds([obj])
    assert tuple(high - low) == pytest.approx((0.04, 0.002, 0.05))
    assert tuple(obj.location) == pytest.approx((0.03, 0.01, -0.05))
    assert paint.zone_shares(obj)[paint.ZONE_MAIN] == pytest.approx(1.0)
    _assert_closed(obj)


def test_stamps_recess_the_front_without_expanding_bounds_or_losing_zones():
    obj, rubber = _plate()
    for face in obj.data.polygons:
        if face.normal.y < -0.9:
            paint.zone(obj, paint.ZONE_TRIM, [face])
        elif face.normal.y > 0.9:
            paint.zone(obj, paint.ZONE_GLOW, [face])
    for color in obj.data.color_attributes["Color"].data:
        color.color = (0.7, 0.7, 0.7, color.color[3])
    bpy.context.view_layer.update()
    bounds = check_models.bounds([obj])
    strokes = [(-0.007, 0.0, 0.003, 0.010), (0, -0.005, 0.003, 0.006), (0.007, 0.003, 0.003, 0.014)]
    engrave(obj, strokes, 0.0003, rubber)
    bpy.context.view_layer.update()
    for x, z, _width, _height in strokes:
        hit, point, _normal, index = obj.ray_cast(Vector((x, -0.01, z)), Vector((0, 1, 0)))
        assert hit and point.y == pytest.approx(-0.0007)
        assert obj.data.materials[obj.data.polygons[index].material_index] == rubber
    _hit, point, _normal, index = obj.ray_cast(Vector((0.014, -0.01, 0)), Vector((0, 1, 0)))
    assert point.y == pytest.approx(-0.001)
    attribute = obj.data.color_attributes["Color"]
    assert paint._face_zone(obj.data, attribute, obj.data.polygons[index]) == paint.ZONE_TRIM
    assert attribute.data[obj.data.polygons[index].loop_start].color[0] == pytest.approx(0.7)
    assert all(share > 0 for share in paint.zone_shares(obj).values())
    for before, after in zip(bounds, check_models.bounds([obj]), strict=True):
        assert tuple(after) == pytest.approx(tuple(before))
    assert len(bpy.context.scene.objects) == 1, "cutters must not leak into exports"
    _assert_closed(obj)


def test_overlapping_strokes_form_one_closed_recess():
    obj, rubber = _plate()
    engrave(obj, [(0, 0, 0.003, 0.016), (0.003, -0.005, 0.009, 0.003)], 0.00025, rubber)
    _assert_closed(obj)
    assert paint.zone_shares(obj)[paint.ZONE_ACCENT] > 0


@pytest.mark.parametrize("depth", [0, -0.001, 0.002, 0.003])
def test_stamp_rejects_cutting_through_the_shell(depth):
    obj, rubber = _plate()
    with pytest.raises(ValueError, match="shallower"):
        engrave(obj, [(0, 0, 0.005, 0.005)], depth, rubber)


def test_stamp_rejects_nonpositive_sizes_before_changing_the_mesh():
    obj, rubber = _plate()
    count = len(obj.data.vertices)
    with pytest.raises(ValueError, match="positive"):
        engrave(obj, [(0, 0, 0.005, 0.005), (0.01, 0, 0, 0.005)], 0.0003, rubber)
    assert len(obj.data.vertices) == count


def test_flat_face_refinement_localizes_ao_without_changing_shape_or_zones():
    obj, rubber = _plate()
    paint.zone(obj, paint.ZONE_TRIM, [face for face in obj.data.polygons if face.normal.y > 0.9])
    engrave(obj, [(-0.006, 0, 0.003, 0.014), (0.006, 0.004, 0.003, 0.008)], 0.0003, rubber)
    bpy.context.view_layer.update()
    bounds, shares = check_models.bounds([obj]), paint.zone_shares(obj)
    before = check_models.world_mesh(obj)
    volume = before.calc_volume()
    before.free()
    refine_face(obj)
    bpy.context.view_layer.update()
    _assert_closed(obj)
    after = check_models.world_mesh(obj)
    assert after.calc_volume() == pytest.approx(volume, rel=1e-6)
    after.free()
    assert paint.zone_shares(obj) == pytest.approx(shares, abs=1e-7)
    for old, new in zip(bounds, check_models.bounds([obj]), strict=True):
        assert tuple(new) == pytest.approx(tuple(old))
    for face in obj.data.polygons:
        if face.normal.y < -0.999:
            points = [obj.data.vertices[index].co for index in face.vertices]
            for axis in (0, 2):
                assert max(point[axis] for point in points) - min(point[axis] for point in points) <= 0.006001
    hit, point, _normal, face_index = obj.ray_cast(Vector((-0.006, -0.01, 0)), Vector((0, 1, 0)))
    assert hit and point.y == pytest.approx(-0.0007)
    assert obj.data.materials[obj.data.polygons[face_index].material_index] == rubber


@pytest.mark.parametrize("pitch", [0, -0.006])
def test_flat_face_refinement_rejects_nonpositive_pitch(pitch):
    obj, _rubber = _plate()
    with pytest.raises(ValueError, match="positive"):
        refine_face(obj, pitch)


@pytest.mark.parametrize("name", ["charm_dog_tags", "charm_keycard", "charm_coin"])
def test_refined_stamped_caps_keep_valid_triangles_after_gltf_export(name, tmp_path):
    from build_models import export

    character_models.MODELS[name][1]()
    bpy.context.view_layer.update()
    objects = list(bpy.context.scene.objects)
    assert check_models.check_geometry(objects, "gear") == []
    bounds = check_models.bounds(objects)
    shares = paint.zone_shares(bpy.data.objects["Body"])
    path = tmp_path / (name + ".glb")
    export(str(path))
    objects = check_models.load_glb(str(path))
    assert check_models.check_geometry(objects, "gear") == []
    assert paint.zone_shares(bpy.data.objects["Body"]) == pytest.approx(shares, abs=1e-6)
    for old, new in zip(bounds, check_models.bounds(objects), strict=True):
        assert tuple(new) == pytest.approx(tuple(old), abs=1e-7)
