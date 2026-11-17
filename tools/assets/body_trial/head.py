"""Survivor head: shaped face, short hair, full beard, brows, ears and eyes on the head bone."""

import math

import numpy as np
import surface as surf
from surface import bump, step

# z, side shift, front shift, half width, front depth, back depth, squareness
HEAD_KEYS = (
    (1.545, 0, 0, 0.030, 0.035, 0.045, 2.0),
    (1.560, 0, 0, 0.043, 0.074, 0.050, 2.0),
    (1.572, 0, 0, 0.051, 0.088, 0.055, 2.1),
    (1.590, 0, 0, 0.060, 0.095, 0.062, 2.2),
    (1.610, 0, 0, 0.066, 0.097, 0.076, 2.3),
    (1.630, 0, 0, 0.070, 0.096, 0.088, 2.3),
    (1.650, 0, 0, 0.073, 0.094, 0.096, 2.3),
    (1.670, 0, 0, 0.075, 0.093, 0.100, 2.3),
    (1.690, 0, 0, 0.076, 0.092, 0.102, 2.3),
    (1.710, 0, 0, 0.077, 0.097, 0.102, 2.3),
    (1.730, 0, 0, 0.077, 0.097, 0.100, 2.2),
    (1.750, 0, 0, 0.074, 0.090, 0.094, 2.1),
    (1.770, 0, 0, 0.066, 0.075, 0.082, 2.0),
    (1.785, 0, 0, 0.052, 0.055, 0.062, 2.0),
    (1.795, 0, 0, 0.032, 0.030, 0.038, 2.0),
    (1.800, 0, 0, 0.012, 0.010, 0.012, 2.0),
)
NECK_KEYS = (
    (1.46, 0, -0.016, 0.060, 0.058, 0.060, 2.0),
    (1.53, 0, -0.008, 0.055, 0.054, 0.056, 2.0),
    (1.60, 0, 0.004, 0.054, 0.056, 0.056, 2.0),
)
FACE_X = (0, 0.005, 0.010, 0.015, 0.0205, 0.025, 0.0295, 0.034, 0.0385, 0.043, 0.048, 0.055, 0.063)
SIDE_ANGLES = (68, 80, 95, 115, 145, 180)
FACE_Z = (
    *(1.545, 1.558, 1.571, 1.584, 1.596, 1.606, 1.613, 1.6165, 1.620, 1.624, 1.629, 1.634),
    *(1.639, 1.644, 1.649, 1.656, 1.664, 1.672, 1.679, 1.684, 1.688, 1.692, 1.6955, 1.700, 1.705),
    *(1.710, 1.716, 1.726, 1.742, 1.760, 1.776, 1.789, 1.797, 1.800),
)
EYE = (0.031, 1.6895)
EYE_RADIUS = 0.0125
HIDDEN = 0.012  # hair shells sink this far under the skin where no hair grows
NOSE_Z = (1.626, 1.633, 1.640, 1.647, 1.660, 1.680, 1.700, 1.712)
NOSE_OUT = (0.0, 0.006, 0.019, 0.024, 0.017, 0.009, 0.003, 0.0)
NOSE_WIDE = (0.013, 0.013, 0.0125, 0.011, 0.008, 0.0065, 0.007, 0.009)


def head_tube() -> surf.Tube:
    return surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), HEAD_KEYS)


def _around(half: list) -> np.ndarray:
    """Mirror a list of half-ring angles (turns, 0 to 0.5) into a full ring."""
    half = np.asarray(half)
    return np.concatenate([half, 1.0 - half[-2:0:-1]])


def face_columns() -> np.ndarray:
    """Columns packed on the face, where the nose, eyes and mouth need them."""
    front = [math.asin(x / 0.0765) / math.tau for x in FACE_X]
    return _around(front + [angle / 360 for angle in SIDE_ANGLES])


