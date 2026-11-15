"""Talon DMR: shaped receiver, long eight-sided handguard, precision stock, turned 3-9x optic and heavy barrel.

Static parts join into `Receiver`. Code and tests need `Stock`, `Optic`, `OpticGlass`,
`ScopeLensMount`, `Barrel` (with `MuzzleBrake`), `Bipod`, `Magazine`, `Bolt` (with
`ChargingHandle`), `Trigger` and the `Muzzle` marker.
"""

import math

import gun_parts as g

BORE_Z = 0.016


def upper(metal, black, grey):
    """Upper, rail, deflector and the long free-float handguard with slots."""
    flat = math.pi / 8
    parts = [
        g.slab("RailBase", [(-0.17, 0.048), (0.5, 0.048), (0.5, 0.053), (-0.17, 0.053)], 0.026, black),
        g.slab("RailTeeth", g.teeth(-0.167, 0.495, 0.053, 0.061), 0.023, black),
        g.lathe(
            "Handguard",
            [(0.031, 0.175), (0.035, 0.18), (0.035, 0.49), (0.031, 0.497)],
            (0, 0, BORE_Z),
            grey,
            8,
            turn=flat,
        ),
        g.lathe("HandguardNose", [(0.024, 0.495), (0.024, 0.505)], (0, 0, BORE_Z), black, 16),
        g.slab("EjectionPort", g.rounded(-0.03, 0.006, 0.06, 0.038, 0.004), 0.002, black, x=0.029),
        g.slab(
            "Deflector",
            [(-0.075, 0.004), (-0.04, 0.004), (-0.04, 0.034), (-0.055, 0.046), (-0.075, 0.046)],
            0.008,
            metal,
            x=0.03,
            bevel=0.002,
        ),
    ]
    side = 0.035 * math.cos(flat) + 0.0004
    for i in range(5):
        y = 0.205 + i * 0.056
        for x in (-1, 1):
            parts.append(g.slab(f"Slot{x}{i}", g.rounded(y, 0.008, y + 0.03, 0.024, 0.006), 0.002, black, x=x * side))
    return parts


def lower(metal, black, grey):
    """Lower with flared well, trigger guard, grip with panels, selector and pins."""
    grip = [
        (-0.095, -0.047),
        (-0.128, -0.047),
        (-0.172, -0.152),
        (-0.168, -0.166),
        (-0.132, -0.166),
        (-0.122, -0.152),
        (-0.117, -0.13),
        (-0.108, -0.114),
        (-0.104, -0.094),
        (-0.097, -0.078),
    ]
    guard = [
        (0.016, -0.048),
        (0.016, -0.086),
        (-0.084, -0.086),
        (-0.1, -0.048),
        (-0.092, -0.048),
        (-0.079, -0.079),
        (0.009, -0.079),
        (0.009, -0.048),
    ]
    parts = [
        g.slab(
            "Lower",
            [
                (-0.17, -0.009),
                (0.13, -0.009),
                (0.125, -0.035),
                (0.117, -0.062),
                (0.02, -0.062),
                (0.018, -0.048),
                (-0.135, -0.048),
                (-0.17, -0.03),
            ],
            0.048,
            black,
            bevel=0.002,
        ),
        g.slab(
            "WellLip", [(0.016, -0.057), (0.12, -0.057), (0.122, -0.067), (0.014, -0.067)], 0.052, black, bevel=0.0015
        ),
        g.slab("Grip", grip, 0.034, black, bevel=0.005),
        g.slab("TriggerGuard", guard, 0.013, black, bevel=0.0015),
        g.lathe("Selector", [(0.009, -0.029), (0.009, -0.025)], (0, -0.09, -0.028), metal, 12, axis="x"),
        g.lathe("MagRelease", [(0.007, 0.025), (0.007, 0.031)], (0, 0.03, -0.035), metal, 12, axis="x"),
    ]
    for x in (-1, 1):
        parts.append(
            g.slab(
                f"GripPanel{x}",
                [(-0.123, -0.058), (-0.157, -0.14), (-0.14, -0.155), (-0.116, -0.098), (-0.108, -0.068)],
                0.002,
                grey,
                x=x * 0.0175,
            )
        )
        for y, z in ((-0.155, 0.0), (0.11, 0.0), (-0.045, -0.035), (-0.003, -0.035)):
            parts.append(
                g.lathe(f"Pin{x}{y}", [(0.004, -0.0015), (0.004, 0.0015)], (x * 0.025, y, z), metal, 10, axis="x")
            )
    return parts


