"""Support fits use the real concave shell and finite ribs around the cradle."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import player_heavy_grip as heavy
import pytest
from mathutils import Vector


def test_section_distance_keeps_a_concave_rail_notch_outside_the_shell():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    polygon = tuple(Vector(point) for point in ((0, 0), (2, 0), (2, 1), (1, 1), (1, 2), (0, 2)))
    assert heavy._section_distance(Vector((1.5, 1.5)), polygon) == pytest.approx(0.5)
    assert heavy._section_distance(Vector((0.5, 1.5)), polygon) == pytest.approx(-0.5)


def test_fingers_can_seat_between_finite_ribs_instead_of_floating_over_their_envelope():
    point = Vector((0.035, -0.039))
    between_ribs = heavy._section("rampart_br", 0.210, 0.002)
    touching_rib = heavy._section("rampart_br", 0.180, 0.002)
    assert heavy._section_distance(point, between_ribs) > 0.002
    assert heavy._section_distance(point, touching_rib) < -0.001
