# Plan: Halcyon Labs wall-buy racks and Specimen Vault models

Status: Done
Roadmap: F-64
Phase: P4 (v0.1 Vertical slice)
Size: S
Approved by: review-plan checklist by a separate Claude reviewer (2026-11-17), approve with 6 suggestions, all applied; size S, no open decisions

## Goal

The six wall-buy boards in Halcyon Labs stop being plain wooden slabs and the
Specimen Vault stops being a grey box. Each wall-buy becomes a Blender-built
steel weapon rack with the real gun hanging on it, and the Vault becomes an
Oriel sample archive with green vials behind glass. Same style and pipeline as
the F-63 doors. Players see what a wall sells from across the room, and the
Vault reads as the green experiment machine even before the power is on.
Serves "The pressure always builds" (fast, readable buys) and the Cold
Containment look.

## Scope

In:

- A model script `tools/assets/machine_models.py` (same pattern as
  `door_models.py`: a `MODELS` dict that `build_models.py` merges), exported
  to a new budget folder `assets/models/machines/` (2,000 triangles, 4
  materials, bottom centre origin, front Godot +Z):
  - `weapon_rack` (1.6 x 0.1 x 0.8 m): steel-framed panel-paint backplate, a
    hazard-orange band across the top (the same "you buy this" orange as the
    doors), two rubber gun clamps and a small stencil plate. The five bought
    wall guns.
  - `weapon_rack_cold` (same size): white cold-store backplate with frost and
    no orange band, for the free secret `CryoRack`.
  - `specimen_vault` (2.0 x 1.0 x 1.0 m): heavy steel archive chest on a dark
    plinth, a glass window on both long sides showing green sample vials, a
    dark groove where the existing `Glow` strip lights up when the power comes
    on. Both long sides are the same, because the six Vault spots face it
    either way (four spots have the wall on local +Z, two on local -Z).
- Imports through `tools/assets/prop_import.gd` with `light_baking=3` (not
  lightmapped), like the boxes today: the Vault moves between spots, and the
  wall-buys stay out of the bake as `Block.baked = false` already said.
- In `levels/halcyon_labs/map.tscn`, each wall-buy's `Board` stops being a
  `Block` and becomes a plain `StaticBody3D` on the WORLD layer with the same
  `BoxShape3D` (0.1 x 0.8 x 1.6), collision mask 0, the rack as child
  `Model` and a `Marker3D` child `GunMount` in front of the clamps. `Block`
  centres its box on the node, the models have a bottom centre origin, so the
  rack `Model` sits at y -0.4 and is turned 90 degrees about Y (the box is
  long along Z). Its front faces away from the wall: local +X, except
  `WallBuyBrennerTrench` and `WallBuyRifle` whose wall is on local +X (found
  once with a ray probe while building; the content test then checks that
  each `GunMount` is on the side away from that wall).
- `WallBuy._ready()` hangs a copy of `weapon.world_model` (the same gun model
  teammates hold) on `Board/GunMount` when both exist. No new data: the gun
  model already lives in `WeaponData`. `WallBuy` has no `_ready()` today, so
  the new one calls `super()` first (`Interactable._ready()` sets the
  interactable layer).
- In `systems/interactables/specimen_vault.tscn`, `Body` stops being a `Block`
  and becomes a `StaticBody3D` with the same 2 x 1 x 1 box shape and the
  Vault model as `Model` at y -0.5. `Glow` (1.8 x 0.06 x 1.02 at y 0.35,
  1 cm proud of each long side), `Label`, sounds and the script stay; the
  model's groove sits at the Glow height.
- Stale comments: the `Block.baked` doc comment in `systems/level/block.gd`
  and the `docs/DECISIONS.md` line that call wall-buy boards and the Vault
  body `Block`s.
- Look-check renders of a rack and the Vault, shown to the person with the
  result. A look change after that is a follow-up, not a blocker.

Not in (non-goals, and where each one goes instead):

- Med Dispensers, Reforger, power switch, wall radios, exfil hatch: the
  person was asked about wall-buys and the Vault only. A later card or plan.
- Vault animations (lid opening, the "breathing" before a move, a gun rising
  out of it): the roll label and sounds already show the state; a later
  game-feel row if wanted.
- Rarity colours on the Vault or the racks: rarity shows on the item, not the
  machine (look-rules rule 6).
- Other maps: no other map is built yet.
- Lightmap re-bake: nothing here is baked; the F-13 re-bake prompt just lists
  the new models as dynamic.

## Ready to build

```
### Ready to build
- Foundations touched: 11 Asset pipeline (solid: build_models.py, finish.py, check_models.py, glTF
  validator, prop_import.gd, turnarounds), 9 Tests and CI (solid). Interactables: WallBuy gets a few
  visual lines in _ready(). Nothing shaky.
- Decision records: 0008 code-built assets first; 0003 trusted-client co-op (unchanged). Goes against
  one: no.
- Co-op:
  - Who decides: the server, unchanged (WallBuy.interact and SpecimenVault rolls run on the server).
  - How a client triggers it: unchanged (interaction request to the server).
  - What other players see: every peer builds the same rack, gun and Vault model from the scene and
    WeaponData; the Vault's spot already syncs through net_state(), the model moves with it.
  - Works on a dedicated server with no local player: yes; models are visual only.
- Data: model names are file names in map.tscn and specimen_vault.tscn; the gun comes from
  WeaponData.world_model. No new Resource field. Code compares against a specific id: no.
- Save: no change. Renames or removes a saved id: no.
- Events and UI: none.
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a. (visual only).
- Tests: new tests/content/test_machine_models.gd (models load as one dynamic mesh, racks use the
  shared Hazard slot only when bought, every wall-buy Board is a model that fits its box and has a
  GunMount with its gun hung on it after _ready(), the Vault Body fits its box), existing wall-buy, Vault and co-op interaction tests unchanged; check_models.py budget.
- Logging: none (no new system).
- Performance: 7 static-shaped meshes (max 4 materials each) plus 6 gun models already loaded for
  teammates; one instantiate per wall-buy at load. No per-frame work.
- Out of scope: as listed under "Not in".
```

