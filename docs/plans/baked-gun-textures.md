# Plan: Baked texture maps for the four concept guns

Status: Approved
Roadmap: F-75
Phase: P4 (v0.1 Vertical slice, look pass on built guns)
Size: L
Approved by: the person by decision card on 2026-11-17 (AR-17 only for now), plan PR #323

## Goal

The AR-17, BR-12, VX-9 and MR-28 reach the detail of the weapon concept sheet
([images/guns_concept.jpg](../design/images/guns_concept.jpg)): soft bevels
that catch the light, stippled grips, engraved Oriel marks and serials, sculpted
chips and dents. Shader noise on a low-poly mesh (F-72) cannot draw that; baked
texture maps can. We judge the result in the game's own renderer with real
lighting, not in flat software previews. Serves "Guns feel great" and the
Cold Containment look: these are the guns players hold most.

The person chose this on 2026-11-17 (follow-up to F-72): baked maps, gun
budget 30,000 triangles, real in-game lighting for previews, and a pipeline
that also takes detailed `.glb` guns the person hands over.

## How it works

```
gun script (F-72 shapes)  ──►  low-poly game mesh  ──► chamfer, UV unwrap ──┐
        │                                                                    │ Cycles bake,
        └──► high-detail copy: bevels, subdivision, stipple,                 │ part by part
             engraved marks, dents and chips, procedural paint ─────────────►┤
handed-over .glb (step 6) ──► decimate per part ──► low-poly ───────────────┘
                                                                             ▼
                      assets/textures/weapons/<id>_albedo / _normal / _orm (2048 px)
                                                                             ▼
                      gun_finish_import.gd: "Baked" material = gun_finish shader in baked mode
```

The high-detail copy is never in the game. It exists only inside the bake
script run, so the gun script stays the one source (ADR 0008 spirit), and a
handed-over `.glb` becomes the source for that gun (new ADR 0014).

## Scope

In:

- **ADR 0014** "Guns may use baked texture maps": amends ADR 0008 for guns.
  Allows image textures for guns made by a bake script from a code-built or
  handed-over high-detail source; drops the "no image textures" rule of the gun
  finish shader for these guns.
- **Budget**: weapons 8,000 to 30,000 triangles in `check_models.py`
  (the person's number). Materials stay at most 6.
- **Lit previews**: renders in Godot's Forward+ renderer (Vulkan, with SSAO,
  glow, tonemapping, shadows) of the first-person view in a Halcyon-lit room
  and a studio turntable, so the look is judged with real lighting.
- **Bake pipeline** `tools/assets/gun_bake.py`: high-detail pass, low-poly
  chamfer and UVs, per-part Cycles bake of normal, base colour, AO, roughness
  and metal, packed into three maps per gun.
- **Baked mode in `gun_finish.gdshader`**: samples the three maps; keeps the
  rarity inlay (vertex alpha) and Prototype glow so loot rarity still shows.
- The four guns baked, one step each, after their F-72 shape step merges.
- **Intake for handed-over guns** `tools/assets/gun_intake.py`: a detailed
  `.glb` plus a small part map becomes a game gun with the same node names,
  pivots and baked maps.
- Turnarounds, lineup next to the concept, look-rules rule 6 line about baked
  guns, DECISIONS.md entry.

Not in (and where each goes):

- The other 18 guns: they keep the F-72 shader finish. Baking them is one
  step per gun with this pipeline; later, if the person wants it.
