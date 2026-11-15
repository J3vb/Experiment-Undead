"""Receiver cradle: fingers support the chassis and thumb holds its left side."""

import math

import player_grip_frames as frames
from mathutils import Vector

ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
BASE_INWARD = Vector((-0.16, -0.12, math.sqrt(0.96)))
INWARD = BASE_INWARD * math.cos(math.radians(40)) + ALONG.cross(BASE_INWARD) * math.sin(math.radians(40))
ACROSS = ALONG.cross(INWARD)
SOURCE_ACROSS, SOURCE_ALONG, SOURCE_INWARD = frames.rest_frame(1)
SOURCE_CENTRE = Vector((0.675, -0.057, 0.985))
GUN_CENTRE = Vector((-0.030, 0.110, -0.020))


gun, source = frames.converters(SOURCE_CENTRE, GUN_CENTRE, (ACROSS, ALONG, INWARD), 1)


def finger_path(root, index):
    row = 0.133 - index * 0.014
    end_z = -0.0527 if index == 0 else -0.0635
    points = [gun(root)]
    coords = [
        (-0.053, row + 0.014, -0.052),
        (-0.046, row + 0.010, -0.066),
        (-0.035, row + 0.005, -0.071),
        (-0.025, row + 0.001, -0.072),
        (-0.015, row, -0.072),
        (-0.008, row, -0.070),
        (-0.003, row, -0.066),
        (-0.001, row, -0.060),
        (-0.002, row, end_z),
    ]
    if index:
        coords = _lower_curls(index)
    points += [Vector(p) for p in coords]
    return [source(p) for p in points]


def _lower_curls(index):
    return [
        [
            (-0.041, 0.135, -0.065),
            (-0.033, 0.128, -0.074),
            (-0.023, 0.122, -0.075),
            (-0.012, 0.119, -0.075),
            (-0.001, 0.119, -0.074),
            (0.009, 0.119, -0.073),
            (0.015, 0.119, -0.070),
            (0.017, 0.119, -0.067),
            (0.016, 0.119, -0.0635),
        ],
        [
            (-0.033, 0.125, -0.071),
            (-0.026, 0.118, -0.077),
            (-0.016, 0.110, -0.078),
            (-0.005, 0.105, -0.077),
            (0.004, 0.105, -0.076),
            (0.012, 0.105, -0.074),
            (0.017, 0.105, -0.070),
            (0.018, 0.105, -0.067),
            (0.017, 0.105, -0.0635),
        ],
        [
            (-0.026, 0.116, -0.078),
            (-0.023, 0.109, -0.081),
            (-0.016, 0.102, -0.080),
            (-0.008, 0.096, -0.078),
            (0, 0.091, -0.076),
            (0.006, 0.091, -0.074),
            (0.010, 0.091, -0.071),
            (0.011, 0.091, -0.067),
            (0.010, 0.091, -0.0635),
        ],
    ][index - 1]


def thumb_path():
    start = Vector((0.649, 0, 1.011)) - SOURCE_ACROSS * 0.034 - SOURCE_ALONG * 0.006 + SOURCE_INWARD * 0.008
    points = [gun(start)]
    points += [
        Vector(p)
        for p in [
            (-0.086, 0.130, -0.024),
            (-0.067, 0.126, -0.015),
            (-0.055, 0.125, -0.018),
            (-0.0485, 0.128, -0.027),
            (-0.0425, 0.130, -0.034),
        ]
    ]
    return [source(p) for p in points]
