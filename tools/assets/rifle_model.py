"""AR-7 rifle: shaped upper and lower receiver, free-float handguard, curved magazine, turned scope.

Static parts join into `Receiver`. `Magazine`, `Bolt`, `Barrel` (with `MuzzleBrake`)
and `OpticGlass` stay separate nodes for code. Gun forward is Blender +Y.
"""

import math

import gun_parts as g

AXIS_Z = 0.016  # barrel and handguard centre height


def upper(m, metal, black):
    """Flat-top upper with a recessed ejection port, brass deflector and full-length rail."""
    receiver = g.slab(
        "Receiver",
        [(-0.17, -0.004), (0.17, -0.004), (0.17, 0.046), (-0.152, 0.046), (-0.17, 0.034)],
        0.05,
        metal,
        bevel=0.002,
    )
    g.cut(receiver, [g.slab("PortCut", g.rounded(-0.03, 0.002, 0.065, 0.034, 0.004), 0.018, metal, x=0.028)])
    parts = [
        g.slab("RailBase", [(-0.168, 0.046), (0.475, 0.046), (0.475, 0.051), (-0.168, 0.051)], 0.024, black),
        g.slab("RailTeeth", g.teeth(-0.165, 0.47, 0.051, 0.059), 0.021, black),
        g.slab(
            "Deflector",
            [(-0.07, 0.0), (-0.035, 0.0), (-0.035, 0.03), (-0.05, 0.042), (-0.07, 0.042)],
            0.008,
            metal,
            x=0.027,
            bevel=0.002,
        ),
        g.lathe("DustCoverHinge", [(0.002, -0.03), (0.002, 0.065)], (0.026, 0, 0.001), black, 10),
        g.lathe(
            "ForwardAssist",
            [(0.009, -0.11), (0.009, -0.07), (0.0065, -0.065), (0.0065, -0.05)],
            (0.03, 0.0, 0.028),
            metal,
            segments=16,
        ),
        g.slab("BoltRelease", [(-0.13, 0.0), (-0.1, 0.0), (-0.1, 0.012), (-0.13, 0.018)], 0.004, metal, x=-0.027),
        g.slab(
            "ChargeHandle",
            [(-0.205, 0.035), (-0.165, 0.035), (-0.165, 0.046), (-0.205, 0.046)],
            0.036,
            black,
            bevel=0.002,
        ),
        g.slab("ChargeLatch", [(-0.2, 0.035), (-0.178, 0.035), (-0.175, 0.045), (-0.2, 0.046)], 0.008, black, x=-0.022),
    ]
    for x in (-1, 1):
        parts.append(g.lathe(f"ChargeWing{x}", [(0.006, -0.205), (0.006, -0.185)], (x * 0.022, 0.0, 0.04), black, 8))
    m.join_into(receiver, parts)
    return receiver


def lower(m, metal, black):
    """Lower with flared mag well, trigger guard, trigger, pistol grip, selector and pins."""
    grip = [
        (-0.09, -0.048),
        (-0.122, -0.048),
        (-0.168, -0.152),
        (-0.164, -0.166),
        (-0.128, -0.166),
        (-0.118, -0.152),
        (-0.113, -0.13),
        (-0.104, -0.114),
        (-0.1, -0.094),
        (-0.092, -0.078),
    ]
    guard = [
        (0.016, -0.05),
        (0.016, -0.086),
        (-0.082, -0.086),
        (-0.096, -0.05),
        (-0.088, -0.05),
        (-0.077, -0.079),
        (0.009, -0.079),
        (0.009, -0.05),
    ]
    parts = [
        g.slab(
            "Lower",
            [
                (-0.168, -0.004),
                (0.122, -0.004),
                (0.122, -0.026),
                (0.114, -0.09),
                (0.02, -0.09),
                (0.016, -0.05),
                (-0.13, -0.05),
                (-0.168, -0.028),
            ],
            0.046,
            black,
            bevel=0.002,
        ),
        g.slab(
            "WellFlare", [(0.018, -0.084), (0.118, -0.084), (0.12, -0.094), (0.016, -0.094)], 0.05, black, bevel=0.002
        ),
        g.slab("Grip", grip, 0.032, black, bevel=0.005),
        g.slab("TriggerGuard", guard, 0.012, black, bevel=0.0015),
        g.slab(
            "Trigger",
            [(-0.035, -0.05), (-0.029, -0.05), (-0.031, -0.064), (-0.039, -0.076), (-0.044, -0.073), (-0.037, -0.063)],
            0.006,
            metal,
        ),
        g.lathe("MagRelease", [(0.007, 0.024), (0.007, 0.03)], (0.0, 0.03, -0.03), metal, 12, axis="x"),
    ]
    for side in (-1, 1):
        parts.append(
            g.slab(
                f"GripPanel{side}",
                [(-0.118, -0.06), (-0.152, -0.14), (-0.135, -0.155), (-0.112, -0.1), (-0.104, -0.07)],
                0.002,
                m.material("GunMetalKnurled", m.GUN_METAL, metallic=0.8, roughness=0.45),
                x=side * 0.0165,
            )
        )
        for y, z in ((-0.15, 0.0), (0.105, 0.0), (-0.045, -0.035), (-0.003, -0.035)):
            parts.append(
                g.lathe(f"Pin{side}{y}", [(0.004, -0.0015), (0.004, 0.0015)], (side * 0.024, y, z), metal, 10, axis="x")
            )
    parts.append(g.lathe("Selector", [(0.009, -0.004), (0.009, 0.0)], (-0.0235, -0.09, -0.028), metal, 12, axis="x"))
    parts.append(
        g.slab(
            "SelectorLever",
            [(-0.093, -0.03), (-0.068, -0.024), (-0.068, -0.02), (-0.09, -0.024)],
            0.003,
            metal,
            x=-0.028,
        )
    )
    return parts


