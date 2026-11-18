"""Ceiling layer (plan F-68 step 6): one merged ceiling model per Halcyon Labs room with trusses or
beams across the short side, a duct and a cable tray down the long side, and cables sagging off the
tray. Built from the room's rect and height in layout.json; the duct and tray run in the lanes
between the ceiling light rows (same spacing as tools/blockout_builder.gd) so no fixture is covered.
One material (steel) so each room pays one extra surface. Same rules as prop_models.py.
Place each with `at` = [room centre x, CEILING_DROP[room], centre z].
"""

import itertools
import json
import math
import os

import prop_models as p
from props_fenlight import _tube

LAYOUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels", "halcyon_labs", "layout.json")
LIGHT_SPACING = 6.0
LIGHT_HANG = 3.5
TALL = 5.5
EDGE = 0.1

# Lowest point of each room's ceiling model above its floor (the sagging cables).
CEILING_DROP = {
    "loading_dock": 3.3,
    "guard_post": 2.7,
    "mess_hall": 3.9,
    "main_corridor": 2.7,
    "generator_hall": 3.9,
    "labs": 2.7,
    "coolant_tunnel": 2.3,
    "containment_wing": 4.3,
}


def _room(room_id: str) -> tuple:
    with open(LAYOUT, encoding="utf-8") as handle:
        rooms = {r["id"]: r for r in json.load(handle)["rooms"]}
    x0, z0, x1, z1 = rooms[room_id]["rect"]
    return x1 - x0, z1 - z0, float(rooms[room_id]["height"])


def _lanes(short: float) -> list:
    """Offsets across the short side midway between light rows and the walls."""
    rows = max(1, round(short / LIGHT_SPACING))
    centres = [(j + 0.5) * short / rows - short / 2 for j in range(rows)]
    middles = [(a + b) / 2 for a, b in itertools.pairwise(centres)]
    gaps = [(-short / 2 + centres[0]) / 2, *middles, (centres[-1] + short / 2) / 2]
    return sorted(gaps, key=abs)


def _beam_spots(long: float) -> list:
    """Positions along the long side midway between light columns."""
    cols = max(1, round(long / LIGHT_SPACING))
    if cols == 1:
        return [-long / 4, long / 4]
    return [i * long / cols - long / 2 for i in range(1, cols)]


class _Frame:
    """Maps (along, across, height) in the room to Blender coordinates; Blender y is Godot -z."""

    def __init__(self, width: float, depth: float) -> None:
        self.along_x = width >= depth

    def at(self, u: float, v: float, z: float) -> tuple:
        return (u, -v, z) if self.along_x else (v, -u, z)

    def size(self, su: float, sv: float, sz: float) -> tuple:
        return (su, sv, sz) if self.along_x else (sv, su, sz)


def _truss(f: _Frame, i: int, u: float, short: float, top: float, depth: float, m: dict) -> None:
    from build_models import box

    span = short - 2 * EDGE
    box(f"Chord{i}T", f.size(0.12, span, 0.1), f.at(u, 0, top - 0.05), m["steel"])
    box(f"Chord{i}B", f.size(0.1, span, 0.08), f.at(u, 0, top - depth + 0.04), m["steel"])
    panels = max(2, round(span / 2.2))
    for k in range(panels):
        v0 = -span / 2 + span * k / panels
        v1 = v0 + span / panels
        lo, hi = (v0, v1) if k % 2 == 0 else (v1, v0)
        _tube(f"Web{i}_{k}", [f.at(u, lo, top - depth + 0.08), f.at(u, hi, top - 0.1)], 0.025, 0.025, m["steel"])


def _beam(f: _Frame, i: int, u: float, short: float, top: float, m: dict) -> None:
    from build_models import box

    box(f"Beam{i}", f.size(0.14, short - 2 * EDGE, 0.22), f.at(u, 0, top - 0.11), m["steel"])


def _duct(f: _Frame, long: float, v: float, z: float, m: dict) -> None:
    from build_models import box

    run = long - 2 * EDGE
    box("Duct", f.size(run, 0.55, 0.32), f.at(0, v, z), m["steel"])
    seams = max(2, round(run / 4.0))
    for k in range(1, seams):
        u = -run / 2 + run * k / seams
        box(f"Seam{k}", f.size(0.06, 0.6, 0.37), f.at(u, v, z), m["steel"])


def _tray(f: _Frame, long: float, v: float, z: float, m: dict) -> None:
    from build_models import box

    run = long - 2 * EDGE
    box("TrayBase", f.size(run, 0.4, 0.02), f.at(0, v, z), m["steel"])
    for side in (-1, 1):
        box(f"TrayLip{side}", f.size(run, 0.02, 0.08), f.at(0, v + side * 0.2, z + 0.04), m["steel"])
    for k, dv in enumerate((-0.08, 0.06)):
        _tube(f"Bundle{k}", [f.at(-run / 2, v + dv, z + 0.05), f.at(run / 2, v + dv, z + 0.05)], 0.04, 0.04, m["steel"])


def _hangers(f: _Frame, spots: list, v: float, z: float, top: float, m: dict) -> None:
    for i, u in enumerate(spots):
        _tube(f"Hanger{i}", [f.at(u, v, z), f.at(u, v, top)], 0.015, 0.015, m["steel"])


def _sag(f: _Frame, i: int, u0: float, u1: float, v: float, z: float, low: float, m: dict) -> None:
    """Cable hanging off the tray between two beams, its lowest point at `low`."""
    points = []
    drop = z - low - 0.03
    for k in range(5):
        t = k / 4
        points.append(f.at(u0 + (u1 - u0) * t, v + 0.15 * math.sin(t * math.pi), z - drop * math.sin(t * math.pi)))
    _tube(f"Sag{i}", points, 0.03, 0.03, m["steel"])


def build_ceiling(room_id: str) -> None:
    width, depth, height = _room(room_id)
    f = _Frame(width, depth)
    long, short = max(width, depth), min(width, depth)
    m = p._mats()
    top = height - 0.02
    tall = height >= TALL
    spots = _beam_spots(long)
    for i, u in enumerate(spots):
        if tall:
            _truss(f, i, u, short, top, 0.6, m)
        else:
            _beam(f, i, u, short, top, m)
    lanes = _lanes(short)
    duct_v, tray_v = lanes[0], -lanes[0] if len(lanes) < 2 else lanes[1]
    under = top - (0.6 if tall else 0.22)
    duct_z = under - (0.5 if tall else 0.2)
    tray_z = under - (0.9 if tall else 0.3)
    _duct(f, long, duct_v, duct_z, m)
    _tray(f, long, tray_v, tray_z, m)
    _hangers(f, spots, duct_v, duct_z + 0.16, under, m)
    _hangers(f, [u + 0.4 for u in spots], tray_v, tray_z, under, m)
    ends = [-long / 2 + EDGE, *spots, long / 2 - EDGE]
    low = CEILING_DROP[room_id]
    for i, (u0, u1) in enumerate(itertools.pairwise(ends)):
        if i % 2 == 0:
            _sag(f, i, u0 + 0.5, u1 - 0.5, tray_v, tray_z, low, m)
    p._merge("Ceiling")


def _builder(room_id: str):
    return lambda: build_ceiling(room_id)


MODELS = {f"ceiling_{r}": (f"dressing/ceiling_{r}.glb", _builder(r)) for r in CEILING_DROP}
