"""Field clothes: hip-length jacket with sleeves, scarf and dropped hood, cargo trousers."""

import math

import numpy as np
import surface as surf
from surface import bump

# z, side shift, front shift, half width, front depth, back depth, squareness
JACKET_KEYS = (
    (0.865, 0, 0, 0.194, 0.134, 0.134, 2.5),
    (0.900, 0, 0, 0.192, 0.133, 0.132, 2.5),
    (0.980, 0, 0, 0.176, 0.124, 0.118, 2.5),
    (1.050, 0, 0, 0.168, 0.118, 0.108, 2.5),
    (1.150, 0, 0, 0.176, 0.124, 0.110, 2.5),
    (1.280, 0, 0, 0.196, 0.136, 0.118, 2.5),
    (1.380, 0, 0, 0.198, 0.134, 0.122, 2.4),
    (1.450, 0, 0, 0.198, 0.118, 0.118, 2.3),
    (1.495, 0, 0, 0.168, 0.096, 0.104, 2.2),
    (1.530, 0, 0, 0.095, 0.072, 0.082, 2.0),
    (1.550, 0, 0, 0.066, 0.058, 0.066, 2.0),
)
PELVIS_KEYS = (
    (0.790, 0, 0, 0.050, 0.060, 0.070, 2.0),
    (0.830, 0, 0, 0.130, 0.100, 0.108, 2.3),
    (0.900, 0, 0, 0.168, 0.114, 0.120, 2.4),
    (1.000, 0, 0, 0.164, 0.112, 0.108, 2.4),
)
# distance from the shoulder, side shift, front shift, half width, front depth, back depth, squareness
SLEEVE_KEYS = (
    (-0.050, 0.050, 0, 0.020, 0.040, 0.040, 2.0),
    (-0.020, 0.030, 0, 0.042, 0.062, 0.062, 2.0),
    (0.030, 0.010, 0, 0.060, 0.070, 0.070, 2.0),
    (0.120, 0, 0, 0.062, 0.064, 0.064, 2.0),
    (0.250, 0, 0, 0.056, 0.058, 0.058, 2.0),
    (0.311, 0, 0, 0.054, 0.055, 0.057, 2.0),
    (0.420, 0, 0, 0.053, 0.054, 0.054, 2.0),
    (0.540, 0, 0, 0.048, 0.048, 0.048, 2.0),
    (0.560, 0, 0, 0.043, 0.043, 0.043, 2.0),
)
# height, side shift, front shift, half width, front depth, back depth, squareness
LEG_KEYS = (
    (0.215, 0, 0, 0.056, 0.060, 0.060, 2.0),
    (0.235, 0, 0, 0.072, 0.078, 0.076, 2.0),
    (0.290, 0, -0.006, 0.070, 0.072, 0.078, 2.0),
    (0.400, 0, -0.008, 0.074, 0.072, 0.086, 2.0),
    (0.530, 0, 0.004, 0.076, 0.084, 0.080, 2.1),
    (0.640, 0, 0.002, 0.086, 0.090, 0.090, 2.1),
    (0.780, 0, 0, 0.098, 0.104, 0.106, 2.1),
    (0.900, -0.004, 0, 0.104, 0.110, 0.114, 2.1),
    (0.980, -0.008, 0, 0.098, 0.106, 0.110, 2.1),
)
SHOULDER = (0.19, 0.0, 1.47)
ARM_AXIS = (1, 0, -1)


def jacket_tube() -> surf.Tube:
    return surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), JACKET_KEYS)


def sleeve_tube(sign: int) -> surf.Tube:
    origin = (sign * SHOULDER[0], SHOULDER[1], SHOULDER[2])
    keys = np.asarray(SLEEVE_KEYS) * (1, sign, 1, 1, 1, 1, 1)
    return surf.Tube(origin, (sign * ARM_AXIS[0], 0, ARM_AXIS[2]), (-1, 0, -sign), keys)


def leg_tube(sign: int) -> surf.Tube:
    keys = np.asarray(LEG_KEYS) * (1, sign, 1, 1, 1, 1, 1)
    return surf.Tube((sign * 0.11, 0, 0), (0, 0, 1), (1, 0, 0), keys)


