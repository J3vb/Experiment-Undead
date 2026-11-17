"""Concept blockout: Halcyon Labs Sublevel, the Night Supervisor fused to the cold tank array.

Re-render: blender -b -P tools/concepts/halcyon_sublevel.py
Brief: docs/design/concepts/act1/halcyon_sublevel.md
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import blockout as b

BOSS = (0, 6.8)
SHOTS = {
    "overview": ((-16, -20, 17), (0, 1.5, 1), 50),
    "player": ((0, -9.6, 1.7), (0, 6.5, 2.6), 80),
    "boss": ((-1.6, 0.8, 1.7), (0, 6.4, 2.4), 80),
}


def room():
    """24 x 24 m hall, 7 m high. Returns the parts hidden in the overview."""
    wall = b.material(b.WALL)
    b.box("Floor", (0, 0, -0.3), (24, 24, 0.3), b.material(b.WET_FLOOR, rough=0.55, wet=True), bevel=0)
    b.box("WallN", (0, 12.2, 0), (24.8, 0.4, 7), wall)
    b.box("WallE", (12.2, 0, 0), (0.4, 24, 7), wall)
    hidden = [
        b.box("Ceiling", (0, 0, 7), (24.8, 24.8, 0.3), b.material(b.TRIM), bevel=0),
        b.box("WallS", (0, -12.2, 0), (24.8, 0.4, 7), wall),
        b.box("WallW", (-12.2, 0, 0), (0.4, 24, 7), wall),
    ]
    trim = b.material(b.TRIM)
    b.box("TrimN", (0, 11.97, 1.3), (24, 0.06, 0.15), trim)
    b.box("TrimE", (11.97, 0, 1.3), (0.06, 24, 0.15), trim)
    for x in (-7, 7):
        for y in (-4, 2.5):
            b.box("Pillar", (x, y, 0), (0.9, 0.9, 7), b.material(b.CONCRETE))
    return hidden


def tank(x, y, glow):
    """One 5 m cold tank with a window band where Fenlight has grown in."""
    steel = b.material(b.PIPE, rough=0.4, metal=0.8)
    b.box("TankBase", (x, y, 0), (2.3, 2.3, 0.3), b.material(b.TRIM))
    b.cylinder("Tank", (x, y, 0.3), 1.0, 4.7, steel)
    b.cylinder("TankWindow", (x, y, 2.0), 1.03, 1.0, b.material(b.BIO_GREEN, rough=0.2, glow=glow))
    b.tube("TankRiser", (x, y, 5.0), (x, y, 5.9), 0.14, steel)


def tank_array():
    """The landmark: two rows of cold tanks under one coolant manifold, a gap where the boss sits."""
    for x in (-8.4, -6.0, -3.6, 3.6, 6.0, 8.4):
        tank(x, 8.4, 1.2)
    for x in (-7.2, -4.8, -2.4, 0, 2.4, 4.8, 7.2):
        tank(x, 10.6, 0.5)
    steel = b.material(b.PIPE, rough=0.4, metal=0.8)
    b.tube("Manifold", (-9.4, 8.4, 5.9), (9.4, 8.4, 5.9), 0.3, steel)
    b.tube("ManifoldBack", (-8.2, 10.6, 5.9), (8.2, 10.6, 5.9), 0.3, steel)


def coolant_lines():
    """The cold tool: frosted coolant mains with a red burst valve on each pillar."""
    frost = b.material(b.FLUORESCENT, rough=0.5)
    valve = b.material(b.ALARM, rough=0.5, glow=0.6)
    for x in (-7, 7):
        b.tube("CoolantMain", (x, -11.9, 4.6), (x, 8.4, 4.6), 0.2, frost)
        b.tube("CoolantFeed", (x, 8.4, 4.6), (x, 8.4, 5.9), 0.2, frost)
        side = -0.62 if x > 0 else 0.62
        for y in (-4, 2.5):
            b.tube("CoolantDrop", (x + side, y, 4.6), (x + side, y, 1.2), 0.14, frost)
            b.tube("CoolantElbow", (x, y, 4.6), (x + side, y, 4.6), 0.14, frost)
            b.cylinder("BurstValve", (x + side * 1.35, y, 1.5), 0.3, 0.1, valve, rot=(0, 90, 0))
    b.tube("CoolantCross", (-7, 2.5, 4.6), (7, 2.5, 4.6), 0.2, frost)


def night_supervisor():
    """Placeholder boss, 4 m: a wide hunched torso growing out of a split tank, one arm all pipe."""
    x, y = BOSS
    coat, steel = b.material(b.LAB_COAT), b.material(b.PIPE, rough=0.4, metal=0.8)
    flesh, seam = b.material(b.DARK_SKIN), b.material(b.BIO_GREEN, glow=9)
    b.cylinder("SplitTank", (x, y + 0.2, 0), 1.3, 1.4, steel, top=1.05)
    b.box("Torso", (x, y, 1.3), (1.5, 0.9, 1.5), coat, rot=(12, 0, 0), bevel=0.08)
    b.box("Shoulders", (x, y - 0.3, 2.65), (2.3, 1.0, 0.65), coat, rot=(12, 0, 0), bevel=0.12)
    b.cylinder("BackTank", (x + 0.7, y + 0.5, 2.5), 0.5, 1.5, steel, rot=(0, 14, 0))
    b.ball("Head", (x - 0.15, y - 0.85, 3.3), 0.3, b.material(b.HEAD))
    for side in (-0.11, 0.11):
        b.ball("Eye", (x - 0.15 + side, y - 1.12, 3.33), 0.05, seam)
    b.tube("ArmUpperL", (x - 1.15, y - 0.4, 3.0), (x - 2.3, y - 1.3, 1.9), 0.22, flesh)
    b.tube("ArmLowerL", (x - 2.3, y - 1.3, 1.9), (x - 2.5, y - 2.4, 0.15), 0.17, flesh)
    b.tube("PipeArmR", (x + 1.15, y - 0.4, 3.0), (x + 2.7, y + 0.5, 3.7), 0.2, steel)
    b.tube("PipeArmR2", (x + 2.7, y + 0.5, 3.7), (3.6, 8.4, 4.4), 0.2, steel)
    for sx, kink in ((-0.42, 0.14), (0, -0.12), (0.42, 0.1)):
        b.tube("Seam", (x + sx, y - 0.5, 1.5), (x + sx + kink, y - 0.64, 2.1), 0.045, seam)
        b.tube("Seam", (x + sx + kink, y - 0.64, 2.1), (x + sx * 1.3, y - 0.78, 2.7), 0.045, seam)
    for end in ((-3.6, 8.4, 3.6), (-2.4, 10.6, 4.2), (2.4, 10.6, 4.2), (0, 10.6, 4.6)):
        b.tube("Hose", (x, y + 0.6, 2.6), end, 0.1, b.material(b.TRIM))


def props():
    """Freight elevator (the descent point), cover and three lab-coat Lit. Returns the elevator roof."""
    cage = b.material(b.RUST, rough=0.6, metal=0.6)
    b.box("ElevatorFloor", (0, -10.3, 0), (3.6, 3.2, 0.12), cage)
    for x in (-1.75, 1.75):
        for y in (-11.8, -8.8):
            b.box("ElevatorPost", (x, y, 0), (0.14, 0.14, 3.1), cage)
    crate = b.material(b.TRIM)
    for x, y, size in ((-4.2, -6.5, 1.2), (-3.1, -6.2, 0.8), (4.6, -5.6, 1.1), (3.4, -0.8, 1.0), (-9.5, 4.5, 1.2)):
        b.box("Crate", (x, y, 0), (size, size, size), crate, rot=(0, 0, x * 9))
    for y in (-7, -3.5, 0):
        b.box("Console", (11.5, y, 0), (0.8, 2.2, 1.1), b.material(b.PIPE))
    b.cylinder("FallenTank", (-9.2, -1.5, 1.0), 1.0, 4.2, b.material(b.PIPE, rough=0.4, metal=0.8), rot=(90, 0, 20))
    b.lit((2.6, -3.6, 0), facing=160)
    b.lit((-3.4, 4.2, 0), facing=-20)
    b.lit((4.4, 5.6, 0), facing=25)
    return b.box("ElevatorRoof", (0, -10.3, 3.1), (3.6, 3.2, 0.15), cage)


def lights():
    """Cold tubes with gaps, green only from the tanks, one rim spot behind the boss."""
    for x, y in ((-6, -7.5), (0, -7.5), (6, -1.5), (-6, 4.5), (6, 4.5)):
        b.fixture((x, y, 6.9), watts=260)
    b.light("TankGlow", "POINT", (0, 9.4, 2.4), b.BIO_GREEN, 120, size=0.6)
    b.light("BossRim", "SPOT", (0, 11.6, 6.6), b.FLUORESCENT, 900, aim=(0, 4.5, 1.2), cone=75)
    b.light("ElevatorLamp", "POINT", (0, -10.3, 2.9), b.FLUORESCENT, 50, size=0.2)


def build():
    b.new_scene("halcyon_sublevel", fog_size=(44, 50, 24))
    hidden = room()
    tank_array()
    coolant_lines()
    night_supervisor()
    hidden.append(props())
    lights()
    return hidden


if __name__ == "__main__":
    b.render_shots(SHOTS, cutaway=build())