- Zombies, player body, props: same idea may follow (the player-body trial,
  draft PR #316, is weighing it). Not here.
- Any handed-over gun model itself: step 6 builds the intake and proves it on
  a test file; real models come when the person hands one over.
- Balance, aim offsets, `ads_fov`, recoil: no change (F-07).
- Texture streaming, LOD textures: not needed at 4 guns (see Performance).

## Ready to build

```
### Ready to build
- Foundations touched: asset pipeline only (model checks, turnarounds, gun finish import,
  Assets CI). All solid. No game-code foundation.
- Decision records that apply: ADR 0008 (code-built assets first). Does this go against
  one? Partly: image textures on guns and handed-over models. Step 1 writes ADR 0014 first.
- Co-op:
  - Who decides: nobody, visuals only. Same .glb and maps on every peer.
  - How a client triggers it: n.a.
  - What other players see: the baked guns in teammates' hands and on wall racks.
  - Works on a dedicated server with no local player: yes (no script runs; maps are
    unused resources in the server build)
- Data: no new ids, Resource types or fields. Code compares against a specific id: no
- Save: changes what is saved? no. Renames a saved id: no
- Events and UI: none. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG:
  n.a. (no gameplay code); bake noise uses fixed seeds
- Tests: check_models.py budget, tools/assets/tests (bake, intake), tools/ci stale-bake test,
  tests/content/test_generated_models.gd and test_gun_finish.gd, turnarounds
- Logging: none (no runtime system)
- Performance: see Performance; GPU agent fps check in step 5
- Out of scope: other 18 guns, characters, balance
```

## Design references

- [images/guns_concept.jpg](../design/images/guns_concept.jpg): the look target.
- [look-rules.md](../design/look-rules.md) rule 6 (matte black and gunmetal,
  one secondary colour, rarity as a thin inlay strip, no real brand marks) and
  the F-72 accents line (yellow mag tape, brass, Oriel marks).
- [plans/guns-concept.md](guns-concept.md): the shapes, names and red dots this
  plan bakes. Its node-name and ADS-ray rules stay.
- ADR 0008 (code-built assets first), ADR 0009 (CI is the gate).
- Earlier work: PR #65 (code-built guns), #68 (finish shader), #317 (worn
  finish, markings atlas, red dot), #322 (AR-17 shapes, open), `finish.py`
  (Smart UV and Cycles AO bake already run on every model).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `docs/adr/0014-baked-gun-textures.md`, `docs/adr/README.md` | new / changed | The decision record |
| `tools/assets/check_models.py` | changed | `weapons` budget 30,000 |
| `tools/gun_showcase.gd` (+ `.tscn`) | new | Forward+ lit renders: first person in a Halcyon-lit room, studio turntable |
| `.claude/hooks/session-start.sh` | changed | Install Mesa's software Vulkan (lavapipe) so cloud threads render Forward+ |
| `tools/assets/gun_bake.py` | new | High-detail pass, chamfer, UVs, per-part bake, map packing, bake record |
| `tools/assets/build_models.py` | changed | Baked guns run the bake after their script |
| `assets/materials/gun_finish.gdshader` | changed | `baked` mode: albedo, normal and ORM maps through UV |
| `tools/assets/gun_finish_import.gd` | changed | `Baked` material name: shader in baked mode with `<id>_*` maps |
| `assets/textures/weapons/<id>_{albedo,normal,orm}.png` | new | Bake output (generated, never hand-edited) |
| `assets/textures/weapons/<id>_bake.json` | new | Bake record: input hashes, map size, triangle count |
| `assets/models/weapons/{rifle_ar,kestrel_smg,shotgun_brenner,talon_dmr}.glb` | changed | Re-exported low-poly with UVs and the `Baked` material |
| `tools/assets/{rifle,kestrel,shotgun,talon}_model.py` | changed | Only where a part needs more segments for the new budget |
| `tools/assets/gun_intake.py`, `tools/assets/intake/` | new | Handed-over `.glb` to game gun (step 6) |
| `tools/ci/test_gun_bakes.py` | new | Fails when a baked gun's inputs changed without a re-bake |
| `docs/HOW_TO_ADD.md` | changed | "Bake a gun" and "Bring in a gun model" recipes |
| `docs/design/look-rules.md`, `docs/DECISIONS.md`, `docs/CREDITS.md` | changed | Rule 6 line, entry, credits for any handed-over model |

Autoloads, managers or base classes added: none.