def precision_stock(m, receiver, metal, black, grey):
    """Fixed precision stock with cheek riser, adjustment wheel, sling slot and rubber recoil pad."""
    outline = [
        (-0.17, 0.04),
        (-0.3, 0.038),
        (-0.415, 0.032),
        (-0.42, -0.08),
        (-0.4, -0.088),
        (-0.33, -0.045),
        (-0.25, -0.032),
        (-0.2, -0.036),
        (-0.17, -0.03),
    ]
    stock = g.slab("Stock", outline, 0.044, grey, bevel=0.004)
    pieces = [
        g.slab("CheekRiser", g.rounded(-0.37, 0.046, -0.235, 0.064, 0.007), 0.04, black, bevel=0.003),
        g.slab(
            "RecoilPad",
            [(-0.413, 0.036), (-0.43, 0.036), (-0.434, -0.084), (-0.418, -0.092), (-0.4, -0.088)],
            0.05,
            black,
            bevel=0.004,
        ),
        g.lathe("RiserWheel", [(0.012, 0.022), (0.012, 0.03)], (0, -0.3, 0.03), metal, 16, axis="x"),
        g.slab("SlingSlot", g.rounded(-0.39, 0.0, -0.36, 0.01, 0.004), 0.002, black, x=0.0225),
    ]
    for y in (-0.33, -0.27):
        pieces.append(g.lathe(f"RiserPost{y}", [(0.005, 0.038), (0.005, 0.048)], (0, y, 0), metal, 10, axis="z"))
    m.join_into(stock, pieces)
    m.attach(stock, (0, -0.17, 0), receiver)


def scope_parts(m, receiver, metal, black, glass):
    """Turned 3-9x optic on two rings; the rear lens mount matches the picture-in-picture disc."""
    tube = [
        (0.017, -0.126),
        (0.019, -0.12),
        (0.019, -0.085),
        (0.016, -0.077),
        (0.0135, -0.06),
        (0.0135, 0.17),
        (0.016, 0.19),
        (0.025, 0.24),
        (0.026, 0.302),
        (0.0245, 0.308),
    ]
    optic = g.lathe("Optic", tube, (0, 0, 0.09), black, 24)
    knob = [(0.007, 0.0), (0.007, 0.022), (0.011, 0.023), (0.011, 0.035), (0.0095, 0.037)]
    knurled = m.material("GunMetalKnurled", m.GUN_METAL, metallic=0.8, roughness=0.45)
    pieces = [
        g.lathe("Saddle", [(0.016, 0.02), (0.016, 0.058)], (0, 0, 0.09), black, 16),
        g.lathe("Elevation", knob, (0, 0.039, 0.09), knurled, 16, axis="z"),
        g.lathe("Windage", knob, (0, 0.039, 0.09), knurled, 16, axis="x"),
        g.lathe("Parallax", [(r, -a) for r, a in knob], (0, 0.039, 0.09), knurled, 16, axis="x"),
    ]
    for y in (-0.048, 0.158):
        pieces += [
            g.lathe(f"Ring{y}", [(0.0165, y - 0.009), (0.0165, y + 0.009)], (0, 0, 0.09), metal, 20),
            g.slab(
                f"RingBase{y}",
                [(y - 0.013, 0.061), (y + 0.013, 0.061), (y + 0.009, 0.08), (y - 0.009, 0.08)],
                0.026,
                black,
                bevel=0.002,
            ),
            g.lathe(f"RingBolt{y}", [(0.004, 0.013), (0.004, 0.019)], (0, y, 0.068), metal, 8, axis="x"),
        ]
    m.join_into(optic, pieces)
    m.attach(optic, (0, 0.055, 0.09), receiver)
    g.lathe("OpticGlass", [(0.023, 0.3085), (0.023, 0.3095)], (0, 0, 0.09), glass, 24, parent=receiver)
    m.marker("ScopeLensMount", (0, -0.128, 0.09), parent=receiver)


