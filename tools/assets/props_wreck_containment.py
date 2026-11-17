"""Containment wreck (plan F-68 step 5): the big cold tanks (one shattered and empty, two cracked
and leaking) inside bent hazard railings, a toppled console, fallen barrels, floor cables and the
catwalk office with its collapsed stair. Same rules as prop_models.py.
"""

import math
import random

import prop_models as p


def _hazard():
    from build_models import material, srgb

    return material("Hazard", srgb("#C27534"), roughness=0.6)


def _railing(m, radius: float, gap: float, bend: float) -> None:
    """Ring of posts and two rails round a tank, open by `gap` radians at the front, one section bent in."""
    from props_fenlight import _tube

    posts = 10

    def at(i: int, z: float) -> tuple:
        a = -math.pi / 2 + gap / 2 + (2 * math.pi - gap) * i / posts
        r = radius * (1 - bend) if i == 3 else radius
        return (r * math.cos(a), r * math.sin(a), z - (0.3 if i == 3 and z > 1.0 else 0.0))

    for i in range(posts + 1):
        _tube(f"Post{i}", [at(i, 0.0), at(i, 1.05)], 0.03, 0.03, m["hazard"])
    for z in (0.55, 1.05):
        _tube(f"Rail{z}", [at(i, z) for i in range(posts + 1)], 0.025, 0.025, m["hazard"])


def _big_tank(seed: int, shattered: bool) -> None:
    from build_models import box

    rng = random.Random(seed)
    m = {**p._mats(), "hazard": _hazard()}
    p._cyl("Base", 1.1, 0.6, (0, 0, 0), m["steel"], verts=20)
    p._cyl("Cap", 1.1, 0.5, (0, 0, 4.0), m["steel"], verts=20)
    for i in range(4):
        a = math.radians(45 + i * 90)
        p._cyl(f"Strut{i}", 0.06, 3.4, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.6), m["steel"], verts=6)
    if shattered:
        for i in range(9):
            a = 2 * math.pi * i / 9
            h = rng.uniform(0.3, 1.2)
            shard = p._cyl(f"Stub{i}", 0.02, h, (0, 0, 0), m["glass"], verts=4)
            shard.location = (0.95 * math.cos(a), 0.95 * math.sin(a), 0.6 + h / 2)
            shard.scale = (12.0, 1.0, 1.0)
            shard.rotation_euler = (0, 0, a + math.pi / 2)
        for i in range(3):
            a = 2 * math.pi * i / 3 + 0.4
            top = p._cyl(f"Fang{i}", 0.02, 0.6, (0, 0, 0), m["glass"], verts=4)
            top.location = (0.95 * math.cos(a), 0.95 * math.sin(a), 3.7)
            top.scale = (10.0, 1.0, 1.0)
            top.rotation_euler = (0, 0, a + math.pi / 2)
    else:
        p._cyl("Tube", 0.95, 3.4, (0, 0, 0.6), m["glass"], verts=20)
        p._cyl("Fluid", 0.9, rng.uniform(1.6, 2.4), (0, 0, 0.6), m["fluid"], verts=20)
        for i in range(10):
            a = rng.uniform(-1.2, 1.2) - math.pi / 2
            crack = box(f"Crack{i}", (rng.uniform(0.3, 0.7), 0.012, 0.018), (0, 0, 0), m["fluid"])
            crack.location = (0.965 * math.cos(a), 0.965 * math.sin(a), rng.uniform(1.0, 3.4))
            crack.rotation_euler = (0, math.radians(rng.uniform(-60, 60)), a + math.pi / 2)
    _railing(m, 1.4, math.radians(50), 0.25)


def build_big_tank_shattered() -> None:
    """C-01: the cold tank the outbreak came from, glass blown out, empty. Box 2.9 x 4.5 x 2.9."""
    _big_tank(71, True)
    p._merge("BigTankShattered")


def build_big_tank_cracked() -> None:
    """C-02 and C-03: cracked cold tank, half drained and still glowing. Box 2.9 x 4.5 x 2.9."""
    _big_tank(73, False)
    p._merge("BigTankCracked")


