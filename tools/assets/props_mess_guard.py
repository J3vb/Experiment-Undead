"""Mess Hall and Guard Post props (plan F-15 step 2): canteen tables, serving counter, tipped chairs,
dropped trays, guard desk with monitors, locker row. Same rules as prop_models.py.
"""

import math

import bpy
import prop_models as p


def _laminate():
    from build_models import material, srgb

    return material("Laminate", srgb("#6C7566"), roughness=0.55)


def _tray(m, name: str, at: tuple, turn: float = 0.0, tilt: float = 0.0):
    from build_models import box

    tray = box(name, (0.42, 0.3, 0.02), at, m["tray"])
    tray.rotation_euler = (tilt, 0, math.radians(turn))
    return tray


def _cup(m, name: str, at: tuple) -> None:
    p._cyl(name, 0.035, 0.09, at, m["paper"], verts=8)


def build_mess_table() -> None:
    """9 m canteen table with fixed benches both sides, a few abandoned trays. Box 9 x 0.8 x 2.2."""
    from build_models import box

    m = p._mats()
    m["tray"] = m["dark"]
    top = _laminate()
    box("Top", (9.0, 1.2, 0.05), (0, 0, 0.75), top, bevel=0.01)
    box("Apron", (8.8, 1.0, 0.08), (0, 0, 0.68), m["steel"])
    for x in (-4.2, -1.4, 1.4, 4.2):
        box(f"Leg{x}", (0.08, 0.9, 0.06), (x, 0, 0.33), m["steel"])
        for side in (-1, 1):
            box(f"Strut{x}{side}", (0.06, 0.06, 0.45), (x, side * 0.8, 0.22), m["steel"])
            box(f"Rail{x}{side}", (0.06, 0.38, 0.04), (x, side * 0.62, 0.25), m["steel"])
    for side in (-1, 1):
        box(f"Bench{side}", (9.0, 0.35, 0.05), (0, side * 0.92, 0.45), top, bevel=0.008)
    trays = [(-3.1, -0.3, 8), (-1.0, 0.32, -14), (0.6, -0.28, 3), (2.9, 0.3, 21), (3.6, -0.25, -6)]
    for i, (x, y, turn) in enumerate(trays):
        _tray(m, f"Tray{i}", (x, y, 0.785), turn)
        _cup(m, f"Cup{i}", (x + 0.12, y + 0.06, 0.795))
    p._merge("MessTable")


def build_serving_counter() -> None:
    """Steel serving line with food pans, tray rail and a glass sneeze guard. Box 3.5 x 1.4 x 0.8."""
    from build_models import box

    m = p._mats()
    box("Body", (3.5, 0.62, 0.9), (0, 0.09, 0.45), m["paint"], bevel=0.015)
    box("Worktop", (3.5, 0.66, 0.04), (0, 0.07, 0.92), m["steel"])
    box("TrayRail", (3.5, 0.14, 0.03), (0, -0.33, 0.82), m["steel"])
    for x in (-1.6, 0, 1.6):
        box(f"RailArm{x}", (0.03, 0.12, 0.03), (x, -0.27, 0.82), m["steel"])
    for i in range(4):
        box(f"Pan{i}", (0.6, 0.42, 0.05), (-1.17 + i * 0.78, 0.1, 0.95), m["dark"])
    for x in (-1.7, 1.7):
        box(f"GuardPost{x}", (0.03, 0.03, 0.45), (x, -0.08, 1.165), m["steel"])
    guard = box("SneezeGuard", (3.44, 0.01, 0.34), (0, -0.14, 1.22), m["glass"])
    guard.rotation_euler = (math.radians(-20), 0, 0)
    p._merge("ServingCounter")


def _chair(m, name: str, at: tuple, turn: float) -> list:
    """Canteen chair lying on its back: seat, back and legs. Returns its parts."""
    from build_models import box

    x, y = at
    parts = [
        box(f"{name}Seat", (0.42, 0.42, 0.03), (0, 0, 0.2), m["laminate"]),
        box(f"{name}Back", (0.42, 0.03, 0.32), (0, 0.2, 0.36), m["laminate"]),
    ]
    for lx in (-0.18, 0.18):
        for ly in (-0.18, 0.18):
            parts.append(box(f"{name}Leg{lx}{ly}", (0.025, 0.025, 0.42), (lx, ly, 0.0), m["steel"]))
    for part in parts:
        part.select_set(False)
    pivot = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(pivot)
    for part in parts:
        part.parent = pivot
    pivot.rotation_euler = (math.radians(90), 0, math.radians(turn))
    pivot.location = (x, y, 0.22)
    bpy.context.view_layer.update()
    for part in parts:
        mat = part.matrix_world.copy()
        part.parent = None
        part.matrix_world = mat
    bpy.data.objects.remove(pivot)
    return parts


