"""Corvid glove curls seat high on the stock wrist and pass the thumb through its opening."""

import math

import player_grip_frames as frames
from mathutils import Vector
from player_stock_grip import _curve as stock_curve

SOURCE = Vector((-0.675, -0.054, 0.985))
ANCHOR = Vector((0, -0.110, -0.095))
ALONG = Vector((0, math.sqrt(0.75), 0.5))
INWARD = Vector((-1, 0, 0))
ACROSS = INWARD.cross(ALONG)
REST_ACROSS, REST_ALONG, REST_INWARD = frames.rest_frame(-1)


def _gun(point):
    return frames.transform(point, SOURCE, ANCHOR, (REST_ACROSS, REST_ALONG, REST_INWARD), (ACROSS, ALONG, INWARD))


def _source(point, source=SOURCE, anchor=ANCHOR):
    return frames.transform(point, anchor, source, (ACROSS, ALONG, INWARD), (REST_ACROSS, REST_ALONG, REST_INWARD))


def _curve(controls, count):
    return stock_curve(controls, count, _source)


def finger_radii(index):
    """Keep MCP attachment size and taper the phalanges around the wide stock."""
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


_CURLS = {
    1: (
        (0.03826166, -0.11399991, -0.08807177),
        (0.03777210, -0.10753336, -0.08736822),
        (0.03726885, -0.09858723, -0.08641548),
        (0.03655858, -0.09032810, -0.08560078),
        (0.03323926, -0.08003795, -0.08512647),
        (0.02000000, -0.07507796, -0.08453937),
        (0.00824000, -0.07491684, -0.08445554),
        (-0.00464000, -0.07557369, -0.08523384),
        (-0.01450400, -0.07645681, -0.08700745),
        (-0.02072198, -0.07800751, -0.08934266),
        (-0.02492502, -0.07939341, -0.09101901),
        (-0.02698944, -0.08222851, -0.09138087),
        (-0.02753649, -0.08535274, -0.09113397),
        (-0.02628215, -0.08365463, -0.09156516),
    ),
    2: (
        (0.03785148, -0.10600001, -0.10192818),
        (0.03737424, -0.10127465, -0.10016069),
        (0.03675646, -0.09480307, -0.09834577),
        (0.03511985, -0.08910833, -0.09947348),
        (0.02590720, -0.07924852, -0.10433970),
        (0.01600000, -0.07945385, -0.10755770),
        (0.00425600, -0.07981856, -0.10958992),
        (-0.00803200, -0.08063225, -0.11134764),
        (-0.01698400, -0.08157983, -0.11353821),
        (-0.02208710, -0.08305173, -0.11562809),
        (-0.02506988, -0.08433186, -0.11700393),
        (-0.02672018, -0.08629141, -0.11737943),
        (-0.02910012, -0.08958577, -0.11705652),
        (-0.02723377, -0.08870875, -0.11732514),
    ),
    3: (
        (0.03682547, -0.09799996, -0.11578450),
        (0.03631691, -0.09463345, -0.11371160),
        (0.03508562, -0.08984262, -0.11194572),
        (0.03232008, -0.08657608, -0.11493397),
        (0.02196935, -0.08280583, -0.12316888),
        (0.01200000, -0.08438171, -0.12981816),
        (0.00311200, -0.08490449, -0.13303488),
        (-0.00494400, -0.08569571, -0.13488255),
        (-0.01019200, -0.08663494, -0.13710442),
        (-0.01234803, -0.08825596, -0.13899039),
        (-0.01328230, -0.08986552, -0.14012641),
        (-0.01370599, -0.09135421, -0.14050527),
        (-0.01390489, -0.09216182, -0.14060815),
        (-0.01400000, -0.09262919, -0.14062355),
    ),
}


def finger_path(start, index):
    """Seat each lower phalanx on the stock; keep the trigger finger extended."""
    if index:
        return [_source(Vector(point)) for point in _CURLS[index]]
    knots = [
        (0.040, -0.102, -0.066),
        (0.035, -0.081, -0.064),
        (0.016, -0.054, -0.066),
        (-0.005, -0.043, -0.066),
    ]
    return _curve([_gun(start), *[Vector(point) for point in knots]], 14)


def thumb_path():
    """Reach the actual thumbhole directly from the embedded upper palm web."""
    start = Vector((-0.649, 0, 1.011)) - REST_ACROSS * 0.023 + REST_ALONG * 0.010 + REST_INWARD * 0.006
    controls = [
        _gun(start),
        Vector((0.050, -0.135, -0.062)),
        Vector((0.040, -0.124, -0.030)),
    ]
    return _curve(
        [*controls, Vector((0.019, -0.121, -0.031)), Vector((0.002, -0.119, -0.043))],
        10,
    )


def ironwood_finger(start):
    """Rest the long trigger finger along the lower frame, outside the guard."""
    controls = [
        (0.0356461, -0.16049998, -0.08828231),
        (0.0358461, -0.14999998, -0.07808231),
        (0.0358461, -0.14089998, -0.06788231),
        (0.0356461, -0.13179998, -0.06193231),
        (0.0355261, -0.12339998, -0.05938231),
        (0.0354461, -0.11639998, -0.05768231),
        (0.0352461, -0.11009998, -0.05683231),
        (0.0350461, -0.10449998, -0.05640731),
        (0.0348461, -0.10029998, -0.05598231),
        (0.0344461, -0.09749998, -0.05640731),
        (0.0340461, -0.09539998, -0.05683231),
        (0.0332461, -0.09399998, -0.05725731),
        (0.0324461, -0.09329998, -0.05768231),
    ]
    source, anchor = Vector((-0.675, -0.048, 0.985)), Vector((0, -0.159, -0.122))
    return [start, *[_source(Vector(point), source, anchor) for point in controls]]
