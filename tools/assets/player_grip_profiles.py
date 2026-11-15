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
    "fieldhand_lever",
    "ironwood_50",
    "wren_mp",
    "siphon",
    "sentry_br3",
    "nightjar_sd",
    "rampart_br",
    "cryo_lance",
    "synapse",
    "bastion_lmg",
    "coachman_2b",
    "grubber_sawnoff",
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
    "fieldhand_lever": 0.033,
    "ironwood_50": 0.042,
    "wren_mp": 0.033,
    "siphon": 0.033,
    "sentry_br3": 0.033,
    "nightjar_sd": 0.035,
    "rampart_br": 0.042,
    "cryo_lance": 0.039,
    "synapse": 0.041,
    "bastion_lmg": 0.038,
}
FLAT_SUPPORT_SECTIONS = {
    "corvid_338": (0.030, 0.024, 0.048, 0.0),
    "fieldhand_lever": (0.030, 0.024, 0.048, 0.0),
    "coachman_2b": (0.030, 0.024, 0.048, 0.0),
    "grubber_sawnoff": (0.0325, 0.024, 0.048, 0.0),
}
FIRING_SECTIONS = {
    "bastion_lmg": (0.024, 0.021, 0.048, math.radians(49)),
    "sentry_br3": (0.0215, 0.0169, 0.046, math.radians(48)),
    "nightjar_sd": (0.024, 0.0175, 0.045, math.radians(45.5)),
    "rampart_br": (0.0265, 0.01925, 0.048, math.radians(50.9)),
    "cryo_lance": (0.0245, 0.0195, 0.048, math.radians(48.5)),
    "synapse": (0.0255, 0.017, 0.047, math.radians(47.9)),
}
EXTENDED_INDEX_PROFILES = ("ironwood_50", "siphon", *FIRING_SECTIONS)
FIRING_SECTIONS.update(
    {
        "fieldhand_lever": (0.026, 0.0185, 0.055, math.atan2(0.34, 0.94) + math.pi / 6),
        "brenner_trench": (0.026, 0.0185, 0.057, math.atan2(0.34, 0.94) + math.pi / 6),
        "ironwood_50": (0.029, 0.0215, 0.048, math.atan2(0.32, 0.9474) + math.pi / 6),
        "siphon": (0.028, 0.022, 0.048, math.atan2(0.25, 0.968) + math.pi / 6),
        "corvid_338": (0.024, 0.031, 0.054, math.atan2(0.15, 0.9887) + math.pi / 6),
        "pistol_service": (0.029, 0.0185, 0.045, -math.asin(0.2079) + math.pi / 6),
        "coachman_2b": (0.026, 0.0185, 0.046, math.atan2(0.34, 0.94) + math.pi / 6),
        "grubber_sawnoff": (0.026, 0.0195, 0.048, math.pi / 3),
    }
)


def section(profile, gap):
    """Return depth/width half extents, palm offset and grip shaft angle."""
    if gap == 0.045:
        if profile == "cryo_lance":
            return 0.0405, 0.0405, 0.063, 0.0
        if profile == "synapse":
            return 0.041, 0.041, 0.074, 0.0
        if profile in ("ironwood_50", "rampart_br"):
            return 0.0435, 0.0435, 0.066, 0.0
        if profile in FLAT_SUPPORT_SECTIONS:
            return FLAT_SUPPORT_SECTIONS[profile]
        radius = SUPPORT_RADII[profile]
        return radius, radius, 0.057 + radius - 0.033, 0.0
    return FIRING_SECTIONS.get(profile, (0.026, 0.0185, 0.045, math.atan2(0.34, 0.94) + math.pi / 6))


def end_angle(profile, gap):
    """Keep support fingertips beneath barrels that sit immediately above the grip."""
    if gap == 0.032 and profile == "corvid_338":
        return 1.05
    if gap == 0.045 and profile == "ironwood_50":
        return -0.30
    return 0.15 if gap == 0.045 and (profile in FLAT_SUPPORT_SECTIONS or profile == "brenner_trench") else 0.65


def finger_angle(profile, gap, index):
    offset = (0, 0.20, 0.15, -0.12)[index]
    if profile == "ironwood_50" and gap == 0.045 and index == 3:
        offset = 0.05
    return end_angle(profile, gap) + offset