def jacket_folds(points, u, _s):
    """Cloth pulled in at the belt line, with slack folds above and below it."""
    z = points[..., 2]
    cinch = -0.010 * bump(z, 1.005, 0.022)
    slack = 0.005 * bump(z, 1.075, 0.035) * (0.6 + 0.4 * np.sin(math.tau * u * 9 + 1.0))
    skirt = 0.004 * bump(z, 0.93, 0.04) * np.sin(math.tau * u * 7 + 0.4)
    chest = 0.003 * bump(z, 1.22, 0.05) * np.sin(math.tau * (u * 5 + z * 3.0))
    return cinch + slack + skirt + chest


def sleeve_folds(_points, u, s):
    """Bunched folds at the elbow and above the cuff, diagonal drag lines between."""
    elbow = 0.0055 * bump(s, 0.311, 0.07) * np.sin(s * 150 + 2.2 * np.sin(math.tau * u))
    cuff = 0.0045 * bump(s, 0.50, 0.05) * np.sin(s * 210 + 1.5 * np.cos(math.tau * u))
    drag = 0.0030 * bump(s, 0.17, 0.09) * np.sin(math.tau * (u * 3 + s * 6))
    return elbow + cuff + drag


def leg_folds(_points, u, s):
    """Knee bunching, stacked folds over the boot and long drag lines down the thigh."""
    knee = 0.0050 * bump(s, 0.50, 0.06) * np.sin(s * 140 + 2.0 * np.sin(math.tau * u)) * (1 - 0.7 * bump(u, 0, 0.12))
    stack = 0.0060 * bump(s, 0.30, 0.055) * np.sin(s * 170 + 1.6 * np.cos(math.tau * u))
    thigh = 0.0035 * bump(s, 0.76, 0.10) * np.sin(math.tau * (u * 4 - s * 5))
    return knee + stack + thigh


def _jacket(mats: dict) -> list:
    tube = jacket_tube()
    rows = np.concatenate(
        [np.linspace(0.865, 1.15, 10), np.linspace(1.19, 1.45, 6), [1.475, 1.495, 1.515, 1.535, 1.55]]
    )
    body = surf.shell("Jacket", tube.grid(surf.turns(30), rows, jacket_folds), mats["cloth"])
    hem = surf.patch("JacketHem", tube, (0.0, 1.0, 0.862, 0.888), 0.004, mats["cloth"], (26, 1), jacket_folds)
    return [body, hem]


def _jacket_details(mats: dict) -> list:
    tube = jacket_tube()
    parts = [
        surf.patch("Placket", tube, (-0.016, 0.016, 0.87, 1.50), 0.0045, mats["cloth"], (1, 16), jacket_folds),
        surf.patch("BackYoke", tube, (0.30, 0.70, 1.36, 1.48), 0.0035, mats["cloth"], (12, 4), jacket_folds),
    ]
    for sign in (1, -1):
        chest = (sign * 0.035, sign * 0.115, 1.235, 1.345)
        parts.append(surf.patch("ChestPocket", tube, chest, 0.007, mats["cloth"], (5, 5), jacket_folds))
        flap = (sign * 0.031, sign * 0.119, 1.315, 1.360)
        parts.append(
            surf.patch(
                "PocketFlap", tube, flap, 0.011, mats["cloth"], (5, 3), jacket_folds, lambda un: 0.012 * abs(un - 0.5)
            )
        )
        hip = (sign * 0.045, sign * 0.150, 0.885, 0.975)
        parts.append(surf.patch("HipPocket", tube, hip, 0.008, mats["cloth"], (5, 4), jacket_folds))
    for z in (1.06, 1.19, 1.32, 1.45):
        parts.append(
            surf.patch("Snap", tube, (-0.004, 0.004, z - 0.006, z + 0.006), 0.008, mats["rubber"], (1, 1), jacket_folds)
        )
    return parts


def _sleeve(mats: dict, sign: int) -> list:
    tube = sleeve_tube(sign)
    rows = np.concatenate([[-0.05, -0.02, 0.03, 0.09, 0.15, 0.20], np.linspace(0.24, 0.56, 15)])
    parts = [surf.shell("Sleeve", tube.grid(surf.turns(14), rows, sleeve_folds), mats["cloth"])]
    parts.append(surf.patch("ElbowPatch", tube, (0.36, 0.64, 0.25, 0.38), 0.005, mats["cloth"], (5, 5), sleeve_folds))
    parts.append(surf.patch("CuffBand", tube, (0.0, 1.0, 0.515, 0.552), 0.004, mats["cloth"], (12, 1)))
    outer = 0.75 if sign > 0 else 0.25
    pocket = (outer - 0.10, outer + 0.10, 0.09, 0.19)
    parts.append(surf.patch("ArmPocket", tube, pocket, 0.006, mats["cloth"], (4, 4), sleeve_folds))
    return parts


