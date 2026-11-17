"""Concept blockout: Kessel Dam turbine pit, the Turbine Keeper standing in the flooded basin.

Re-render: blender -b -P tools/concepts/kessel_turbine_pit.py
Brief: docs/design/concepts/act1/kessel_turbine_pit.md
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import blockout as b

BOSS = (0, 3)
BASIN = -0.6  # basin floor; the ring walkway is at 0
SHOTS = {
    "overview": ((-17, -21, 21), (0, 1, 0), 50),
    "player": ((0, -12.2, 1.7), (0, 3, 1.8), 80),
    "boss": ((-1.2, -3.4, BASIN + 1.7), (0, 3, 1.5), 80),
}


def polar(radius, angle, z):
    """A point `radius` from the pit centre at `angle` degrees."""
    return radius * math.cos(math.radians(angle)), radius * math.sin(math.radians(angle)), z


def pit():
    """Round concrete pit, 28 m across, open to the night above. Returns the wall panels hidden in the overview."""
    concrete = b.material(b.CONCRETE)
    b.cylinder("BasinFloor", (0, 0, BASIN - 0.3), 14.4, 0.3, b.material(b.TRIM), segments=40)
    b.cylinder("Water", (0, 0, BASIN), 11.5, 0.35, b.material(b.FOG, rough=0.12), segments=40)
    walkway = b.cylinder("Walkway", (0, 0, BASIN), 14.4, 0.6, concrete, segments=40)
    basin = b.cylinder("BasinCut", (0, 0, BASIN - 0.2), 11.5, 1.2, concrete, segments=40)
    basin.hide_render = True
    walkway.modifiers.new("Basin", "BOOLEAN").object = basin
    for x in (-3.4, 3.4):
        b.box("Ramp", (x, -10.3, BASIN - 0.1), (1.8, 3.4, 0.3), concrete, rot=(-10, 0, 0))
    hidden = []
    for step in range(20):
        x, y, z = polar(14.3, step * 18 + 9, BASIN)
        panel = b.box("Wall", (x, y, z), (0.5, 4.6, 14), b.material(b.WALL), rot=(0, 0, step * 18 + 9))
        if -0.63 * x - 0.78 * y > 6:
            hidden.append(panel)
    return hidden


def floodgates():
    """The cold tool: three lit gates on the north wall, each with a red wheel. The west one is open."""
    steel = b.material(b.RUST, rough=0.6, metal=0.5)
    water = b.material(b.FLUORESCENT, rough=0.08, glow=0.5)
    for angle, lift in ((60, 0.0), (90, 0.0), (120, 1.8)):
        turn = (0, 0, angle)
        b.box("GateFrame", polar(13.8, angle, 0), (0.7, 4.6, 5.8), b.material(b.CONCRETE), rot=turn)
        b.box("GateMouth", polar(13.6, angle, 0), (0.5, 3.6, 5.0), b.material(b.FOG), rot=turn, bevel=0)
        b.box("Gate", polar(13.35, angle, lift), (0.3, 3.7, 5.0), steel, rot=turn)
        b.box("WheelPost", polar(11.95, angle, 0), (0.25, 0.25, 1.15), b.material(b.PIPE), rot=turn)
        b.cylinder("GateWheel", polar(11.76, angle, 1.3), 0.38, 0.1, b.material(b.ALARM, glow=0.6), rot=(0, 90, angle))
        b.light("GateLamp", "POINT", polar(12.8, angle, 6.4), b.FLUORESCENT, 140, size=0.2)
    b.box("Spill", polar(12.3, 120, 0), (2.4, 3.2, 0.1), water, rot=(0, 0, 120), bevel=0)
    b.box("Fall", polar(11.45, 120, BASIN), (0.2, 3.2, 0.68), water, rot=(0, 0, 120), bevel=0)


def wreckage():
    """The landmark: the turbine runner torn off its shaft, lying in the basin under the broken stub."""
    steel = b.material(b.PIPE, rough=0.35, metal=0.9)
    rust = b.material(b.RUST, rough=0.6, metal=0.6)
    b.cylinder("ShaftStub", (4.5, 0.5, 6.5), 0.7, 8, steel)
    hub = b.cylinder("RunnerHub", (5.2, -0.6, BASIN), 1.5, 1.5, steel, rot=(24, -14, 0))
    for step in range(8):
        blade = b.box("RunnerBlade", polar(2.5, step * 45, 0.5), (2.6, 1.0, 0.14), rust, rot=(24, 0, step * 45))
        blade.parent = hub
    b.cylinder("FallenShaft", (-7.5, 3.5, BASIN + 0.7), 0.7, 5.5, steel, rot=(90, 0, 100))
    for at, rot in (
        ((-9.5, 4.5, 0), (70, 20, 30)),
        ((8.6, 7.5, 0), (55, -30, 100)),
        ((-2.5, 8.8, BASIN), (80, 10, 160)),
    ):
        b.box("LooseBlade", at, (2.6, 1.0, 0.14), rust, rot=rot)


def turbine_keeper():
    """Placeholder boss, 3.8 m: huge shoulders under a stator ring, a turbine blade for one arm."""
    x, y = BOSS
    overalls, flesh = b.material(b.SHIRT), b.material(b.DARK_SKIN)
    rust, seam = b.material(b.RUST, rough=0.6, metal=0.6), b.material(b.BIO_GREEN, glow=9)
    for side in (-0.55, 0.55):
        b.tube("Leg", (x + side, y, BASIN), (x + side * 0.9, y, 1.0), 0.33, overalls)
    b.box("Torso", (x, y, 0.8), (1.7, 1.1, 1.2), overalls, bevel=0.15)
    b.box("Shoulders", (x, y - 0.1, 1.8), (3.1, 1.3, 0.75), overalls, rot=(8, 0, 0), bevel=0.2)
    b.cylinder("StatorRing", (x, y + 0.2, 2.4), 1.05, 0.45, rust, rot=(-10, 6, 0))
    b.ball("Head", (x, y - 0.75, 2.85), 0.27, b.material(b.HEAD))
    for side in (-0.1, 0.1):
        b.ball("Eye", (x + side, y - 1.0, 2.88), 0.045, seam)
    b.tube("ArmL", (x - 1.5, y - 0.1, 2.2), (x - 2.3, y - 0.8, 1.0), 0.3, flesh)
    b.ball("FistL", (x - 2.35, y - 1.0, 0.6), 0.45, flesh)
    b.tube("ArmR", (x + 1.5, y - 0.1, 2.2), (x + 2.45, y - 0.8, 1.5), 0.3, flesh)
    b.box("BladeArm", (x + 2.5, y - 1.6, BASIN), (0.16, 1.1, 2.7), rust, rot=(-18, 0, 0))
    for sx, kink, bend in ((-0.5, 0.22, 1.55), (0.3, -0.16, 1.2), (0.62, 0.1, 1.7)):
        b.tube("Seam", (x + sx, y - 0.58, 0.95), (x + sx + kink, y - 0.6, bend), 0.045, seam)
        b.tube("Seam", (x + sx + kink, y - 0.6, bend), (x + sx * 0.8, y - 0.78, 1.95), 0.045, seam)


def props():
    """Service lift down the turbine shaft (the descent point) and three Lit in overalls."""
    cage = b.material(b.RUST, rough=0.6, metal=0.6)
    b.box("LiftFloor", (0, -12.9, 0), (3.0, 2.4, 0.12), cage)
    for x in (-1.4, 1.4):
        for y in (-13.9, -11.8):
            b.box("LiftPost", (x, y, 0), (0.12, 0.12, 2.8), cage)
    for x in (-0.9, 0.9):
        b.tube("LiftRail", (x, -14.0, 0), (x, -14.0, 13.4), 0.08, cage)
    b.lit((-8.6, -8.9, 0), facing=-40, clothes=b.SHIRT, hem=0.05)
    b.lit((-3.8, -1.5, BASIN), facing=150, clothes=b.SHIRT, hem=0.05)
    b.lit((5.6, 6.6, BASIN), facing=20, clothes=b.SHIRT, hem=0.05)


def lights():
    """Cold wall lamps with gaps, one sodium shaft from the dam above, a rim spot behind the boss."""
    for angle in (20, 160, 245, 295):
        b.box("WallLamp", polar(13.95, angle, 4.5), (0.2, 0.6, 0.25), b.material(b.FLUORESCENT, glow=12), bevel=0)
        b.light("WallLight", "POINT", polar(13.5, angle, 4.6), b.FLUORESCENT, 520, size=0.2)
    b.light("SodiumShaft", "SPOT", (2, -3, 22), b.SODIUM, 80000, aim=(4.6, -0.6, 0), size=0.6, cone=26)
    b.light("BossRim", "SPOT", (0, 12.5, 8), b.FLUORESCENT, 900, aim=(0, 2, 1), cone=60)


def build():
    b.new_scene("kessel_turbine_pit", fog_size=(48, 52, 30))
    hidden = pit()
    floodgates()
    wreckage()
    turbine_keeper()
    props()
    lights()
    return hidden


if __name__ == "__main__":
    b.render_shots(SHOTS, cutaway=build())
