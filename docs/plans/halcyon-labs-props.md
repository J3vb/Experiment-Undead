# Plan: Halcyon Labs detail props

Status: Review
Roadmap: F-15
Phase: P4 (v0.1 Vertical slice)
Size: M
Approved by:

## Goal

Every room in Halcyon Labs looks like a real place where something went wrong:
the grey boxes become Blender-built models (specimen tanks, benches,
terminals, generators, cells, tables, crates, a forklift) and each room gets
story clutter (trays, jars, papers, barricades, body bags). The map plays
exactly the same. Serves "The pressure always builds" (readable rooms you can
navigate under pressure) and the Cold Containment look.

## Scope

In:

- A prop model script `tools/assets/prop_models.py` (same pattern as
  `character_models.py`: a `MODELS` dict that `build_models.py` merges) that
  exports `.glb` files into `assets/models/props/`. Finished with
  `finish.finish()` (baked AO, weighted normals) like the guns.
- `layout.json` `props` entries get an optional `"model"` field (a model name).
  The builder instances that `.glb` at the box and gives it a plain box
  collider of the box size, so footprint, clearance tests, collision and the
  navmesh stay the same as today. Props without `"model"` stay boxes.
- A new `dressing` list in `layout.json`: visual-only models with no collision
  (wall signs, cables and pipe runs, floor clutter under 0.3 m, papers, body
  bags). They never touch the navmesh (the map's NavigationMesh parses static
  colliders only, `geometry_parsed_geometry_type = 1`).
- Models per area, from `docs/design/maps.md` and `docs/design/lore.md`
  (Oriel's cold-tank lab, the cold failed on Day 0, staff turned first, last
  truck burning at the dock):
  - Labs: specimen tank (glass, bio-green core, the only green on the map),
    lab bench with microscope and centrifuge, computer terminal, jar shelf,
    filing cabinet.
  - Mess Hall: long table with benches, food trays and cups (dressing),
    tipped chairs (dressing), serving counter.
  - Guard Post: desk with terminal and monitors, locker row.
  - Generator Hall: diesel generator with pipes and a control box.
  - Containment Wing: holding cell with bars and a bent door, hazard signs and
    cable runs (dressing).
  - Main Corridor: pipe and cable runs along the ceiling line, hazard signs.
  - Loading Dock: crates, barrel, forklift, and the burning truck as a model.
  - Everywhere: barricades (tables and planks piled at a door the staff
    held), body bags and a covered gurney.
- Each step's look-check renders go to the person on a decision card before
  the next area starts (look choices are theirs).
- The prop list for the GPU re-bake prompt
  (`/mnt/project-files/halcyon-labs/f13-rebake-and-fps-prompt.md`).

Not in (non-goals, and where each one goes instead):

- Wall, floor and ceiling surfaces and the shared materials: the Halcyon Labs
  texture thread owns `levels/materials/` and the room entries.
- Lights, particles, fire and ambient motion: the "Halcyon Labs feel alive"
  thread. This plan keeps the existing `TruckFire` light and only swaps the
  truck mesh.
- Doors, barriers, machines, wall-buy boards, Vault, radios, freezer door,
  vent grates, `TruckWreckage`: already built as gameplay nodes; not re-modelled
  here (later: a polish pass after v0.1).
- Asset packs: stage B after v0.1 (ADR 0008).
- Destructible or physics props: no gameplay need.
- LODs and visibility ranges: only if the fps check after the re-bake drops
  (the map ran 434-530 fps at 1440p with 24 zombies on 2026-11-14).

## Ready to build

```
### Ready to build
- Foundations touched: 11 Asset pipeline (solid: build_models.py, finish.py, check_models.py,
  glTF validator), 9 Tests and CI (solid). Nothing shaky.
- Decision records: 0008 code-built assets first (this is that pipeline). Goes against one: no.
- Co-op:
  - Who decides: nobody; props are static scenery built into blockout.tscn, identical on every peer.
  - How a client triggers it: n.a. (no interaction).
  - What other players see: the same blockout scene; nothing is sent.
  - Works on a dedicated server with no local player: yes (meshes load, colliders same as today).
- Data: model names and boxes live in levels/halcyon_labs/layout.json (props, dressing). No Resource
  type. Code compares against a specific id: no (the builder reads "model" as a file name).
- Save: no change. Renames or removes a saved id: no.
- Events and UI: none.
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a. (no runtime code).
- Tests: content tests in tests/content/test_halcyon_labs.gd and test_generated_models.gd;
  check_models.py rules for the props folder; existing nav and clearance tests unchanged.
- Logging: none (no runtime system).
- Performance: nothing created at run time. Static meshes, max 4 materials each, budget below.
- Out of scope: as listed under "Not in".
```

