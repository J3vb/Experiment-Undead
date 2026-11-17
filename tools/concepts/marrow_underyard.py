"""Concept blockout: under the Marrow Junction yard, the Courier swollen around the Siphon.

Re-render: blender -b -P tools/concepts/marrow_underyard.py
Brief: docs/design/concepts/act1/marrow_underyard.md
"""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import blockout as b

BOSS = (0, -1)
SIPHON = (0, -2.55, 1.9)
SHOTS = {
    "overview": ((-19, -21, 18), (0, 0, 1), 50),
    "player": ((1.6, -9.8, 1.7), (0, -1, 2.0), 80),
    "boss": ((0.9, -6.8, 1.7), (0, -1, 1.9), 80),
}


def undercroft():
    """30 x 22 m brick undercroft, 5.7 m high. Returns the parts hidden in the overview."""
    brick, steel = b.material(b.BRICK), b.material(b.TRIM)
    b.box("Floor", (0, 0, -0.3), (30, 22, 0.3), b.material(b.CONCRETE, rough=0.6, wet=True), bevel=0)
    b.box("WallN", (0, 11.2, 0), (30.8, 0.4, 5.7), brick)
    b.box("WallE", (15.2, 0, 0), (0.4, 22, 5.7), brick)
    hidden = [
        b.box("WallS", (0, -11.2, 0), (30.8, 0.4, 5.7), brick),
        b.box("WallW", (-15.2, 0, 0), (0.4, 22, 5.7), brick),
    ]
    for x in (-10, -3.4, 3.4, 10):
        b.box("CrossBeam", (x, 0, 5.2), (0.4, 22, 0.5), steel)
        for y in (-8.2, 6.2):
            b.box("Pier", (x, y, 0), (1.2, 1.2, 5.2), brick)
    for y, width in ((-9.15, 3.7), (-1.25, 6.9), (7.9, 6.2)):
        hidden.append(b.box("Slab", (0, y, 5.7), (30, width, 0.3), steel, bevel=0))
    return hidden


def tracks():
    """Two tracks overhead: sodium light from the yard falls between the sleepers. One has caved in."""
    wood, rail = b.material(b.WOOD), b.material(b.PIPE, rough=0.4, metal=0.9)
    for y, end in ((-6, 15), (3.5, 5.5)):
        for step in range(50):
            x = -14.7 + step * 0.6
            if x < end:
                b.box("Sleeper", (x, y, 5.7), (0.26, 2.6, 0.16), wood, bevel=0)
        for side in (-0.72, 0.72):
            b.tube("Rail", (-15, y + side, 5.93), (end, y + side, 5.93), 0.06, rail)
    for side in (-0.72, 0.72):
        b.tube("BentRail", (5.5, 3.5 + side, 5.93), (8.6, 3.3 + side, 3.9), 0.06, rail)


def reefer_wagon():
    """The landmark and the cold tool: a refrigerated wagon that fell through the track. Shoot its cooling unit."""
    frost = b.material(b.FLUORESCENT, glow=1.5)
    body = b.box("Wagon", (10.2, 3.6, 1.6), (8.5, 2.7, 2.8), b.material(b.LAB_COAT, rough=0.5), rot=(5, -27, 4))
    parts = [
        b.box("WagonRoof", (0, 0, 2.8), (8.6, 2.8, 0.15), b.material(b.TRIM)),
        b.box("CoolingUnit", (-4.7, 0, 0.5), (0.9, 2.2, 1.7), b.material(b.PIPE)),
        b.box("FrostVent", (-5.17, 0, 0.9), (0.08, 1.8, 0.9), frost, bevel=0),
        b.cylinder("CoolantValve", (-5.2, -0.85, 0.75), 0.24, 0.1, b.material(b.ALARM, glow=0.6), rot=(0, -90, 0)),
        b.box("DoorGap", (0.6, -1.36, 0.3), (1.6, 0.06, 2.2), b.material(b.FLUORESCENT, glow=0.5), bevel=0),
    ]
    for x in (-2.8, 2.8):
        parts.append(b.cylinder("Axle", (x, 1.1, -0.4), 0.45, 2.2, b.material(b.TRIM), rot=(90, 0, 0)))
    for part in parts:
        part.parent = body


def siphon():
    """The Siphon prototype in the Courier's chest: a live Fenlight core in an open cage."""
    x, y, z = SIPHON
    steel = b.material(b.PIPE, rough=0.35, metal=0.9)
    b.ball("SiphonCore", SIPHON, 0.4, b.material(b.BIO_GREEN, glow=3))
    for step in range(6):
        dx, dy = 0.55 * math.cos(step * math.tau / 6), 0.55 * math.sin(step * math.tau / 6)
        b.tube("CageBar", (x + dx, y + dy, z - 0.6), (x + dx, y + dy, z + 0.6), 0.035, steel)
    for dz in (-0.66, 0.6):
        b.cylinder("CageCap", (x, y, z + dz), 0.6, 0.06, steel)


