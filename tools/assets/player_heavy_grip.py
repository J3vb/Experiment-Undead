"""A shorter support cradle around the large octagonal fore-end."""

import math

import player_grip_frames as frames
from mathutils import Vector

ACROSS = Vector((0.6, -0.8, 0))
ALONG = Vector((0.8 * math.sqrt(0.96), 0.6 * math.sqrt(0.96), 0.2))
INWARD = Vector((-0.16, -0.12, math.sqrt(0.96)))
REST_ACROSS, REST_ALONG, REST_INWARD = frames.rest_frame(1)
SOURCE = Vector((0.675, -0.066, 0.985))
ANCHOR = Vector((0, 0.220, 0.018))
OCTAGON = tuple(
    Vector(
        (
            math.cos(i * math.pi / 4 + math.pi / 8),
            math.sin(i * math.pi / 4 + math.pi / 8),
        )
    )
    * 0.042
    for i in range(8)
)


_gun, _source = frames.converters(SOURCE, ANCHOR, (ACROSS, ALONG, INWARD), 1)


def _octagon_distance(point):
    distances = []
    for index, first in enumerate(OCTAGON):
        edge = OCTAGON[(index + 1) % 8] - first
        fraction = max(0, min(1, (point - first).dot(edge) / edge.length_squared))
        distances.append((point - first - edge * fraction).length)
    return min(distances)


def _ironwood_finger(points, radii):
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


def _ironwood_thumb():
    start = Vector((0.649, 0, 1.011)) - REST_ACROSS * 0.034 - REST_ALONG * 0.006 + REST_INWARD * 0.008
    controls = (
        (-0.057, 0.235, -0.021),
        (-0.055, 0.242, 0),
        (-0.053, 0.248, 0.015),
        (-0.048, 0.255, 0.023),
        (-0.043, 0.262, 0.025),
    )
    return [start, *[_source(Vector(point)) for point in controls]]


# The original cradle remains the seed, including its palm attachments.
_FRAMES = {
    "rampart_br": (Vector((0.675, -0.066, 0.985)), Vector((0, 0.210, 0.016))),
    "synapse": (Vector((0.675, -0.074, 0.985)), Vector((0, 0.195, 0.024))),
}
_RAMPART_BODY = tuple(
    Vector(point)
    for point in (
        (-0.0345, -0.036),
        (0.0345, -0.036),
        (0.0345, 0.046),
        (-0.0345, 0.046),
    )
)
_RAMPART_RIB = tuple(
    Vector(point)
    for point in (
        (-0.0365, -0.041),
        (0.0365, -0.041),
        (0.0365, -0.031),
        (0.0345, -0.031),
        (0.0345, 0.046),
        (-0.0345, 0.046),
        (-0.0345, -0.031),
        (-0.0365, -0.031),
    )
)
_SYN_SECTION = [
    Vector(
        (
            math.cos(i * math.pi / 4 + math.pi / 8),
            math.sin(i * math.pi / 4 + math.pi / 8),
        )
    )
    * 0.039
    for i in range(8)
]
_SYN_SECTION[6:6] = [
    Vector((-0.009, _SYN_SECTION[5].y)),
    Vector((-0.009, -0.049)),
    Vector((0.009, -0.049)),
    Vector((0.009, _SYN_SECTION[5].y)),
]
_SYN_OFFSETS = (
    (0,) * 10,
    (0, 0, 0, 0, 0, 0, 0.00149580, 0, 0.01050404, 0.01124682),
    (0, 0, 0, 0, 0, 0, 0, 0, 0.00332035, 0),
    (0, 0, 0, 0, 0, 0, 0.003, 0.00535775, 0.00518348, 0),
    (0, 0, 0.0025, 0.00274361, 0.00892414, 0.01084904),
)


def _weapon(point, profile):
    source, anchor = _FRAMES[profile]
    return frames.transform(point, source, anchor, (REST_ACROSS, REST_ALONG, REST_INWARD), (ACROSS, ALONG, INWARD))


def _rest(point, profile):
    source, anchor = _FRAMES[profile]
    return frames.transform(point, anchor, source, (ACROSS, ALONG, INWARD), (REST_ACROSS, REST_ALONG, REST_INWARD))


def _section(profile, y, radius):
    if profile == "synapse":
        return _SYN_SECTION
    near_rib = any(y + radius >= start and y - radius <= start + 0.017 for start in (0.174, 0.234, 0.294, 0.354))
    return _RAMPART_RIB if near_rib else _RAMPART_BODY


def _section_distance(point, polygon):
    """Signed distance also handles the concave step beside a lower rail or rib."""
    inside, distance = False, float("inf")
    for index, first in enumerate(polygon):
        end = polygon[(index + 1) % len(polygon)]
        edge, relative = end - first, point - first
        if (first.y > point.y) != (end.y > point.y) and point.x < first.x + edge.x * (point.y - first.y) / edge.y:
            inside = not inside
        fraction = max(0, min(1, relative.dot(edge) / edge.length_squared))
        distance = min(distance, (relative - edge * fraction).length)
    return -distance if inside else distance


def _project(point, radius, profile, extra):
    position = _weapon(point, profile)
    centre = _FRAMES[profile][1]
    direction = Vector((position.x, position.z - centre.z)).normalized()
    polygon = _section(profile, position.y, radius)
    low, high = 0.0, 0.120
    for _step in range(24):
        distance = (low + high) / 2
        if _section_distance(direction * distance, polygon) < radius + 0.0025:
            low = distance
        else:
            high = distance
    position.x, position.z = direction.x * high, centre.z + direction.y * high
    position += Vector((direction.x, 0, direction.y)) * extra
    return _rest(position, profile)


def finger_path(points, radii, profile="ironwood_50", index=0):
    """Fit the short cradle to flat shells and finite external cable bundles."""
    if profile == "ironwood_50":
        return _ironwood_finger(points, radii)
    offsets = _SYN_OFFSETS[index] if profile == "synapse" else (0,) * 10
    return [
        points[0],
        *[
            _project(point, radius, profile, extra)
            for point, radius, extra in zip(points[1:], radii[1:], offsets[1:], strict=True)
        ],
    ]


def thumb_path(profile="ironwood_50"):
    points = _ironwood_thumb()
    if profile == "ironwood_50":
        return points
    offsets = _SYN_OFFSETS[4] if profile == "synapse" else (0,) * 6
    radii = (0.014, 0.014, 0.013, 0.011, 0.008, 0.002)
    return [
        points[0],
        *[
            _project(point, radius, profile, extra)
            for point, radius, extra in zip(points[1:], radii[1:], offsets[1:], strict=True)
        ],
    ]
