"""Fieldhand glove curls follow the lever opening and leave the index extended."""

import player_grip_frames as frames
from mathutils import Vector
from player_stock_grip import _curve as stock_curve

SOURCE = Vector((-0.675, -0.055, 0.985))
ANCHOR = Vector((-0.008, -0.145, -0.050))
ALONG = Vector((-0.100000001490116, 0.762204587459564, 0.639565587043762))
INWARD = Vector((-0.994987428188324, -0.0766044408082962, -0.0642787590622902))
ACROSS = INWARD.cross(ALONG)
REST_ACROSS, REST_ALONG, REST_INWARD = frames.rest_frame(-1)


_gun, _source = frames.converters(SOURCE, ANCHOR, (ACROSS, ALONG, INWARD), -1)


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
    if index == 0:
        start = start - REST_INWARD * 0.002
    start = _gun(start)
    knots = [
        [
            (0.037, -0.139, -0.022),
            (0.035, -0.115, -0.033),
            (0.022, -0.087, -0.050),
            (0.010, -0.075, -0.057),
        ],
        [
            (0.034, -0.138, -0.035),
            (0.010, -0.135, -0.046),
            (-0.022, -0.148, -0.047),
            (-0.034, -0.161, -0.043),
        ],
        [
            (0.027, -0.127, -0.050),
            (0.007, -0.138, -0.062),
            (-0.024, -0.153, -0.063),
            (-0.032, -0.168, -0.060),
        ],
        [
            (0.024, -0.122, -0.061),
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
        Vector((0.041, -0.188, -0.027)),
        Vector((0.042, -0.188, 0.003)),
    ]
    return _curve([*controls, Vector((0.032, -0.187, 0.026)), Vector((0.018, -0.184, 0.026))], 10)
