"""Clothes the player has not got: long wool coat, knit shawl, reading glasses on a cord, plain trousers."""

import math

import numpy as np
import outfit
import surface as surf
from head import EYE
from surface import bump, step

# z, side shift, front shift, half width, front depth, back depth, squareness (hem at mid-shin)
COAT_KEYS = (
    (0.360, 0, 0, 0.250, 0.165, 0.175, 2.3),
    (0.380, 0, 0, 0.248, 0.164, 0.174, 2.3),
    (0.600, 0, 0, 0.232, 0.155, 0.165, 2.4),
    (0.800, 0, 0, 0.218, 0.146, 0.152, 2.5),
    (0.905, 0, 0, 0.212, 0.144, 0.146, 2.5),
    (0.985, 0, 0, 0.196, 0.138, 0.132, 2.5),
    (1.050, 0, 0, 0.182, 0.130, 0.120, 2.5),
    (1.150, 0, 0, 0.188, 0.134, 0.120, 2.5),
    (1.280, 0, 0, 0.206, 0.146, 0.128, 2.5),
    (1.380, 0, 0, 0.208, 0.144, 0.132, 2.4),
    (1.450, 0, 0, 0.208, 0.128, 0.128, 2.3),
    (1.495, 0, 0, 0.178, 0.106, 0.114, 2.2),
    (1.530, 0, 0, 0.105, 0.082, 0.092, 2.0),
    (1.560, 0, 0, 0.078, 0.070, 0.078, 2.0),
)
SLEEVE_SCALE = 1.15  # wool sleeves sit loose over the arm
# Lower edge of the shawl round the body (u in turns from the front): a V in front, deep at the back.
SHAWL_U = (0.0, 0.06, 0.12, 0.25, 0.38, 0.5)
SHAWL_LOW = (1.37, 1.30, 1.31, 1.42, 1.30, 1.25)
SHAWL_TOP = 1.556
LENS = (EYE[0] + 0.001, -0.106, EYE[1] - 0.010)
LENS_SIZE = (0.0155, 0.0120)
TEMPLE = ((0.049, -0.104, 1.674), (0.080, -0.060, 1.680), (0.087, -0.025, 1.682), (0.089, 0.004, 1.676))
CORD = ((0.089, 0.006, 1.672), (0.083, 0.040, 1.630), (0.062, 0.074, 1.588), (0.032, 0.093, 1.566))
# Clothes follow only these bones, like the player's CLOTH_BONES.
TORSO = ("pelvis", "spine_01", "spine_02", "spine_03", "neck", "clavicle_L", "clavicle_R")
CLOTH_BONES = {
    **dict.fromkeys(
        ("Coat", "CoatHem", "CoatPlacket", "Button", "CoatPocket", "CoatFlap"), (*TORSO, "thigh_L", "thigh_R")
    ),
    **dict.fromkeys(("Shawl", "ShawlEnd"), ("spine_02", "spine_03", "neck", "clavicle_L", "clavicle_R")),
    "Leg": ("pelvis", "thigh_{s}", "shin_{s}"),
    **dict.fromkeys(("CoatSleeve", "CoatCuff"), ("clavicle_{s}", "upperarm_{s}", "forearm_{s}")),
}


def coat_tube() -> surf.Tube:
    return surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), COAT_KEYS)


def coat_folds(points, u, _s):
    """Heavy wool: long soft folds in the skirt, a little slack across the chest and back."""
    z = points[..., 2]
    skirt = 0.008 * step(0.92 - z, 0, 0.2) * np.sin(math.tau * u * 9 + 0.6 + 2.0 * z)
    back = 0.003 * bump(z, 1.20, 0.08) * np.sin(math.tau * u * 5)
    return skirt + back


def _coat(mats: dict) -> list:
    tube = coat_tube()
    rows = np.concatenate([np.linspace(0.36, 0.88, 10), np.linspace(0.905, 1.15, 6), np.linspace(1.19, 1.45, 6)])
    rows = np.concatenate([rows, [1.475, 1.495, 1.515, 1.54, 1.56]])
    parts = [surf.shell("Coat", tube.grid(surf.turns(32), rows, coat_folds), mats["cloth"])]
    parts.append(surf.patch("CoatHem", tube, (0.25, 1.25, 0.358, 0.40), 0.004, mats["cloth"], (30, 1), coat_folds))
    parts.append(surf.patch("CoatPlacket", tube, (-0.02, 0.02, 0.40, 1.36), 0.005, mats["cloth"], (1, 12)))
    for z in (0.74, 0.90, 1.06, 1.21, 1.34):
        button = (-0.006, 0.006, z - 0.009, z + 0.009)
        parts.append(surf.patch("Button", tube, button, 0.009, mats["rubber"], (1, 1)))
    for sign in (1, -1):
        pocket = sorted((sign * 0.09, sign * 0.19))
        parts.append(surf.patch("CoatPocket", tube, (*pocket, 0.74, 0.88), 0.006, mats["cloth"], (5, 4), coat_folds))
        flap = sorted((sign * 0.085, sign * 0.195))
        parts.append(surf.patch("CoatFlap", tube, (*flap, 0.86, 0.91), 0.010, mats["cloth"], (5, 2), coat_folds))
    return parts


