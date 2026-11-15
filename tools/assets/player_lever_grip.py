"""Fieldhand glove curls follow the lever opening and leave the index extended."""

import math

import player_grip_frames as frames
from mathutils import Vector
from player_stock_grip import _curve as stock_curve

SOURCE = Vector((-0.675, -0.055, 0.985))
ANCHOR = Vector((0, -0.145, -0.050))
ALONG = Vector((0, math.cos(math.radians(20)), math.sin(math.radians(20))))
INWARD = Vector((-1, 0, 0))
ACROSS = INWARD.cross(ALONG)
REST_ACROSS, REST_ALONG, REST_INWARD = frames.rest_frame(-1)


def _gun(point):
    return frames.transform(point, SOURCE, ANCHOR, (REST_ACROSS, REST_ALONG, REST_INWARD), (ACROSS, ALONG, INWARD))


def _source(point):
    return frames.transform(point, ANCHOR, SOURCE, (ACROSS, ALONG, INWARD), (REST_ACROSS, REST_ALONG, REST_INWARD))


def _curve(controls, count):
    return stock_curve(controls, count, _source)


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
