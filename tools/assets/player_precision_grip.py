"""Trigger reach and thumbhole wrap for the wide precision stock."""

import math

from mathutils import Vector

SOURCE = Vector((-0.675, -0.054, 0.985))
ANCHOR = Vector((0, -0.118, -0.123))
ACROSS = Vector((0, 0.5, -math.sqrt(0.75)))
ALONG = Vector((0, math.sqrt(0.75), 0.5))
INWARD = Vector((-1, 0, 0))
REST_ACROSS = Vector((1, 0, -1)).normalized()
REST_ALONG = Vector((-1, 0, -1)).normalized()
REST_INWARD = Vector((0, -1, 0))


def _source(point):
    relative = point - ANCHOR
    return (
        SOURCE
        + REST_ACROSS * relative.dot(ACROSS)
        + REST_ALONG * relative.dot(ALONG)
        + REST_INWARD * relative.dot(INWARD)
    )


def _gun(point):
    relative = point - SOURCE
    return (
        ANCHOR
        + ACROSS * relative.dot(REST_ACROSS)
        + ALONG * relative.dot(REST_ALONG)
        + INWARD * relative.dot(REST_INWARD)
    )


def finger_path(start):
    """Leave the stock side and curl the index inside the empty trigger well."""
    controls = [
        (0.042, -0.112, -0.090),
        (0.039, -0.092, -0.078),
        (0.036, -0.078, -0.068),
        (0.031, -0.067, -0.062),
        (0.024, -0.054, -0.062),
        (0.015, -0.048, -0.064),
        (0.006, -0.0465, -0.064),
        (-0.003, -0.047, -0.064),
        (-0.007, -0.0477, -0.064),
        (-0.010, -0.048, -0.064),
        (-0.012, -0.0482, -0.064),
        (-0.013, -0.0483, -0.064),
        (-0.0135, -0.04835, -0.064),
    ]
    return [start, *[_source(Vector(point)) for point in controls]]


def thumb_path():
    """Cross the open space behind the stock wrist, then rest along its left side."""
    start = Vector((-0.649, 0, 1.011)) - REST_ACROSS * 0.034 - REST_ALONG * 0.006 + REST_INWARD * 0.008
    controls = [
        (0.048, -0.164, -0.087),
        (0.043, -0.159, -0.074),
        (0.020, -0.157, -0.074),
        (-0.005, -0.157, -0.072),
        (-0.030, -0.155, -0.070),
        (-0.037, -0.148, -0.071),
        (-0.035, -0.142, -0.073),
        (-0.032, -0.138, -0.075),
        (-0.029, -0.136, -0.076),
    ]
    return [start, *[_source(Vector(point)) for point in controls]]
