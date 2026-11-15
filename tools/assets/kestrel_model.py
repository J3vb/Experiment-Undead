"""Kestrel SMG: shaped receiver, eight-sided fore-end, folding skeleton stock and serviceable moving parts.

Static parts join into `Receiver`. Code needs `Magazine`, `Bolt` (with `ChargingHandle`),
`Barrel`, `FoldingStock`, `IronSights`, `Grip`, `Trigger` and the `Muzzle` marker.
"""

import math

import gun_parts as g

BORE_Z = 0.008


def body(m, metal, black, olive):
    """Upper with ejection port and charging slot, lower with flared mag well, fore-end and rail."""
    receiver = g.slab(
        "Receiver",
        [(-0.14, -0.01), (0.13, -0.01), (0.13, 0.022), (0.115, 0.034), (-0.125, 0.034), (-0.14, 0.024)],
        0.05,
        metal,
        bevel=0.002,
    )
    flat = math.pi / 8
    parts = [
        g.slab(
            "Lower",
            [
                (-0.135, -0.009),
                (0.125, -0.009),
                (0.12, -0.035),
                (0.092, -0.045),
                (0.09, -0.07),
                (0.02, -0.07),
                (0.018, -0.045),
                (-0.115, -0.045),
                (-0.135, -0.03),
            ],
            0.046,
            black,
            bevel=0.002,
        ),
        g.slab(
            "WellLip", [(0.018, -0.066), (0.092, -0.066), (0.094, -0.075), (0.016, -0.075)], 0.05, black, bevel=0.0015
        ),
        g.lathe(
            "Handguard",
            [(0.028, 0.128), (0.031, 0.133), (0.031, 0.252), (0.028, 0.258)],
            (0, 0, BORE_Z),
            olive,
            8,
            turn=flat,
        ),
        g.slab("RailBase", [(-0.125, 0.034), (0.25, 0.034), (0.25, 0.039), (-0.125, 0.039)], 0.024, black),
        g.slab("RailTeeth", g.teeth(-0.122, 0.245, 0.039, 0.046), 0.021, black),
        g.slab("EjectionPort", g.rounded(-0.012, 0.0, 0.064, 0.027, 0.004), 0.002, black, x=0.026),
        g.slab("HandleSlot", [(-0.095, 0.014), (-0.02, 0.014), (-0.02, 0.022), (-0.095, 0.022)], 0.002, black, x=0.026),
        g.lathe("MagRelease", [(0.006, 0.023), (0.006, 0.029)], (0, 0.1, -0.035), metal, 12, axis="x"),
        g.lathe("Selector", [(0.008, -0.027), (0.008, -0.023)], (0, -0.07, -0.025), metal, 12, axis="x"),
        g.slab(
            "SelectorLever",
            [(-0.075, -0.027), (-0.05, -0.02), (-0.05, -0.016), (-0.073, -0.022)],
            0.003,
            metal,
            x=-0.028,
        ),
    ]
    side = 0.031 * math.cos(flat) + 0.0004
    for i in range(3):
        y = 0.145 + i * 0.036
        for x in (-1, 1):
            parts.append(g.slab(f"Slot{x}{i}", g.rounded(y, 0.001, y + 0.024, 0.015, 0.005), 0.002, black, x=x * side))
    for x in (-1, 1):
        for y, z in ((-0.12, 0.0), (0.105, 0.0), (-0.03, -0.035)):
            parts.append(
                g.lathe(f"Pin{x}{y}", [(0.0035, -0.0015), (0.0035, 0.0015)], (x * 0.024, y, z), metal, 10, axis="x")
            )
    m.join_into(receiver, parts)
    return receiver


def lower_controls(m, receiver, metal, black, olive):
    """Trigger guard joins the body; grip and trigger keep their own pivots."""
    guard = [
        (0.012, -0.045),
        (0.012, -0.08),
        (-0.062, -0.08),
        (-0.075, -0.045),
        (-0.067, -0.045),
        (-0.056, -0.073),
        (0.005, -0.073),
        (0.005, -0.045),
    ]
    m.join_into(receiver, [g.slab("TriggerGuard", guard, 0.012, black, bevel=0.0015)])
    grip_shape = [
        (-0.075, -0.044),
        (-0.107, -0.044),
        (-0.148, -0.142),
        (-0.144, -0.156),
        (-0.11, -0.156),
        (-0.1, -0.142),
        (-0.095, -0.12),
        (-0.088, -0.105),
        (-0.084, -0.085),
        (-0.078, -0.068),
    ]
    grip = g.slab("Grip", grip_shape, 0.032, olive, bevel=0.005)
    panels = [
        g.slab(
            f"GripPanel{x}",
            [(-0.103, -0.055), (-0.138, -0.14), (-0.12, -0.148), (-0.096, -0.09), (-0.088, -0.062)],
            0.002,
            black,
            x=x * 0.0165,
        )
        for x in (-1, 1)
    ]
    m.join_into(grip, panels)
    m.attach(grip, (0, -0.09, -0.045), receiver)
    trigger = g.slab(
        "Trigger",
        [(-0.03, -0.045), (-0.024, -0.045), (-0.026, -0.058), (-0.034, -0.069), (-0.039, -0.066), (-0.032, -0.057)],
        0.006,
        metal,
    )
    m.attach(trigger, (0, -0.028, -0.047), receiver)


