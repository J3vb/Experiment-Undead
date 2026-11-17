"""Mess Hall and Main Corridor wreck (plan F-68 step 3): the kitchen line behind broken serving
windows, an overturned table, a smashed vending machine, a hanging broken light strip and
military cases. Same rules as prop_models.py.
"""

import math

import prop_models as p


def _laminate():
    from build_models import material, srgb

    return material("Laminate", srgb("#6C7566"), roughness=0.55)


def _shard(m, name: str, at: tuple, size: tuple, turn: float) -> None:
    from build_models import box

    shard = box(name, (size[0], 0.01, size[1]), at, m["glass"])
    shard.rotation_euler = (0, math.radians(turn), 0)


def build_kitchen_line() -> None:
    """Stoves and hood against the wall, a serving counter in front with broken window frames.
    Box 3.5 x 2.4 x 1.3, back against Godot -Z."""
    from build_models import box

    m = p._mats()
    back = 0.65
    box("Stoves", (3.4, 0.65, 0.9), (0, back - 0.33, 0.45), m["steel"], bevel=0.01)
    box("Splash", (3.4, 0.04, 1.0), (0, back - 0.02, 1.4), m["steel"])
    box("Hood", (3.4, 0.6, 0.35), (0, back - 0.3, 2.2), m["paint"], bevel=0.02)
    for i, x in enumerate((-1.2, -0.4, 0.4, 1.2)):
        box(f"Burner{i}", (0.5, 0.45, 0.03), (x, back - 0.33, 0.915), m["dark"])
    p._cyl("Pot", 0.18, 0.26, (-1.2, back - 0.33, 0.93), m["steel"], verts=12)
    p._cyl("Pan", 0.2, 0.05, (0.4, back - 0.35, 0.93), m["dark"], verts=12)
    p._cyl("Stock", 0.16, 0.3, (1.2, back - 0.3, 0.93), m["steel"], verts=12)
    front = -back + 0.2
    box("Counter", (3.4, 0.4, 1.0), (0, front, 0.5), m["paint"], bevel=0.015)
    box("CounterTop", (3.4, 0.46, 0.04), (0, front, 1.02), m["steel"])
    for i, x in enumerate((-1.67, -0.56, 0.56, 1.67)):
        box(f"Post{i}", (0.06, 0.06, 1.36), (x, front, 1.72), m["steel"])
    box("Beam", (3.4, 0.08, 0.08), (0, front, 2.36), m["steel"])
    shards = [
        (-1.75, 2.15, (0.3, 0.35), 12),
        (-1.1, 1.3, (0.25, 0.4), -20),
        (-0.9, 2.2, (0.4, 0.25), 6),
        (0.2, 2.25, (0.5, 0.2), -4),
        (1.15, 1.25, (0.3, 0.45), 25),
        (1.75, 2.1, (0.35, 0.4), -10),
    ]
    for i, (x, z, size, turn) in enumerate(shards):
        _shard(m, f"Shard{i}", (x * 0.85, front, z), size, turn)
    p._merge("KitchenLine")


def build_overturned_table() -> None:
    """A 2.4 m canteen table knocked on its side with a tipped bench. Box 2.6 x 1.1 x 1.4."""
    from build_models import box

    m = p._mats()
    top = _laminate()
    box("Top", (2.4, 0.05, 1.0), (0, 0.35, 0.52), top, bevel=0.01)
    for x in (-1.0, 1.0):
        leg = box(f"Leg{x}", (0.06, 0.72, 0.06), (x, -0.02, 0.6), m["steel"])
        leg.rotation_euler = (math.radians(4), 0, 0)
        box(f"Foot{x}", (0.06, 0.06, 0.7), (x, -0.36, 0.52), m["steel"])
    bench = box("Bench", (2.2, 0.35, 0.05), (0.1, -0.3, 0.24), top, bevel=0.008)
    bench.rotation_euler = (math.radians(70), 0, math.radians(6))
    for x in (-0.8, 0.9):
        box(f"BenchLeg{x}", (0.05, 0.05, 0.42), (x, -0.42, 0.21), m["steel"])
    p._merge("OverturnedTable")