## Data

- No Resource types, fields, ids or `.tres` changes. Weapons keep their
  `world_model` paths.
- Bake record `<id>_bake.json` (tool data, not game data): sha256 of the gun
  script, `gun_parts.py`, `gun_bake.py`, the markings atlas (or the handed-over
  source), map size, low-poly triangle count. Read only by
  `tools/ci/test_gun_bakes.py`.
- Save format change: none.
- Content checks: `tests/content/test_generated_models.gd` checks the four
  guns use the `Baked` material with all three maps loaded, and keep their
  node names and ADS rays.

## Co-op behaviour

- Who owns the state: nobody; models and maps are local visuals.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same baked guns on
  teammates and wall racks.
- Late joiner: nothing extra.
- Dedicated server: no script runs; the maps sit unused in the server build
  (about 12 MB of imported textures; excluding them is a later size tweak, not
  needed for correctness).

## Performance

- **Triangles**: up to 30,000 per gun (person's budget). Spent on rounder
  barrels and scopes and a one-segment chamfer on hard edges; detail smaller
  than about 1 mm goes into the normal map, not the mesh. Worst case on screen:
  1 viewmodel + 3 teammate guns + 8 wall-rack guns = 360,000 triangles; the
  import's auto LODs (`generate_lods=true`) cut the far rack and teammate
  guns to a fraction. Halcyon held 434 fps at 1440p (memory, 2026-11-14), so
  this is far inside the 120 fps target.
- **Materials and draw calls**: fewer than today. Each baked gun goes from 5-6
  materials to `Baked` plus optic glass (2-3), so 2-3 draw calls per gun.
- **Textures**: three 2048 x 2048 maps per gun, VRAM-compressed on import
  (BPTC/S3TC), about 5.3 MB of VRAM per gun with mipmaps, 21 MB for all four.
  2048 because the viewmodel fills about a third of a 1440p screen; that gives
  about one texel per pixel. Technical pick, no design number exists.
- **Shader**: baked mode replaces the six noise reads per pixel with three
  texture reads, so it is cheaper than today's finish.
- **Repo size** (no Git LFS): PNG maps are about 10-14 MB per gun. A CI test
  caps each gun's map set at 16 MB, and guns are only re-baked when their
  inputs change (bake record).
- Check: the GPU agent's fps run in step 5 (Halcyon, 24 zombies, 4 players).

## Steps

Each gun step: build with `blender-model`, import with `godot-asset-import`,
render with `look-check` and the new Forward+ showcase, approve turnarounds,
post concept / before / after in the thread. A gun step starts only after
that gun's F-72 shape step has merged, so the two threads never edit the same
gun script at once.

### Step 1: ADR, budget and lit previews

- Build: ADR 0014 (accepted, decided by the person 2026-11-17); weapons budget
  30,000; Mesa lavapipe in the session-start hook; `tools/gun_showcase.gd` that
  renders in Forward+ (Vulkan) a first-person shot of each gun in a
  Halcyon-lit room (corridor light colours from look-rules) and a 4-angle studio
  turntable. Baseline renders of today's four guns go to project files as the
  "before". If lavapipe cannot run Forward+ in the container, the fallback is a
  paste-ready prompt for the local GPU agent in project files (it renders
  the same scene on the RTX 4080 Super), and cloud threads keep OpenGL for
  shape checks only.
- Files: `docs/adr/0014-baked-gun-textures.md`, `docs/adr/README.md`,
  `tools/assets/check_models.py`, `.claude/hooks/session-start.sh`,
  `tools/gun_showcase.gd`, `tools/gun_showcase.tscn`, `.claude/skills/look-check/SKILL.md`
  (edited in `.agents/skills/`, then mirrored).
- Tests: `tools/assets/tests` budget test reads 30,000 (fails at 8,000);
  `tests/unit/test_gun_showcase.gd` builds the showcase scene headless and
  checks one camera, the gun and the light rig are placed.
- Done when: a Forward+ render of today's AR-17 is posted, or the GPU agent
  prompt is in project files and the reason is written in the PR.

### Step 2: Bake pipeline on the AR-17 (the risky step)

Needs F-72 step 2 (PR #322) merged.

- Build: `gun_bake.py`:
  1. Builds the gun from its script as today.
  2. Low-poly: one-segment chamfer (Bevel modifier, angle limit 30 degrees,
     0.6 mm) on hard edges, weighted normals, Smart UV with 4 px margin at
     2048, all parts on one UV sheet, mirrored parts not overlapped.
  3. High-detail copy of every part: three-segment bevel, subdivision where
     curved, then detail by material name: `Knurled` gets stipple
     (displacement from a fixed-seed Voronoi), `Worn` gets dents and edge chips
     (curvature mask), `Markings` quads become engraved logo and serial text
     (displacement from the markings atlas). Paint: base colour per material,
     chipped edges showing bare metal or primer, grime in AO creases, the
     atlas printed on.
  4. Bakes part by part (high `Magazine` onto low `Magazine` and so on, so
     moving parts never bake onto each other): normal (cage), base colour,
     AO, roughness, metal. Packs ORM (R = AO, G = roughness, B = metal).
  5. Exports the low-poly `.glb` with one `Baked` material on the gun
     (optic and sight glass stay their own materials), writes the three PNGs
     and the bake record.
  Shader baked mode and the `Baked` import mapping. Baked mode ignores the
  vertex AO in `COLOR.rgb` (the AO map replaces it); vertex alpha still marks
  the rarity inlay and Prototype glow.
- Files: `tools/assets/gun_bake.py`, `tools/assets/build_models.py`,
  `assets/materials/gun_finish.gdshader`, `tools/assets/gun_finish_import.gd`,
  `assets/textures/weapons/rifle_ar_*`, `assets/models/weapons/rifle_ar.glb`,
  `tools/ci/test_gun_bakes.py`, turnaround, tests.
- Tests: `tools/assets/tests/test_gun_bake.py` (bake a tiny two-part test
  gun at 128 px: maps exist, normal map is not flat where the high copy has a
  bevel, parts do not bake onto each other, UV islands do not overlap);
  `tools/ci/test_gun_bakes.py` (record hashes match the inputs, maps 2048 px,
  set under 16 MB); `tests/content/test_gun_finish.gd` (the `Baked` material
  gets the shader in baked mode with three maps; rarity inlay still applies);
  existing rifle node, red-dot ADS and budget tests stay green.
- Done when: the Forward+ render of the baked AR-17 sits next to the concept
  and the step 1 "before", posted to the person as a look card (keep going,
  more wear, less wear).

### Step 3: VX-9 (kestrel_smg)

Needs F-72 step 3 merged.

- Build: bake the VX-9 with the step 2 settings (and the person's step 2 look
  answer). Add segments only where the silhouette is faceted (curved mag,
  barrel, grip).
- Files: `kestrel_model.py` (segments only), `kestrel_smg.glb`, its maps and
  record, turnaround.
- Tests: Kestrel node, vertical-grip and red-dot ADS tests stay green; it is
  added to `test_gun_bakes.py` and the baked-material content check.
- Done when: Forward+ render next to the concept posted.

### Step 4: BR-12 (shotgun_brenner)

Needs F-72 step 4 merged.

- Build: bake the BR-12; shell holder hulls and brass heads come out of the
  bake (no extra materials).
- Files: `shotgun_model.py` (segments only), `shotgun_brenner.glb`, maps,
  record, turnaround.
- Tests: pump, ADS ray and budget tests stay green; added to the bake tests.
- Done when: Forward+ render next to the concept posted.

### Step 5: MR-28 (talon_dmr) and the lineup

Needs F-72 step 5 merged.

- Build: bake the MR-28; scope keeps its `ScopeLens` Z rule and `Bipod` node.
  Four-gun Forward+ lineup next to the concept; paste-ready GPU fps prompt in
  project files (Halcyon, 24 zombies, 4 players, 1440p High).
- Files: `talon_model.py` (segments only), `talon_dmr.glb`, maps, record,
  turnaround, `docs/design/look-rules.md` rule 6 line.
- Tests: Talon tests stay green; added to the bake tests.
- Done when: lineup posted, the person has seen it.

### Step 6: Intake for handed-over gun models, and close-out

Can run any time after step 2.

- Build: `gun_intake.py <source.glb> --id <weapon id>` with a part map
  `tools/assets/intake/<id>.json` (source object names to `Receiver`,
  `Magazine`, `Bolt`, `Muzzle`, `Pump`... and the grip, ADS and muzzle
  markers). It scales and turns the source to our axes (forward -Z in Godot,
  metres), decimates each part to its share of 30,000, and runs the
  `gun_bake.py` steps 2, 4 and 5 with the source as the high-detail copy.
  Sources up to 50 MB go in `tools/assets/intake/sources/` with a
  `docs/CREDITS.md` line; a bigger source is decimated to 50 MB first and
  the record keeps its sha256. Recipes in `docs/HOW_TO_ADD.md`. Then
  `finish-feature`, roadmap row Done, DECISIONS.md entry.
- Files: `tools/assets/gun_intake.py`, `tools/assets/intake/`,
  `tools/assets/tests/test_gun_intake.py`, `docs/HOW_TO_ADD.md`,
  `docs/ROADMAP.md`, `docs/DECISIONS.md`, this plan.
- Tests: `test_gun_intake.py` feeds a fixture source (a code gun built at
  high density, exported with other object names, metres off by 100 and
  Y-up) and checks the result passes `check_models.py`, has the named
  joints, faces forward and stays under 30,000 triangles. Fails without
  the intake.
- Done when: the fixture runs through end to end in CI and the recipe is
  written.

## Acceptance

- [ ] The four guns use baked maps in game and their Forward+ lineup sits
  next to the concept.
- [ ] Every gun is under 30,000 triangles and 6 materials (`check_models.py`).
- [ ] Red-dot and scope ADS ray tests, node-name tests and the arm contact
  check stay green.
- [ ] Rarity inlay still shows on baked guns (content test).
- [ ] A changed gun script without a re-bake fails CI (`test_gun_bakes.py`).
- [ ] A handed-over `.glb` runs through the intake (fixture test).
- [ ] GPU fps run at 1440p High still above 120 fps with 24 zombies.
- [ ] The person has looked at the lineup.
- [ ] `quality`, `test` and `soak` green on every step.

## Risks

- **Forward+ does not run in the cloud container** (no GPU): step 1 tries
  lavapipe first; the fallback is the local GPU agent prompt. Found in step
  1, before any bake work.
- **Bake artefacts** (moving parts baking onto each other, seams, skewed
  normals): per-part baking with a cage, tested on a two-part test gun in
  step 2 before the four guns.
- **Bake time in CI**: CI never bakes. It checks the committed maps against
  the bake record. Cloud threads bake at 2048 with low samples (AO 64);
  expected a few minutes per gun on 4 CPU cores.
- **Repo growth without LFS**: 16 MB cap per gun, re-bake only on input
  change. If it still grows too fast, switch the PNGs to lossless WebP (Godot
  imports it) before adding LFS.
- **F-72 and F-75 editing the same gun script**: each bake step waits for
  that gun's F-72 step to merge.
- **The look still misses the concept**: the step 2 look card catches it on
  one gun before three more are baked.

## Open decisions

- [x] Plan: approved for steps 1 and 2 only (the person, 2026-11-17,
  decision card "AR-17 only for now"). Steps 3 to 6 wait until the person has
  seen the baked AR-17 from step 2 and says go.
- [x] Direction, budget (30,000), lighting and intake: the person,
  2026-11-17. Map size and file format are technical picks above.
