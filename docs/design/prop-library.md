# Prop library catalogue

One row per code-built prop, dressing piece and town model, so map builders look
here before modelling anything new. Plan: [prop-library.md](../plans/prop-library.md)
(F-77). `tools/ci/test_prop_catalogue.py` fails when a `.glb` in `props/`,
`dressing/`, `town/`, `town_large/` or `props_large/` has no row, or a row names a
missing file. Sizes are the model's bounds in metres (W = x, D = z, H = up),
rounded to 0.1.

## How to use a model

- In a map's `layout.json`, a prop or dressing entry names the model:
  `"model": "barricade"` loads `props/barricade.glb` (or `dressing/` for
  dressing). Any other folder needs its prefix: `"model": "props_large/<name>"`
  or `"model": "town/street_lamp"`.
- Props get a box collider from their layout box; dressing never collides
  (clearance rules: `docs/plans/halcyon-labs-props.md`).
- Render a family to look at it:
  `xvfb-run -s "-screen 0 1600x900x24" godot --path . -s res://tools/prop_lineup.gd -- <Family>`
  saves `screenshots/prop_lineup_<family>.png`. The figure is 1.8 m tall.

## Families

A row can be in more than one family; the lineup tool reads the Families column.

| Family | What | Step |
|---|---|---|
| Halcyon | Halcyon Labs props and dressing (F-15, F-68) | done |
| Town | Lantern Post props and buildings (F-50, F-74) | done |
| Barriers | Barriers and checkpoint | 2 |
| Military | Military camp and vehicles | 3 |
| Industrial | Industrial | 4 |
| Rail | Rail | 5 |
| Large | Large pieces (`props_large/`) | 6 |
| Hospital | Hospital and sanatorium | 7 |
| Heroes | Map hero pieces (`props_large/`) | 8 |
| Outdoor | Outdoor and clutter | 9 |

## Material slots

Models imported with `tools/assets/prop_import.gd` name their Blender materials
after a shared slot, and import swaps in the shared material from
`levels/materials/` (the `SHARED` table): Steel, Dark, Paint, Laminate, Olive,
Wood, Glass, Fluid, JarFluid, Paper, Alarm, SodiumPaint, Hazard, Concrete, Vine,
Screen, Logs, Planks, DarkWood, RoofSnow, Snow, Iron, WindowGlow, Canvas,
SignPaint, TownHazard, Banner, Beacon, Bulb, Pine, and for the library Stone (clean dressed
stone and rock), Tile (`clinic_tile`), Enamel (off-white hospital metal), Ice and
Burlap (sandbags, step 2). Red signal and tail lamps use Beacon. "(own)" marks town models that keep their
embedded colours (`vertex_shading_import.gd`).

## Models

### Props (`assets/models/props/`)

