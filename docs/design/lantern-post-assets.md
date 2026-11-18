# Lantern Post asset list

Every model the town needs to match the concept art
([images/lantern_post_concept.jpg](images/lantern_post_concept.jpg)), built with
Blender Python in `tools/assets/` and exported to `assets/models/town/` (props) or
`assets/models/town_large/` (buildings and the gate; the folder picks the budget). Plan and
build order: [docs/plans/lantern-post-concept.md](../plans/lantern-post-concept.md).
Layout map: [images/lantern_post_layout.png](images/lantern_post_layout.png).

The old grey-box houses, palisade gate and boxes in the scene generator are
replaced by these models. The generator only places them.

## Rules for every town model

- Same pipeline as the Halcyon Labs props (`docs/plans/halcyon-labs-props.md`):
  one mesh per model, origin at the bottom centre, front faces Godot +Z, metres.
- Materials use only the shared slot names below. `prop_import.gd` swaps each
  slot for the shared textured material in `levels/materials/`, so the whole
  town shares a handful of materials and batches well.
- Budgets (check_models.py): `town` 2,500 triangles / 4 materials for props;
  `town_large` 12,000 triangles / 6 materials for buildings and the gate.
  With six materials a building picks its slots: sign text is a Label3D and
  lanterns are the `wall_lantern` model, both placed by the generator.