## Design references

- `docs/design/maps.md#map-1-halcyon-labs-refined` (area table, setting and
  mood, table loop, specimen tanks).
- `docs/design/maps.md#pass-2-improve` (swap kit pieces for Blender models;
  gameplay nodes stay in map.tscn so art swaps never break the map).
- `docs/design/maps.md#performance-budget`.
- `docs/design/look-rules.md` (palette, bio-green only where the experiment
  leaks, `light_baking` 2 for static props, model rules).
- `docs/design/lore.md#1-halcyon-labs-where-it-broke-out`.
- `docs/DECISIONS.md`: Halcyon Labs blockout, lightmaps (re-bake steps).
- `docs/adr/0008-code-built-assets-first.md`.
- `docs/plans/halcyon-labs-finish.md` (props as data, clearance rule 1.5 m).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/prop_models.py | new | prop builders and `MODELS` |
| tools/assets/prop_parts.py | new (step 2) | shared shapes once a third prop needs them (Keep it simple rule 2) |
| tools/assets/build_models.py | changed | merges `prop_models.MODELS` |
| tools/assets/check_models.py | changed | `props` folder budget and `JOINTS` entries |
| assets/models/props/*.glb + .import | new | exported models, `light_baking=2`, vertex shading import script |
| tools/blockout_builder.gd | changed | `_build_prop()` instances `"model"`; new `_build_dressing()` |
| levels/halcyon_labs/layout.json | changed | `model` on props, new props and `dressing` |
| levels/halcyon_labs/blockout.tscn | regenerated | builder output |
| levels/halcyon_labs/map.tscn | changed (step 4) | dock Truck, crates, drum use models |
| tests/content/test_halcyon_labs.gd | changed | model props and dressing checks |
| tests/content/test_generated_models.gd | changed | props load, have `light_baking` 2 |

Autoloads, managers or base classes added: none.

## Data

- `layout.json` `props[]`: optional `"model": "<name>"` -> `res://assets/models/props/<name>.glb`.
  The box stays the footprint and the collider. The model is placed at the
  box's bottom centre; an optional `"turn"` (degrees about Y, multiples of 90)
  rotates the model, and the box is already given in map axes.
- `layout.json` `dressing[]`: `{"id", "room", "model", "at": [x, y above room floor, z], "turn"}`.
  No collider.
- Save format change: none.
- Content checks: every `model` file exists and loads; every dressing item sits
  inside its room; dressing models have no collision shapes.

## Co-op behaviour

- Who owns the state: none; static scenery in the shared blockout scene.
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: everything (same scene file).
- Late joiner: nothing to send; the scene loads with the map.
- Dedicated server: loads the meshes like any peer (same as the blockout
  today); no extra cost worth a branch.

## Performance

No run-time code. Budget, checked by tests and `check_models.py`:

- Per prop model: at most 2,000 triangles and 4 materials (same as the `kit`
  folder). Dressing pieces at most 1,000 triangles.
- Small clutter is merged into one model per cluster (a tray-and-cup table
  set, a jar shelf) instead of many small nodes, so draw calls grow per
  cluster, not per item.
- At most 60 model props and 80 dressing items on the map (content test). The
  Mess Hall and Main Corridor already have about 4x the ramp's draw calls
  (2026-11-14), so they get the fewest dressing items.
- The re-bake prompt's fps check (4 spots, 24 zombies) is the final gate. If it
  drops below 120 fps at 1440p, add visibility ranges to dressing first.

## Steps

### Step 1: Pipeline and the Labs

- Build: `prop_models.py` with specimen tank, lab bench (microscope,
  centrifuge, terminal on top), jar shelf, filing cabinet; merge into
  `build_models.py`; `props` folder in `check_models.py`. Builder: `"model"`
  on props and the `dressing` list. Labs props use the models (the 12 tank
  boxes become 4 tank props with the same outer footprint); add a jar shelf
  and filing cabinets on the walls, kept 1.5 m clear.
- Files: tools/assets/prop_models.py, build_models.py, check_models.py,
  assets/models/props/, tools/blockout_builder.gd, layout.json,
  blockout.tscn, tests/content/test_halcyon_labs.gd,
  tests/content/test_generated_models.gd.
- Tests: model props load and get a box collider of exactly the box size;
  dressing has no collider and lies inside its room; prop and dressing caps;
  `check_models.py` passes on the new glbs; existing nav, clearance and
  "blockout up to date" tests still pass. Look-check render of the Labs on a
  decision card.
- Done when: the Labs render shows the models, all checks green.

### Step 2: Mess Hall and Guard Post

- Build: long table with benches, serving counter, tray-and-cup sets and tipped
  chairs as dressing; guard desk with terminal and monitors, locker row.
  Extract `prop_parts.py` only if a shape gets its third copy.
- Files: prop_models.py, layout.json, blockout.tscn, check_models.py,
  assets/models/props/, tests.
- Tests: the Mess Hall table-loop nav test still passes (two paths around the
  tables on each side); new models load and pass `check_models.py`.
- Done when: renders on the card, all green.

### Step 3: Generator Hall, Containment Wing, Main Corridor

- Build: generator model, holding cell model; pipe runs, cable runs and hazard
  signs as dressing in the Corridor, Generator Hall and Containment Wing.
- Files: as step 2.
- Tests: as step 2; dressing cap still holds; spawn points still reach the
  start.
- Done when: renders on the card, all green.

### Step 4: Loading Dock

- Build: crate, barrel, forklift and truck models; dock `Truck`, `CrateA-D` and
  `Drum` in map.tscn keep their colliders and swap the mesh for the model; a
  forklift prop in the yard kept clear of the barriers and truck gaps.
  `TruckFire` light and `TruckWreckage` stay as they are.
- Files: prop_models.py, map.tscn, layout.json, check_models.py,
  assets/models/props/, tests.
- Tests: dock props keep their collision boxes (sizes unchanged);
  "every spawn reaches the start" still passes.
- Done when: renders on the card, all green.

### Step 5: Barricades and bodies everywhere, re-bake handoff

- Build: barricade (tables and planks), body bag and covered gurney models as
  props or dressing in each room, telling where the staff held out; add every
  new model to the re-bake prompt list; tell the Halcyon Labs build thread.
- Files: prop_models.py, layout.json, blockout.tscn, tests,
  `/mnt/project-files/halcyon-labs/f13-rebake-and-fps-prompt.md`.
- Tests: caps hold; clearance and nav tests pass.
- Done when: all areas have models, the re-bake prompt lists them, the build
  thread is told.

## Acceptance

- [ ] No room prop in Halcyon Labs is a plain box (content test: every prop
      has a `model`).
- [ ] Every model passes `check_models.py` and the glTF validator.
- [ ] Nav, clearance, spawn and table-loop tests pass unchanged.
- [ ] Prop and dressing caps hold.
- [ ] The person picked the look on each area's decision card.
- [ ] fps check after the re-bake holds 120 fps at 1440p (the person's PC).

## Risks

- Lightmap goes stale for changed meshes until the GPU re-bake. Static
  props render with ambient + real-time lights meanwhile; the re-bake runs
  once, after step 5 (not per step).
- Models that stick out of their box would let players clip into them or hide
  a gap the navmesh thinks is open. The builder places models inside the box,
  and `check_models.py`-style bounds are checked in the content test (model
  bounds within the box plus 5 cm).
- Draw calls in the Mess Hall and Corridor: clusters are merged and capped;
  the fps check is the gate.
- Collisions with the texture and "feel alive" threads: file split agreed
  (they own materials, room entries, lights, particles; this plan owns
  `props`, `dressing`, `assets/models/props/` and the dock props in map.tscn).

## Open decisions

- none (the look of each area goes to the person as a decision card with
  renders in its step)
