"""Implant cutaways preserve attachments while real recesses survive GLB export."""

import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy
import character_checks
import character_models
import check_models
import pytest
from mathutils import Matrix, Vector


def _model(name, version):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path, build = character_models.MODELS[name]
    if version == "source":
        build()
    else:
        check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
    bpy.context.view_layer.update()
    return bpy.data.objects["Module"], bpy.data.objects["Port"]


def _front_edges(module):
    """Outer black profile sampled in physical metres, independent of face/material names."""
    points = [module.matrix_world @ vertex.co for vertex in module.data.vertices]
    profile = []
    for z in (-0.045, -0.055, -0.065, -0.075, -0.085, -0.095, -0.105, -0.115, -0.125, -0.135):
        crossings = []
        for edge in module.data.edges:
            a, b = (points[index] for index in edge.vertices)
            if min(a.z, b.z) <= z <= max(a.z, b.z) and abs(a.z - b.z) > 1e-8:
                crossings.append(a.x + (b.x - a.x) * (z - a.z) / (b.z - a.z))
        assert crossings, "the cutaway must leave the longitudinal mounting saddle"
        profile.extend((min(crossings), max(crossings)))
    return profile


@pytest.mark.parametrize("version", ("source", "committed"))
def test_implants_have_distinct_front_black_profiles(version):
    profiles = {}
    for name in character_checks.IMPLANTS:
        module, _port = _model(name, version)
        profiles[name] = _front_edges(module)
    for first, second in itertools.combinations(profiles, 2):
        difference = max(abs(a - b) for a, b in zip(profiles[first], profiles[second], strict=True))
        assert difference > 0.008, (first, second, "shape difference must exceed tiny surface marks", difference)


def _front_hit(obj, x, z):
    hit, point, _normal, _face = obj.ray_cast(Vector((x, -0.2, z)), Vector((0, 1, 0)))
    assert hit, "the recess needs a closed backing surface"
    return point.y


@pytest.mark.parametrize("version", ("source", "committed"))
@pytest.mark.parametrize("name", character_checks.IMPLANTS)
def test_implant_ports_and_screws_are_recessed_and_origins_stay_exact(name, version):
    module, port = _model(name, version)
    for obj in (module, port):
        assert obj.parent is None
        assert all(
            abs(obj.matrix_world[row][column] - Matrix.Identity(4)[row][column]) < 1e-6
            for row in range(4)
            for column in range(4)
        )
    low, high = check_models.bounds([module, port])
    assert low.x >= -0.0681 and high.x <= 0.0941
    assert low.z == pytest.approx(-0.160, abs=1e-6)
    assert high.z <= 0.0721 and high.y <= 0.0346
    for x in (-0.029, 0.029):
        assert _front_hit(module, x, -0.144) - _front_hit(module, x + 0.005, -0.144) > 0.008
        assert _front_hit(module, x, -0.032) - _front_hit(module, x, -0.0305) > 0.0004
    if name != "implant_ocular":
        assert _front_hit(port, 0.066, 0.050) - _front_hit(port, 0.066, 0.058) > 0.0008
