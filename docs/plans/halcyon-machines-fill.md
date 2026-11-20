# Plan: Halcyon Labs machine models and fuller rooms

Status: Building
Roadmap: F-83
Phase: P5 (art)
Size: L
Approved by: the person (decision card "Approve, build it", 2026-11-19), plan PR #382
Lore link: machines from docs/design/lore.md "Machines" (every machine is leftover Oriel equipment that Fenlight has grown into; power switch restarts the backup generators; exfil is a Lantern Post pickup crew's hatch). Room props from "Maps, rooms and props" (each room tells one small story: Guard Post is Oriel security, Generator Hall the backup power, Labs where HALCYON grew Fenlight).

## Goal

Git note: the F-83 commits are #388 and #395 (and step 4). #385, #387 and #386
are labelled F-83 by mistake; they are F-84 and F-85 work.

From the person's solo play-test (2026-11-19): the Med Dispensers, Reforger,
power switch and exfil hatch are still grey boxes, and the rooms feel empty.
The four machines get real models made in Tripo, and the bare rooms get more
story clutter plus a few small moving and sounding things, so Halcyon Labs
feels lived in and abandoned. Pillar: the look matches the concept art.

## Scope

In:

- `tripo_make.py` makes the input image itself: Tripo `text_to_image` from
  the manifest row's `prompt` (5 credits, measured 2026-11-19), saved to
  `tripo/sources/<family>/<name>.jpg` for the person to approve before the
  model is paid for. `--images` makes images only.
- Four machine models in `assets/models/machines/`: `med_dispenser` (one
  model for all 8 Serums with one teal glow for every Serum, as DECISIONS.md
  records for F-83; PR #388 removed the per-Serum `GlowBack` line, the label
  stays), `reforger`, `power_switch`, `exfil_hatch`.
- About 12 Tripo room props (list in step 3) placed in the barest rooms
  (Main Corridor, Generator Hall, Guard Post, Labs floor), plus more copies of
  existing code-built props and dressing where they fit.
- Small life: a slow ceiling fan, dripping water, a crackling PA speaker,
  papers lifting near a vent (code and generated sounds, no Tripo).

Not in (non-goals, and where each one goes instead):

- Walk-through props (missing colliders): thread "Fix walk-through objects
  and stutters" owns that. New props in this plan get colliders from the start.
- Lantern Post fill: a later thread once Halcyon is signed off (same props).
- Exfil hatch opening animation or rope ladder: later, with the exfil polish.
- Specimen Vault and wall racks: already code-built (F-64), unchanged.

## Ready to build

```
### Ready to build
- Foundations touched: none (asset tools, models, map dressing).
- Decision records that apply: ADR 0017 (Tripo models) covers F-76/F-77 only;
  step 1 widens it to Halcyon machines and room props (one paragraph).
  ADR 0015 (baked maps) covers the map set. Does this go against one? no.
- Co-op: n.a. Models and dressing only; machine logic (MedDispenser,
  Reforger, PowerSwitch, ExfilHatch scripts) is not touched. Ambient motion
  is local visuals on each peer.
  Works on a dedicated server with no local player: yes (loads the same scenes).
- Data: no new ids or numbers. Manifest rows in tools/assets/tripo/halcyon.json.
  Code compares against a specific id anywhere: no
- Save: no
- Events and UI: none
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a.
  (fan spin and drip timing are visual, in _process, not gameplay)
- Tests: test_tripo_make.py (image task faked), tests/content/test_machine_models.gd,
  existing halcyon prop/clearance tests, Assets CI checks.
- Logging: n.a. (offline tool prints credits per model).
- Performance: see Performance.
- Lore link: see header.
- Out of scope: as listed above.
```

## Design references

- docs/design/lore.md "Machines" and "Maps, rooms and props"
- docs/design/look-rules.md (palette; Halcyon hazard colour is orange, not yellow)
- docs/design/maps.md Halcyon rooms table (where each machine sits)
- docs/plans/tripo-models.md, docs/design/tripo-prompts.md (style line, rules)
- docs/adr/0017 (Tripo models), 0015 (baked maps)

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/tripo_make.py | changed | `text_to_image` step, `--images` |
| tools/assets/tests/test_tripo_make.py | changed | image task tests |
| tools/assets/tripo/halcyon.json | new | machine and room prop rows with prompts |
| docs/design/tripo-prompts.md | changed | Halcyon machine and prop prompts |
| docs/adr/0017-tripo-models.md | changed | scope widened to Halcyon machines and props |
| assets/models/machines/*.glb | new | four machine models (intake output) |
| systems/interactables/med_dispenser.tscn, reforger.tscn, power_switch.tscn, exfil_hatch.tscn | changed | Block body replaced by model + box collider |
| assets/models/props/*.glb | new | room props (intake output) |
| levels/halcyon_labs/layout.json, blockout.tscn | changed | new prop rows (regenerated) |
| levels/halcyon_labs/atmosphere.tscn | changed | fan, drips, PA speaker, papers |
| tools/generate_sfx.py, assets/audio/ | changed | drip and PA crackle sounds |
| tests/content/test_machine_models.gd | changed | machine scene checks (planned as a new test_halcyon_machines.gd) |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: tools/assets/tripo_make.py (about 230
now; the image step adds about 40).

## Data

- Manifest rows (JSON, tools only): name, folder, kind, height or length,
  yaw, `prompt`, then `image`, `image_task_id`, `task_id`, `source`, `made`
  written back by the tool. Images and sources live in the project files,
  not in git.
- Save format change: none
- Content checks to add in `tests/content/`: none (no new Resource type).

## Co-op behaviour

- Who owns the state: no new state. Machine scripts are unchanged.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same models. Fan angle and
  drip timing differ per peer (visual only, does not matter).
- Late joiner: nothing extra.
- Dedicated server: loads the models; ambient sounds and particles never
  play there (no camera, existing atmosphere rule).

## Performance

- Each Tripo model is one material, so one draw call per instance. 8 Med
  Dispensers = 8 draw calls, about the same as today's boxes plus strips.
- Room props: at most +15 draw calls per room (F-68 room budget rule: +30 %
  over its baseline, Mess Hall and Main Corridor +15 %). Measured by hiding
  the new nodes in the step's PR.
- Budgets from check_models.py: machines 2,000 tris / 4 mats (current
  machines family); room props 2,000 / 4; maps 1024 px. Each Tripo prop adds
  about 3 MB video memory.
- Fan: one Node3D rotation per frame in _process, no allocation. Drips are a
  GPUParticles3D with a small amount; PA crackle is an AudioStreamPlayer3D on
  a Timer.

## Credits

960 at the start; 900 left after the probes in this plan (two test models
and four images). Measured: image 5, text model 30. Budget for this plan
(image to model assumed about 30, checked in step 1):

| Step | Models | Images | Credits |
|---|---|---|---|
| 2 machines | 4 | 4 made + 2 redos | about 130 |
| 3 room props | 12 | 12 + 4 redos | about 440 |
| Reserve for redos | | | about 330 |

As spent: image to model cost 40 credits per model, not 30 (PR #388), and
step 3 spent 540 against its budget of about 440 (PR #395).

Manifests keep task ids, so a good model is never paid for twice.

## Steps

### Step 1: Image step in the Tripo tool

- Build: `tripo_make.py` makes the image from the row's `prompt` (style line
  added from tripo-prompts.md) with `text_to_image` when the row has no
  `image`; `--images` stops after images; prints each task id as soon as
  Tripo returns it. Manifest `tools/assets/tripo/halcyon.json` with the four
  machines and the room props. ADR 0017 scope paragraph. Contact sheet of the
  machine images to the person.
- Files: tools/assets/tripo_make.py, tools/assets/tests/test_tripo_make.py,
  tools/assets/tripo/halcyon.json, docs/design/tripo-prompts.md, docs/adr/0017.
- Tests: test_tripo_make.py: image task body, image saved and row updated,
  `--images` never starts a model task, failed image task stops with Tripo's message.
- Done when: CI green; the person approves the four machine images.

### Step 2: The four machines

- Build: `tripo_make.py --only` the four machines; intake to
  `assets/models/machines/` (light_baking 3 like the other machines). Each
  scene swaps its Block `Body` for a StaticBody3D with a box collider plus the
  model; labels and sounds stay (one teal glow, see Scope). Exfil hatch lies flat and is
  walkable (3 x 3 m, under 0.2 m tall). Before and after shots per room.
- Files: assets/models/machines/, the four machine scenes, turnarounds,
  tests/content/test_machine_models.gd (as built; F-79 step 10 made the
  check_models.py JOINTS rows and assets.yml outputs unnecessary).
- Tests: test_machine_models.gd: each scene has its model, each model fills its
  collider box (colliders and interaction areas were refit in PR #388), glow nodes still found by the scripts; existing
  machine unit tests stay green; Assets CI budgets.
- Done when: CI green; shots in the PR; the person signs off the look.

### Step 3: Room props

- Build: images (approved first), then models for: tipped office chair,
  wheeled lab cart with trays, steel supply shelving, engineer's tool cart,
  gas cylinder rack, biohazard waste bin, wheelchair, janitor cart, fire
  hose cabinet (wall), tipped server rack, dropped riot shield with spent
  cases, water cooler. Place them in layout.json (Main Corridor, Generator
  Hall, Guard Post, Labs floor first) with colliders, plus extra copies of
  existing code-built crates, papers, cables and filing cabinets.
- Files: assets/models/props/, layout.json, blockout.tscn (regenerated),
  docs/design/lore.md (one line per room story if a new one is needed).
- Tests: existing door and spawn clearance tests, player-start sight line
  test, Assets CI budgets, blockout up-to-date test.
- Done when: CI green; draw calls per room within budget; before and after
  shots.

### Step 4: Small life

- Build: slow ceiling fan in the Mess Hall, a PA speaker in the Main Corridor
  that crackles every 20 to 40 s, papers lifting near a Labs vent (the Coolant
  Tunnel and Containment drips already exist from F-61, `Drips/*` in
  atmosphere.tscn). All in atmosphere.tscn,
  power-on and power-off groups as F-61 did.
- Files: levels/halcyon_labs/atmosphere.tscn, tools/generate_sfx.py,
  assets/audio/, tests/unit/test_halcyon_atmosphere.gd (or existing atmosphere test).
- Tests: atmosphere test finds the new nodes and that none cast shadows;
  sound files exist and are short.
- Done when: CI green; a GPU fps check prompt for the person (same as F-61).

## Acceptance

- [x] The four machines use Tripo models; the machine scripts and tests are unchanged.
- [x] 12 new room props placed, each with a collider, rooms within draw-call budget.
- [x] Fan, drips, PA crackle and papers play in game.
- [ ] fps after the GPU check stays above 120 at 1440p with 24 zombies.
- [x] Credits spent per model listed in each step's PR.

## Risks

- Tripo look drift (yellow stripes, AI text): images are approved before any
  model is paid for; prompts ask for hazard orange and no text.
- Lightmap: new static props need the person's GPU re-bake to look right;
  until then they use dynamic light only (machines are light_baking 3 anyway).
- Draw calls: one material per Tripo prop; if a room goes over, cut the copies
  of code-built dressing first.

## Open decisions

- [x] Approve this plan and the four machine images (board in the project
  files: halcyon-machines-tripo/board.jpg): approved 2026-11-19; stripes
  redone in hazard orange before modelling.
