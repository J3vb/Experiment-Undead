"""Support glove paths for the angled handstop and two-handed handgun holds."""

import math

from mathutils import Vector

ACROSS = Vector((0.6, -0.8, 0))
ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
INWARD = Vector((-0.16, -0.12, math.sqrt(0.96)))
SOURCE_ACROSS = Vector((-1, 0, -1)).normalized()
SOURCE_ALONG = Vector((1, 0, -1)).normalized()
SOURCE_INWARD = Vector((0, -1, 0))
SOURCE_CENTRE = Vector((0.675, -0.057, 0.985))
GUN_CENTRE = Vector((0, 0.178, -0.040))


def _mako_gun(point):
    offset = point - SOURCE_CENTRE
    return (
        GUN_CENTRE
        + ACROSS * offset.dot(SOURCE_ACROSS)
        + ALONG * offset.dot(SOURCE_ALONG)
        + INWARD * offset.dot(SOURCE_INWARD)
    )


def _mako_source(point):
    offset = point - GUN_CENTRE
    return (
        SOURCE_CENTRE
        + SOURCE_ACROSS * offset.dot(ACROSS)
        + SOURCE_ALONG * offset.dot(ALONG)
        + SOURCE_INWARD * offset.dot(INWARD)
    )


def mako_finger(rifle_points, index):
    first = _mako_gun(rifle_points[0]) - Vector((0, 0, 0.005))
    y = GUN_CENTRE.y + 0.032 - index * 0.018
    near = Vector((0.020 + 0.003 * index, y + 0.010, -0.060))
    points = [first, first.lerp(near, 0.5), near]
    for x, dy, z in (
        (0.032 + 0.001 * index, 0.012, -0.048),
        (0.036, 0.011, -0.036),
        (0.036, 0.009, -0.026),
        (0.035, 0.006, -0.015),
        (0.035, 0.003, -0.002),
        (0.031, 0.001, 0.008),
        (0.0245, 0, 0.005),
    ):
        points.append(Vector((x, y + dy, z)))
    return [_mako_source(point) for point in points]


def mako_thumb():
    y = GUN_CENTRE.y + 0.032
    start = Vector((0.649, 0, 1.011)) - SOURCE_ACROSS * 0.034 - SOURCE_ALONG * 0.006 + SOURCE_INWARD * 0.008
    points = [_mako_gun(start)]
    points += [
        Vector((x, y + dy, z))
        for x, dy, z in (
            (-0.042, -0.020, -0.080),
            (-0.040, -0.012, -0.050),
            (-0.039, -0.005, -0.020),
            (-0.037, 0, 0.009),
            (-0.0245, 0, 0.005),
        )
    ]
    return [_mako_source(point) for point in points]
