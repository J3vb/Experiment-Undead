"""Character-only grip sections; weapon placement is separate from glove shape."""

import math

PROFILES = (
    "rifle_ar",
    "talon_dmr",
    "kestrel_smg",
    "mako_pdw",
    "atlas_auto",
    "halberd_lmg",
    "corvid_338",
    "brenner_trench",
    "hollis_44",
    "pistol_service",
)
SUPPORT_RADII = {
    "rifle_ar": 0.033,
    "talon_dmr": 0.035,
    "kestrel_smg": 0.031,
    "mako_pdw": 0.033,
    "atlas_auto": 0.0352,
    "halberd_lmg": 0.038,
    "corvid_338": 0.033,
    "brenner_trench": 0.0225,
    "hollis_44": 0.033,
    "pistol_service": 0.033,
}


def section(profile, gap):
    """Return depth/width half extents, palm offset and grip shaft angle."""
    if gap == 0.045:
        if profile == "corvid_338":
            return 0.030, 0.024, 0.048, 0.0
        radius = SUPPORT_RADII[profile]
        return radius, radius, 0.057 + radius - 0.033, 0.0
    if profile == "corvid_338":
        return 0.024, 0.031, 0.054, math.atan2(0.15, 0.9887) + math.pi / 6
    if profile == "pistol_service":
        return 0.029, 0.0185, 0.045, -math.asin(0.2079) + math.pi / 6
    return 0.026, 0.0185, 0.045, math.atan2(0.34, 0.94) + math.pi / 6


def end_angle(profile, gap):
    """Keep support fingertips beneath barrels that sit immediately above the grip."""
    if gap == 0.032 and profile == "corvid_338":
        return 1.05
    return 0.15 if gap == 0.045 and profile in ("corvid_338", "brenner_trench") else 0.65
