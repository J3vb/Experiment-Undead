"""Halcyon Labs machine models (plan F-64): the wall-buy weapon racks and the Specimen Vault.

Same rules as door_models.py: one merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z), and it fits inside the box it replaces. Slots map to the shared Halcyon materials
through prop_import.gd. Racks you buy carry the `Hazard` band like bought doors; the gun itself is not
part of the model (WallBuy hangs `WeaponData.world_model` on the rack's GunMount).
"""

from functools import partial

import prop_models as p

RACK_W, RACK_D, RACK_H = 1.6, 0.1, 0.8
VAULT_W, VAULT_D = 2.0, 0.96
CORE_D = 0.8


def _mats() -> dict:
    from build_models import material, srgb

    m = p._mats()
    return {
        "hazard": material("Hazard", srgb("#D96614"), metallic=0.4, roughness=0.6),
        "dark": m["dark"],
        "steel": m["steel"],
        "glass": m["glass"],
        "fluid": m["fluid"],
        "paper": m["paper"],
    }


def build_weapon_rack(cold: bool) -> None:
    """Wall rack for a wall gun: steel frame round a backplate, two rubber clamps the gun rests on and a
    stencil plate. Bought racks get a hazard band; the cold one (free secret) has frost instead.
    Box 1.6 x 0.1 x 0.8, back flat on the wall (+Y)."""
    from build_models import box

    m = _mats()
    back = RACK_D / 2
    # Backplate in 4 x 2 tiles: AO is baked per corner, so one big face framed on every side would bake
    # dark all over; tile corners in the open stay light and the black gun reads against them.
    tile_w, tile_h = (RACK_W - 0.08) / 4, (RACK_H - 0.08) / 2
    for i in range(4):
        for j in range(2):
            at = (-RACK_W / 2 + 0.04 + tile_w * (i + 0.5), back - 0.0125, 0.04 + tile_h * (j + 0.5))
            box(f"Backplate{i}{j}", (tile_w, 0.025, tile_h), at, m["paper"])
    for k, z in enumerate((0.02, RACK_H - 0.02)):
        box(f"Rail{k}", (RACK_W, 0.04, 0.04), (0, back - 0.02, z), m["steel"], bevel=0.008)
    for k, x in enumerate((-(RACK_W / 2 - 0.02), RACK_W / 2 - 0.02)):
        box(f"Stile{k}", (0.04, 0.04, RACK_H - 0.08), (x, back - 0.02, RACK_H / 2), m["steel"])
        for j, z in enumerate((0.1, RACK_H - 0.1)):
            box(f"Bolt{k}{j}", (0.025, 0.01, 0.025), (x, back - 0.045, z), m["dark"])
    face = back - 0.025
    for k, x in enumerate((-0.42, 0.42)):
        box(f"Clamp{k}", (0.08, 0.04, 0.12), (x, face - 0.02, 0.36), m["dark"])
        box(f"ClampLip{k}", (0.08, 0.035, 0.03), (x, face - 0.04 - 0.0175, 0.315), m["dark"])
    box("Stencil", (0.3, 0.008, 0.1), (-0.5, face - 0.004, 0.13), m["steel"])
    for k, z in enumerate((0.15, 0.11)):
        box(f"StencilMark{k}", (0.22 - k * 0.08, 0.004, 0.02), (-0.52 + k * 0.04, face - 0.01, z), m["dark"])
    if cold:
        for k, (x, w) in enumerate(((-0.45, 0.5), (0.2, 0.36), (0.6, 0.22))):
            box(f"Frost{k}", (w, 0.012, 0.035), (x, face - 0.006, 0.0575), m["glass"])
    else:
        box("HazardBand", (RACK_W - 0.16, 0.01, 0.07), (0, face - 0.005, 0.68), m["hazard"])
    p._merge("WeaponRackCold" if cold else "WeaponRack")


def _vault_side(m, side: int) -> None:
    """Window frame on one long side (side -1 front, 1 back): two rows of green vials behind glass."""
    from build_models import box

    inner, outer = side * CORE_D / 2, side * VAULT_D / 2
    mid, depth = (inner + outer) / 2, abs(outer - inner)
    box(f"FrameLow{side}", (VAULT_W, depth, 0.14), (0, mid, 0.15), m["steel"])
    box(f"FrameTop{side}", (VAULT_W, depth, 0.18), (0, mid, 0.73), m["steel"])
    for k, x in enumerate((-0.825, 0.825)):
        box(f"Post{side}{k}", (0.35, depth, 0.42), (x, mid, 0.43), m["steel"])
    box(f"Liner{side}", (1.3, 0.005, 0.42), (0, inner + side * 0.0025, 0.43), m["dark"])
    box(f"Shelf{side}", (1.3, 0.065, 0.02), (0, inner + side * 0.0375, 0.43), m["dark"])
    vial_y = inner + side * 0.04
    for row, z in enumerate((0.22, 0.44)):
        for i in range(8):
            if (i + row) % 5 != 3:
                p._cyl(f"Vial{side}{row}{i}", 0.024, 0.15, (-0.56 + i * 0.16, vial_y, z), m["fluid"], verts=8)
    box(f"Glass{side}", (1.3, 0.01, 0.42), (0, outer - side * 0.005, 0.43), m["glass"])
    box(f"Plate{side}", (0.4, 0.005, 0.08), (0.5, outer + side * 0.0025, 0.73), m["dark"])


def build_specimen_vault() -> None:
    """Oriel sample archive: steel chest on a dark plinth, a glass window on both long sides (the Vault
    spots face it either way) with green vials on a shelf, a dark groove for the scene's Glow strip at
    0.82-0.88 m and a hatch on the lid. Box 2.0 x 1.0 x 1.0."""
    from build_models import box

    m = _mats()
    box("Plinth", (VAULT_W - 0.1, CORE_D + 0.1, 0.08), (0, 0, 0.04), m["dark"])
    box("Core", (VAULT_W, CORE_D, 0.74), (0, 0, 0.45), m["steel"])
    for side in (-1, 1):
        _vault_side(m, side)
    box("Groove", (VAULT_W - 0.06, VAULT_D - 0.06, 0.06), (0, 0, 0.85), m["dark"])
    box("Lid", (VAULT_W, VAULT_D, 0.11), (0, 0, 0.935), m["steel"], bevel=0.02)
    box("Hatch", (1.4, 0.6, 0.01), (0, 0, 0.995), m["dark"])
    for k, x in enumerate((-(VAULT_W / 2 + 0.005), VAULT_W / 2 + 0.005)):
        box(f"Vent{k}", (0.01, 0.5, 0.3), (x, 0, 0.45), m["dark"])
    p._merge("SpecimenVault")


MODELS = {
    "weapon_rack": ("machines/weapon_rack.glb", partial(build_weapon_rack, False)),
    "weapon_rack_cold": ("machines/weapon_rack_cold.glb", partial(build_weapon_rack, True)),
    "specimen_vault": ("machines/specimen_vault.glb", build_specimen_vault),
}
