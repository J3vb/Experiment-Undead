# Plan: Tripo model trial

Status: Approved
Roadmap: F-78 (trial, decides how F-76 and F-77 models are made)
Phase: P5 (art)
Size: M
Approved by: review PR #345, 2026-11-18 (trial, tools only, no open decisions)

## Goal

Find out, on one prop and one vendor, whether models made in Tripo (image to
3D) can go into the game with less work and closer to the concept art than
our code-built models. The result is a report and side-by-side renders, so
the person can pick how the prop library (F-77) and vendors (F-76) are made.
Pillar: the look matches the concept art.

## Scope

In:

- An intake script that turns a Tripo `.glb` into a game-ready `.glb`: one
  mesh, scale, floor origin, facing, decimate to budget, new UVs, bake the
  Tripo detail into our three maps (albedo, normal, ORM).
- Characters only: fit our 22-bone skeleton (`tools/assets/character_rig.py`)
  to the Tripo body, skin it, and add the existing player clips, so the clips
  we already have play on it.
- Run `check_models.py`, the glTF validator and a turnaround on the results.
- Side-by-side renders against the code-built version, and a short report:
  what works, what does not, effort per model, licence.

Not in (non-goals, and where each one goes instead):

- Putting a Tripo model into a level or the town (later: F-76 / F-77, only if
  the person picks Tripo).
- Changing the F-76 or F-77 plans or their running steps (the person decides
  after the report).
- Face rigs, finger bones, cloth sim (never for vendors at this distance).
- Buying a Tripo plan (the person).

## Ready to build

```
### Ready to build
- Foundations touched: none (tools/assets only, no game code).
- Decision records that apply: ADR 0015 (baked maps on player.glb). The trial
  writes outside assets/models, so no new ADR. If Tripo is picked, F-76's
  planned ADR 0016 covers baked NPC maps.
- Co-op: n.a. (offline asset tool, nothing runs in game).
- Data: no ids or numbers in game data. Budgets come from check_models.py
  (props 2,000 tris / 4 materials, characters 16,000 / 4).
  Code compares against a specific id anywhere: no
- Save: no
- Events and UI: none / n.a.
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a.
- Tests: tools/assets/tests/test_tripo_intake.py (pytest, bpy).
- Logging: n.a. (offline tool prints a summary).
- Performance: same budgets as code-built models, checked by check_models.py.
- Out of scope: in-game placement, shop or vendor behaviour.
```

## Design references

- docs/design/lore.md#the-stall-keepers (Odile Brandt, Quartermaster: grey bun,
  reading glasses on a cord, long charcoal wool coat, maroon knit shawl,
  fingerless gloves, a ledger)
- docs/design/look-rules.md (Cold Containment palette and finish)
- docs/adr/0015-baked-player-body.md (albedo / normal / ORM maps)
- tools/assets/check_models.py BUDGETS, character_checks.py BUDGETS
- docs/plans/teammate-animations.md (clip names in player.glb)

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/tripo_intake.py | new | Import, clean, decimate, unwrap, bake, export |
| tools/assets/tripo_rig.py | new | Fit 22 bones to a body, skin, copy clips |
| tools/assets/tests/test_tripo_intake.py | new | Fixture tests |
| docs/design/reviews/tripo-trial/ | new | Output .glb, renders, report (`.gdignore`d) |

Autoloads, managers or base classes added: none.

## Data

None in the game. Source files from Tripo live in `/mnt/project-files/tripo/`
during the trial (not committed: size and licence are unknown until the
report).

- Save format change: none
- Content checks to add in `tests/content/`: none

## Co-op behaviour

- Who owns the state: not networked (offline asset tool).
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: n.a.
- Late joiner: n.a.
- Dedicated server: n.a.

## Performance

Output must pass the same budgets as code-built models, so the game cost is
the same. Maps at 1024 for props, 2048 for characters, like the player body.

## Steps

### Step 1: Prop intake

- Build: `python tools/assets/tripo_intake.py <source.glb> --kind prop --height <m>`.
  Joins meshes, scales to the given height, puts the origin at floor centre,
  turns the front to Godot +Z, decimates to 2,000 triangles, smart-unwraps,
  bakes albedo / normal / ORM from the source at 1024, exports a `.glb` with
  one material. Renders it beside the nearest code-built prop.
- Files: tools/assets/tripo_intake.py, tools/assets/tests/test_tripo_intake.py,
  docs/design/reviews/tripo-trial/.
- Tests: a fixture "Tripo-like" source (a code prop subdivided to 40k tris
  with a texture) goes through the intake; the test checks triangles, origin,
  facing, one material, three maps, and that check_models passes it as a prop.
- Done when: the person's Tripo prop passes check_models and the validator,
  and the side-by-side render is in the report folder.

### Step 2: Character intake and rig

- Build: `--kind character` adds: decimate to 16,000, maps at 2048, fit the
  22 bones (from Tripo's own skeleton joints when it is rigged, else from body
  slices: feet, knees, hips, shoulders, elbows, hands, neck, head top), skin
  with `character_rig` segment weights, add an `Eyes` marker, copy the clips
  from `assets/models/characters/player.glb` by bone name. Renders idle, walk
  and a turnaround.
- Files: tools/assets/tripo_rig.py, tripo_intake.py, test_tripo_intake.py.
- Tests: the code-built player body (no skeleton) goes through the rig step;
  the test checks all 22 bones exist, every vertex is weighted, the clips
  are present, and check_models passes it as a character.
- Done when: the person's Tripo vendor passes check_models with the clips
  playing in the render, or the report says exactly where it breaks.

### Step 3: Report

- Build: report in docs/design/reviews/tripo-trial/README.md: renders side by
  side, what worked, what broke, minutes per model, licence and cost, and a
  recommendation for F-76 and F-77. A decision card to the person.
- Files: docs/design/reviews/tripo-trial/.
- Tests: none (docs only).
- Done when: the person has picked on the card (switch F-76 / F-77 to Tripo or not).

## Acceptance

- [ ] A Tripo prop passes check_models and the glTF validator (step 1 test + run).
- [ ] A Tripo character on our skeleton plays the existing clips (step 2 test + render).
- [ ] Report and card delivered (step 3).

## Risks

- Tripo's auto-rig uses its own bones and rest pose; our clips need our bone
  names and rest pose. The plan does not reuse Tripo's skin, only its joint
  positions, so the clips stay valid.
- Tripo bodies in a different pose (T-pose vs our A-pose) give bad skin
  weights at the shoulders. Ask for an A-pose source; the report notes it.
- Decimating 300k+ Tripo meshes to 2k can wreck thin parts. The bake keeps the
  look in the normal map; the render shows how bad it is.
- Licence: free-plan models are public under CC BY 4.0; private models with
  commercial rights need a paid plan. The report states it; nothing ships
  in the trial.

## Open decisions

- none
