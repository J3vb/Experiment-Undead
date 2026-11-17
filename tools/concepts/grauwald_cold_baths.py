"""Concept blockout: the Grauwald cold baths under Ward Zero, the Sleeper rooted in the plunge pool.

Re-render: blender -b -P tools/concepts/grauwald_cold_baths.py
Brief: docs/design/concepts/act1/grauwald_cold_baths.md
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import blockout as b

BOSS = (0, 2)
SHOTS = {
    "overview": ((-17, -21, 17.5), (0, 1, 1), 50),
    "player": ((0, -11.2, 1.7), (0, 2, 2.3), 80),
    "boss": ((-1.3, -4.6, 1.7), (0, 2, 2.2), 80),
}


def slab(dx, thick, wide):
    """(x, y) size of a part lying flat against an east/west wall (dx) or a north/south one."""
    return (thick, wide) if dx else (wide, thick)


def hall():
    """26 x 26 m tiled bath hall, 6.5 m high. Returns the parts hidden in the overview."""
    paint, trim = b.material(b.WALL), b.material(b.TRIM)
    tiles = b.material(b.LAB_COAT, rough=0.35, checker=(b.TILE, 0.25))
    b.box("Floor", (0, 0, -0.3), (26, 26, 0.3), b.material(b.TILE, rough=0.25, checker=(b.TRIM, 0.5)), bevel=0)
    hidden = [b.box("Ceiling", (0, 0, 6.5), (26.8, 26.8, 0.3), trim, bevel=0)]
    for name, dx, dy in (("N", 0, 1), ("E", 1, 0), ("S", 0, -1), ("W", -1, 0)):
        parts = [
            b.box("Wall" + name, (dx * 13.2, dy * 13.2, 0), (*slab(dx, 0.4, 26.8), 6.5), paint),
            b.box("Tiles" + name, (dx * 12.96, dy * 12.96, 0), (*slab(dx, 0.1, 26), 2.2), tiles, bevel=0),
            b.box("Trim" + name, (dx * 12.95, dy * 12.95, 2.2), (*slab(dx, 0.14, 26), 0.12), trim),
        ]
        if name in "SW":
            hidden += parts
    return hidden


def baths():
    """The landmark: the round Ward Zero plunge pool (green: Fenlight lives in it) and eight side tubs."""
    x, y = BOSS
    ceramic, water = b.material(b.LAB_COAT, rough=0.3), b.material(b.FOG, rough=0.03)
    b.cylinder("PoolRim", (x, y, 0), 4.3, 0.55, ceramic, segments=40)
    b.cylinder("PoolWater", (x, y, 0.5), 3.9, 0.07, water, segments=40)
    for dx, dy, size in ((-1.4, -1.6, 0.7), (1.7, -0.9, 0.5), (0.6, -2.6, 0.4), (-2.6, 0.6, 0.55), (2.4, 1.7, 0.6)):
        b.ball("FenlightMat", (x + dx, y + dy, 0.56), size, b.material(b.BIO_GREEN, glow=1.6), scale=(1, 1, 0.08))
    for tx in (-10.6, 10.6):
        for ty in (-8.5, -5, 5, 8.5):
            b.box("Tub", (tx, ty, 0), (3.2, 1.5, 0.8), ceramic, bevel=0.1)
            b.box("TubWater", (tx, ty, 0.76), (2.8, 1.1, 0.05), water, bevel=0)


def fire_doors():
    """Tool one: four 1950s steel fire doors, a red alarm lamp over each. The north-east pair is closing."""
    steel, band = b.material(b.CONCRETE, rough=0.5, metal=0.6), b.material(b.ALARM, rough=0.6)
    for dx, dy, along, gap in ((1, 0, 0, 0.0), (-1, 0, 0, 0.0), (0, 1, -8, 0.0), (0, 1, 8, 0.9)):
        for inset, name, size, mat in (
            (12.8, "DoorFrame", (*slab(dx, 0.3, 3.9), 3.7), b.material(b.TRIM)),
            (12.79, "Doorway", (*slab(dx, 0.3, 3.5), 3.3), b.material(b.FOG)),
        ):
            b.box(name, (dx * inset, along, 0) if dx else (along, dy * inset, 0), size, mat)
        for side in (-1, 1):
            shift = along + side * (0.87 + gap)
            at = (dx * 12.62, shift) if dx else (shift, dy * 12.62)
            b.box("FireDoor", (*at, 0), (*slab(dx, 0.2, 1.72), 3.3), steel)
            b.box("DoorBand", (*at, 1.4), (*slab(dx, 0.24, 1.72), 0.35), band)
        lamp = (dx * 12.5, along, 4.1) if dx else (along, dy * 12.5, 4.1)
        b.ball("AlarmLamp", lamp, 0.16, b.material(b.ALARM, glow=14)).visible_shadow = False
        b.light("AlarmLight", "POINT", lamp, b.ALARM, 90, size=0.16)


def cold_vents():
    """Tool two: four louvred cold-air vents pour freezing air into the hall. Returns their two ceiling ducts."""
    duct = b.material(b.TRIM)
    ducts = [b.box("Duct", (x, 0, 5.4), (1.1, 26, 0.9), duct) for x in (-7.5, 7.5)]
    for x in (-7.5, 7.5):
        for y in (-5.5, 6.5):
            b.box("VentGlow", (x, y, 5.32), (0.9, 2.0, 0.06), b.material(b.FLUORESCENT, glow=3), bevel=0)
            for step in range(6):
                b.box("Louvre", (x, y - 0.9 + step * 0.36, 5.12), (1.1, 0.05, 0.22), duct, rot=(30, 0, 0), bevel=0)
            b.light("ColdAir", "SPOT", (x, y, 5.0), b.FLUORESCENT, 1500, size=0.4, cone=40)
    return ducts


def sleeper():
    """Placeholder act boss, 3.9 m: thin and far too tall, arms to its shins, rooted in the pool since 1951."""
    x, y = BOSS
    skin, vein = b.material(b.SKIN), b.material(b.BIO_GREEN, glow=2.5)
    for side in (-1, 1):
        b.tube("Leg", (x + side * 0.2, y, 0.5), (x + side * 0.2, y, 1.5), 0.11, skin)
        shoulder, elbow = (x + side * 0.45, y - 0.05, 3.1), (x + side * 0.9, y - 0.35, 1.95)
        hand = (x + side * 0.72, y - 0.85, 0.9)
        b.tube("UpperArm", shoulder, elbow, 0.08, skin)
        b.tube("Forearm", elbow, hand, 0.07, skin)
        b.tube("Vein", (shoulder[0], shoulder[1] - 0.09, 3.0), (elbow[0], elbow[1] - 0.09, 2.0), 0.012, vein)
        for finger in (-0.12, 0, 0.12):
            b.tube("Finger", hand, (hand[0] + finger, hand[1] - 0.15, hand[2] - 0.45), 0.025, skin)
        b.ball("Eye", (x + side * 0.08, y - 0.59, 3.7), 0.04, vein)
    b.cylinder("Gown", (x, y, 1.1), 0.6, 1.6, b.material(b.LAB_COAT), top=0.3)
    b.box("Chest", (x, y, 2.7), (0.85, 0.42, 0.5), skin, rot=(10, 0, 0), bevel=0.1)
    b.tube("Neck", (x, y - 0.05, 3.15), (x, y - 0.3, 3.55), 0.09, skin)
    b.ball("Head", (x, y - 0.38, 3.68), 0.23, b.material(b.HEAD), scale=(0.9, 1, 1.15))
    b.tube("Vein", (x - 0.1, y - 0.5, 1.4), (x + 0.12, y - 0.36, 2.6), 0.012, vein)
    for end in (
        (-3.4, 4.4, 0.55),
        (3.5, 3.6, 0.55),
        (-1.6, 6.0, 0.55),
        (-2.2, 5.5, 6.5),
        (2.4, 6.2, 6.5),
        (0.3, 3.6, 6.5),
    ):
        b.tube("Root", (x, y + 0.2, 2.8), end, 0.05, b.material(b.BLOATER))


def props():
    """Patient lift (the descent point) and four Lit in gowns. Returns the lift roof."""
    cage = b.material(b.RUST, rough=0.6, metal=0.6)
    b.box("LiftFloor", (0, -11.6, 0), (2.8, 2.6, 0.12), cage)
    for x in (-1.3, 1.3):
        for y in (-12.8, -10.4):
            b.box("LiftPost", (x, y, 0), (0.12, 0.12, 2.9), cage)
    for at, facing in (((-5.8, -3.2, 0), 140), ((4.6, -6.4, 0), 200), ((6.4, 5.6, 0), 60), ((-4.6, 7.4, 0), -50)):
        b.lit(at, facing=facing, clothes=b.LAB_COAT, hem=0.25, flare=1.1)
    return b.box("LiftRoof", (0, -11.6, 2.9), (2.8, 2.6, 0.12), cage)


def lights():
    """Sparse globe lamps, green from the pool, a rim spot behind the boss. The red alarm lamps are the accent."""
    for x, y in ((-6, -7), (6, -7), (0, -10.4), (-6, 8), (9, 2), (-9.5, 0.5)):
        b.tube("LampRod", (x, y, 6.5), (x, y, 5.4), 0.02, b.material(b.TRIM))
        b.ball("GlobeLamp", (x, y, 5.2), 0.22, b.material(b.FLUORESCENT, glow=12)).visible_shadow = False
        b.light("GlobeLight", "POINT", (x, y, 5.2), b.FLUORESCENT, 420, size=0.22)
    b.light("PoolGlow", "POINT", (BOSS[0], BOSS[1], 1.1), b.BIO_GREEN, 60, size=0.5)
    b.light("BossRim", "SPOT", (0, 12.4, 6.0), b.FLUORESCENT, 800, aim=(0, 2, 1.5), cone=60)


def build():
    b.new_scene("grauwald_cold_baths", fog_size=(46, 52, 24), fog_density=0.028)  # cold mist off the baths
    hidden = hall()
    baths()
    fire_doors()
    hidden += cold_vents()
    sleeper()
    hidden.append(props())
    lights()
    return hidden


if __name__ == "__main__":
    b.render_shots(SHOTS, cutaway=build())