def barrel_parts(m, receiver, metal, black):
    """Heavy stepped barrel with gas block, ported brake and a folded bipod."""
    run = [
        (0.018, 0.48),
        (0.018, 0.515),
        (0.0135, 0.52),
        (0.0135, 0.575),
        (0.018, 0.578),
        (0.018, 0.605),
        (0.0125, 0.608),
        (0.0125, 0.8),
        (0.011, 0.802),
    ]
    barrel = g.lathe("Barrel", run, (0, 0, BORE_Z), metal, 16)
    m.join_into(barrel, [g.lathe("GasTube", [(0.005, 0.5), (0.005, 0.59)], (0, 0, BORE_Z + 0.022), metal, 8)])
    m.attach(barrel, (0, 0.475, BORE_Z), receiver)
    brake = g.lathe(
        "MuzzleBrake", [(0.016, 0.796), (0.018, 0.8), (0.018, 0.862), (0.016, 0.866)], (0, 0, BORE_Z), metal, 12
    )
    ports = [g.lathe("Bore", [(0.007, 0.866), (0.007, 0.867)], (0, 0, BORE_Z), black, 12)]
    for x in (-1, 1):
        for i in range(3):
            y = 0.806 + i * 0.019
            ports.append(
                g.slab(
                    f"Port{x}{i}",
                    g.rounded(y, BORE_Z - 0.009, y + 0.012, BORE_Z + 0.009, 0.004),
                    0.002,
                    black,
                    x=x * 0.0175,
                )
            )
    m.join_into(brake, ports)
    m.attach(brake, (0, 0.831, BORE_Z), barrel)
    bipod = g.slab("Bipod", g.rounded(0.39, -0.03, 0.425, -0.015, 0.004), 0.05, metal, bevel=0.002)
    legs = []
    for x in (-1, 1):
        legs += [
            g.lathe(
                f"Leg{x}",
                [(0.006, 0.41), (0.006, 0.55), (0.0045, 0.555), (0.0045, 0.57)],
                (x * 0.022, 0, -0.036),
                black,
                10,
            ),
            g.slab(f"Foot{x}", g.rounded(0.565, -0.044, 0.585, -0.028, 0.004), 0.016, black, x=x * 0.022),
        ]
    m.join_into(bipod, legs)
    m.attach(bipod, (0, 0.407, -0.026), receiver)
    m.marker("Muzzle", (0, 0.868, BORE_Z), parent=receiver)


def moving_parts(m, receiver, metal, black, grey):
    """Magazine pivots at its feed lips; the charging handle travels with the bolt."""
    magazine = g.slab(
        "Magazine", [(0.028, -0.05), (0.104, -0.05), (0.108, -0.17), (0.03, -0.17)], 0.039, black, bevel=0.002
    )
    pieces = [
        g.slab(
            "MagBase", [(0.024, -0.168), (0.112, -0.168), (0.11, -0.181), (0.026, -0.181)], 0.045, metal, bevel=0.002
        )
    ]
    for i in range(3):
        z = -0.1 - i * 0.022
        pieces.append(g.slab(f"MagRib{i}", g.rounded(0.042, z, 0.092, z + 0.005, 0.002), 0.042, grey))
    m.join_into(magazine, pieces)
    m.attach(magazine, (0, 0.065, -0.065), receiver)
    magazine.rotation_euler.x = 0.08
    bolt = g.slab("Bolt", g.rounded(-0.025, 0.01, 0.055, 0.034, 0.003), 0.002, metal, x=0.0305)
    m.attach(bolt, (0.0305, 0.015, 0.022), receiver)
    knob = [(0.004, 0.03), (0.004, 0.048), (0.008, 0.05), (0.008, 0.062), (0.006, 0.064)]
    handle = g.lathe("ChargingHandle", knob, (0, -0.035, 0.025), black, 12, axis="x")
    m.attach(handle, (0.036, -0.035, 0.025), bolt)
    trigger = g.slab(
        "Trigger",
        [(-0.057, -0.048), (-0.051, -0.048), (-0.053, -0.062), (-0.061, -0.074), (-0.066, -0.071), (-0.059, -0.061)],
        0.006,
        metal,
    )
    m.attach(trigger, (0, -0.054, -0.05), receiver)


def build_talon_dmr(m) -> None:
    """Build from shared helpers supplied by build_models, keeping all runtime part names."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    grey = m.material("GreyPolymer", m.srgb("#5F6D68"), roughness=0.8)
    glass = m.material("OpticGlass", m.LENS, metallic=0.3, roughness=0.05)
    receiver = g.slab(
        "Receiver",
        [(-0.175, -0.01), (0.175, -0.01), (0.175, 0.048), (-0.158, 0.048), (-0.175, 0.036)],
        0.056,
        metal,
        bevel=0.002,
    )
    m.join_into(receiver, upper(metal, black, grey) + lower(metal, black, grey))
    precision_stock(m, receiver, metal, black, grey)
    scope_parts(m, receiver, metal, black, glass)
    barrel_parts(m, receiver, metal, black)
    moving_parts(m, receiver, metal, black, grey)