| Name | Folder | W x D x H m | Families | Maps | Slots |
|---|---|---|---|---|---|
| `barricade` | props | 2.4 x 0.8 x 1.3 | Halcyon, Barriers | Halcyon Labs, Kessel Dam, Marrow Junction | Paint, Steel, Wood, Dark |
| `big_tank_cracked` | props | 2.9 x 2.7 x 4.5 | Halcyon | Halcyon Labs | Steel, Glass, Fluid, Hazard |
| `big_tank_shattered` | props | 2.9 x 2.7 x 4.5 | Halcyon | Halcyon Labs | Steel, Glass, Hazard |
| `biohazard_bin` | props | 0.4 x 0.5 x 0.9 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `boom_barrier` | props | 4.6 x 0.6 x 1.1 | Barriers | Kessel Dam, Marrow Junction | Paint, TownHazard, Dark, Beacon |
| `chain_link_fence` | props | 3.1 x 0.1 x 2.0 | Barriers, Industrial | Kessel Dam, Marrow Junction, towns, Halcyon Labs dock | Steel, Dark |
| `chain_link_gate` | props | 2.3 x 0.1 x 2.1 | Barriers, Industrial | Kessel Dam, Marrow Junction, towns, Halcyon Labs dock | Steel, Dark |
| `concrete_block` | props | 1.7 x 0.8 x 0.9 | Barriers | Kessel Dam, Marrow Junction, towns | Concrete, Iron, Olive |
| `covered_gurney` | props | 2.0 x 0.7 x 0.9 | Halcyon, Hospital | Halcyon Labs, Grauwald Sanatorium | Steel, Dark, Paper |
| `crate_large` | props | 1.2 x 1.2 x 1.2 | Halcyon | Halcyon Labs | Wood, Steel, Paper |
| `crate_long` | props | 0.9 x 1.2 x 0.9 | Halcyon | Halcyon Labs | Wood, Steel, Paper |
| `crate_stack` | props | 1.1 x 1.0 x 1.8 | Halcyon, Military | Halcyon Labs, Kessel Dam, Marrow Junction | Wood, Steel, Paper |
| `fallen_barrels` | props | 2.0 x 1.5 x 0.9 | Halcyon | Halcyon Labs | Steel |
| `filing_cabinets` | props | 1.0 x 0.9 x 1.3 | Halcyon, Hospital | Halcyon Labs, Grauwald Sanatorium | Paint, Steel, Dark, Paper |
| `fire_hose_cabinet` | props | 0.7 x 1.0 x 0.9 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `forklift` | props | 2.4 x 1.2 x 2.2 | Halcyon | Halcyon Labs | SodiumPaint, Dark, Steel |
| `fuel_drum` | props | 0.6 x 0.6 x 0.9 | Halcyon, Military | Halcyon Labs, Kessel Dam, Marrow Junction | Olive, Dark, Steel |
| `gas_cylinder_rack` | props | 0.8 x 0.6 x 1.6 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `generator` | props | 4.0 x 2.4 x 2.4 | Halcyon | Halcyon Labs | Dark, Olive, Steel |
| `guard_desk` | props | 2.4 x 1.0 x 1.3 | Halcyon | Halcyon Labs | Paint, Steel, Dark, Screen |
| `hard_case` | props | 0.9 x 0.6 x 0.4 | Barriers, Military | Kessel Dam, Marrow Junction, Halcyon Labs dock, towns | TownHazard, Dark |
| `holding_cell` | props | 2.5 x 2.5 x 3.0 | Halcyon | Halcyon Labs | Dark, Olive, Steel, Alarm |
| `janitor_cart` | props | 0.9 x 0.9 x 1.2 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `jar_shelf` | props | 2.0 x 0.5 x 2.0 | Halcyon | Halcyon Labs | Steel, JarFluid, Dark, Fluid |
| `jersey_barrier` | props | 2.0 x 0.6 x 0.8 | Barriers | Kessel Dam, Marrow Junction, towns, Halcyon Labs dock | Concrete, TownHazard, Dark |
| `kitchen_line` | props | 3.4 x 1.3 x 2.4 | Halcyon | Halcyon Labs | Steel, Paint, Dark, Glass |
| `lab_bench` | props | 7.0 x 1.0 x 1.5 | Halcyon | Halcyon Labs | Dark, Paint, Steel, Screen |
| `lab_cart` | props | 1.0 x 0.6 x 0.9 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `locker_row` | props | 6.0 x 0.6 x 2.0 | Halcyon | Halcyon Labs | Dark, Paint, Steel |
| `mess_table` | props | 9.0 x 2.2 x 0.9 | Halcyon | Halcyon Labs | Laminate, Steel, Dark, Paper |
| `military_cases` | props | 1.3 x 0.6 x 0.7 | Halcyon, Barriers, Military | Halcyon Labs, Kessel Dam, Marrow Junction | Paint, Steel, Dark |
| `office_chair_tipped` | props | 1.1 x 0.75 x 0.7 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `overturned_table` | props | 2.4 x 0.9 x 1.0 | Halcyon | Halcyon Labs | Laminate, Steel |
| `pallet_stack` | props | 1.3 x 0.9 x 0.6 | Barriers, Industrial | Kessel Dam, Marrow Junction, towns, Halcyon Labs dock | Wood |
| `razor_wire_fence` | props | 3.1 x 0.5 x 2.3 | Barriers, Military | Kessel Dam, Marrow Junction | Steel |
| `research_room` | props | 4.0 x 1.1 x 2.8 | Halcyon | Halcyon Labs | Steel, Glass, Vine, Fluid |
| `riot_shield_cases` | props | 0.8 x 0.6 x 1.0 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `sandbag_corner` | props | 1.5 x 1.5 x 0.9 | Barriers, Military | Kessel Dam, Marrow Junction, towns | Burlap |
| `sandbag_wall` | props | 2.1 x 0.5 x 0.9 | Barriers, Military | Kessel Dam, Marrow Junction, towns | Burlap |
| `server_rack_tipped` | props | 1.1 x 1.5 x 2.0 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `serving_counter` | props | 3.5 x 0.8 x 1.4 | Halcyon | Halcyon Labs | Paint, Steel, Dark, Glass |
| `specimen_tank` | props | 1.2 x 1.2 x 2.7 | Halcyon | Halcyon Labs | Steel, Dark, Glass, Fluid |
| `supply_shelving` | props | 1.2 x 0.5 x 2.0 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `supply_truck` | props | 2.6 x 7.1 x 2.8 | Halcyon, Military | Halcyon Labs, Kessel Dam, Marrow Junction | Dark, Olive, Steel |
| `tool_cart` | props | 1.0 x 0.6 x 1.0 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `toppled_console` | props | 1.3 x 1.1 x 0.9 | Halcyon | Halcyon Labs | Paint, Dark, Screen |
| `vending_machine` | props | 0.9 x 0.9 x 1.9 | Halcyon | Halcyon Labs | Alarm, Screen, Dark, Steel |
| `water_cooler` | props | 0.4 x 0.4 x 1.3 | Halcyon | Halcyon Labs | Baked (Tripo) |
| `wheelchair` | props | 0.6 x 1.0 x 0.9 | Halcyon | Halcyon Labs | Baked (Tripo) |

