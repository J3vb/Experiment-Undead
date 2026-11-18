# Plan: Shared prop library for future maps

Status: Review
Roadmap: F-77
Phase: art track ahead of the Act I maps (Kessel Dam is next in the maps.md build order)
Size: L
Approved by:

## Goal

A ready-made library of about 70 code-built props, so building Kessel Dam,
Marrow Junction, Grauwald Sanatorium and later towns is placing models in
`layout.json`, not modelling first. Props are generic kit pieces that fit more
than one map (barriers, vehicles, fences, pipes, rail pieces, hospital
furniture, trees and rocks), in the Cold Containment look. Serves "The
pressure always builds" (readable cover and lanes) and keeps map building
fast and cheap.

## Scope

In:

- About 70 new props and dressing models in seven families (list below), each
  built by script in `tools/assets/library_<family>.py` with the existing
  pipeline (`build_models.py`, `finish.finish()`, `check_models.py`, glTF
  validator, turnarounds, `prop_import.gd` shared slots).
- A catalogue, `docs/design/prop-library.md`: one row per model (name, folder,
  size in metres, families, which maps it suits, material slots), covering the
  51 Halcyon props and dressing models that already exist too, so there is one
  place to look before modelling anything.
- A catalogue check (Python, in `tools/assets/tests/`) that fails when a model
  in `props/`, `dressing/` or `props_large/` has no catalogue row, or a row
  names a missing file.
- A lineup render, `tools/prop_lineup.gd`: one family per image, models in a
  row under Cold Containment light with a 1.8 m figure for scale. Each step's
  board goes in `docs/design/prop-library/` and to the person on a decision
  card.
- A few new shared material slots for outdoor and hospital surfaces (Stone,
  Tile, Enamel, Ice, SignalLamp; final list in step 1), added to
  `prop_import.gd` like the town slots were.
- `props_large/` folder for big pieces (train car, signal gantry, container
  stack) with the `town_large` budget, and a small builder change so a
  `layout.json` prop or dressing entry can name `"model": "props_large/<name>"`.

The families (sizes are real-world; final list fixed per step):

| Family | Models | Suits |
|---|---|---|
| 1 Barriers and checkpoint | jersey barrier (yellow-black), concrete block, sandbag wall straight + corner, boom barrier, chain-link fence + gate, razor-wire fence, yellow hard case, jerrycan pair, pallet stack | Kessel crest, Marrow gate, towns, Halcyon dock |
| 2 Military camp and vehicles | canvas-top army truck, armoured car, field tent, field table with laptop and radio, ammo crate stack, portable generator, floodlight tripod, body under tarp (dressing) | Kessel crest, Marrow gate, towns |
| 3 Industrial | yellow guard rail section, big pipe straight + elbow + valve wheel, electrical cabinet, transformer, cable reel, wall ladder, sodium street lamp (cobra head), control desk, steel stair landing rail | Kessel, Marrow substation, Grauwald boiler room |
| 4 Rail | track section, buffer stop, signal post with red lamps, shipping container closed + open, flatbed wagon, platform bench, luggage pile (dressing), station sign | Marrow, later rail maps |
| 5 Large pieces | hospital train car, last car with green glow, signal gantry, container stack (3 high) | Marrow, towns |
| 6 Hospital and sanatorium | iron hospital bed, wheelchair, IV stand, medical trolley, privacy screen, glass-front cabinet, bathtub, reception desk, chapel pew, wall radiator | Grauwald, Halcyon med rooms, town clinic |
| 7 Outdoor and clutter | dead tree, pine tree, rock cluster, iron gate with stone posts and lanterns, iron fence section, iron park bench, snow drift (dressing), leaf litter (dressing), trash bags, cardboard boxes | Grauwald, Kessel, Marrow, towns |

Not in (non-goals, and where each one goes instead):

