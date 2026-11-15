"""Topology-stable glove curls and reinforcements for first-person weapon grips."""

import math

# isort: split
import body_parts as soft
import player_grip_profiles as profiles
import player_handgun_grips as handgun
import player_precision_grip as precision
import player_support_grips as support
from mathutils import Vector

GRIP_HALVES = {0.032: (0.026, 0.0185), 0.045: (0.033, 0.033)}

FINGER_RADII = (0.010, 0.010, 0.0105, 0.010, 0.009, 0.009, 0.008, 0.007, 0.005, 0.002)

FINGER_SCALES = (0.98, 1.0, 0.96, 0.86)


def _frame(sign):
    """Index-to-little, wrist-to-fingers and palm inward; each hand keeps its chirality."""
    across = Vector((-sign, 0, -1)).normalized()
    along = Vector((sign, 0, -1)).normalized()
    inward = Vector((0, -1, 0))
    return across, along, inward


def _grip_axes(sign, gap, profile="rifle_ar"):
    """Weapon axis and depth direction in a naturally oblique grasp frame."""
    across, along, inward = _frame(sign)
    if gap == 0.045:
        return -across * 0.8 + along * (0.6 * math.sqrt(0.96)) - inward * 0.12, along
    angle = profiles.section(profile, gap)[3]
    return across * math.cos(angle) - along * math.sin(angle), across * math.sin(angle) + along * math.cos(angle)


def _grip_centre(root, sign, gap, profile="rifle_ar"):
    across, _along, _inward = _frame(sign)
    axis, _depth = _grip_axes(sign, gap, profile)
    centre = Vector((sign * 0.675, -profiles.section(profile, gap)[2], 0.985))
    return centre + axis * ((root - centre).dot(across) / axis.dot(across))


def _bore_point(centre, sign, gap, angle, radius, profile="rifle_ar"):
    """Offset a fingertip or phalanx from the actual grip cross section."""
    across, along, inward = _frame(sign)
    axis, depth = _grip_axes(sign, gap, profile)
    half_length, half_depth, _offset, _angle = profiles.section(profile, gap)
    direction = along * math.cos(angle) + inward * math.sin(angle)
    if gap == 0.045 and profile == "corvid_338":
        horizontal = across * 0.6 + along * (0.8 * math.sqrt(0.96)) - inward * 0.16
        vertical = along * 0.2 + inward * math.sqrt(0.96)
        surface, normal = _shaped_section(direction, horizontal, vertical, (half_length, half_depth), 4)
    elif gap == 0.045:
        radial = direction - axis * direction.dot(axis)
        surface = direction * (half_length / radial.length)
        normal = radial.normalized()
    else:
        u, v = direction.dot(depth) / half_length, direction.dot(inward) / half_depth
        distance = (abs(u) ** 8 + abs(v) ** 8) ** (-1 / 8)
        surface = direction * distance
        normal = (
            depth * ((u * distance) ** 7 / half_length) + inward * ((v * distance) ** 7 / half_depth)
        ).normalized()
    outward = (normal - across * normal.dot(across)).normalized()
    return centre + surface + outward * ((radius + 0.0015) / outward.dot(normal))


def _shaped_section(direction, first, second, halves, power):
    u, v = direction.dot(first) / halves[0], direction.dot(second) / halves[1]
    distance = (abs(u) ** power + abs(v) ** power) ** (-1 / power)
    normal = (
        first * ((u * distance) ** (power - 1) / halves[0]) + second * ((v * distance) ** (power - 1) / halves[1])
    ).normalized()
    return direction * distance, normal


def _finger_path(root, sign, diameter, index, profile="rifle_ar"):
    """Curl around the grip while leaving the fingertips opposed to the thumb."""
    if diameter == 0.045 and profile == "mako_pdw":
        return support.mako_finger(_finger_path(root, sign, diameter, index), index)
    if diameter == 0.045 and profile in handgun.PATHS:
        return handgun.finger_path(profile, index)
    _across, along, _inward = _frame(sign)
    centre = _grip_centre(root, sign, diameter, profile)
    low, high = -math.pi, 0.0
    for _step in range(24):
        angle = (low + high) / 2
        start = _bore_point(centre, sign, diameter, angle, FINGER_RADII[0] * FINGER_SCALES[index], profile)
        if (start - root).dot(along) > 0:
            high = angle
        else:
            low = angle
    start_angle = (low + high) / 2
    end_angle = profiles.end_angle(profile, diameter) + (0, 0.20, 0.15, -0.12)[index]
    fractions = (0, 0.13, 0.27, 0.40, 0.50, 0.61, 0.72, 0.83, 0.94, 1.0)
    angles = [start_angle + (end_angle - start_angle) * fraction for fraction in fractions]
    if diameter == 0.032:
        axis, _depth = _grip_axes(sign, diameter, profile)
        across, _along, _inward = _frame(sign)
        half_length, half_depth, _offset, _angle = profiles.section(profile, diameter)
        corner = math.atan(half_depth * axis.dot(across) / half_length)
        angles = [start_angle, (start_angle - corner - 0.18) / 2]
        angles += [-corner + offset for offset in (-0.18, -0.08, 0, 0.08, 0.18)]
        angles += [0] + [corner + offset for offset in (-0.18, -0.08, 0, 0.08, 0.18)] + [end_angle]
    points = [
        _bore_point(centre, sign, diameter, angle, radius, profile)
        for angle, radius in zip(angles, _finger_radii(diameter, index), strict=True)
    ]
    if diameter == 0.032 and profile == "corvid_338" and index == 0:
        return precision.finger_path(points[0])
    return _firing_curl(points, sign, index, profile) if diameter == 0.032 else points


