"""Brenner Trench pump shotgun: humpback receiver, vented heat shield, walnut stock and grooved pump.

Static parts join into `Receiver`. The pump is the `Bolt` node so the viewmodel racks it;
there is no Magazine (shells load one by one through the loading port).
"""

import gun_parts as g

BORE_Z = 0.03
TUBE_Z = -0.005


def receiver(m, metal, black):
    """Receiver with ejection and loading ports, trigger group and cross-bolt safety."""
    body = g.slab(
        "Receiver",
        [(-0.085, -0.02), (0.125, -0.02), (0.125, 0.041), (0.105, 0.047), (-0.035, 0.047), (-0.085, 0.026)],
        0.05,
        metal,
        bevel=0.002,
    )
    guard = [
        (0.012, -0.02),
        (0.012, -0.058),
        (-0.062, -0.058),
        (-0.078, -0.02),
        (-0.07, -0.02),
        (-0.058, -0.051),
        (0.005, -0.051),
        (0.005, -0.02),
    ]
    parts = [
        g.slab("EjectionPort", g.rounded(0.0, 0.004, 0.075, 0.034, 0.004), 0.002, black, x=0.026),
        g.slab("LoadingPort", [(0.02, -0.022), (0.11, -0.022), (0.11, -0.019), (0.02, -0.019)], 0.034, black),
        g.slab("TriggerPlate", [(-0.08, -0.02), (0.02, -0.02), (0.02, -0.026), (-0.08, -0.026)], 0.03, black),
        g.slab("TriggerGuard", guard, 0.012, black, bevel=0.0015),
        g.slab(
            "Trigger",
            [(-0.03, -0.026), (-0.024, -0.026), (-0.026, -0.04), (-0.034, -0.05), (-0.038, -0.047), (-0.032, -0.038)],
            0.006,
            metal,
        ),
        g.lathe("Safety", [(0.005, -0.03), (0.005, 0.03)], (0.0, 0.01, -0.023), black, 12, axis="x"),
        g.lathe("ActionRelease", [(0.004, -0.031), (0.004, -0.025)], (0.0, -0.07, -0.012), metal, 10, axis="x"),
    ]
    for side in (-1, 1):
        for y in (-0.06, 0.1):
            parts.append(
                g.lathe(
                    f"Pin{side}{y}", [(0.004, -0.0015), (0.004, 0.0015)], (side * 0.025, y, 0.0), metal, 10, axis="x"
                )
            )
    m.join_into(body, parts)
    return body


def stock(metal, black, wood):
    """Walnut stock with a slim wrist, comb and rubber butt pad."""
    outline = [
        (-0.085, 0.03),
        (-0.085, -0.02),
        (-0.105, -0.032),
        (-0.145, -0.058),
        (-0.2, -0.078),
        (-0.3, -0.1),
        (-0.372, -0.11),
        (-0.372, 0.018),
        (-0.3, 0.02),
        (-0.18, 0.018),
        (-0.12, 0.022),
    ]
    return [
        g.slab("Stock", outline, 0.042, wood, bevel=0.006),
        g.slab("ButtPad", [(-0.37, 0.02), (-0.388, 0.022), (-0.39, -0.11), (-0.37, -0.112)], 0.046, black, bevel=0.004),
        g.lathe("Swivel", [(0.006, -0.105), (0.006, -0.085)], (0, -0.31, 0), metal, 10, axis="z"),
    ]


def barrel(metal, black):
    """Barrel and magazine tube, band, bead sight, bayonet lug and a perforated heat shield."""
    parts = [
        g.lathe(
            "Barrel", [(0.0125, 0.125), (0.0115, 0.13), (0.0115, 0.62), (0.0105, 0.623)], (0, 0, BORE_Z), metal, 20
        ),
        g.lathe("MagTube", [(0.011, 0.125), (0.011, 0.52)], (0, 0, TUBE_Z), metal, 16),
        g.lathe(
            "TubeCap",
            [
                (0.012, 0.518),
                (0.0135, 0.522),
                (0.0135, 0.53),
                (0.0125, 0.532),
                (0.0135, 0.534),
                (0.0135, 0.542),
                (0.011, 0.548),
            ],
            (0, 0, TUBE_Z),
            black,
            16,
        ),
        g.slab("BarrelBand", g.rounded(0.495, -0.018, 0.515, 0.044, 0.006), 0.03, black, bevel=0.002),
        g.slab("BayonetLug", [(0.56, 0.013), (0.6, 0.013), (0.6, 0.019), (0.56, 0.019)], 0.008, black, bevel=0.001),
        g.lathe(
            "Bead", [(0.0025, 0.0), (0.0025, 0.004), (0.0015, 0.006)], (0, 0.612, BORE_Z + 0.011), metal, 8, axis="z"
        ),
        g.slab(
            "Shield",
            [(0.14, 0.019), (0.47, 0.019), (0.47, 0.042), (0.46, 0.045), (0.15, 0.045), (0.14, 0.04)],
            0.036,
            black,
            bevel=0.002,
        ),
    ]
    for side in (-1, 1):
        for i in range(7):
            y = 0.165 + i * 0.042
            parts.append(
                g.slab(f"Hole{side}{i}", g.rounded(y, 0.027, y + 0.026, 0.045, 0.006), 0.002, metal, x=side * 0.018)
            )
    for i in range(7):
        y = 0.17 + i * 0.042
        parts.append(g.lathe(f"TopHole{i}", [(0.004, 0.0445), (0.004, 0.0455)], (0, y + 0.008, 0), metal, 10, axis="z"))
    return parts


def pump(m, black, wood, body):
    """Grooved walnut pump on the tube, with the action bars that run back into the receiver."""
    profile = [(0.019, 0.19), (0.0225, 0.196)]
    for i in range(9):
        y = 0.2 + i * 0.014
        profile += [(0.0225, y + 0.009), (0.0205, y + 0.01), (0.0205, y + 0.013), (0.0225, y + 0.014)]
    profile += [(0.0225, 0.33), (0.019, 0.336)]
    grip = g.lathe("Bolt", profile, (0, 0, TUBE_Z), wood, 20)
    bars = [
        g.slab(
            f"ActionBar{s}", [(0.1, -0.012), (0.2, -0.012), (0.2, -0.004), (0.1, -0.004)], 0.002, black, x=s * 0.0125
        )
        for s in (-1, 1)
    ]
    m.join_into(grip, bars)
    m.attach(grip, (0, 0.26, TUBE_Z), body)


def build(m) -> None:
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    wood = m.material("Wood", m.WOOD, roughness=0.7)
    body = receiver(m, metal, black)
    m.join_into(body, stock(metal, black, wood) + barrel(metal, black))
    pump(m, black, wood, body)
    m.marker("Muzzle", (0, 0.625, BORE_Z), parent=body)