def build_toppled_console() -> None:
    """Control console knocked on its back, screen cracked. Box 1.4 x 0.9 x 1.2."""
    from build_models import box

    m = p._mats()
    body = box("Body", (1.3, 0.75, 0.6), (0, 0.05, 0.3), m["paint"], bevel=0.02)
    body.rotation_euler = (math.radians(-12), 0, 0)
    box("Desk", (1.3, 0.45, 0.06), (0, -0.4, 0.55), m["dark"])
    box("Screen", (0.9, 0.02, 0.5), (0, -0.33, 0.62), m["screen"])
    for i, (x, z, turn) in enumerate(((-0.15, 0.68, 30), (0.1, 0.6, -40))):
        crack = box(f"Crack{i}", (0.4, 0.01, 0.012), (x, -0.345, z), m["dark"])
        crack.rotation_euler = (0, math.radians(turn), 0)
    p._merge("ToppledConsole")


def build_fallen_barrels() -> None:
    """Three steel drums, two on their sides (one material to keep Containment's draw calls in budget)."""
    from build_models import box

    m = p._mats()
    p._cyl("Standing", 0.3, 0.9, (-0.6, 0.25, 0), m["steel"], verts=14)
    box("Band", (0.62, 0.62, 0.06), (-0.6, 0.25, 0.6), m["steel"])
    for i, (x, y, turn) in enumerate(((0.2, -0.2, 20), (0.55, 0.35, -50))):
        drum = p._cyl(f"Lying{i}", 0.3, 0.9, (0, 0, 0), m["steel"], verts=14)
        drum.location = (x, y, 0.3)
        drum.rotation_euler = (0, math.radians(90), math.radians(turn))
    p._merge("FallenBarrels")


def build_floor_cables() -> None:
    """Floor dressing: three thick cables snaking across the grating. About 4 x 1.2 x 0.1."""
    from props_fenlight import _tube

    m = p._mats()
    for i in range(3):
        y = -0.4 + i * 0.4
        points = [(-2.0 + t * 0.5, y + math.sin(t * 1.3 + i) * 0.25, 0.04) for t in range(9)]
        _tube(f"Cable{i}", points, 0.04, 0.04, m["dark"])
    p._merge("FloorCables")


def build_catwalk_office() -> None:
    """Wall dressing out of reach: catwalk deck with hazard rails and a small office, the stair torn
    down to hang 1.8 m above the floor. Place at 1.8 m. About 5 x 3 x 3.5, back against Godot -Z."""
    from build_models import box
    from props_fenlight import _tube

    m = {**p._mats(), "hazard": _hazard()}
    deck = 1.3
    back = 0.8
    box("Deck", (5.0, 1.5, 0.08), (0, back - 0.75, deck), m["steel"])
    for i in range(6):
        x = -2.5 + i
        _tube(f"RailPost{i}", [(x, back - 1.48, deck), (x, back - 1.48, deck + 1.0)], 0.025, 0.025, m["hazard"])
    box("RailTop", (5.0, 0.04, 0.04), (0, back - 1.48, deck + 1.0), m["hazard"])
    box("RailMid", (5.0, 0.03, 0.03), (0, back - 1.48, deck + 0.5), m["hazard"])
    box("Office", (2.4, 1.2, 2.2), (1.0, back - 0.62, deck + 1.1), m["steel"], bevel=0.02)
    box("Window", (1.6, 0.02, 0.7), (1.0, back - 1.23, deck + 1.5), m["dark"])
    for i, x in enumerate((-2.4, 2.4)):
        brace = box(f"Brace{i}", (0.08, 0.08, 1.3), (x, back - 0.4, deck - 0.6), m["dark"])
        brace.rotation_euler = (math.radians(-35), 0, 0)
    stair = box("Stair", (0.8, 1.8, 0.06), (-1.4, back - 1.75, deck * 0.45), m["steel"])
    stair.rotation_euler = (math.radians(65), 0, math.radians(8))
    for i in range(4):
        z = deck - 0.15 - 0.3 * i
        tread = box(f"Tread{i}", (0.8, 0.22, 0.03), (-1.4 + 0.03 * i, back - 1.55 - i * 0.13, z), m["dark"])
        tread.rotation_euler = (0, 0, math.radians(8))
    p._merge("CatwalkOffice")


MODELS = {
    "big_tank_shattered": ("props/big_tank_shattered.glb", build_big_tank_shattered),
    "big_tank_cracked": ("props/big_tank_cracked.glb", build_big_tank_cracked),
    "toppled_console": ("props/toppled_console.glb", build_toppled_console),
    "fallen_barrels": ("props/fallen_barrels.glb", build_fallen_barrels),
    "floor_cables": ("dressing/floor_cables.glb", build_floor_cables),
    "catwalk_office": ("dressing/catwalk_office.glb", build_catwalk_office),
}