def build_mess_spill() -> None:
    """Floor dressing: two knocked-over chairs, dropped trays and cups (no collision)."""
    m = p._mats()
    m["laminate"] = _laminate()
    m["tray"] = m["dark"]
    _chair(m, "ChairA", (-0.5, 0.0), 20)
    _chair(m, "ChairB", (0.55, 0.35), 145)
    _tray(m, "TrayA", (0.1, -0.55, 0.012), 35)
    _tray(m, "TrayB", (-0.9, -0.35, 0.06), -10, math.radians(14))
    for i, (x, y) in enumerate([(0.3, -0.75), (-0.2, -0.9), (0.9, -0.4)]):
        p._cyl(f"Cup{i}", 0.035, 0.09, (x, y, 0.0), m["paper"], verts=8)
    p._merge("MessSpill")


def build_guard_desk() -> None:
    """Guard desk: steel desk, two monitors (Screen surfaces), CCTV switcher, phone, logbook. Box 2.4 x 1.45 x 1."""
    from build_models import box

    m = p._mats()
    top = 0.76
    box("Top", (2.4, 1.0, 0.04), (0, 0, top - 0.02), m["paint"], bevel=0.008)
    for x in (-1.0, 1.0):
        box(f"Pedestal{x}", (0.42, 0.9, 0.72), (x, 0.02, 0.36), m["paint"], bevel=0.01)
        for d in range(3):
            box(f"Drawer{x}{d}", (0.36, 0.02, 0.2), (x, -0.44, 0.13 + d * 0.23), m["steel"])
    box("Modesty", (1.56, 0.03, 0.5), (0, 0.42, 0.45), m["paint"])
    p._terminal(m, -0.55, top)
    p._terminal(m, 0.25, top)
    box("Switcher", (0.3, 0.18, 0.05), (0.85, -0.25, top + 0.025), m["dark"])
    box("Phone", (0.18, 0.2, 0.07), (-1.0, -0.2, top + 0.035), m["dark"], bevel=0.01)
    book = box("Logbook", (0.3, 0.22, 0.02), (0.75, 0.15, top + 0.01), m["dark"])
    book.rotation_euler = (0, 0, math.radians(12))
    p._merge("GuardDesk")


def build_locker_row() -> None:
    """Ten staff lockers on a plinth, one door ajar. Box 6 x 2 x 0.6 (long side along x)."""
    from build_models import attach, box

    m = p._mats()
    box("Plinth", (6.0, 0.5, 0.1), (0, 0.04, 0.05), m["dark"])
    box("Carcass", (6.0, 0.48, 1.86), (0, 0.05, 1.03), m["paint"])
    for i in range(10):
        x = -2.7 + i * 0.6
        if i == 6:
            door = box(f"Door{i}", (0.56, 0.02, 1.8), (x, -0.2, 1.03), m["steel"])
            attach(door, (x + 0.28, -0.2, 1.03))
            door.rotation_euler = (0, 0, math.radians(8))
            box(f"Inside{i}", (0.54, 0.02, 1.76), (x, 0.26, 1.03), m["dark"])
            continue
        box(f"Door{i}", (0.56, 0.02, 1.8), (x, -0.2, 1.03), m["steel"])
        for v in range(3):
            box(f"Vent{i}{v}", (0.3, 0.01, 0.02), (x, -0.212, 1.75 - v * 0.05), m["dark"])
        box(f"Latch{i}", (0.03, 0.02, 0.12), (x + 0.22, -0.215, 1.05), m["dark"])
    p._merge("LockerRow")


MODELS = {
    "mess_table": ("props/mess_table.glb", build_mess_table),
    "serving_counter": ("props/serving_counter.glb", build_serving_counter),
    "guard_desk": ("props/guard_desk.glb", build_guard_desk),
    "locker_row": ("props/locker_row.glb", build_locker_row),
    "mess_spill": ("dressing/mess_spill.glb", build_mess_spill),
}
