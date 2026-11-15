"""Hollis .44: heavy six-shot revolver with a full-lug barrel, fluted cylinder and wood grips.

Static parts join into `Receiver` (the frame). The hammer is the `Bolt` node, so the
viewmodel kick cocks it back; there is no Magazine (the cylinder loads by hand).
"""

import math

import gun_parts as g

BORE_Z = 0.04
CYL_R = 0.0215
SIGHT_Z = 0.074


def frame_parts(metal, black):
    """Frame around the cylinder window, top strap with rear sight, guard and side plate."""
    parts = [
        g.slab(
            "FrameRear",
            [(-0.052, 0.0), (-0.03, 0.0), (-0.03, 0.068), (-0.04, 0.068), (-0.052, 0.05)],
            0.03,
            metal,
            bevel=0.002,
        ),
        g.slab(
            "TopStrap", [(-0.033, 0.062), (0.042, 0.062), (0.042, 0.071), (-0.033, 0.071)], 0.02, metal, bevel=0.002
        ),
        g.slab(
            "FrameFront",
            [(0.034, 0.0), (0.05, 0.0), (0.05, 0.071), (0.034, 0.071)],
            0.03,
            metal,
            bevel=0.002,
        ),
        g.slab(
            "FrameBottom", [(-0.052, -0.004), (0.05, -0.004), (0.05, 0.017), (-0.052, 0.017)], 0.03, metal, bevel=0.002
        ),
        g.slab(
            "TriggerGuard",
            [
                (0.022, -0.004),
                (0.022, -0.03),
                (0.005, -0.045),
                (-0.03, -0.045),
                (-0.04, -0.004),
                (-0.032, -0.004),
                (-0.025, -0.038),
                (0.002, -0.038),
                (0.015, -0.026),
                (0.015, -0.004),
            ],
            0.012,
            metal,
            bevel=0.0015,
        ),
        g.slab("SidePlate", g.rounded(-0.05, 0.002, -0.032, 0.048, 0.004), 0.002, metal, x=0.0155),
        g.slab("Latch", g.rounded(-0.046, 0.03, -0.034, 0.038, 0.002), 0.004, black, x=-0.016),
    ]
    for x in (-0.0045, 0.0045):
        parts.append(
            g.slab(
                f"RearSight{x}",
                [(-0.03, 0.07), (-0.018, 0.07), (-0.018, SIGHT_Z + 0.002), (-0.03, SIGHT_Z + 0.002)],
                0.004,
                black,
                x=x,
            )
        )
    for x in (-1, 1):
        for y, z in ((-0.044, 0.008), (-0.04, 0.04), (0.042, 0.008)):
            parts.append(g.lathe(f"Screw{x}{y}{z}", [(0.003, 0.0145), (0.003, 0.0165)], (0, y, z), black, 8, axis="x"))
    return parts


def cylinder_parts(metal, black):
    """Fluted cylinder with six chamber mouths, on its crane between the frame halves."""
    cylinder = [
        g.lathe("Cylinder", [(0.019, -0.03), (CYL_R, -0.027), (CYL_R, 0.03), (0.019, 0.033)], (0, 0, BORE_Z), metal, 48)
    ]
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        flute = g.slab(f"Flute{i}", g.rounded(-0.018, -0.0035, 0.022, 0.0035, 0.0034), 0.002, black, x=CYL_R - 0.0006)
        flute.rotation_euler = (0.0, a, 0.0)
        flute.location = (0.0, 0.0, BORE_Z)
        mouth = (0.013 * math.cos(a + math.pi / 6), 0.0, BORE_Z + 0.013 * math.sin(a + math.pi / 6))
        cylinder += [flute, g.lathe(f"Chamber{i}", [(0.0048, 0.032), (0.0048, 0.0336)], mouth, black, 14)]
    cylinder.append(g.lathe("Pin", [(0.004, 0.033), (0.004, 0.036)], (0, 0, BORE_Z), metal, 10))
    return cylinder


