"""Gloved hands and laced boots for the player body."""

import numpy as np
import surface as surf

WRIST = (0.61, 0.0, 1.05)
# distance from the wrist, side shift, front shift, half width, palm depth, back depth, squareness
PALM_KEYS = (
    (-0.060, 0, 0, 0.040, 0.036, 0.036, 2.0),
    (-0.010, 0, 0, 0.034, 0.026, 0.028, 2.4),
    (0.030, 0, 0, 0.041, 0.018, 0.021, 3.0),
    (0.070, 0, 0, 0.045, 0.015, 0.018, 3.0),
    (0.098, 0, 0, 0.043, 0.012, 0.015, 3.0),
    (0.108, 0, 0, 0.037, 0.007, 0.010, 3.0),
)
# across the knuckles (towards the thumb is positive), length, radius: index to little finger
FINGERS = ((0.030, 0.072, 0.0098), (0.010, 0.080, 0.0100), (-0.010, 0.074, 0.0095), (-0.029, 0.058, 0.0085))
# height, side shift, toe shift, half width, toe reach, heel reach, squareness
BOOT_KEYS = (
    (0.000, 0, 0, 0.049, 0.200, 0.072, 2.7),
    (0.006, 0, 0, 0.053, 0.208, 0.078, 2.7),
    (0.030, 0, 0, 0.054, 0.210, 0.080, 2.7),
    (0.036, 0, 0, 0.049, 0.202, 0.074, 2.6),
    (0.060, 0, 0, 0.049, 0.198, 0.074, 2.5),
    (0.085, 0, 0, 0.047, 0.178, 0.072, 2.4),
    (0.105, 0, 0, 0.045, 0.128, 0.070, 2.3),
    (0.125, 0, 0, 0.044, 0.086, 0.068, 2.2),
    (0.150, 0, 0, 0.046, 0.066, 0.066, 2.1),
    (0.200, 0, 0, 0.050, 0.060, 0.064, 2.0),
    (0.250, 0, 0, 0.053, 0.062, 0.066, 2.0),
)


def hand_tube(sign: int) -> surf.Tube:
    origin = (sign * WRIST[0], WRIST[1], WRIST[2])
    return surf.Tube(origin, (sign, 0, -1), (-1, 0, -sign), PALM_KEYS)


def _finger(tube, mat, name, root, reach, radius, lean):
    """Four joints with a relaxed curl towards the palm and a rounded tip."""
    points, radii = [], []
    for along, curl, size in (
        (0, 0, 1.0),
        (0.42, 0.003, 0.96),
        (0.74, 0.011, 0.88),
        (0.95, 0.021, 0.76),
        (1.0, 0.024, 0.4),
    ):
        points.append(root + (tube.axis + lean) * reach * along + tube.front * curl)
        radii.append(radius * size)
    return surf.sweep(name, points, radii, mat, 6, up=tube.front)


def build_glove(mats: dict, sign: int) -> list:
    tube = hand_tube(sign)
    thumb_side = -sign * tube.side
    rows = (-0.060, -0.035, -0.010, 0.012, 0.035, 0.060, 0.082, 0.098, 0.108)
    parts = [surf.shell("GlovePalm", tube.grid(surf.turns(14), rows), mats["rubber"])]
    for across, reach, radius in FINGERS:
        root = tube.origin + tube.axis * 0.100 + thumb_side * across - tube.front * 0.001
        parts.append(_finger(tube, mats["rubber"], "GloveFinger", root, reach, radius, thumb_side * across * 2.2))
    root = tube.origin + tube.axis * 0.030 + thumb_side * 0.034 + tube.front * 0.006
    lean = thumb_side * 0.85 + tube.front * 0.45 - tube.axis * 0.25
    parts.append(_finger(tube, mats["rubber"], "GloveThumb", root, 0.062, 0.0125, lean))
    ball_at = tube.origin + tube.axis * 0.040 + thumb_side * 0.026 + tube.front * 0.010
    parts.append(surf.ball("GloveThumbPad", ball_at, (0.021, 0.014, 0.024), mats["rubber"], (8, 5)))
    parts.append(surf.patch("GloveCuff", tube, (0.0, 1.0, -0.058, -0.012), 0.005, mats["rubber"], (10, 1)))
    parts.append(surf.patch("KnuckleGuard", tube, (0.33, 0.67, 0.066, 0.104), 0.007, mats["rubber"], (4, 2)))
    parts.append(surf.patch("GloveStrap", tube, (0.30, 0.70, -0.006, 0.014), 0.005, mats["rubber"], (4, 1)))
    return parts


def boot_tube(sign: int) -> surf.Tube:
    return surf.Tube((sign * 0.11, 0, 0), (0, 0, 1), (1, 0, 0), BOOT_KEYS)


def _laces(tube, mat) -> list:
    parts = []
    for row, height in enumerate((0.104, 0.138, 0.172, 0.206)):
        tilt = 0.006 if row % 2 else -0.006
        u = np.asarray((-0.06, -0.02, 0.02, 0.06))
        path = tube.surface(u, height + tilt * np.sign(u), lambda p, _u, _s: 0.0030 + 0 * p[..., 0])
        parts.append(surf.sweep("BootLace", path, np.full(len(u), 0.0032), mat, 4))
    return parts


def build_boot(mats: dict, sign: int) -> list:
    tube = boot_tube(sign)
    rows = (0, 0.006, 0.030, 0.036, 0.048, 0.060, 0.073, 0.085, 0.095, 0.105, 0.125, 0.15, 0.2, 0.25)
    around = np.concatenate([np.linspace(-0.25, 0.25, 12)[:-1], np.linspace(0.25, 0.75, 8)[:-1]]) % 1.0
    parts = [surf.shell("Boot", tube.grid(around, rows), mats["rubber"])]
    parts.append(surf.patch("ToeCap", tube, (-0.21, 0.21, 0.037, 0.088), 0.0050, mats["rubber"], (10, 4)))
    parts.append(surf.patch("HeelCounter", tube, (0.32, 0.68, 0.037, 0.130), 0.0035, mats["rubber"], (5, 2)))
    parts.append(surf.patch("BootCollar", tube, (0.0, 1.0, 0.222, 0.250), 0.006, mats["rubber"], (12, 1)))
    return parts + _laces(tube, mats["rubber"])
