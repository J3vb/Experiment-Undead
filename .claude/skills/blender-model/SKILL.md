---
name: blender-model
description: Build or change a code-made 3D model (zombie, gun, kit piece, prop) with Blender Python in tools/assets/. Use before editing build_models.py, a gun script (rifle_model.py, shotgun_model.py, kestrel_model.py, talon_model.py, gun_parts.py) or adding a new model script.
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
   Guns live in their own files (`rifle_model.py`, `shotgun_model.py`,
   `kestrel_model.py`, `talon_model.py`) and are built from `gun_parts.py`:
   `slab` (extrude a side outline, so grips, stocks and receivers get real
   silhouettes), `lathe` (turn a radius profile: barrels, scopes, knobs, pins),
   `teeth` (accessory rail) and `rounded` (slots, ports, plates). Prefer these
   over stacked boxes for guns.

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
  `EyeR`, `ArmL`, `ArmR`, plus `LegL`, `LegR` (not Crawler). Tripo zombies
  (Shamblers, Bloater, Glower) come from `tripo_intake.py --kind zombie`
  instead. `check_models.py` lists them in `JOINTS`.
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
- Gun surface detail (edge wear, roughness, wood grain, polymer stipple) comes
  from `assets/materials/gun_finish.gdshader`, not textures. The import script
  `tools/assets/gun_finish_import.gd` picks the finish from the Blender material
  name (`FINISHES`: GunMetal, MatteBlack, Tan, OlivePolymer, GreyPolymer, Wood).
  Add `Knurled` to the name (`GunMetalKnurled`) for grip panels and knobs.
  A new gun material name needs a line in `FINISHES`; a new gun's `.import`
  uses that script as `import_script/path`.
- Bevel every visible box edge (`bevel=` on `box`). Unbevelled edges look like
  grey-box placeholders. About 1-3% of the part's smallest size works.
- Each enemy type needs its own silhouette. Check it in black only.

## Budgets and automatic checks

`tools/assets/check_models.py` enforces the rules on every `.glb`: triangle and
material budget per folder (`BUDGETS`: kit 2,000 / 4, weapons 8,000 / 6,
zombies 6,000 / 8), origin, forward axis, named joints with the right parents
(`JOINTS`), closed shells with outward normals, materials. A new gun, zombie,
character or gear model needs a line in `JOINTS`; static models (kit, props,
props_large, dressing, doors, machines, town, town_large) do not.

Those are hard limits, not targets. Today: rifle 6,332 triangles, Talon 7,452,
Shambler 2,904, wall panel 240. Stay close to the similar model. Guns also have
a test cap of 1.5x the rifle in `tests/content/test_generated_models.gd`.
For gear pieces see the budget table in `docs/design/gear-visuals.md`.

Over budget: remove hidden faces and lower cylinder segments before cutting
bevels.

## When you are done

1. Run the same checks as the Assets CI:
   ```bash
   python tools/assets/check_models.py
   npm ci --prefix tools/assets && node tools/assets/validate_gltf.mjs assets/models
   ```
2. Follow the `godot-asset-import` skill (import settings,
   `.import` file, tests).
3. Render it and compare with the reference: `look-check` skill.
4. Commit the script change, the `.glb` and its `.import` together.
5. New model file: add it to its family script's `MODELS`. The Assets CI
   (`tools/assets/check_outputs.py`) fails if a `MODELS` entry is not built or
   a committed `.glb` is not in `MODELS`.