def _sleeve(mats: dict, sign: int) -> list:
    keys = np.asarray(outfit.SLEEVE_KEYS) * (1, sign, 1, SLEEVE_SCALE, SLEEVE_SCALE, SLEEVE_SCALE, 1)
    origin = (sign * outfit.SHOULDER[0], outfit.SHOULDER[1], outfit.SHOULDER[2])
    tube = surf.Tube(origin, (sign * outfit.ARM_AXIS[0], 0, outfit.ARM_AXIS[2]), (-1, 0, -sign), keys)
    rows = np.concatenate([[-0.05, -0.02, 0.03, 0.09, 0.15, 0.20], np.linspace(0.24, 0.56, 12)])
    return [
        surf.shell("CoatSleeve", tube.grid(surf.turns(14), rows, outfit.sleeve_folds), mats["cloth"]),
        surf.patch("CoatCuff", tube, (0.0, 1.0, 0.47, 0.548), 0.008, mats["cloth"], (12, 2)),
    ]


def _shawl(mats: dict) -> list:
    """A knit shawl round the shoulders that rolls up into a cowl, its two ends hanging down the front."""
    tube = coat_tube()
    around = surf.turns(40)
    low = surf.spline(SHAWL_U, np.asarray(SHAWL_LOW)[:, None], 0.5 - np.abs(0.5 - around))[..., 0]
    blend = np.linspace(0.0, 1.0, 9)[:, None]
    s = low[None, :] + (SHAWL_TOP - low[None, :]) * blend

    def knit(points, u, ss):
        rib = 0.002 * np.sin(math.tau * u * 60)
        drape = 0.004 * np.sin(math.tau * u * 7 + 1.3)
        return 0.012 + 0.012 * step(ss, 1.50, 0.04) + rib + drape

    parts = [surf.shell("Shawl", tube.surface(around[None, :], s, knit), mats["cloth"])]
    for sign in (1, -1):
        span = sorted((sign * 0.035, sign * 0.115))
        parts.append(surf.patch("ShawlEnd", tube, (*span, 1.00, 1.335), 0.016, mats["cloth"], (4, 6), coat_folds))
    return parts


def _trousers(mats: dict) -> list:
    rows = np.concatenate([[0.215, 0.235, 0.255], np.linspace(0.275, 0.62, 8), [0.70, 0.80, 0.90, 0.98]])
    return [
        surf.shell("Leg", outfit.leg_tube(sign).grid(surf.turns(12), rows, outfit.leg_folds), mats["cloth"])
        for sign in (1, -1)
    ]


def _glasses(mats: dict) -> list:
    """Reading glasses low on the nose, the cord looped behind the neck."""
    parts = []
    angles = math.tau * surf.turns(14)
    for sign in (1, -1):
        centre = np.asarray((sign * LENS[0], LENS[1], LENS[2]))
        parts.append(surf.ball("Lens", centre, (LENS_SIZE[0], 0.0015, LENS_SIZE[1]), mats["rubber"], (10, 4)))
        ring = centre + np.stack([np.cos(angles) * LENS_SIZE[0], np.zeros(14), np.sin(angles) * LENS_SIZE[1]], axis=1)
        parts.append(surf.sweep("Frame", ring, np.full(14, 0.0011), mats["rubber"], 4, up=(0, -1, 0), closed=True))
        temple = np.asarray(TEMPLE) * (sign, 1, 1)
        parts.append(surf.sweep("Frame", temple, np.full(len(temple), 0.0011), mats["rubber"], 4))
    bridge = np.asarray([(0.0155, LENS[1], LENS[2] + 0.002), (0, LENS[1] - 0.002, LENS[2] + 0.006)])
    bridge = np.concatenate([bridge, bridge[-2::-1] * (-1, 1, 1)])
    parts.append(surf.sweep("Frame", bridge, np.full(3, 0.0011), mats["rubber"], 4))
    cord = np.concatenate([np.asarray(CORD), [(0.0, 0.097, 1.561)], np.asarray(CORD[::-1]) * (-1, 1, 1)])
    parts.append(surf.sweep("Cord", cord, np.full(len(cord), 0.0012), mats["rubber"], 4))
    return parts


def build_quartermaster(mats: dict) -> dict:
    """Odile Brandt's clothes: {"cloth": [...], "arms": {sign: [...]}, "head": [...]}."""
    cloth = _coat(mats) + _shawl(mats) + _trousers(mats)
    return {"cloth": cloth, "arms": {sign: _sleeve(mats, sign) for sign in (1, -1)}, "head": _glasses(mats)}