## Design references

- `docs/design/look-rules.md` (bio-green reserved for the Vault, "anything you
  use is one step brighter", gun colours).
- `docs/design/lore.md#why-the-machines-exist` (the Vault is Oriel's sample
  and seized-gear archive).
- `docs/design/game-design.md` (wall guns: same price and place every match;
  Vault spots).
- `docs/plans/halcyon-doors.md` (pipeline, Hazard slot, model-in-blocker
  pattern).
- `docs/adr/0008-code-built-assets-first.md`.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/machine_models.py | new | rack and Vault builders and `MODELS` |
| tools/assets/build_models.py | changed | merges `machine_models.MODELS` |
| tools/assets/check_models.py | changed | `machines` budget (2,000 / 4), `JOINTS` lines |
| tools/turnarounds.py | changed | `machines` reference image |
| .github/workflows/assets.yml | changed | machine files in the required-output list (replaced by `tools/assets/check_outputs.py` via `build_models.MODELS` in F-79 step 10) |
| assets/models/machines/ (*.glb + .import) | new | exported models, `light_baking=3`, `prop_import.gd` |
| docs/design/turnarounds/machines/ | new | approved turnarounds |
| systems/interactables/wall_buy.gd | changed | hangs `weapon.world_model` on `Board/GunMount` |
| systems/interactables/specimen_vault.tscn | changed | `Body` becomes StaticBody3D + shape + model |
| levels/halcyon_labs/map.tscn | changed | six `Board`s become StaticBody3D + model + GunMount |
| systems/level/block.gd | changed | doc comment no longer names wall-buys and the Vault |
| docs/DECISIONS.md | changed | wall-buy and Vault line, new F-64 entry |
| tests/content/test_machine_models.gd | new | models load, fit, slots, mounts; the gun hangs on each mount after `_ready()` |

Autoloads, managers or base classes added: none.

## Data

- Model files: `res://assets/models/machines/<name>.glb`, placed by hand in
  map.tscn (wall-buys) and specimen_vault.tscn (Vault). Later, F-83 added four
  Tripo machines to the same folder (`tools/assets/tripo/halcyon.json`).
- The gun on a rack is `WeaponData.world_model`, already required for every
  gun by `test_content.gd`.
- Save format change: none.
- Content checks: every wall-buy `Board` has a `Model` and a `GunMount`, the
  model fits its `BoxShape3D` plus 5 cm (measuring `Model` only, not the
  hung gun); the Vault model fits its body box plus 5 cm; Boards and the
  Vault Body are not `Block`, are on WORLD with mask 0; no machine mesh is GI static.

## Co-op behaviour

- Who owns the state: the server, unchanged (wall-buy `taken_by`, Vault state,
  offer, buyer and spot).
- What clients send, what the server sends back: unchanged.
- What a client sees that the host sees too: the same racks, guns and Vault
  model, built locally from the same scenes.
- Late joiner: unchanged; the Vault is moved to its synced spot by
  `apply_net_state()` and its model goes with it.
- Dedicated server: loads the meshes like any peer; nothing runs per frame.

## Performance

- 7 machine meshes replace 7 box meshes; each at most 2,000 triangles and 4
  materials (`check_models.py`).
- 6 gun models on the walls; the same glbs teammates hold, so no new imports.
- No per-frame allocations; one instantiate per wall-buy when the map loads.

## Steps

### Step 1: Racks, guns on the racks and the Vault

- Build: `machine_models.py` with `weapon_rack`, `weapon_rack_cold`,
  `specimen_vault`; `machines` budget, turnarounds and assets CI list; the six
  wall-buy Boards in map.tscn become StaticBody3D + rack + GunMount;
  `WallBuy` hangs its gun; the Vault Body in specimen_vault.tscn becomes
  StaticBody3D + model; list the models in the F-13 re-bake prompt; look-check
  renders with the result.
- Files: everything in Systems touched, plus
  `/mnt/project-files/halcyon-labs/f13-rebake-and-fps-prompt.md`.
- Tests: wall-buy Boards are models that fit and have a GunMount; the gun
  hangs on the mount after `_ready()`; the Vault model fits its body; machine
  models are one dynamic mesh; existing wall-buy, Vault and co-op interaction
  tests pass unchanged.
- Done when: renders shown to the person, all checks green, plan Done.

## Acceptance

- [x] No wall-buy in Halcyon Labs is a plain board, and each shows its gun (content test).
- [x] The Specimen Vault is a model, not a box (content test).
- [x] Every machine model passes `check_models.py`, the glTF validator and turnarounds.
- [x] Wall-buy, Vault and co-op interaction tests pass unchanged.

## Risks

- A gun model hanging through the wall: the mount sits in front of the rack,
  the rack front was chosen with a ray probe per wall-buy, and the content
  test checks each GunMount's local X sign against the known wall side.
- The Vault model hiding a Vault spot problem (it is 1 m deep and two spots
  are 0.4 m from the wall): the collision box is unchanged, so nothing plays
  differently; the model fits that same box.
- Stale `.godot/imported` copies after an import change: delete the imported
  machine files before re-importing (props thread gotcha).

## Open decisions

- none
