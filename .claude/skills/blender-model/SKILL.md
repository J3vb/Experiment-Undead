---
name: blender-model
description: Build or change a code-made 3D model (zombie, gun, kit piece, prop) with Blender Python in tools/assets/. Use before editing build_models.py, kestrel_model.py, talon_model.py or adding a new model script.
---

# Build a model with Blender Python

Models are built in code, not by hand. The script in `tools/assets/` is the
source; the `.glb` in `assets/models/` is its output. Never hand-edit a `.glb`.

## Before you start

1. Read `docs/design/look-rules.md` (palette, rules, "Models built in code").
2. Look at the reference render for what you build: `docs/design/images/style_lineup.jpg`
   (zombies), `style_corridor.jpg` (kit), `weapon_comparison_*.png` (guns).
3. Find a similar model in `tools/assets/build_models.py` and copy its pattern.
   Reuse the helpers there (`box`, `cylinder`, `ball`, `limb`, `attach`,
   `tilted_box`, `head`, `material`, `srgb`, `marker`, `join_into`).

## Setup and build

```bash
pip install -r tools/assets/requirements.txt     # Python 3.13, bpy as a module
python tools/assets/build_models.py              # all models
python tools/assets/build_models.py shambler     # one model
python tools/assets/build_models.py --out /tmp/m # build somewhere else to compare
```

A new model is one `build_<name>()` function plus one line in `MODELS`
(`"name": ("folder/file.glb", build_name)`). If `build_models.py` would pass
350 lines, put the model in its own file next to it (like `kestrel_model.py`).

## Axes and pivots (most common mistakes)

- Units are metres. Blender +Z is up. The exporter (`export_yup=True`) turns
  Blender -Y into Godot +Z and Blender +Y into Godot -Z.
- **Guns** point down Blender +Y, so Godot -Z. Moving parts are separate,
  named objects: `Magazine`, `Bolt` (also the shotgun pump), `Muzzle` marker.
- **Zombies face Blender -Y, which is Godot +Z.** Feet at z = 0.
- Every part that code swings is its own object with its **origin at the
  joint** (shoulder, hip, knee, neck). Use `attach(obj, pivot, parent)` and
  `limb()`. Zombie part names code needs: `Hips`, `Torso`, `Head`, `EyeL`,
  `EyeR`, `ArmL`, `ArmR` (Bloater also `Belly`).
- Kit pieces: origin at floor level on the wall's back edge, sized to the 2 m
  grid (wall panel is 2.0 x 0.2 x 2.7).

## Look rules for models

- Colours come from the hex values in `look-rules.md`, converted with
  `srgb("#RRGGBB")`. Do not invent new colours.
- Zombie head is always the lightest value in the silhouette.
- Glow (the `glow` argument) only on bio-green parts: eyes, Bloater belly,
  Vault, Reforger. Never on clothes or guns.
- Guns: matte black, gunmetal, polymer and one secondary colour (tan, olive
  or grey). No brand marks. Original shapes.
- Bevel every visible box edge (`bevel=` on `box`). Unbevelled edges look like
  grey-box placeholders. About 1-3% of the part's smallest size works.
- Each enemy type needs its own silhouette. Check it in black only.

## Triangle budgets (provisional)

Count with the test in `tests/content/test_generated_models.gd` (`_triangle_count`).

| Model | Budget | Today |
|---|---|---|
| Gun (first person) | 1.5x the rifle (about 4,800), CI checks this | rifle 3,192, Talon 4,756 |
| Zombie | 4,000 (24 alive at once) | Shambler 2,976, Bloater 3,028 |
| Kit piece | 1,000 | wall panel 240 |
| Gear pieces | see `docs/design/gear-visuals.md` budget table | |

Over budget: remove hidden faces and lower cylinder segments before cutting
bevels.

## When you are done

1. Build it, then follow the `godot-asset-import` skill (import settings,
   `.import` file, tests).
2. Render it and compare with the reference: `look-check` skill.
3. Commit the script change, the `.glb` and its `.import` together.
4. New model file: add it to the file list in `.github/workflows/assets.yml`.
