"""Fieldhand glove curls follow the lever opening and leave the index extended."""

import math

from mathutils import Vector

SOURCE = Vector((-0.675, -0.055, 0.985))
ANCHOR = Vector((0, -0.145, -0.050))
ALONG = Vector((0, math.cos(math.radians(20)), math.sin(math.radians(20))))
INWARD = Vector((-1, 0, 0))
ACROSS = INWARD.cross(ALONG)
REST_ACROSS = Vector((1, 0, -1)).normalized()
REST_ALONG = Vector((-1, 0, -1)).normalized()
REST_INWARD = Vector((0, -1, 0))


def _gun(point):
    relative = point - SOURCE
    return (
        ANCHOR
        + ACROSS * relative.dot(REST_ACROSS)
        + ALONG * relative.dot(REST_ALONG)
        + INWARD * relative.dot(REST_INWARD)
    )


def _source(point):
    relative = point - ANCHOR
    return (
        SOURCE
        + REST_ACROSS * relative.dot(ACROSS)
        + REST_ALONG * relative.dot(ALONG)
        + REST_INWARD * relative.dot(INWARD)
    )


def _curve(controls, count):
    points = []
    for row in range(count):
        fractions = (
            0,
            0.10,
            0.20,
            0.30,
            0.40,
            0.50,
            0.60,
            0.70,
            0.80,
            0.88,
            0.94,
            0.975,
            0.992,
            1,
        )
        if count == 10:
            fractions = (0, 0.14, 0.28, 0.42, 0.55, 0.68, 0.80, 0.90, 0.97, 1)
        time = fractions[row] * (len(controls) - 1)
        section = min(len(controls) - 2, int(time))
        blend = time - section
        p0, p1 = controls[max(0, section - 1)], controls[section]
        p2, p3 = controls[section + 1], controls[min(len(controls) - 1, section + 2)]
        point = 2 * p1 + (-p0 + p2) * blend
        point += (2 * p0 - 5 * p1 + 4 * p2 - p3) * blend**2
        point += (-p0 + 3 * p1 - 3 * p2 + p3) * blend**3
        points.append(_source(point * 0.5))
    return points


def finger_radii(index):
    """Keep MCP attachment size and taper the phalanges through the lever loop."""
    scale = (0.98, 1, 0.96, 0.86)[index]
    radii = (
        0.010,
        0.0095,
        0.009,
        0.0085,
        0.0085,
        0.008,
        0.008,
        0.0075,
        0.007,
        0.006,
        0.0055,
        0.0045,
        0.0032,
        0.002,
    )
    return [radius * scale for radius in radii]


def finger_path(start, index):
    """Curl in each finger's flexion plane without crossing neighbouring digits."""
    start = _gun(start)
    if index == 0:
        start.x += 0.002
    knots = [
        [
            (0.043, -0.132, -0.028),
            (0.035, -0.108, -0.037),
            (0.022, -0.087, -0.050),
            (0.010, -0.075, -0.057),
        ],
        [
            (0.038, -0.132, -0.042),
            (0.010, -0.135, -0.046),
            (-0.022, -0.148, -0.047),
            (-0.034, -0.161, -0.043),
        ],
        [
            (0.036, -0.129, -0.057),
            (0.007, -0.138, -0.062),
            (-0.024, -0.153, -0.063),
            (-0.032, -0.168, -0.060),
        ],
        [
            (0.034, -0.130, -0.071),
            (0.005, -0.150, -0.072),
            (-0.020, -0.164, -0.074),
            (-0.022, -0.173, -0.071),
        ],
    ]
    return _curve([start, *[Vector(point) for point in knots[index]]], 14)


def thumb_path():
    """Place the thumb along the stock comb without imposing a tip-gap target."""
    start = Vector((-0.649, 0, 1.011)) - REST_ACROSS * 0.015 - REST_ALONG * 0.006 + REST_INWARD * 0.008
    controls = [
        _gun(start),
        Vector((0.052, -0.190, -0.018)),
        Vector((0.044, -0.190, 0.010)),
    ]
    return _curve([*controls, Vector((0.030, -0.187, 0.030)), Vector((0.018, -0.184, 0.026))], 10)