### Dressing (`assets/models/dressing/`)

| Name | Folder | W x D x H m | Families | Maps | Slots |
|---|---|---|---|---|---|
| `body_bag` | dressing | 1.8 x 0.6 x 0.3 | Halcyon, Hospital | Halcyon Labs, Grauwald Sanatorium | Dark, Steel, Paper |
| `catwalk_office` | dressing | 5.0 x 2.2 x 3.7 | Halcyon | Halcyon Labs | Steel, Hazard, Dark |
| `ceiling_containment_wing` | dressing | 15.8 x 27.8 x 2.2 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_coolant_tunnel` | dressing | 7.8 x 2.8 x 0.7 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_generator_hall` | dressing | 19.8 x 19.8 x 2.1 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_guard_post` | dressing | 11.8 x 19.8 x 0.8 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_labs` | dressing | 15.8 x 15.8 x 0.8 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_loading_dock` | dressing | 23.8 x 13.8 x 1.2 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_main_corridor` | dressing | 29.8 x 3.8 x 0.8 | Halcyon | Halcyon Labs (room fit) | Steel |
| `ceiling_mess_hall` | dressing | 19.8 x 15.8 x 2.1 | Halcyon | Halcyon Labs (room fit) | Steel |
| `fenlight_spill` | dressing | 1.8 x 1.2 x 0.4 | Halcyon | Halcyon Labs | Vine, Fluid |
| `floor_cables` | dressing | 4.0 x 1.3 x 0.1 | Halcyon | Halcyon Labs | Dark |
| `hanging_strip` | dressing | 0.7 x 0.2 x 4.0 | Halcyon | Halcyon Labs | Dark, Steel |
| `hazard_sign` | dressing | 0.6 x 0.0 x 0.4 | Halcyon | Halcyon Labs | Paper, Alarm, Dark |
| `jerrycan_pair` | dressing | 0.8 x 0.3 x 0.5 | Barriers, Military | Kessel Dam, Marrow Junction, towns | Paint, Dark |
| `lab_floor_wreck` | dressing | 1.5 x 1.1 x 0.3 | Halcyon | Halcyon Labs | Dark, Steel, Fluid, Paper |
| `lab_papers` | dressing | 1.5 x 0.9 x 0.0 | Halcyon | Halcyon Labs | Paper, Dark |
| `mess_spill` | dressing | 2.2 x 1.8 x 0.4 | Halcyon | Halcyon Labs | Laminate, Steel, Dark, Paper |
| `pipe_run_3` | dressing | 3.0 x 0.3 x 0.4 | Halcyon, Industrial | Halcyon Labs, Kessel Dam, Marrow Junction, Grauwald Sanatorium | Dark, Steel, Olive, Alarm |
| `pipe_run_6` | dressing | 6.0 x 0.3 x 0.4 | Halcyon, Industrial | Halcyon Labs, Kessel Dam, Marrow Junction, Grauwald Sanatorium | Dark, Steel, Olive, Alarm |
| `screen_pair` | dressing | 2.0 x 0.1 x 0.7 | Halcyon | Halcyon Labs | Steel, Dark, Screen, Glass |
| `vine_ceiling` | dressing | 2.0 x 0.7 x 1.3 | Halcyon | Halcyon Labs | Vine, Fluid |
| `vine_pillar` | dressing | 1.5 x 1.5 x 2.3 | Halcyon | Halcyon Labs | Vine, Fluid |
| `vine_wall` | dressing | 2.2 x 0.3 x 2.6 | Halcyon | Halcyon Labs | Vine, Fluid |
| `vine_wall_small` | dressing | 1.2 x 0.3 x 1.8 | Halcyon | Halcyon Labs | Vine, Fluid |

