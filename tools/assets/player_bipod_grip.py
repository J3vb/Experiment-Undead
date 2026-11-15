"""Support curls beside the folded bipod, in the validated rolled hand frame."""

import math

from mathutils import Vector

ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
INWARD = Vector((0.509092349539438, -0.792796513827807, 0.335109933160583))
ACROSS = ALONG.cross(INWARD)
SOURCE_ACROSS = Vector((-1, 0, -1)).normalized()
SOURCE_ALONG = Vector((1, 0, -1)).normalized()
SOURCE_INWARD = Vector((0, -1, 0))
SOURCE_CENTRE = Vector((0.675, -0.062, 0.985))
GUN_CENTRE = Vector((-0.021, 0.219, 0.030))


def gun(point):
    offset = point - SOURCE_CENTRE
    return (
        GUN_CENTRE
        + ACROSS * offset.dot(SOURCE_ACROSS)
        + ALONG * offset.dot(SOURCE_ALONG)
        + INWARD * offset.dot(SOURCE_INWARD)
    )


def source(point):
    offset = point - GUN_CENTRE
    return (
        SOURCE_CENTRE
        + SOURCE_ACROSS * offset.dot(ACROSS)
        + SOURCE_ALONG * offset.dot(ALONG)
        + SOURCE_INWARD * offset.dot(INWARD)
    )


def finger_path(root, index, radii):
    row = 0.310 - index * 0.016
    angles = (
        (190, 200, 205, 210, 215, 220, 223, 225),
        (196, 202, 208, 215, 221, 225, 228, 230),
        (206, 210, 215, 218, 223, 228, 232, 235),
        (214, 216, 218, 221, 225, 230, 235, 240),
    )[index]
    points = [gun(root) - (INWARD * 0.008 if index == 3 else Vector())]
    for step, (angle, y) in enumerate(zip(angles, (0.018, 0.023, 0.022, 0.018, 0.013, 0.008, 0.003, 0), strict=True)):
        radius = 0.038 + radii[step + 2] + 0.002
        theta = math.radians(angle)
        point = Vector((math.cos(theta) * radius, row + y, 0.030 + math.sin(theta) * radius))
        if step == 0:
            points.append(points[0].lerp(point, 0.45))
        points.append(point)
    return [source(point) for point in points]


def thumb_path():
    start = Vector((0.649, 0, 1.011)) - SOURCE_ACROSS * 0.034 - SOURCE_ALONG * 0.006 + SOURCE_INWARD * 0.008
    points = [gun(start)]
    points += [
        Vector(point)
        for point in ((-0.080, 0.254, 0.044), (-0.064, 0.270, 0.048), (-0.054, 0.284, 0.046), (-0.047, 0.297, 0.044))
    ]
    theta = math.radians(170)
    points.append(Vector((0.042 * math.cos(theta), 0.290, 0.030 + 0.042 * math.sin(theta))))
    return [source(point) for point in points]