def courier():
    """Placeholder boss, 3.6 m: a swollen ball of a body around the Siphon, small head, torn coat."""
    x, y = BOSS
    coat = b.material(b.TROUSERS)
    for side in (-1, 1):
        b.cylinder("Leg", (x + side * 0.65, y, 0), 0.42, 0.8, coat)
        b.box("CoatFlap", (x + side * 1.5, y + 0.2, 0.5), (0.2, 1.7, 2.1), coat, rot=(0, side * -9, 0), bevel=0.08)
        shoulder, hand = (x + side * 1.35, y - 0.5, 2.7), (x + side * 1.75, y - 1.3, 2.0)
        b.tube("Arm", shoulder, hand, 0.16, b.material(b.DARK_SKIN))
    b.ball("Body", (x, y, 1.9), 1.55, b.material(b.BLOATER), scale=(1.05, 1.0, 0.95))
    b.cylinder("Collar", (x, y, 3.0), 0.8, 0.3, coat)
    b.ball("Head", (x, y - 0.6, 3.4), 0.26, b.material(b.HEAD))
    for side in (-0.1, 0.1):
        b.ball("Eye", (x + side, y - 0.84, 3.43), 0.045, b.material(b.BIO_GREEN, glow=9))
    siphon()


def feeders():
    """Six feeder hosts in long coats, each tied to the Siphon by a cord trailing over the floor. Kill them first."""
    x, y = BOSS
    cord = b.material(b.BIO_GREEN, glow=0.8)
    for angle, radius in ((200, 5.6), (236, 5.0), (304, 5.0), (340, 5.6), (30, 5.2), (150, 5.4)):
        fx = x + radius * math.cos(math.radians(angle))
        fy = y + radius * math.sin(math.radians(angle))
        b.lit((fx, fy, 0), facing=angle - 90, clothes=b.TROUSERS, hem=0.3, flare=1.15)
        near = (SIPHON[0] + (fx - SIPHON[0]) * 0.2, SIPHON[1] + (fy - SIPHON[1]) * 0.2, 0.04)
        far = (SIPHON[0] + (fx - SIPHON[0]) * 0.85, SIPHON[1] + (fy - SIPHON[1]) * 0.85, 0.04)
        for start, end in ((SIPHON, near), (near, far), (far, (fx, fy, 1.2))):
            b.tube("Cord", start, end, 0.03, cord)


def props():
    """Evacuees' suitcases in spilled piles, and the iron stair from the yard hatch (the descent point)."""
    rng = random.Random(7)
    colours = [b.material(colour) for colour in (b.WOOD, b.RUST, b.SHIRT, b.LAB_COAT, b.TRIM)]
    for px, py in ((-6.5, -6.5), (6.2, -5.4), (-8.5, 3), (4.5, 8.2), (-1, 8.8)):
        for step in range(9):
            at = (px + rng.uniform(-1.1, 1.1), py + rng.uniform(-0.9, 0.9), (step // 4) * 0.26)
            b.box("Suitcase", at, (0.75, 0.5, 0.26), rng.choice(colours), rot=(0, 0, rng.uniform(0, 180)))
    iron = b.material(b.RUST, rough=0.6, metal=0.6)
    for step in range(19):
        b.box("Step", (-6.0 + step * 0.3, -10.2, 5.4 - step * 0.3), (0.32, 1.5, 0.06), iron, bevel=0)
    b.tube("Handrail", (-6.0, -9.45, 6.3), (-0.4, -9.45, 0.9), 0.04, iron)


def lights():
    """Sodium yard lamps above the tracks, four cold work lamps below, a rim spot behind the boss."""
    b.light("YardLamp", "POINT", (-7, -4, 13), b.SODIUM, 6000, size=0.3)
    b.light("YardLampHole", "POINT", (10, 5, 12), b.SODIUM, 6000, size=0.3)
    b.light("HatchSpill", "POINT", (-6.3, -10.2, 5.2), b.SODIUM, 120, size=0.2)
    for x, y in ((-8, 0.5), (5.5, -8), (0, 8.6), (6.4, 0.6)):
        b.fixture((x, y, 5.1), watts=260)
    b.light("BossRim", "SPOT", (0, 10, 5.2), b.FLUORESCENT, 700, aim=(0, -1, 1.6), cone=60)


def build():
    b.new_scene("marrow_underyard", fog_size=(30.4, 22.4, 7.7))  # fog only inside the room
    hidden = undercroft()
    tracks()
    reefer_wagon()
    courier()
    feeders()
    props()
    lights()
    return hidden


if __name__ == "__main__":
    b.render_shots(SHOTS, cutaway=build())
