"""Every implant triangle clears the forearm bore, including faces between different shell sections."""

import math
import sys
from pathlib import Path

import bpy
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import character_checks
import character_models
import check_models
from mathutils import Vector


def _edge_distance(a, b):
    edge = b - a
    fraction = max(0.0, min(1.0, -a.dot(edge) / edge.length_squared)) if edge.length_squared > 0 else 0.0
    return (a + edge * fraction).length


def _minimum_radius(points):
    """Exact distance from the bore axis to the entire triangle's XY projection."""
    pairs = list(zip(points, points[1:] + points[:1], strict=True))
    crosses = [a.x * b.y - a.y * b.x for a, b in pairs]
    if abs(sum(crosses)) > 1e-15 and (min(crosses) >= 0 or max(crosses) <= 0):
        return 0.0
    return min(_edge_distance(a, b) for a, b in pairs)


def test_clearance_measure_includes_face_interiors_and_degenerate_projections():
    triangle = [Vector(point) for point in ((0.061, 0), (0, 0.061), (0.070, 0))]
    assert _minimum_radius(triangle) == pytest.approx(0.061 / math.sqrt(2))
    around_axis = [Vector(point) for point in ((0.06, -0.02), (-0.06, -0.02), (0, 0.06))]
    assert _minimum_radius(around_axis) == 0.0
    edge_on = [Vector(point) for point in ((0.06, 0), (0.06, 0), (0.07, 0))]
    assert _minimum_radius(edge_on) == pytest.approx(0.06)


@pytest.mark.parametrize("name", character_checks.IMPLANTS)
@pytest.mark.parametrize("version", ("source", "committed"))
def test_entire_module_surface_clears_the_forearm_bore(name, version):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path, build = character_models.MODELS[name]
    if version == "source":
        build()
    else:
        check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
    bpy.context.view_layer.update()
    module = bpy.data.objects["Module"]
    module.data.calc_loop_triangles()
    worst = (float("inf"), -1)
    for index, triangle in enumerate(module.data.loop_triangles):
        points = [(module.matrix_world @ module.data.vertices[vertex].co).xy for vertex in triangle.vertices]
        worst = min(worst, (_minimum_radius(points), index))
    # A 60 mm faceted bore may lose 0.3 mm at a chord, while still clearing the built thermal sleeve.
    assert worst[0] >= 0.0597 - 1e-6, (name, version, "triangle radius below 59.7 mm", worst)