- Colliders: buildings and blocking props get a simple box collider in the
  scene (the generator's `Block` nodes, invisible), never mesh colliders.
- Glow parts (windows, lamps, Fenlight jars, tunnel strips) are emissive
  material slots, not lights. Real lights are placed by the generator and stay
  inside the light budget (6 shadowed, 30 total).
- Snow is part of the model (roof caps, ledges, drifts at the base), using the
  `Snow` slot, so every building sits in the snow like the concept.
- Each model gets an approved turnaround in `docs/design/turnarounds/town/`.

## Shared material slots

| Slot | Look | Used on |
|---|---|---|
| `Logs` | Dark weathered log walls, round ends | Lodges, cabins |
| `Planks` | Vertical dark planks, grey worn edges | Stalls, porches, crates |
| `DarkWood` | Near-black beams and posts | Frames, rails, legs |
| `RoofSnow` | Corrugated or shingle roof with snow on top | All roofs |
| `Snow` | Soft snow, slightly blue | Caps, drifts, ledges |
| `Iron` | Dark rusty metal | Lamps, barrels, rails, mast |
| `Concrete` | Stained grey concrete | Gate wall, tunnel, blocks |
| `Hazard` | Yellow and black stripes | Gate posts, tunnel mouth |
| `Canvas` | Dark olive-grey tarp | Stall awnings, sign cloths |
| `Banner` | Deep maroon cloth with the outpost emblem in light grey | Banners |
| `SignPaint` | Painted letters on wood or metal, light on dark | Sign boards |
| `WindowGlow` | Warm emissive glass | Windows |
| `SodiumPaint` | Warm emissive bulb | Lamps, string lights, lanterns |
| `Fluid` | Bio-green emissive liquid (#8DFF3A) | Fenlight jars, Deploy chevrons, tunnel strips |
| `Paper` | Off-white notes and maps | Missions board |
| `Screen` | Blue-green monitor glow | Technician monitors |

`prop_import.gd` maps each slot to its material. Mapped in step 2: `Logs`
(`town_logs.tres`, round-log grain), `Planks`, `DarkWood`, `RoofSnow`
(`town_slate.tres`), `Snow`, `Iron`, `WindowGlow` (`lit_window.tres`), plus the
Halcyon slots the town reuses as they are (`Concrete`, `Hazard`, `Fluid`,
`Paper`, `Screen`, `SodiumPaint`, and `Olive` for the ammo tins). Step 3 adds
`Canvas` (`town_canvas.tres`) and `SignPaint` (`town_sign_paint.tres`). `Banner`
gets its material in step 4 with the banner model, the first model that uses it.

Built so far: B1-B2 in `tools/assets/town_buildings.py`, B3-B6 in
`tools/assets/town_cabins.py` (same helpers), S1-S7 in `tools/assets/town_market.py`.

## 1. Buildings (`town_large`)

| # | Model id | What | Size (m) | Notes |
|---|---|---|---|---|
| B1 | `lodge_lantern_post` | The big two-storey log lodge with the painted "LANTERN POST" sign on its gable and a hanging lantern | 12 x 9 x 11 | Front porch with roof, upper windows, icicles on the eaves. West side, by the plaza |
| B2 | `lodge_common_room` | Two-storey lodge with a long first-floor balcony and rail, string lights, "COMMON ROOM" board, satellite dish, stone chimney | 14 x 9 x 10 | Big lit windows downstairs; balcony overlooks the street. West side, north end |
| B3 | `cabin_small` | One-storey log cabin, porch, two windows | 7 x 6 x 6 | East side, used 2 times (mirrored) |
| B4 | `cabin_two_storey` | Narrow two-storey cabin with a side stair | 7 x 7 x 9 | East side, used 2 times |
| B5 | `shed_lean_to` | Lean-to shed with firewood stacked under it | 4 x 3 x 3 | Back yards, used 4 times |
| B6 | `watchtower` | Timber tower on four legs with a ladder, roofed platform, rail, floodlight and spotlight mount | 4 x 4 x 13 | Next to the gate, east |

## 2. Market row (stalls, `town`)

| # | Model id | What | Size (m) | Notes |
|---|---|---|---|---|
| S1 | `stall_frame` | Timber stall: four posts, counter, sloped canvas awning with snow, hanging lamp | 4 x 3 x 3.2 | Base for the four stalls; sign board is a separate model |
| S2 | `stall_sign` | Long cloth or plank sign board above a stall; text and icon come from a Label3D and a decal so one model serves all four | 3.6 x 0.1 x 0.8 | Signs: MISSIONS, TRADER "Buy / Sell", GUNSMITH "Upgrades / Mods", TECHNICIAN "Serums / Gear" |
| S3 | `missions_board` | Big notice board: map, pinned notes and photos, roof cap, lamp | 3 x 0.4 x 2.6 | Front of the Missions stall |
| S4 | `trader_goods` | Counter dressing: crates, ammo tins, a scale, cash box | 2 x 0.8 x 0.6 | Trader stall |
| S5 | `gun_wall` | Pegboard wall with tools and three rifles hung on it | 3 x 0.2 x 2 | Gunsmith stall; guns are simple silhouettes, not the real gun models |
| S6 | `workbench` | Heavy bench with a vice, tools, a lamp | 2 x 0.8 x 1 | Gunsmith stall |
| S7 | `tech_desk` | Desk with two monitors, a radio set and cables | 2 x 0.8 x 1.4 | Technician stall; monitors use `Screen` |

## 3. Deploy gate (`town_large` unless noted)

| # | Model id | What | Size (m) | Notes |
|---|---|---|---|---|
| G1 | `gate_wall` | Thick concrete wall section with a walkway and rail on top | 8 x 3 x 8 | Repeats across the north end, 4 sections |
| G2 | `gate_tunnel` | The tunnel mouth: concrete frame, "DEPLOY" with green chevrons, hazard striped posts, inner tunnel 12 m deep with green strip lights and a closed blast door at the far end | 10 x 14 x 9 | The Deploy board stands in front. Tunnel floor walkable to 3 m, then a collider |
| G3 | `banner` (`town`) | Hanging maroon banner on an iron pole with the outpost emblem | 1.4 x 0.2 x 4.5 | 4 on the gate wall, 1 on the Common Room |
| G4 | `floodlight` (`town`) | Box floodlight on a short pole or wall bracket | 0.8 x 0.8 x 2 | On the gate wall and watchtower |
| G5 | `radio_mast` | Lattice mast with dish and red beacons | 3 x 3 x 30 | On the ridge (replaces the step 1 box mast) |

## 4. Props (`town`)

| # | Model id | What | Notes |
|---|---|---|---|
| P1 | `fire_barrel` | Rusty barrel with holes, burning wood inside | Fire is a particle and one flickering light per barrel |
| P2 | `bench` | Heavy timber bench | Around the fire barrels |
| P3 | `crate_large`, `crate_small` | Planked supply crates with snow on top | Stacked in groups |
| P4 | `ammo_case` | Olive metal case with handles | Stacks by the stalls |
| P5 | `fenlight_crate` | Open crate of glass jars glowing bio-green, "FENLIGHT SAMPLES" stencil | 2 in town, by the Technician |
| P6 | `lantern_hanging` | Hanging oil lantern | Porches and posts |
| P7 | `lantern_table` | Small table lantern | On benches and counters |
| P8 | `string_lights` | A 6 m sagging wire with bulbs | Across the street and on the balcony |
| P9 | `street_lamp` | Keep the current model, retexture to `Iron` | Street |
| P10 | `fence_rail` | Split-rail timber fence, 3 m | Yards |
| P11 | `snow_drift_a`, `snow_drift_b` | Soft drift shapes | Along walls and stall bases |
| P12 | `firewood_stack` | Log pile | Yards, by the cabins |
| P13 | `pine_tree` | Snowy pine in 3 sizes (one model, scaled) | Replaces the cone pines |
| P14 | `sign_post` | Keep the current model | Plaza |

## 5. Not models

| Item | How it is made |
|---|---|
| Snowfall, chimney smoke, fire | GPUParticles3D scenes (step 1, fire in step 5) |
| Sky, aurora, mountains | Sky shader (step 1) |
| Mud road and puddles | `town_mud` shader (step 1) |
| Sign text | Label3D on the sign models, so names stay editable |
| People at the stalls | Not in this plan (F-45 NPCs) |

## Count

6 buildings, 7 market models, 5 gate models, 14 props: 32 models.
