"""Brenner glove curls cup the stock wrist with a separate trigger finger."""

import math

import player_grip_frames as frames
from mathutils import Vector

SOURCE = Vector((-0.675, -0.057, 0.985))
ANCHOR = Vector((0, -0.134, -0.020))
ACROSS = Vector((-0.845568597, -0.238752484, -0.477504969))
ALONG = Vector((-0.45, 0.8, math.sqrt(0.1575)))
INWARD = Vector((-0.287252039, -0.550451875, 0.783893526))
REST_ACROSS, REST_ALONG, REST_INWARD = frames.rest_frame(-1)


_gun, _source = frames.converters(SOURCE, ANCHOR, (ACROSS, ALONG, INWARD), -1)


def _curve(controls, count, converter=_source):
    points = []
    for row in range(count):
        fractions = (0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.88, 0.94, 0.975, 0.992, 1)
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
        points.append(converter(point * 0.5))
    return points


def finger_path(start, index, radii):
    """Keep the shared MCP attachment and cup the narrowing stock underside."""
    start = _gun(start)
    if index == 0:
        start.x += 0.008
    elif index == 1:
        start.z -= 0.003
    knots = [
        [(0.035, -0.090, -0.034), (0.029, -0.070, -0.036), (0.023, -0.050, -0.036), (0.010, -0.042, -0.038)],
        [(0.014, -0.106, -0.060), (-0.012, -0.108, -0.061), (-0.032, -0.105, -0.045), (-0.025, -0.105, -0.030)],
        [(0.003, -0.120, -0.071), (-0.016, -0.125, -0.071), (-0.032, -0.125, -0.054), (-0.025, -0.125, -0.038)],
        [(-0.010, -0.134, -0.079), (-0.021, -0.145, -0.081), (-0.031, -0.145, -0.067), (-0.025, -0.145, -0.052)],
    ]
    points = _curve([start, *[Vector(point) for point in knots[index]]], 14)
    if index:
        for row in range(8, 14):
            point = _gun(points[row])
            point.x = min(point.x, -0.021 - radii[row] - 0.003)
            points[row] = _source(point)
    return points


def thumb_path(index_tip):
    """Rest the thumb beside the receiver while retaining the 32 mm tip chord."""
    start = Vector((-0.649, 0, 1.011)) - REST_ACROSS * 0.015 - REST_ALONG * 0.006 + REST_INWARD * 0.008
    gap_y = math.sqrt(0.032**2 - 0.021**2 - 0.005**2)
    end = _gun(index_tip) + Vector((0.021, -gap_y, 0.005))
    controls = [_gun(start), Vector((0.050, -0.105, -0.045)), Vector((0.040, -0.090, -0.030))]
    return _curve([*controls, Vector((0.035, -0.076, -0.028)), end], 10)