### Town props (`assets/models/town/`)

| Name | Folder | W x D x H m | Families | Maps | Slots |
|---|---|---|---|---|---|
| `ammo_case` | town | 0.8 x 0.4 x 0.4 | Town | Lantern Post | Olive, Iron, Snow |
| `banner` | town | 1.6 x 0.2 x 4.4 | Town | Lantern Post | Banner, Iron, Snow |
| `bench` | town | 1.8 x 0.4 x 0.6 | Town | Lantern Post | Planks, DarkWood, Snow |
| `fence_rail` | town | 3.0 x 0.2 x 1.2 | Town | Lantern Post | DarkWood, Snow, Planks |
| `fenlight_crate` | town | 0.9 x 0.6 x 0.5 | Town | Lantern Post | Planks, DarkWood, Fluid, Iron |
| `fire_barrel` | town | 0.6 x 0.6 x 1.2 | Town | Lantern Post | Iron, Bulb, DarkWood |
| `firewood_stack` | town | 1.9 x 0.9 x 1.0 | Town | Lantern Post | Logs, DarkWood, Snow |
| `floodlight` | town | 0.8 x 0.5 x 2.1 | Town | Lantern Post | Iron, Snow, Bulb |
| `gun_wall` | town | 3.0 x 0.2 x 2.0 | Town | Lantern Post | Planks, DarkWood, Iron |
| `lantern_hanging` | town | 0.2 x 0.2 x 0.5 | Town | Lantern Post | Iron, Bulb |
| `lantern_table` | town | 0.2 x 0.2 x 0.3 | Town | Lantern Post | Iron, Bulb |
| `missions_board` | town | 3.2 x 0.5 x 2.5 | Town | Lantern Post | DarkWood, Paper, Snow, Bulb |
| `pine_tree` | town | 4.3 x 4.3 x 10.1 | Town, Outdoor | Lantern Post, Grauwald Sanatorium, Kessel Dam | DarkWood, Pine, Snow |
| `signpost` | town | 2.0 x 0.5 x 2.7 | Town | Lantern Post | SignWood (own), SignPost (own) |
| `snow_drift_a` | town | 2.4 x 1.0 x 0.4 | Town, Outdoor | Lantern Post, Grauwald Sanatorium, Kessel Dam | Snow |
| `snow_drift_b` | town | 1.4 x 1.2 x 0.6 | Town, Outdoor | Lantern Post, Grauwald Sanatorium, Kessel Dam | Snow |
| `stall_frame` | town | 4.2 x 3.3 x 3.2 | Town | Lantern Post | Planks, Canvas, Snow, Bulb |
| `stall_sign` | town | 3.6 x 0.1 x 1.0 | Town | Lantern Post | SignPaint, DarkWood, Snow, Iron |
| `street_lamp` | town | 0.7 x 1.0 x 4.6 | Town | Lantern Post | Iron, LampGlass (own), Stone |
| `string_lights` | town | 9.2 x 0.1 x 0.7 | Town | Lantern Post | Iron, Bulb |
| `supply_crate_large` | town | 1.0 x 0.8 x 0.8 | Town | Lantern Post | Planks, DarkWood, Snow |
| `supply_crate_small` | town | 0.6 x 0.5 x 0.5 | Town | Lantern Post | Planks, DarkWood, Snow |
| `tech_desk` | town | 2.0 x 0.8 x 1.5 | Town | Lantern Post | Planks, DarkWood, Iron, Screen |
| `trader_goods` | town | 1.8 x 0.6 x 0.7 | Town | Lantern Post | Planks, Olive, Iron, Paper |
| `wall_lantern` | town | 0.5 x 0.5 x 0.4 | Town | Lantern Post | Iron, LampGlass (own) |
| `window_dark` | town | 2.1 x 0.3 x 1.4 | Town | Lantern Post | DarkGlass (own), WindowFrame (own), Stone (own), Shutter (own) |
| `window_lit` | town | 2.1 x 0.3 x 1.4 | Town | Lantern Post | WindowGlow (own), WindowFrame (own), Stone (own), Shutter (own) |
| `workbench` | town | 2.0 x 1.1 x 1.2 | Town | Lantern Post | Planks, DarkWood, Iron, Bulb |