def _nose(ax, z):
    profile = surf.spline(NOSE_Z, np.stack([NOSE_OUT, NOSE_WIDE], axis=1), z)
    ridge = profile[..., 0] * np.exp(-((ax / profile[..., 1]) ** 2))
    return ridge + 0.007 * bump(ax, 0.0135, 0.006) * bump(z, 1.6415, 0.0065)


def _eyes(ax, z):
    socket = -0.009 * bump(ax, EYE[0], 0.017) * bump(z, EYE[1] + 0.0005, 0.0105)
    almond = ((ax - EYE[0]) / 0.0170) ** 2 + ((z - EYE[1]) / 0.0070) ** 2
    brow = 0.005 * bump(z, 1.708, 0.0075) * (1 - 0.5 * bump(ax, 0, 0.008)) * step(0.062 - ax, 0, 0.02)
    return socket - 0.0080 * (1 - step(almond, 1.0, 0.5)) + brow


def _mouth(ax, z):
    lips = 0.003 * bump(z, 1.6225, 0.004) * bump(ax, 0, 0.020) + 0.0035 * bump(z, 1.6105, 0.0045) * bump(ax, 0, 0.017)
    return lips - 0.0035 * bump(z, 1.6165, 0.0017) * step(0.024 - ax, 0, 0.006)


def face(points, _u, _s):
    """Lift in metres that turns the plain skull into a face; only the front is touched."""
    ax, y, z = np.abs(points[..., 0]), points[..., 1], points[..., 2]
    cheeks = 0.004 * bump(ax, 0.052, 0.016) * bump(z, 1.667, 0.012) - 0.004 * bump(ax, 0.047, 0.016) * bump(
        z, 1.630, 0.018
    )
    chin = 0.004 * bump(ax, 0, 0.018) * bump(z, 1.582, 0.012)
    return step(-y, 0.03, 0.04) * (_nose(ax, z) + _eyes(ax, z) + _mouth(ax, z) + cheeks + chin)


HAIRLINE_Y = (-0.11, -0.085, -0.06, -0.045, -0.03, -0.018, -0.008, 0.022, 0.035, 0.06, 0.11)
HAIRLINE_Z = (1.756, 1.754, 1.738, 1.700, 1.655, 1.655, 1.700, 1.705, 1.660, 1.615, 1.605)


def hair(points, u, s):
    """Short cropped hair: thickness above the hairline, sunk under the skin below it."""
    y, z = points[..., 1], points[..., 2]
    line = surf.spline(HAIRLINE_Y, np.asarray(HAIRLINE_Z)[:, None], y)[..., 0]
    cover = step(z - line, 0.0, 0.008)
    strands = 0.0012 * np.sin(math.tau * (u * 13 + 0.35 * np.sin(z * 55)))
    tuft = 0.005 * bump(y, -0.055, 0.04) * step(z - 1.745, 0, 0.02)
    strands *= 1 - step(z, 1.775, 0.02)
    return face(points, u, s) - HIDDEN + cover * (0.011 + tuft + strands + HIDDEN)


CHEEK_X = (0.0, 0.018, 0.030, 0.042, 0.055, 0.066, 0.080)
CHEEK_Z = (1.6375, 1.636, 1.630, 1.632, 1.650, 1.670, 1.678)
JAW_BACK_Z = (1.545, 1.57, 1.60, 1.63, 1.68)
JAW_BACK_Y = (0.040, 0.038, 0.022, 0.004, -0.006)


