"""A shorter support cradle around the large octagonal fore-end."""

import math

from mathutils import Vector

ACROSS = Vector((0.6, -0.8, 0))
ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
INWARD = Vector((-0.16, -0.12, math.sqrt(0.96)))
REST_ACROSS = Vector((-1, 0, -1)).normalized()
REST_ALONG = Vector((1, 0, -1)).normalized()
REST_INWARD = Vector((0, -1, 0))
SOURCE = Vector((0.675, -0.066, 0.985))
ANCHOR = Vector((0, 0.220, 0.018))
OCTAGON = tuple(
    Vector((math.cos(i * math.pi / 4 + math.pi / 8), math.sin(i * math.pi / 4 + math.pi / 8))) * 0.042 for i in range(8)
)


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


def _octagon_distance(point):
    distances = []
    for index, first in enumerate(OCTAGON):
        edge = OCTAGON[(index + 1) % 8] - first
        fraction = max(0, min(1, (point - first).dot(edge) / edge.length_squared))
        distances.append((point - first - edge * fraction).length)
    return min(distances)


def finger_path(points, radii):
    """Keep the MCP roots and seat shortened phalanges against the real flat faces."""
    result = [points[0]]
    for point, radius in zip(points[1:], radii[1:], strict=True):
        position = _gun(point)
        direction = Vector((position.x, position.z - ANCHOR.z)).normalized()
        low, high = 0.042, 0.080
        for _step in range(20):
            distance = (low + high) / 2
            if _octagon_distance(direction * distance) < radius + 0.0025:
                low = distance
            else:
                high = distance
        position.x, position.z = direction.x * high, ANCHOR.z + direction.y * high
        result.append(_source(position))
    return result


def thumb_path():
    start = Vector((0.649, 0, 1.011)) - REST_ACROSS * 0.034 - REST_ALONG * 0.006 + REST_INWARD * 0.008
    controls = (
        (-0.057, 0.235, -0.021),
        (-0.055, 0.242, 0),
        (-0.053, 0.248, 0.015),
        (-0.048, 0.255, 0.023),
        (-0.043, 0.262, 0.025),
    )
    return [start, *[_source(Vector(point)) for point in controls]]
