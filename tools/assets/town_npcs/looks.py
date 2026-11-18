"""Town NPC looks as plain data: face, hair, beard, material colours and the texture looks table.

Texture rows have the shape of player_body textures.LOOKS: (final material, colour, roughness,
(mottle strength, scale), (grain scale, height), (wrinkle scale, height), edge wear, part names).
"""

import textures

BOOTS = {name: textures.LOOKS[name] for name in ("boot", "sole", "lace")}

QUARTERMASTER = {
    "face": "soft",
    "hair": "bun",
    "beard": False,
    "colours": {"skin": "#9C7A66", "hair": "#B5B1AA", "cloth": "#2C2D30", "rubber": "#2A2622"},
    "textures": {
        "skin": (
            "BodySkin",
            "#9C7A66",
            0.58,
            (0.12, 30),
            (260, 0.0004),
            (90, 0.0010),
            0.0,
            ("Head", "Neck", "GloveFinger", "GloveThumb"),
        ),
        "eye": textures.LOOKS["eye"],
        "hair": ("BodyHair", "#B5B1AA", 0.65, (0.35, 1), (1, 0.0030), (30, 0.0010), 0.0, ("Hair", "Brow", "Bun")),
        "coat": (
            "BodyCloth",
            "#2C2D30",
            0.95,
            (0.18, 10),
            (300, 0.0012),
            (30, 0.0030),
            0.15,
            ("Coat", "CoatHem", "CoatPlacket", "CoatSleeve", "CoatCuff"),
        ),
        "pocket": (
            "BodyCloth",
            "#28292C",
            0.95,
            (0.18, 10),
            (300, 0.0012),
            (30, 0.0022),
            0.2,
            ("CoatPocket", "CoatFlap"),
        ),
        "shawl": ("BodyCloth", "#4E1F24", 0.98, (0.22, 16), (120, 0.0026), (40, 0.0030), 0.1, ("Shawl", "ShawlEnd")),
        "trousers": ("BodyCloth", "#2B2723", 0.90, (0.24, 12), (240, 0.0010), (34, 0.0034), 0.2, ("Leg",)),
        "glove": (
            "BodyCloth",
            "#4A3F38",
            0.95,
            (0.20, 30),
            (160, 0.0018),
            (40, 0.0010),
            0.2,
            ("GlovePalm", "GloveThumbPad", "KnuckleGuard", "GloveStrap", "GloveCuff"),
        ),
        **BOOTS,
        "button": ("BodyRubber", "#2A221C", 0.40, (0.10, 30), (300, 0.0), (30, 0.0), 0.3, ("Button",)),
        "frame": ("BodyRubber", "#7A6440", 0.35, (0.05, 30), (300, 0.0), (30, 0.0), 0.4, ("Frame",)),
        "lens": ("BodyRubber", "#B8C4C6", 0.08, (0.0, 1), (1, 0.0), (1, 0.0), 0.0, ("Lens",)),
        "cord": ("BodyRubber", "#2B2622", 0.80, (0.05, 30), (300, 0.0004), (30, 0.0), 0.0, ("Cord",)),
    },
}