def beard(points, u, s):
    """Full beard and moustache with a gap for the lower lip."""
    ax, y, z = np.abs(points[..., 0]), points[..., 1], points[..., 2]
    cover = step(surf.spline(CHEEK_X, np.asarray(CHEEK_Z)[:, None], ax)[..., 0] - z, 0.0, 0.006)
    cover *= 1 - step(0.016 - ax, 0, 0.006) * step(z - 1.6075, 0, 0.003) * step(1.6190 - z, 0, 0.003)
    cover *= step(surf.spline(JAW_BACK_Z, np.asarray(JAW_BACK_Y)[:, None], z)[..., 0] - y, 0.0, 0.010)
    thick = 0.006 + 0.006 * step(1.60 - z, 0, 0.03) + 0.006 * bump(ax, 0, 0.03) * step(1.585 - z, 0, 0.02)
    thick += 0.003 * bump(z, 1.629, 0.006) * step(0.034 - ax, 0, 0.01)
    strands = 0.0010 * np.sin(math.tau * (ax * 45 + z * 20))
    return face(points, u, s) - HIDDEN + cover * (thick + strands + HIDDEN)


def _eye_depth(tube) -> float:
    """Blender y of the skin at the middle of the eye opening."""
    u = np.linspace(0.0, 0.2, 400)
    points = tube.surface(u, np.full_like(u, EYE[1]), face)
    return float(points[np.argmin(np.abs(points[:, 0] - EYE[0])), 1])


def _ear(mat, sign):
    ear = surf.ball("Ear", (0, 0, 0), (0.0065, 0.016, 0.030), mat, (8, 6))
    turn, lean = sign * math.radians(-22), sign * math.radians(-7)
    for vertex in ear.data.vertices:
        x, y, z = vertex.co
        if x * sign > 0:
            x -= sign * 0.004 * bump(y, -0.002, 0.008) * bump(z, 0.002, 0.014)
        x, y = x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn)
        x, z = x * math.cos(lean) - z * math.sin(lean), x * math.sin(lean) + z * math.cos(lean)
        vertex.co = (x + sign * 0.079, y + 0.010, z + 1.677)
    return ear


def _brow(tube, mat, sign):
    low, high = (math.asin(x / 0.0765) / math.tau for x in (0.010, 0.050))
    span = (sign * low, sign * high, 1.7050, 1.7115)

    def arch(un):
        return -0.0035 * un + 0.0025 * bump(un, 0.45, 0.3)

    return surf.patch("Brow", tube, span, 0.0026, mat, (4, 2), face, arch)


def build_head(mats: dict) -> dict:
    """Returns {"skin": [...], "hair": [...], "eyes": [...]}: every part rides the head bone."""
    tube = head_tube()
    skin = [surf.shell("Head", tube.grid(face_columns(), FACE_Z, face), mats["skin"])]
    hair_z = (1.59, 1.615, 1.64, 1.665, 1.69, 1.71, 1.73, 1.75, 1.768, 1.782, 1.792, 1.798, 1.80)
    hairs = [surf.shell("Hair", tube.grid(surf.turns(26), hair_z, hair), mats["hair"])]
    beard_z = (1.545, 1.558, 1.574, 1.592, 1.606, 1.613, 1.620, 1.626, 1.632, 1.638, 1.648, 1.662, 1.676)
    beard_u = _around(
        [0, 0.009, 0.018, 0.028, 0.039, 0.051, 0.064, 0.078, 0.096, 0.116, 0.14, 0.17, 0.205, 0.25, 0.32, 0.5]
    )
    hairs.append(surf.shell("Beard", tube.grid(beard_u, beard_z, beard), mats["hair"]))
    depth = _eye_depth(tube)
    eyes = []
    for sign in (1, -1):
        skin.append(_ear(mats["skin"], sign))
        hairs.append(_brow(tube, mats["hair"], sign))
        centre = (sign * EYE[0], depth + EYE_RADIUS - 0.0035, EYE[1])
        eyes.append(surf.ball("Eyeball", centre, (EYE_RADIUS,) * 3, mats["rubber"], (8, 5)))
    return {"skin": skin, "hair": hairs, "eyes": eyes}


def build_neck(mats: dict):
    tube = surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), NECK_KEYS)
    return surf.shell("Neck", tube.grid(surf.turns(14), (1.46, 1.50, 1.54, 1.575, 1.60)), mats["skin"])