def build_vending_machine() -> None:
    """Smashed drinks machine: cracked lit screen panel, bent door, cans on the floor. Box 1.0 x 1.9 x 0.8."""
    from build_models import box, material, srgb

    m = p._mats()
    shell = material("Alarm", srgb("#7A2420"), roughness=0.5)
    box("Body", (0.95, 0.7, 1.85), (0, 0.04, 0.925), shell, bevel=0.02)
    box("Screen", (0.62, 0.02, 1.2), (-0.1, -0.32, 1.1), m["screen"])
    box("Slot", (0.18, 0.03, 0.5), (0.36, -0.32, 1.25), m["dark"])
    box("Tray", (0.7, 0.05, 0.16), (-0.05, -0.33, 0.25), m["dark"])
    for i, (x, z, size, turn) in enumerate([(-0.25, 1.4, (0.2, 0.3), 30), (0.05, 0.8, (0.25, 0.15), -15)]):
        shard = box(f"Crack{i}", (size[0], 0.01, 0.015), (x, -0.335, z), m["dark"])
        shard.rotation_euler = (0, math.radians(turn), 0)
    for i, (x, y) in enumerate([(-0.3, -0.45), (0.2, -0.48), (0.35, -0.38)]):
        can = p._cyl(f"Can{i}", 0.033, 0.12, (0, 0, 0), m["steel"], verts=8)
        can.rotation_euler = (math.radians(90), 0, math.radians(40 * i))
        can.location = (x, y, 0.033)
    p._merge("VendingMachine")


def build_hanging_strip() -> None:
    """Broken light strip hanging by one cable, 4 m from the ceiling down to 0 (sparks at its low end)."""
    from build_models import box, limb

    m = p._mats()
    limb("Cable", (0.55, 0.0, 4.0), (0.5, 0.0, 1.05), 0.012, m["dark"])
    strip = box("Housing", (0.14, 0.12, 1.25), (0.25, 0.0, 0.6), m["steel"], bevel=0.01)
    strip.rotation_euler = (0, math.radians(-22), 0)
    tube = box("Tube", (0.05, 0.05, 1.1), (0.25, -0.07, 0.6), m["paper"])
    tube.rotation_euler = (0, math.radians(-22), 0)
    limb("LooseWire", (0.02, 0.0, 0.08), (-0.1, -0.05, 0.0), 0.006, m["dark"])
    p._merge("HangingStrip")


def build_military_cases() -> None:
    """Two hard cases stacked on a long one, latches and handles. Box 1.3 x 1.0 x 0.6."""
    from build_models import box, material, srgb

    m = p._mats()
    olive = material("Paint", srgb("#5F6D68"), roughness=0.65)
    box("Long", (1.3, 0.6, 0.42), (0, 0, 0.21), olive, bevel=0.03)
    box("CaseA", (0.6, 0.5, 0.3), (-0.3, 0.02, 0.57), olive, bevel=0.025)
    case_b = box("CaseB", (0.55, 0.45, 0.26), (0.32, -0.02, 0.55), olive, bevel=0.025)
    case_b.rotation_euler = (0, 0, math.radians(8))
    for i, x in enumerate((-0.45, 0.45)):
        box(f"Latch{i}", (0.08, 0.02, 0.06), (x, -0.31, 0.33), m["steel"])
    box("Handle", (0.3, 0.04, 0.03), (0, -0.31, 0.2), m["dark"])
    p._merge("MilitaryCases")


MODELS = {
    "kitchen_line": ("props/kitchen_line.glb", build_kitchen_line),
    "overturned_table": ("props/overturned_table.glb", build_overturned_table),
    "vending_machine": ("props/vending_machine.glb", build_vending_machine),
    "military_cases": ("props/military_cases.glb", build_military_cases),
    "hanging_strip": ("dressing/hanging_strip.glb", build_hanging_strip),
}
