"""Inspection detail must retain articulated pivots and real recessed marks."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy
import character_checks
import character_models
import check_models
import gear_paint as paint
import pytest
from mathutils import Vector


@pytest.fixture(params=("source", "committed"))
def build(request):
    def load(name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        path, builder = character_models.MODELS[name]
        if request.param == "source":
            builder()
        else:
            check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
        bpy.context.view_layer.update()
        return {obj.name: obj for obj in bpy.context.scene.objects}

    return load


@pytest.mark.parametrize("name", character_checks.CHARMS)
def test_chain_keeps_exact_attachment_pivots_and_interlocked_links(build, name):
    nodes = build(name)
    for node, height in (("Hook", 0), ("Link1", 0), ("Link2", -0.012), ("Body", -0.024)):
        assert tuple(nodes[node].matrix_world.translation) == pytest.approx((0, 0, height), abs=1e-7)
    first_low, first_high = check_models.bounds([nodes["Link1"]])
    second_low, second_high = check_models.bounds([nodes["Link2"]])
    assert first_high.z == pytest.approx(0, abs=1e-7)
    assert second_high.z - first_low.z > 0.0015, "orthogonal links must interlock instead of touching at a point"
    assert first_high.x - first_low.x > first_high.y - first_low.y
    assert second_high.y - second_low.y > second_high.x - second_low.x


def _front_hit(obj, xz):
    x, z = xz
    inverse = obj.matrix_world.inverted()
    hit, position, _normal, _face = obj.ray_cast(inverse @ Vector((x, -0.1, z)), Vector((0, 1, 0)))
    assert hit, "stamp samples must hit the body"
    return (obj.matrix_world @ position).y


@pytest.mark.parametrize(
    "name,stamp,face,depth",
    (
        ("charm_dog_tags", (0, -0.057), (0.002, -0.055), 0.0003),
        ("charm_keycard", (-0.008, -0.053), (-0.011, -0.053), 0.00035),
        ("charm_coin", (-0.006, -0.045), (-0.009, -0.045), 0.00035),
        ("charm_dosimeter", (0, -0.062), (0, -0.061), 0.0002),
    ),
)
def test_stamped_marks_are_below_the_surface(build, name, stamp, face, depth):
    body = build(name)["Body"]
    assert _front_hit(body, stamp) - _front_hit(body, face) == pytest.approx(depth, abs=1e-6)


def test_vial_has_clear_shell_separate_liquid_and_a_raised_meniscus(build):
    body = build("charm_vial")["Body"]
    glass = body.data.materials.find("GearGlass")
    liquid = body.data.materials.find("GearLiquid")
    assert glass >= 0 and liquid >= 0
    points = {}
    for index in (glass, liquid):
        points[index] = [
            body.matrix_world @ body.data.vertices[vertex].co
            for face in body.data.polygons
            if face.material_index == index
            for vertex in face.vertices
        ]
    assert max(point.z for point in points[liquid]) == pytest.approx(-0.0495, abs=1e-7)
    assert max(point.z for point in points[glass]) > max(point.z for point in points[liquid]) + 0.01
    assert max(abs(point.x) for point in points[liquid]) < max(abs(point.x) for point in points[glass])
    meniscus = [point for point in points[liquid] if point.z > -0.0501]
    assert max(point.z for point in meniscus) - min(point.z for point in meniscus) > 0.0004
    attribute = body.data.color_attributes["Color"]
    for face in body.data.polygons:
        if face.material_index == glass:
            assert paint._face_zone(body.data, attribute, face) == paint.ZONE_MAIN
