"""Support curls around the rear condenser collar, clear of the removable tank."""

import math

import player_grip_frames as frames
from mathutils import Vector

ACROSS = Vector((0.6, -0.8, 0))
ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
INWARD = Vector((-0.16, -0.12, math.sqrt(0.96)))
SOURCE_ACROSS, SOURCE_ALONG, SOURCE_INWARD = frames.rest_frame(1)
SOURCE_CENTRE = Vector((0.675, -0.063, 0.985))
GUN_CENTRE = Vector((-0.030, 0.205, 0.035))


gun, source = frames.converters(SOURCE_CENTRE, GUN_CENTRE, (ACROSS, ALONG, INWARD), 1)


def finger_path(points, radii, index):
    start = gun(points[0])
    angle = math.atan2(start.z - 0.035, start.x)
    end = math.radians((-27, -20, -23, -25)[index])
    result = [points[0]]
    fractions = (0.10, 0.23, 0.36, 0.48, 0.60, 0.72, 0.84, 0.94, 1.0)
    for fraction, radius in zip(fractions, radii[1:], strict=True):
        theta = angle + (end - angle) * fraction
        y = start.y + (0.027 - 0.002 * index) * math.sin(fraction * math.pi / 2)
        radial = Vector((math.cos(theta), 0, math.sin(theta)))
        surface = 0.039 if y - radius < 0.215 else 0.033
        reach = surface + radius + 0.0008
        for sign in (-1, 1):
            projection = sign * 0.037 * radial.x
            discriminant = projection**2 - (0.037**2 - (radius + 0.0055) ** 2)
            if discriminant >= 0 and projection > 0:
                reach = max(reach, projection + math.sqrt(discriminant))
        result.append(source(Vector((radial.x * reach, y, 0.035 + radial.z * reach))))
    return result


def thumb_path():
    start = Vector((0.649, 0, 1.011)) - SOURCE_ACROSS * 0.034 - SOURCE_ALONG * 0.006 + SOURCE_INWARD * 0.008
    points = [start]
    points += [
        source(Vector(point))
        for point in (
            (-0.057, 0.220, -0.004),
            (-0.055, 0.227, 0.017),
            (-0.053, 0.233, 0.032),
            (-0.048, 0.240, 0.040),
            (-0.043, 0.247, 0.042),
        )
    ]
    return points