def _scarf(mats: dict) -> list:
    """Two loose wraps of a neck scarf; the lower one sags onto the chest."""
    parts = []
    for name, z, wide, deep, thick, tilt, phase in (
        ("ScarfLow", 1.512, 0.094, 0.100, 0.028, 0.044, 0.3),
        ("ScarfHigh", 1.552, 0.076, 0.082, 0.024, 0.016, 1.9),
    ):
        angles = math.tau * surf.turns(22)
        path = np.stack([np.sin(angles) * wide, -np.cos(angles) * deep - 0.006, z - tilt * np.cos(angles)], axis=1)
        swell = 1 + 0.22 * np.sin(angles * 4 + phase) + 0.12 * np.sin(angles * 9 + phase * 2)
        radii = np.stack([thick * swell, thick * 0.85 * (2 - swell)], axis=1)
        parts.append(surf.sweep(name, path, radii, mats["cloth"], 7, closed=True))
    return parts


def _hood(mats: dict) -> list:
    """A hood lying flat on the upper back: a fat roll round the shoulders with a sagging pouch."""
    angles = np.linspace(-0.46 * math.pi, 0.46 * math.pi, 13)
    fade = np.cos(angles / 0.94) ** 0.6
    path = np.stack(
        [np.sin(angles) * 0.125, np.cos(angles) * 0.118 - 0.012, 1.505 - 0.028 * np.cos(angles) + 0.02 * (1 - fade)],
        axis=1,
    )
    swell = 1 + 0.12 * np.sin(angles * 6)
    radii = np.stack([0.006 + 0.036 * fade * swell, 0.006 + 0.034 * fade], axis=1)
    roll = surf.sweep("HoodRoll", path, radii, mats["cloth"], 8)
    pouch = surf.ball("HoodPouch", (0, 0.112, 1.405), (0.115, 0.030, 0.095), mats["cloth"], (12, 6))
    return [roll, pouch]


def _trousers(mats: dict) -> list:
    pelvis = surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), PELVIS_KEYS)
    parts = [surf.shell("Pelvis", pelvis.grid(surf.turns(20), (0.79, 0.83, 0.90, 1.00)), mats["cloth"])]
    for sign in (1, -1):
        tube = leg_tube(sign)
        rows = np.concatenate([[0.215, 0.235, 0.255], np.linspace(0.275, 0.62, 14), [0.70, 0.80, 0.90, 0.98]])
        parts.append(surf.shell("Leg", tube.grid(surf.turns(14), rows, leg_folds), mats["cloth"]))
        outer = 0.25 if sign > 0 else 0.75
        cargo = (outer - 0.10, outer + 0.10, 0.62, 0.76)
        parts.append(surf.patch("CargoPocket", tube, cargo, 0.016, mats["cloth"], (5, 5), leg_folds))
        flap = (outer - 0.11, outer + 0.11, 0.735, 0.785)
        parts.append(surf.patch("CargoFlap", tube, flap, 0.020, mats["cloth"], (5, 3), leg_folds))
        knee = (-0.17, 0.17, 0.455, 0.585)
        parts.append(
            surf.patch(
                "KneePad", tube, knee, 0.016, mats["rubber"], (6, 6), None, lambda un: 0.03 * np.abs(un - 0.5) ** 1.5
            )
        )
        strap = (0.15, 0.85, 0.505, 0.535)
        parts.append(surf.patch("KneeStrap", tube, strap, 0.004, mats["rubber"], (8, 1)))
    return parts


def build_outfit(mats: dict) -> dict:
    """Returns {"cloth": [...], "arms": {sign: [...]}}; arms are bound apart so they follow the arm bones."""
    cloth = _jacket(mats) + _jacket_details(mats) + _scarf(mats) + _hood(mats) + _trousers(mats)
    return {"cloth": cloth, "arms": {sign: _sleeve(mats, sign) for sign in (1, -1)}}
