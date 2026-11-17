"""Labs wreck (plan F-68 step 4): the glass research room with a Fenlight mass inside, a wall
screen pair (one cracked, one still running) and a floor of knocked stools and spilled jars.
Same rules as prop_models.py.
"""

import math
import random

import bpy
import prop_models as p
import props_fenlight as f


def build_research_room() -> None:
    """Glass research bay against a wall: steel frame, cracked panes, one pane gone, a glowing
    Fenlight mass inside. Box 4.0 x 2.7 x 1.1, back against Godot -Z."""
    from build_models import box

    m = {**p._mats(), **f._mats()}
    front = -0.5
    box("Sill", (4.0, 0.12, 0.3), (0, front, 0.15), m["steel"], bevel=0.01)
    box("Head", (4.0, 0.12, 0.14), (0, front, 2.63), m["steel"], bevel=0.01)
    for i, x in enumerate((-1.97, -0.66, 0.66, 1.97)):
        box(f"Mullion{i}", (0.07, 0.1, 2.3), (x, front, 1.45), m["steel"])
    for i, (x, gone) in enumerate(((-1.31, False), (0.0, True), (1.31, False))):
        if gone:
            for j, (sx, sz, w, h) in enumerate(((-0.45, 0.45, 0.3, 0.5), (0.4, 0.4, 0.4, 0.4), (-0.3, 2.3, 0.6, 0.3))):
                box(f"Stub{i}{j}", (w, 0.01, h), (x + sx, front, sz), m["glass"])
            continue
        box(f"Pane{i}", (1.24, 0.012, 2.3), (x, front, 1.45), m["glass"])
    rng = random.Random(61)
    p._blob("Mass", 0.55, (0.1, -0.2, 0.5), m["vine"], squash=(1.6, 0.45, 1.0))
    p._blob("MassTop", 0.4, (-0.2, -0.15, 1.2), m["vine"], squash=(1.2, 0.5, 1.1))
    box("BackRail", (4.0, 0.04, 0.06), (0, 0.53, 0.03), m["steel"])
    for i in range(6):
        a = i * 1.05
        points = [
            (0.2 * math.cos(a), -0.15, 1.1),
            (0.9 * math.cos(a), -0.05, 1.6 + 0.3 * math.sin(a)),
            (1.4 * math.cos(a), 0.0, 2.3),
        ]
        f._tube(f"Tendril{i}", points, 0.07, 0.02, m["vine"])
    for i in range(7):
        at = (rng.uniform(-0.9, 0.9), rng.uniform(-0.38, -0.1), rng.uniform(0.5, 1.6))
        f._pod(f"Pod{i}", at, rng.uniform(0.1, 0.17), m["pod"])
    p._merge("ResearchRoom")


def build_screen_pair() -> None:
    """Two wall screens on a bracket, one cracked and dark, one running. About 2.0 x 0.1 x 0.8; hang at 1.5 m."""
    from build_models import box

    m = p._mats()
    box("Rail", (1.9, 0.04, 0.06), (0, 0.03, 0.4), m["steel"])
    for i, x in enumerate((-0.5, 0.5)):
        box(f"Bezel{i}", (0.96, 0.06, 0.62), (x, -0.01, 0.4), m["dark"], bevel=0.01)
    box("Screen", (0.86, 0.01, 0.52), (0.5, -0.045, 0.4), m["screen"])
    box("DeadFace", (0.86, 0.01, 0.52), (-0.5, -0.045, 0.4), m["dark"])
    for i, (x, z, turn) in enumerate(((-0.6, 0.5, 35), (-0.45, 0.35, -50), (-0.4, 0.5, 80))):
        crack = box(f"Crack{i}", (0.32, 0.008, 0.012), (x, -0.052, z), m["glass"])
        crack.rotation_euler = (0, math.radians(turn), 0)
    box("Cable", (0.03, 0.03, 0.4), (0.8, 0.02, 0.2), m["dark"])
    p._merge("ScreenPair")


def build_lab_floor_wreck() -> None:
    """Floor dressing: two knocked stools, spilled sample jars (two still glowing), glass and papers."""
    from build_models import box, limb

    m = p._mats()
    for i, (x, y, turn) in enumerate(((-0.5, 0.1, 20), (0.6, -0.2, -70))):
        p._cyl(f"Seat{i}", 0.17, 0.05, (0, 0, 0), m["dark"], verts=10).location = (x, y, 0.17)
        seat = bpy.context.active_object
        seat.rotation_euler = (math.radians(90), 0, math.radians(turn))
        a = math.radians(turn)
        limb(f"Post{i}", (x, y, 0.17), (x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), 0.05), 0.022, m["steel"])
    for i, (x, y, glow) in enumerate(((0.1, 0.35, True), (-0.2, -0.3, False), (0.4, 0.3, True))):
        jar = p._cyl(f"Jar{i}", 0.06, 0.18, (0, 0, 0), m["fluid"] if glow else m["dark"], verts=8)
        jar.rotation_euler = (0, math.radians(90), math.radians(40 * i))
        jar.location = (x, y, 0.06)
    for i, (x, y, turn) in enumerate(((-0.1, -0.05, 30), (0.3, 0.05, -15), (-0.5, -0.4, 60))):
        sheet = box(f"Sheet{i}", (0.21, 0.297, 0.002), (x, y, 0.002 + i * 0.002), m["paper"])
        sheet.rotation_euler = (0, 0, math.radians(turn))
    p._merge("LabFloorWreck")


MODELS = {
    "research_room": ("props/research_room.glb", build_research_room),
    "screen_pair": ("dressing/screen_pair.glb", build_screen_pair),
    "lab_floor_wreck": ("dressing/lab_floor_wreck.glb", build_lab_floor_wreck),
}