def barrel_parts(metal, black):
    """Full-lug barrel: round tube, vented top rib, underlug with ejector rod and the front blade."""
    parts = [
        g.lathe(
            "BarrelTube", [(0.011, 0.05), (0.0095, 0.054), (0.0095, 0.2), (0.008, 0.203)], (0, 0, BORE_Z), metal, 32
        ),
        g.slab("TopRib", [(0.05, 0.046), (0.2, 0.046), (0.2, 0.055), (0.05, 0.055)], 0.011, metal, bevel=0.0015),
        g.slab(
            "Underlug",
            [(0.05, 0.012), (0.196, 0.012), (0.203, 0.02), (0.203, 0.036), (0.05, 0.036)],
            0.017,
            metal,
            bevel=0.002,
        ),
        g.slab(
            "FrontSight",
            [(0.178, 0.054), (0.198, 0.054), (0.198, SIGHT_Z), (0.188, SIGHT_Z), (0.178, 0.06)],
            0.004,
            black,
        ),
        g.lathe("Bore", [(0.0055, 0.2025), (0.0055, 0.2035)], (0, 0, BORE_Z), black, 12),
        g.lathe(
            "EjectorRod", [(0.003, 0.033), (0.003, 0.06), (0.0045, 0.062), (0.0045, 0.07)], (0, 0, 0.024), metal, 12
        ),
    ]
    for i in range(5):
        y = 0.065 + i * 0.026
        parts.append(g.slab(f"Vent{i}", g.rounded(y, 0.0465, y + 0.016, 0.0535, 0.003), 0.013, black))
    for x in (-1, 1):
        parts.append(g.slab(f"LugFlat{x}", g.rounded(0.06, 0.016, 0.19, 0.032, 0.006), 0.001, black, x=x * 0.0088))
    return parts


def grip_parts(m, receiver, metal, wood, checker):
    """Round-butt wood grips on a metal grip frame with a lanyard ring."""
    outline = [
        (-0.03, 0.0),
        (-0.054, 0.004),
        (-0.068, -0.03),
        (-0.086, -0.075),
        (-0.092, -0.1),
        (-0.084, -0.113),
        (-0.06, -0.114),
        (-0.05, -0.1),
        (-0.042, -0.065),
        (-0.03, -0.035),
        (-0.018, -0.006),
    ]
    grip = g.slab("Grip", outline, 0.034, wood, bevel=0.005)
    pieces = [
        g.slab(
            "GripFrame",
            [(-0.054, 0.004), (-0.062, 0.004), (-0.078, -0.035), (-0.092, -0.1), (-0.087, -0.1), (-0.072, -0.035)],
            0.026,
            metal,
            bevel=0.0015,
        ),
        g.lathe("Lanyard", [(0.004, -0.008), (0.004, 0.008)], (0, -0.075, -0.112), metal, 10, axis="x"),
    ]
    for x in (-1, 1):
        pieces.append(
            g.slab(
                f"Checker{x}",
                [(-0.05, -0.02), (-0.07, -0.03), (-0.082, -0.08), (-0.068, -0.1), (-0.052, -0.09), (-0.042, -0.05)],
                0.002,
                checker,
                x=x * 0.0172,
            )
        )
        pieces.append(
            g.lathe(f"GripScrew{x}", [(0.004, 0.0165), (0.004, 0.0185)], (0, -0.058, -0.055), metal, 12, axis="x")
        )
    m.join_into(grip, pieces)
    m.attach(grip, (0, -0.04, 0.0), receiver)


def moving_parts(m, receiver, metal, black):
    """Hammer (the Bolt) pivots at its base; trigger in the guard; Muzzle at the crown."""
    hammer = g.slab(
        "Bolt",
        [
            (-0.05, 0.038),
            (-0.042, 0.05),
            (-0.046, 0.062),
            (-0.058, 0.069),
            (-0.064, 0.065),
            (-0.057, 0.058),
            (-0.056, 0.04),
        ],
        0.008,
        metal,
        bevel=0.001,
    )
    m.attach(hammer, (0, -0.05, 0.04), receiver)
    trigger = g.slab(
        "Trigger",
        [(-0.006, -0.004), (0.0, -0.004), (-0.004, -0.02), (-0.014, -0.033), (-0.019, -0.03), (-0.011, -0.018)],
        0.006,
        black,
    )
    m.attach(trigger, (0, -0.004, -0.004), receiver)
    m.marker("Muzzle", (0, 0.204, BORE_Z), parent=receiver)


def build(m) -> None:
    """Build from shared helpers supplied by build_models, keeping the runtime part names."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    wood = m.material("Wood", m.WOOD, roughness=0.7)
    checker = m.material("WoodKnurled", m.WOOD, roughness=0.8)
    receiver = g.slab(
        "Receiver", [(-0.03, 0.017), (0.034, 0.017), (0.034, 0.024), (-0.03, 0.024)], 0.026, metal, bevel=0.001
    )
    m.join_into(receiver, frame_parts(metal, black) + cylinder_parts(metal, black) + barrel_parts(metal, black))
    grip_parts(m, receiver, metal, wood, checker)
    moving_parts(m, receiver, metal, black)