- One-off hero pieces whose shape depends on the map layout: the frozen
  fountain, turbine housings, the dam control building, the sanatorium front
  and cupola (later: each map's own build, which can reuse library parts).
- Placing props in any map, or new map layouts (later: each map's F-row).
- Snow or rain on props as variants: props stay clean; snowy maps add snow
  with library dressing (snow drift) or a top-snow material in their own
  build.
- Animated or moving props (the shunting loco, boom barrier that opens, flood
  water): gameplay pieces are built with their map event. The boom barrier
  here is a static model.
- Asset packs: stage B after v0.1 (ADR 0008).
- LODs and visibility ranges: only when a map's perf capture asks for them
  (`docs/design/maps.md#performance-budget`).

## Ready to build

```
### Ready to build
- Foundations touched: 11 Asset pipeline (solid: build_models.py, finish.py, check_models.py,
  glTF validator, turnarounds), 9 Tests and CI (solid). Nothing shaky.
- Decision records: 0008 code-built assets first (this is that pipeline). Goes against one: no.
- Co-op:
  - Who decides: nobody; props are static scenery in each map's blockout, identical on every peer.
  - How a client triggers it: n.a. (no interaction).
  - What other players see: the same scene; nothing is sent.
  - Works on a dedicated server with no local player: yes (meshes load, colliders as boxes).
- Data: no Resource type. Model names live in layout.json per map and in the catalogue.
  Code compares against a specific id: no (the builder reads "model" as a file name).
- Save: no change. Renames or removes a saved id: no.
- Events and UI: none.
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a. (no runtime code).
- Tests: check_models.py rules per folder, catalogue check, tests/content/test_prop_library.gd
  (models load, light_baking 2, slots mapped, no flat surfaces), builder test for props_large.
- Logging: none (no runtime system).
- Performance: nothing created at run time. Budgets below; one mesh per model.
- Out of scope: as listed under "Not in".
```

## Design references

- `docs/design/maps.md`: Kessel Dam, Marrow Junction and Grauwald Sanatorium
  "Key props" lists (this plan's families come from them), "Pass 1: the
  style-guide look" (the prop kit list) and "Performance budget".
- Key shots: `docs/design/concepts/act1/keyshots/kessel_dam.jpg`,
  `marrow_junction.jpg`, `grauwald_sanatorium.jpg`.
- `docs/design/look-rules.md`: Palette, Rules 2-5 (bio-green only on the
  experiment, so only the green train car glows; outside warm), Materials,
  Models built in code.
- `docs/design/lore.md`: map stories (army convoy at the dam, Day 3 hospital
  train, 1910s sanatorium), so props carry Oriel and Cordon marks, never real
  brands.
- `docs/plans/halcyon-labs-props.md`: the prop pipeline, layout.json `model`
  and `dressing`, clearance rules (props 1.5 m, dressing 1.0 m).
- `docs/plans/lantern-post-concept.md`: how new shared slots were added.
- `docs/adr/0008-code-built-assets-first.md`.
- Budgets from `tools/assets/check_models.py`: props 2,000 tris / 4 materials,
  dressing 1,000 / 4, town_large 12,000 / 6 (reused for props_large).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/library_*.py | new (one per family) | builders and `MODELS` |
| tools/assets/build_models.py | changed | merges each family's `MODELS` |
| tools/assets/prop_import.gd | changed (step 1, maybe 6-7) | new shared slots |
| levels/materials/*.tres | new (step 1) | materials for the new slots |
| tools/assets/check_models.py | changed | `props_large` budget, `JOINTS` entries |
| .github/workflows/assets.yml | changed | new files in the required-output list |
| assets/models/props/, dressing/, props_large/ | new files | `.glb` + `.import` (light_baking=2, import_script prop_import.gd) |
| docs/design/turnarounds/ | new files | approved turnarounds |
| docs/design/prop-library.md | new | the catalogue |
| docs/design/prop-library/*.jpg | new | one lineup board per family |
| tools/prop_lineup.gd | new (step 1) | family lineup render |
| tools/assets/tests/test_prop_library.py | new (step 1) | catalogue check |
| tests/content/test_prop_library.gd | new (step 1) | models load, baking, slots, no flat surfaces |
| tools/blockout_builder.gd | changed (step 5) | `"model"` with a folder prefix loads from that folder |

Autoloads, managers or base classes added: none. Shared shape helpers go in a
`library_parts.py` only once a third family needs the same helper (Keep it
simple rule 2).

## Data

- No Resource types, no save fields, no network messages.
- `layout.json` props and dressing: `"model": "props_large/<name>"` (step 5).
  A name with no folder still means `props/<name>` (or `dressing/<name>`), so
  every existing layout loads as today.
- Catalogue rows: `| name | folder | W x D x H m | families | maps | slots |`.
- Save format change: none.
- Content checks to add: `tests/content/test_prop_library.gd` (every library
  model loads, light_baking 2, every surface uses a shared slot, no flat
  surfaces as in `test_halcyon_surfaces`).

## Co-op behaviour

- Who owns the state: nobody; static scenery.
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: the same models, built into each
  map's blockout scene.
- Late joiner: nothing to receive; the scene is loaded with the map.
- Dedicated server: meshes load headless; colliders are the layout boxes.

## Performance

Nothing runs per frame. Each model is one mesh within its folder budget
(props 2,000 tris / 4 materials, dressing 1,000 / 4, props_large 12,000 / 6),
so a map gets one draw call per material per prop. Shared slots let Godot
batch materials across props. The map that places them does its own perf
capture.

## Steps

One step = one PR, built in its own thread. Every step: models, turnarounds
approved, catalogue rows, lineup board, and a decision card with the board
before the next family starts.

### Step 1: Library basics and barriers

- Build: catalogue `docs/design/prop-library.md` with the 51 existing Halcyon
  rows; catalogue check; `tools/prop_lineup.gd`; the new shared slots and
  materials; family 1 (barriers and checkpoint) in `library_barriers.py`.
- Files: as in Systems touched for step 1.
- Tests: `test_prop_library.py` fails on a model with no row (and on a row with
  no file); `test_prop_library.gd` loads family 1 and checks baking and slots;
  `check_models.py` budgets.
- Done when: CI green, family 1 board approved by the person.

### Step 2: Military camp and vehicles

- Build: family 2 in `library_military.py`. Trucks and the armoured car stay
  under 2,000 tris (simple cab, canvas top, six wheels); if one can't, it moves
  to props_large in step 5 instead.
- Tests: catalogue and content tests extended; budgets.
- Done when: board approved.

### Step 3: Industrial

- Build: family 3 in `library_industrial.py`. Pipes and rails come in lengths
  that snap on a 1 m grid (3 m and 6 m like `pipe_run_3/6`).
- Tests: as step 2, plus a content check that rail and pipe lengths are whole
  metres.
- Done when: board approved.

### Step 4: Rail

- Build: family 4 in `library_rail.py`. Track section 6 m on the 1.435 m
  gauge, so sections line up end to end.
- Tests: as step 2, plus track ends at exactly 0 and 6 m.
- Done when: board approved.

### Step 5: Large pieces

- Build: `props_large/` budget in `check_models.py`; builder reads a folder
  prefix in `"model"` for props and dressing; family 5 in `library_large.py`.
  The train cars are hollow shells (body, roof, windows, doors open, steps)
  placed as dressing over a `layout.json` room, so the map's own walls give
  collision and navmesh and players can walk through them (Marrow's train
  chokepoint). The gantry and container stack are props with box colliders.
- Tests: builder test with a `props_large/` prop in a small test layout;
  existing Halcyon builder tests unchanged; budgets.
- Done when: board approved, Halcyon blockout rebuilds byte-identical.

### Step 6: Hospital and sanatorium

- Build: family 6 in `library_hospital.py`.
- Tests: as step 2.
- Done when: board approved.

### Step 7: Outdoor and clutter, close-out

- Build: family 7 in `library_outdoor.py`; catalogue complete; ROADMAP Done;
  `docs/DECISIONS.md` line; finish-feature check.
- Tests: as step 2.
- Done when: all boards approved, every acceptance line ticked.

## Acceptance

- [ ] Every model in families 1-7 builds from its script and passes
  `check_models.py` and the glTF validator (Assets CI).
- [ ] Every model has an approved turnaround and a catalogue row; the
  catalogue check is green.
- [ ] Every library model loads in Godot with light_baking 2 and only shared
  material slots (`test_prop_library.gd`).
- [ ] A `layout.json` prop can place a `props_large/` model (builder test).
- [ ] The person approved each family's lineup board.

## Risks

- Vehicles over budget at 2,000 tris: step 2 tries first; fallback is
  props_large, no budget raise.
- Look drifts from the key shots across seven threads: each family board goes
  to the person before the next starts, and every step renders with the same
  lineup tool and light.
- Props too map-specific to reuse: families come from the shared "Key props"
  lists; anything only one map wants goes to that map's build.
- Main moves fast: each step only adds new files plus one-line list edits, so
  merge conflicts stay small.

## Open decisions

- [ ] Scope: generic kit plus the big reusable pieces (train car, gantry,
  container stack), with one-off map heroes (fountain, turbine housings, dam
  and sanatorium buildings) left to each map's build. Asked on a decision card.
