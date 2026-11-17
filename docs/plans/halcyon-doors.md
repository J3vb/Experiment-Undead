# Plan: Halcyon Labs door models

Status: Done
Roadmap: F-63
Phase: P4 (v0.1 Vertical slice)
Size: S
Approved by: review-plan checklist in the doors thread (2026-11-17, Claude reviewer; 1 fix: late-joiner line), size S, no open decisions

## Goal

The 12 door nodes in Halcyon Labs (buyable doors, debris, power shutters, vent
grates, the freezer door) stop being plain orange slabs and become Blender-built
models in the same style as the F-15 props. Buyable doors keep orange as hazard
paint, so players still spot them at a glance, and sliding doors slide up when
bought instead of popping out of existence. The map plays exactly the same.
Serves "The pressure always builds" (readable exits under pressure) and the
Cold Containment look.

## Scope

In:

- A door model script `tools/assets/door_models.py` (same pattern as
  `prop_models.py`: a `MODELS` dict that `build_models.py` merges), exported to
  a new budget folder `assets/models/doors/`:
  - `bulkhead_door` (2 m) and `bulkhead_door_wide` (4 m): heavy sliding
    security bulkhead, ribbed steel leaf, hazard-orange paint with a black
    chevron band and a stencil plate. The five `label = "door"` nodes.
  - `debris_pile` (4 m): collapsed ceiling panels, a bent beam, a toppled
    cabinet, an orange-striped sawhorse across it. `MessHallDebris`, `LabsDebris`.
  - `roll_shutter` (3 m): corrugated roll-up shutter with an orange bottom
    bar and a housing on top. The two Coolant Tunnel shutters.
  - `vent_grate` (1.6 m) and `vent_grate_wide` (3 m): rusty louvred grate in
    a frame. The two vent grates.
  - `freezer_door` (2 m): insulated cold-room door with a big lever handle and
    frost. `FreezerDoor`.
- Each model fits inside its door's current `Blocker` box (bottom centre
  origin, front Godot +Z), max 2,000 triangles and 4 materials.
- A new shared material slot `Hazard` in `tools/assets/prop_import.gd`
  -> `levels/materials/hazard_paint.tres` (the current door orange: painted
  metal texture, faint emission so it reads in the power-off dark).
- In `levels/halcyon_labs/map.tscn`, each door's `Blocker` stops being a
  `Block` (which always draws a box) and becomes a plain `StaticBody3D` on the
  WORLD layer with the same `BoxShape3D` size and the model as a child named
  `Model`. Collision, navmesh, prompts and costs stay identical.
- `Door.slide_up` (new export, metres, default 0): when the door opens the
  `Model` is moved to the level and tweened up by that much over 0.8 s, then
  freed. 0 keeps today's instant vanish (debris, grates). The `Blocker` is
  still freed at once, so the navmesh rebake and co-op sync do not change.
- Look check renders on a decision card after step 1 (look choices are asked per step, like F-15, not open decisions here).

Not in (non-goals, and where each one goes instead):

- Wall-buy boards, Med Dispensers, Vault, Reforger, power switch, radios: a
  separate card proposes them in this style once the doors land (later: own
  plan if the person says yes).
- New door sounds: `door_open.wav` already plays.
- Door frames that stay after opening: the Door node is freed on open, and
  the wall cut already reads as the frame.
- Lighting re-bake: the doors are not baked (they move); the F-13 GPU re-bake
  prompt just gets them listed so the bake runs after they land.
- Other maps: no other map has doors yet.

## Ready to build

```
### Ready to build
- Foundations touched: 11 Asset pipeline (solid: build_models.py, finish.py, check_models.py, glTF
  validator, prop_import.gd), 9 Tests and CI (solid). Interactables: Door gets one export. Nothing shaky.
- Decision records: 0008 code-built assets first; 0003 trusted-client co-op (unchanged: server decides,
  clients open doors the server lists). Goes against one: no.
- Co-op:
  - Who decides: the server, as today (Door.interact on the server, InteractionSync lists removed doors).
  - How a client triggers it: unchanged (interaction request to the server).
  - What other players see: Door.retire() on clients calls open(), so they play the same slide.
  - Works on a dedicated server with no local player: yes; the tween is visual only and harmless headless.
- Data: model names are file names in map.tscn; slide_up is a per-door export. No Resource type. Code
  compares against a specific id: no.
- Save: no change. Renames or removes a saved id: no.
- Events and UI: none.
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a. (the slide is a visual tween).
- Tests: tests/integration/test_halcyon_doors.gd (slide, blocker gone at once), tests/content/
  test_halcyon_labs.gd (door blockers unbaked), new tests/content/test_door_models.gd (models load, fit
  their box, Hazard slot maps to the shared material, no flat surfaces), check_models.py doors budget.
- Logging: none (no new system).
- Performance: 12 static meshes, max 4 materials each; one tween per opened door.
- Out of scope: as listed under "Not in".
```

## Design references

- `docs/design/maps.md#map-1-halcyon-labs-refined` (doors, debris, shutters,
  the freezer secret).