def handguard(m, black, tan):
    """Eight-sided free-float handguard with M-slots, a front sight and the exposed barrel."""
    flat = math.pi / 8
    parts = [
        g.lathe(
            "Handguard",
            [(0.03, 0.17), (0.033, 0.175), (0.033, 0.465), (0.03, 0.475)],
            (0, 0, AXIS_Z),
            tan,
            8,
            turn=flat,
        ),
        g.lathe("BarrelNut", [(0.026, 0.165), (0.026, 0.172)], (0, 0, AXIS_Z), black, 16),
        g.slab("FrontSight", [(0.44, 0.059), (0.47, 0.059), (0.47, 0.068), (0.445, 0.068)], 0.02, black, bevel=0.001),
        g.slab(
            "RearSight", [(-0.15, 0.059), (-0.12, 0.059), (-0.125, 0.068), (-0.15, 0.068)], 0.02, black, bevel=0.001
        ),
    ]
    cuts = [g.lathe("GuardCore", [(0.025, 0.165), (0.025, 0.48)], (0, 0, AXIS_Z), tan, 8, turn=flat)]
    for i in range(4):
        y = 0.215 + i * 0.062
        cuts.append(g.slab(f"SlotCut{i}", g.rounded(y, 0.009, y + 0.032, 0.023, 0.006), 0.08, tan))
    g.cut(parts[0], cuts)
    parts.append(g.lathe("InnerBarrel", [(0.009, 0.17), (0.009, 0.475)], (0, 0, AXIS_Z), black, 12))
    return parts


def stock(m, metal, black, tan):
    """Buffer tube, castle nut, six-position stock with cheek line, lever and rubber pad."""
    return [
        g.lathe("BufferTube", [(0.0155, -0.17), (0.0155, -0.39)], (0, 0, 0.018), metal, 20),
        g.lathe("CastleNut", [(0.02, -0.175), (0.02, -0.188)], (0, 0, 0.018), black, 12),
        g.slab(
            "Stock",
            [
                (-0.255, 0.04),
                (-0.395, 0.044),
                (-0.4, -0.072),
                (-0.385, -0.08),
                (-0.35, -0.035),
                (-0.3, -0.01),
                (-0.255, -0.004),
            ],
            0.042,
            tan,
            bevel=0.004,
        ),
        g.slab("StockLever", [(-0.33, -0.02), (-0.27, -0.008), (-0.27, -0.002), (-0.33, -0.012)], 0.012, black),
        g.slab(
            "ButtPad",
            [(-0.398, 0.046), (-0.414, 0.046), (-0.418, -0.075), (-0.403, -0.084), (-0.386, -0.08)],
            0.046,
            black,
            bevel=0.004,
        ),
        g.lathe("SlingCup", [(0.007, 0.0), (0.007, 0.004)], (0.022, -0.29, 0.015), metal, 12, axis="x"),
    ]


