"""Shared hand checks for the grip tests: finger paths, index reach angles and digit spacing."""

import math
from itertools import pairwise

import player_grip_model as grip
from mathutils import Vector

ROOT = Vector((-0.675, -0.017, 0.985))
WIDTH = 0.032


def path_length(points):
    return sum((second - first).length for first, second in pairwise(points))


def finger_paths(profile):
    """The four right-hand finger paths that a stock profile builds."""
    across, _along, _inward = grip._frame(-1)
    return [grip._finger_path(ROOT + across * (index - 1.5) * 0.016, -1, WIDTH, index, profile) for index in range(4)]


def assert_index_reach(points, extension=(-75, 30), abduction=30):
    """The proximal index points forward: no dorsal hyperextension and no sideways splay."""
    across, along, inward = grip._frame(-1)
    for station in (1, 2, 3):
        direction = (points[station] - points[0]).normalized()
        bend = math.degrees(math.atan2(-direction.dot(inward), direction.dot(along)))
        splay = math.degrees(math.atan2(direction.dot(across), direction.dot(along)))
        assert extension[0] < bend < extension[1], "the index must not bend backward into the glove's dorsal side"
        assert abs(splay) < abduction, "the proximal index must follow the palm before its distal curl"


def assert_lower_digits_apart(profile, max_length):
    """Middle, ring and little fingers stay apart past the knuckle web and keep a natural length."""
    paths = finger_paths(profile)
    for index in (1, 2):
        first, second = paths[index : index + 2]
        first_radii = grip._finger_radii(WIDTH, index, profile)
        second_radii = grip._finger_radii(WIDTH, index + 1, profile)
        for first_row in range(5, 14):
            for second_row in range(5, 14):
                distance = (first[first_row] - second[second_row]).length
                assert distance > first_radii[first_row] + second_radii[second_row] + 0.0005
    assert all(path_length(path) < max_length for path in paths)