def _firing_curl(points, sign, index, profile="rifle_ar"):
    """Separate the trigger finger from the three curls beneath the guard."""
    across, along, _inward = _frame(sign)
    axis, _depth = _grip_axes(sign, 0.032, profile)
    shift = (across * math.sqrt(0.75) - along * 0.5) * 0.018 if index == 0 else axis * 0.027
    result = []
    for row, point in enumerate(points):
        blend = min(1.0, row / 4)
        result.append(point + shift * blend * blend * (3 - 2 * blend))
    return result


def _finger_radii(gap, index):
    radii = FINGER_RADII
    if gap == 0.032:
        radii = (0.010, 0.010, 0.0105, 0.0105, 0.010, 0.0097, 0.0095, 0.009, 0.0085, 0.008, 0.007, 0.006, 0.004, 0.002)
    return [radius * FINGER_SCALES[index] for radius in radii]


def _grip_tube(name, points, radii, mat, sign):
    """Keep the sweep frame continuous while fingers bend past the grip centre."""
    across, _along, _inward = _frame(sign)
    rings = []
    for index, (point, radius) in enumerate(zip(points, radii, strict=True)):
        tangent = (points[min(index + 1, len(points) - 1)] - points[max(0, index - 1)]).normalized()
        width = (across - tangent * across.dot(tangent)).normalized()
        normal = tangent.cross(width)
        rings.append(
            [
                point + radius * (width * math.cos(angle) + normal * math.sin(angle))
                for angle in (2 * math.pi * step / 12 for step in range(12))
            ]
        )
    return soft.loft(name, rings, mat)


def _finger_pad(points, radii, joint, sign, mat):
    """A thin curved reinforcement seats into the rubber around a knuckle."""
    across, _along, _inward = _frame(sign)
    rings = []
    outline = [
        (-1, -0.0005),
        (-0.75, -0.0012),
        (0.75, -0.0012),
        (1, -0.0005),
        (0.75, 0.0012),
        (0, 0.0012),
        (-0.75, 0.0012),
    ]
    for index, width in ((joint - 1, 0.72), (joint, 1.0), (joint + 1, 0.72)):
        tangent = (points[index + 1] - points[index - 1]).normalized()
        width_axis = (across - tangent * across.dot(tangent)).normalized()
        outward = tangent.cross(width_axis) * sign
        half_width = min(0.008, radii[index] * 0.82) * width
        rings.append(
            [
                points[index]
                + outward * (math.sqrt(radii[index] ** 2 - (side * half_width) ** 2) + depth)
                + width_axis * side * half_width
                for side, depth in outline
            ]
        )
    return soft.loft("FingerPad" + ("L" if sign == 1 else "R"), rings, mat)


def _thumb_path(index_tip, centre, sign, gap, profile="rifle_ar"):
    """Oppose the thumb around the clear bore; tip spacing is a chord, not its diameter."""
    if gap == 0.045 and profile == "mako_pdw":
        return support.mako_thumb()
    if gap == 0.032 and profile == "corvid_338":
        return precision.thumb_path()
    if gap == 0.045 and profile in handgun.PATHS:
        return handgun.thumb_path(profile)
    across, along, inward = _frame(sign)
    if gap == 0.032:
        index_tip = index_tip - (across * math.sqrt(0.75) - along * 0.5) * 0.018
    high = profiles.end_angle(profile, gap)
    low = high - math.pi
    for _step in range(32):
        angle = (low + high) / 2
        tip = _bore_point(centre, sign, gap, angle, 0.002, profile)
        if (tip - index_tip).length > gap:
            low = angle
        else:
            high = angle
    angle = (low + high) / 2
    start = Vector((sign * 0.649, 0, 1.011)) - across * 0.034 - along * 0.006 + inward * 0.008
    axis, _depth = _grip_axes(sign, gap, profile)
    points = [start]
    sections = [
        (-2.62, 0.014, 0.009),
        (-1.92, 0.013, 0.014),
        (-1.31, 0.011, 0.010),
        ((-1.31 + angle) / 2, 0.008, 0.004),
        (angle, 0.002, 0),
    ]
    if gap == 0.032:
        half_length, half_depth, _offset, _angle = profiles.section(profile, gap)
        corner = math.atan(half_depth * axis.dot(across) / half_length)
        sections = [(-2.62, 0.014, 0.009), (-1.92, 0.013, 0.014), (-1.31, 0.012, 0.012)]
        sections += [((-1.31 - corner - 0.18) / 2, 0.011, 0.010)]
        sections += [
            (-corner + delta, radius, offset)
            for delta, radius, offset in [
                (-0.18, 0.010, 0.008),
                (-0.08, 0.008, 0.006),
                (0, 0.006, 0.004),
                (0.08, 0.004, 0.002),
            ]
        ]
        sections += [(angle, 0.002, 0)]
    for theta, radius, offset in sections:
        row = centre - axis * (offset / axis.dot(across))
        points.append(_bore_point(row, sign, gap, theta, radius, profile))
    return _firing_curl(points, sign, 0, profile) if gap == 0.032 else points