def stock(m, receiver, metal, black, olive):
    """Skeleton stock folding on a real hinge pivot, with cheek rest and rubber pad."""
    hinge_at = (0, -0.145, -0.006)
    folding = g.lathe("FoldingStock", [(0.016, -0.03), (0.016, 0.03)], hinge_at, metal, 16, axis="z")
    parts = [
        g.slab(
            "ButtFrame",
            [(-0.325, 0.032), (-0.345, 0.032), (-0.35, -0.072), (-0.325, -0.066)],
            0.045,
            metal,
            bevel=0.003,
        ),
        g.slab(
            "ButtPad", [(-0.345, 0.034), (-0.36, 0.034), (-0.364, -0.075), (-0.349, -0.077)], 0.049, black, bevel=0.003
        ),
        g.slab("CheekRest", g.rounded(-0.31, 0.012, -0.2, 0.03, 0.006), 0.042, olive, bevel=0.003),
    ]
    for x in (-1, 1):
        parts += [
            g.slab(
                f"TopStrut{x}",
                [(-0.15, 0.002), (-0.33, 0.016), (-0.33, 0.026), (-0.15, 0.012)],
                0.008,
                metal,
                x=x * 0.018,
                bevel=0.0015,
            ),
            g.slab(
                f"LowStrut{x}",
                [(-0.155, -0.018), (-0.33, -0.06), (-0.33, -0.05), (-0.15, -0.008)],
                0.008,
                metal,
                x=x * 0.018,
                bevel=0.0015,
            ),
        ]
    m.join_into(folding, parts)
    m.attach(folding, hinge_at, receiver)


def sights(m, receiver, metal, black):
    """Flip-up aperture rear sight and a hooded front post, one node so code can find them."""
    rear = g.slab(
        "IronSights", [(-0.12, 0.046), (-0.098, 0.046), (-0.1, 0.058), (-0.118, 0.058)], 0.03, black, bevel=0.0015
    )
    parts = [
        g.lathe("Aperture", [(0.006, -0.112), (0.006, -0.106)], (0, 0, 0.064), metal, 12),
        g.slab(
            "FrontBase", [(0.232, 0.046), (0.252, 0.046), (0.25, 0.054), (0.234, 0.054)], 0.026, black, bevel=0.0015
        ),
        g.slab("FrontPost", [(0.24, 0.054), (0.244, 0.054), (0.244, 0.068), (0.24, 0.068)], 0.004, metal),
    ]
    for x in (-1, 1):
        parts.append(
            g.slab(
                f"FrontGuard{x}",
                [(0.234, 0.054), (0.25, 0.054), (0.248, 0.07), (0.236, 0.07)],
                0.004,
                black,
                x=x * 0.011,
            )
        )
    m.join_into(rear, parts)
    m.attach(rear, (0, -0.109, 0.046), receiver)


def moving_parts(m, receiver, metal, black, olive):
    """Magazine origin at the feed lip, charging handle parented to its sliding bolt."""
    magazine = g.slab(
        "Magazine", [(0.027, -0.05), (0.083, -0.05), (0.086, -0.225), (0.024, -0.225)], 0.03, black, bevel=0.002
    )
    parts = [
        g.slab("MagBase", [(0.02, -0.223), (0.092, -0.223), (0.09, -0.237), (0.022, -0.237)], 0.036, olive, bevel=0.002)
    ]
    for i in range(4):
        parts.append(
            g.lathe(
                f"Witness{i}", [(0.003, 0.0145), (0.003, 0.0155)], (0, 0.045, -0.11 - i * 0.025), metal, 8, axis="x"
            )
        )
    m.join_into(magazine, parts)
    m.attach(magazine, (0, 0.055, -0.065), receiver)
    bolt = g.slab("Bolt", g.rounded(-0.005, 0.004, 0.05, 0.023, 0.003), 0.002, metal, x=0.0275)
    m.attach(bolt, (0.0275, 0.022, 0.013), receiver)
    knob = [(0.004, 0.026), (0.004, 0.036), (0.007, 0.038), (0.007, 0.046), (0.005, 0.048)]
    handle = g.lathe("ChargingHandle", knob, (0, -0.06, 0.018), black, 12, axis="x")
    m.attach(handle, (0.03, -0.06, 0.018), bolt)


def barrel(m, receiver, metal, black):
    """Short barrel with a fluted muzzle cap."""
    run = [(0.011, 0.0), (0.011, 0.085)]
    pipe = g.lathe("Barrel", run, (0, 0.25, BORE_Z), metal, 16)
    cap = [(0.012, 0.08)]
    for i in range(4):
        y = 0.085 + i * 0.006
        cap += [(0.0145, y), (0.0145, y + 0.004), (0.013, y + 0.0045), (0.013, y + 0.006)]
    cap += [(0.0145, 0.112), (0.006, 0.113)]
    m.join_into(pipe, [g.lathe("MuzzleCap", cap, (0, 0.25, BORE_Z), black, 16)])
    m.attach(pipe, (0, 0.25, BORE_Z), receiver)
    m.marker("Muzzle", (0, 0.364, BORE_Z), parent=receiver)


def build_kestrel_smg(m):
    """Build in metres along Blender +Y (Godot -Z), keeping the shared animation nodes."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    olive = m.material("OlivePolymer", m.srgb("#5F6D68"), roughness=0.85)
    receiver = body(m, metal, black, olive)
    lower_controls(m, receiver, metal, black, olive)
    stock(m, receiver, metal, black, olive)
    sights(m, receiver, metal, black)
    moving_parts(m, receiver, metal, black, olive)
    barrel(m, receiver, metal, black)