def scope(m, metal, black, glass, receiver):
    """Turned 1-4x scope on two rings, with knurled turrets and a sunshade."""
    tube = [
        (0.017, -0.126),
        (0.019, -0.12),
        (0.019, -0.092),
        (0.016, -0.084),
        (0.0125, -0.066),
        (0.0125, 0.075),
        (0.0145, 0.09),
        (0.021, 0.14),
        (0.021, 0.186),
        (0.0195, 0.19),
    ]
    parts = [g.lathe("ScopeTube", tube, (0, 0, 0.09), black, 24)]
    parts.append(g.lathe("Saddle", [(0.0155, -0.012), (0.0155, 0.024)], (0, 0, 0.09), black, 16))
    for name, axis, at in (("TurretTop", "z", (0, 0.006, 0.09)), ("TurretSide", "x", (0, 0.006, 0.09))):
        knob = [(0.007, 0.0), (0.007, 0.022), (0.0105, 0.023), (0.0105, 0.034), (0.0095, 0.036)]
        parts.append(
            g.lathe(
                name, knob, at, m.material("GunMetalKnurled", m.GUN_METAL, metallic=0.8, roughness=0.45), 16, axis=axis
            )
        )
    for y in (-0.045, 0.05):
        parts.append(g.lathe(f"Ring{y}", [(0.0158, y - 0.008), (0.0158, y + 0.008)], (0, 0, 0.09), black, 20))
        parts.append(
            g.slab(
                f"RingBase{y}",
                [(y - 0.012, 0.059), (y + 0.012, 0.059), (y + 0.008, 0.08), (y - 0.008, 0.08)],
                0.024,
                black,
                bevel=0.002,
            )
        )
        parts.append(g.lathe(f"RingBolt{y}", [(0.004, 0.012), (0.004, 0.018)], (0, y, 0.066), metal, 8, axis="x"))
    parts.append(g.lathe("EyeLens", [(0.016, -0.1265), (0.016, -0.1255)], (0, 0, 0.09), glass, 20))
    m.join_into(receiver, parts)
    g.lathe("OpticGlass", [(0.018, 0.1902), (0.018, 0.1912)], (0, 0, 0.09), glass, 20, parent=receiver)


def magazine(m, black, receiver):
    """Curved 30-round box magazine with side ribs; the origin sits at its feed lip."""
    front = [(0.104, -0.03), (0.106, -0.09), (0.114, -0.14), (0.128, -0.185)]
    rear = [(0.058, -0.185), (0.044, -0.14), (0.034, -0.09), (0.032, -0.03)]
    mag = g.slab("Magazine", front + rear, 0.034, black, bevel=0.002)
    parts = [
        g.slab("MagBase", [(0.126, -0.183), (0.135, -0.198), (0.05, -0.198), (0.056, -0.183)], 0.04, black, bevel=0.002)
    ]
    rib = [(0.094, -0.05), (0.098, -0.1), (0.106, -0.15), (0.096, -0.155), (0.088, -0.105), (0.084, -0.05)]
    parts += [g.slab("MagRib", rib, 0.037, black), g.slab("MagRib2", [(y - 0.03, z) for y, z in rib], 0.037, black)]
    m.join_into(mag, parts)
    m.attach(mag, (0, 0.068, -0.03), receiver)


def barrel(m, metal, black, receiver):
    """Barrel node with a gas block step and a slotted flash hider as `MuzzleBrake`."""
    run = [(0.0095, 0.0), (0.0095, 0.03), (0.0105, 0.03), (0.0105, 0.05), (0.008, 0.055), (0.008, 0.11)]
    pipe = g.lathe("Barrel", run, (0, 0.475, AXIS_Z), metal, 16)
    m.attach(pipe, (0, 0.475, AXIS_Z), receiver)
    hider = [(0.01, 0.108), (0.011, 0.112), (0.011, 0.145), (0.0095, 0.15)]
    brake = g.lathe("MuzzleBrake", hider, (0, 0.475, AXIS_Z), black, 16)
    g.cut(
        brake,
        [
            g.lathe("BoreCut", [(0.0045, 0.575), (0.0045, 0.635)], (0, 0, AXIS_Z), black, 16),
            g.slab("BrakePorts", g.rounded(0.594, AXIS_Z - 0.003, 0.615, AXIS_Z + 0.003, 0.002), 0.03, black),
        ],
    )
    m.attach(brake, (0, 0.583, AXIS_Z), pipe)


def build(m) -> None:
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    tan = m.material("Tan", m.TAN, roughness=0.8)
    glass = m.material("OpticGlass", m.LENS, metallic=0.3, roughness=0.05)
    receiver = upper(m, metal, black)
    m.join_into(receiver, lower(m, metal, black) + handguard(m, black, tan) + stock(m, metal, black, tan))
    scope(m, metal, black, glass, receiver)
    magazine(m, black, receiver)
    barrel(m, metal, black, receiver)
    bolt = g.slab("Bolt", g.rounded(-0.015, 0.012, 0.045, 0.026, 0.003), 0.002, metal, x=0.022)
    m.attach(bolt, (0.0275, 0.015, 0.019), receiver)
    m.marker("Muzzle", (0, 0.627, AXIS_Z), parent=receiver)
    for side in (-1, 1):
        inlay = g.slab("Inlay", g.rounded(-0.145, 0.038, 0.14, 0.040, 0.001), 0.001, metal, x=side * 0.0252)
        m.join_into(receiver, [g.mark_inlay(inlay)])
