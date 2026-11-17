"""Aftermath props everywhere (plan F-15 step 5): barricades where the staff held a door, covered
gurneys and body bags. Same rules as prop_models.py.
"""

import math

import prop_models as p


def _extra():
    from build_models import material

    return {"wood": material("Wood", (0.16, 0.11, 0.065, 1.0), roughness=0.85)}


def build_barricade() -> None:
    """Overturned canteen table braced with planks and a crate. Box 2.4 x 1.4 x 0.9 (long side along x)."""
    from build_models import box

    m = {**p._mats(), **_extra()}
    top = box("TableTop", (2.2, 0.05, 1.0), (0.0, 0.2, 0.55), m["paint"], bevel=0.01)
    top.rotation_euler = (math.radians(-10), 0, 0)
    for x in (-0.95, 0.95):
        box(f"Leg{x}", (0.05, 0.6, 0.05), (x, -0.12, 0.85), m["steel"])
        box(f"LegLow{x}", (0.05, 0.6, 0.05), (x, -0.12, 0.3), m["steel"])
    for i, (x, turn) in enumerate(((-0.5, 22), (0.35, -18), (0.9, 30))):
        plank = box(f"Plank{i}", (0.16, 0.03, 1.3), (x, 0.32, 0.65), m["wood"])
        plank.rotation_euler = (0, math.radians(turn), 0)
    box("Crate", (0.7, 0.6, 0.6), (-0.7, -0.12, 0.3), m["wood"], bevel=0.02)
    box("Sandbag", (0.6, 0.3, 0.18), (0.5, -0.25, 0.09), m["dark"], bevel=0.06)
    p._merge("Barricade")


def build_covered_gurney() -> None:
    """Hospital gurney with a sheet over a body. Box 2.0 x 0.95 x 0.7 (long side along x)."""
    from build_models import box, cylinder

    m = p._mats()
    box("Frame", (1.9, 0.6, 0.05), (0, 0, 0.62), m["steel"])
    for x in (-0.85, 0.85):
        for y in (-0.25, 0.25):
            box(f"Post{x}{y}", (0.03, 0.03, 0.5), (x, y, 0.37), m["steel"])
            cylinder(f"Wheel{x}{y}", 0.05, 0.03, (x, y, 0.05), m["dark"], axis="y")
    box("Sheet", (1.95, 0.68, 0.06), (0, 0, 0.68), m["paper"], bevel=0.025)
    p._blob("Body", 0.32, (0.1, 0.0, 0.72), m["paper"], squash=(2.4, 0.7, 0.32))
    p._blob("Head", 0.13, (-0.72, 0.0, 0.76), m["paper"], squash=(1.0, 1.0, 0.7))
    p._merge("CoveredGurney")


def build_body_bag() -> None:
    """Zipped black body bag lying on the floor (dressing). About 1.9 x 0.6 x 0.3."""
    from build_models import box

    m = p._mats()
    p._blob("Bag", 0.3, (0.0, 0.0, 0.15), m["dark"], squash=(3.1, 0.95, 0.48))
    p._blob("Shoulders", 0.22, (-0.55, 0.0, 0.18), m["dark"], squash=(1.0, 1.25, 0.6))
    box("Zip", (0.9, 0.02, 0.01), (0.05, 0.0, 0.29), m["steel"])
    box("Tag", (0.08, 0.05, 0.005), (0.85, 0.12, 0.2), m["paper"])
    p._merge("BodyBag")


MODELS = {
    "barricade": ("props/barricade.glb", build_barricade),
    "covered_gurney": ("props/covered_gurney.glb", build_covered_gurney),
    "body_bag": ("dressing/body_bag.glb", build_body_bag),
}