### Town buildings (`assets/models/town_large/`)

| Name | Folder | W x D x H m | Families | Maps | Slots |
|---|---|---|---|---|---|
| `cabin_small` | town_large | 7.3 x 6.8 x 5.5 | Town | Lantern Post | Logs, Planks, RoofSnow, Snow, DarkWood, WindowGlow |
| `cabin_two_storey` | town_large | 7.5 x 6.5 x 8.5 | Town | Lantern Post | Logs, Planks, RoofSnow, Snow, DarkWood, WindowGlow |
| `gate_tunnel` | town_large | 10.2 x 14.8 x 9.1 | Town | Lantern Post | Concrete, Snow, Iron, TownHazard, Fluid |
| `gate_wall` | town_large | 8.0 x 3.3 x 8.3 | Town | Lantern Post | Concrete, Snow, Iron |
| `lodge_common_room` | town_large | 15.3 x 9.7 x 10.0 | Town | Lantern Post | Logs, DarkWood, RoofSnow, Snow, Iron, WindowGlow |
| `lodge_lantern_post` | town_large | 14.2 x 9.5 x 11.3 | Town | Lantern Post | Logs, Planks, RoofSnow, Snow, DarkWood, WindowGlow |
| `radio_mast` | town_large | 3.3 x 3.2 x 29.9 | Town | Lantern Post | Concrete, Snow, Iron, Beacon |
| `shed_lean_to` | town_large | 4.2 x 3.4 x 3.1 | Town | Lantern Post | Planks, DarkWood, RoofSnow, Snow, Logs |
| `stall_gunsmith` | town_large | 4.2 x 3.2 x 4.0 | Town | Lantern Post | Baked (Tripo) |
| `stall_technician` | town_large | 4.2 x 4.1 x 3.3 | Town | Lantern Post | Baked (Tripo) |
| `stall_trader` | town_large | 4.2 x 2.6 x 3.2 | Town | Lantern Post | Baked (Tripo) |
| `watchtower` | town_large | 4.7 x 4.8 x 12.7 | Town | Lantern Post | DarkWood, Planks, Snow, RoofSnow, Iron, WindowGlow |