- `docs/design/maps.md#pass-2-improve` (art swaps never break the map).
- `docs/design/look-rules.md` (palette, warning orange `#FF8A1C`, bevels,
  "things you use are one step brighter than the walls").
- `docs/plans/halcyon-labs-props.md` (pipeline, budgets, import script).
- `docs/adr/0008-code-built-assets-first.md`.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/door_models.py | new | door builders and `MODELS` |
| tools/assets/build_models.py | changed | merges `door_models.MODELS` |
| tools/assets/check_models.py | changed | `doors` budget (2,000 / 4), `JOINTS` lines |
| tools/assets/prop_import.gd | changed | `Hazard` slot |
| levels/materials/hazard_paint.tres | new | door orange as a shared material |
| .github/workflows/assets.yml | changed | door files in the required-output list |
| assets/models/doors/ (*.glb + .import) | new | exported models, `light_baking=3` (they move), `prop_import.gd` |
| systems/interactables/door.gd | changed | `slide_up` export and the slide in `open()` |
| levels/halcyon_labs/map.tscn | changed | door Blockers become StaticBody3D + model; `door_dev` material deleted |
| tests/content/test_door_models.gd | new | models load, fit, slots |
| tests/content/test_halcyon_labs.gd | changed | door blockers checked by GI mode instead of `Block.baked` |
| tests/integration/test_halcyon_doors.gd | changed | slide test |

Autoloads, managers or base classes added: none.

## Data

- `Door.slide_up: float` (export, default 0.0). Bulkheads, shutters and the
  freezer door: 2.6 (their height). Debris and grates: 0.
- Model files: `res://assets/models/doors/<name>.glb`, placed by hand in
  map.tscn under each `Blocker` (map.tscn gameplay nodes are hand-edited).
- Save format change: none.
- Content checks: every door Blocker has a `Model` child, the model's bounds
  fit inside the `BoxShape3D` plus 5 cm, no MeshInstance under `Doors` is
  GI static.

## Co-op behaviour

- Who owns the state: the server, unchanged (`Door.is_open`, listed as
  removed by `InteractionSync`).
- What clients send, what the server sends back: unchanged.
- What a client sees that the host sees too: the same model and the same
  slide (clients run `open()` through `retire()`).
- Late joiner: unchanged; `Level.apply_net_state()` retires the removed doors,
  which runs `open()`, so the late joiner sees the doors slide away once on
  load (same as the open sound plays today). Nothing new is sent.
- Dedicated server: loads the meshes like any peer; the tween runs on a node
  with no camera, cost is negligible.

## Performance

- 12 door meshes replace 12 box meshes; each at most 2,000 triangles and 4
  materials (`check_models.py`).
- One Tween per opened door, freed with the model after 0.8 s. No per-frame
  allocations.
- Not baked into the lightmap (they move), same as the boxes today.

## Steps

### Step 1: Pipeline, bulkheads and the slide

- Build: `door_models.py` with `bulkhead_door` and `bulkhead_door_wide`;
  `doors` budget; `Hazard` slot and `hazard_paint.tres`; the five bulkhead
  Blockers in map.tscn become StaticBody3D + model; `Door.slide_up` and the
  slide. Look-check render of the bulkheads in the Guard Post and Main
  Corridor on a decision card.
- Files: door_models.py, build_models.py, check_models.py, prop_import.gd,
  hazard_paint.tres, assets.yml, assets/models/doors/, door.gd, map.tscn,
  tests.
- Tests: bought door: Blocker gone at once, Model slides up and is freed;
  door models load and fit; door blockers not GI static; existing door, nav
  and co-op door tests pass unchanged.
- Done when: render on the card, all checks green.

### Step 2: Debris, shutters, vent grates, freezer door

- Build: `debris_pile`, `roll_shutter`, `vent_grate`, `vent_grate_wide`,
  `freezer_door`; swap the other seven Blockers; delete the unused
  `door_dev` material; list the doors in the F-13 re-bake prompt; tell the
  Halcyon build thread. Then the card proposing wall-buys and machines.
- Files: door_models.py, check_models.py, assets.yml, assets/models/doors/,
  map.tscn, tests, `/mnt/project-files/halcyon-labs/f13-rebake-and-fps-prompt.md`.
- Tests: every door Blocker has a model (content test); no door Blocker is a
  `Block`; the freezer co-op and vent grate tests pass unchanged.
- Done when: renders on the card, all green, plan Done.

## Acceptance

- [x] No door in Halcyon Labs is a plain box (content test).
- [x] Every door model passes `check_models.py` and the glTF validator.
- [x] Door, nav, vent and co-op door tests pass unchanged.
- [x] Bought sliding doors slide up (host tested in test_halcyon_doors.gd; clients run the same `open()` through `retire()`).
- [x] The person picked the look on the decision card.

## Risks

- A model wider than its box would hide a gap the navmesh thinks is open:
  content test checks bounds against the box.
- Sliding up pushes the model through the ceiling: it is hidden above the
  ceiling and freed after 0.8 s; nothing collides with it (Blocker is gone).
- Stale `.godot/imported` copies after changing `prop_import.gd`: delete the
  imported door files before re-importing (props thread gotcha).

## Open decisions

- none
