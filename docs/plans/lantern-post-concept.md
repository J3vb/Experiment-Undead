# Plan: Lantern Post to the concept art

Status: Review
Roadmap: F-68 / issue none (follows F-50)
Phase: P9 (pulled forward with F-50 for the co-op week goal)
Size: L
Approved by:

## Goal

The town players land in after joining a server looks like the Lantern Post
concept art (`docs/design/images/lantern_post_concept.jpg`): a snowy timber
outpost on a mountain ridge at night, warm sodium and lantern light, a market
row of stalls, a Common Room lodge, and a huge concrete Deploy gate with a
green-lit tunnel. Serves the co-op pillar (the hub is where friends meet and
squad up) and the "one warm, safe place" look of look-rules.md.

The Deploy board and the ready-up vote keep working exactly as now (F-50).

## Scope

In:

- Concept image saved as the town look target in `docs/design/images/` and
  linked from look-rules.md (done in this plan PR).
- The town scene generator moves into the repo
  (`tools/levels/lantern_post_scene.py`) so the scene has a source script, like
  Halcyon Labs has `layout.json` and its builder. Today it lives outside the repo.
- Ridge setting: distant snowy mountains, a radio mast with red lights on the
  ridge, night sky with stars and an aurora, falling snow, chimney smoke.
- Ground: wet, muddy, snow-edged road with puddles in place of clean cobbles;
  snow drifts along walls and stalls.
- Timber lodge kit (Blender): log and plank walls, two storeys, balconies with
  rails, heavy snow on roofs, icicles, lit windows. The big "LANTERN POST" lodge
  with its painted sign and hanging lantern, and the Common Room lodge with a
  string-lit balcony, satellite dish and smoking chimney.
- Market row (Blender): stalls with canvas awnings and sign boards (Missions
  board, Trader, Gunsmith, Technician), counters, tool and gun walls, monitors.
  Look only: their jobs come with F-45.
- Deploy gate (Blender): concrete bunker wall with a walkway and rails, the
  "DEPLOY" sign with green chevrons, a tunnel lit by green strip lights,
  hazard stripes, maroon banners with the outpost emblem, floodlights and a
  watchtower with a sweeping spotlight.
- Props (Blender): fire barrel with flames, benches, snowy ammo and supply
  crates, Fenlight sample crates with glowing green jars, hanging lanterns,
  string lights.
- Light pass, look check against the concept, GPU fps check with 8 players.

Not in (and where it goes):

- NPCs and other people at the stalls (F-45, with the NPC models).
- Stall jobs: Stash, Workbench, Quartermaster, Trainer, Contracts, Firing
  Range, Hall of Records (F-45).
- Map list screen and squads at the gate (F-45, with the second map).
- Town ambience and music (later audio row).
- The concept's "EXPERIMENT: UNDEAD" title card: it is concept-art framing,
  not part of the town.

## Ready to build

### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 2 interactions
  (the Deploy board is an F-02 Interactable, unchanged). Any of them shaky or
  missing? No.
- Decision records that apply (docs/adr/): 0003 trusted client, 0008
  code-built assets first. Does this go against one? no.
- Co-op:
  - Who decides: nothing new to decide. The town is static geometry; the
    vote stays the server's `DeployVote`.
  - How a client triggers it: unchanged (interact on the Deploy board).
  - What other players see: the same static town on every peer. Falling snow,
    smoke, flames and the spotlight sweep are cosmetic and run locally.
  - Works on a dedicated server with no local player: yes. Particles and
    lights do nothing without a renderer; the server needs only collision.
- Data: no new Resource types. Code compares against a specific id anywhere: no.
- Save: changes what is saved? no
- Events and UI: none new. The vote panel and board prompt are unchanged.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: no input, no gameplay. Cosmetic randomness only (spotlight
  phase, flame flicker) marked `# cosmetic`.
- Tests: `tests/unit/test_lantern_post.gd` grows (see steps);
  `tests/content/test_town_models.gd` covers the new models.
- Logging: none new.
- Performance: see Performance. Fps check on the GPU agent after step 5.
- Out of scope: see "Not in".

## Design references

- docs/design/images/lantern_post_concept.jpg: the look target (2026-11-17).
- docs/design/look-rules.md#lantern-post-town: warm safe place, lanterns,
  fire barrels, lit windows, cold blue fog, the only green is the Deploy Gate,
  baked light except fire barrels and one sweeping watchtower spotlight.
- docs/design/lore.md#lantern-post-and-its-people: border-post village on the
  highest, coldest ridge; sodium lamps on every roof mean safe. NPC jobs:
  Quartermaster, Gunsmith, Doctor, Radio operator, Cordon liaison, Keeper.
- docs/design/game-design.md#town-hub-lantern-post: the places in town.
- docs/plans/lantern-post-hub.md: current town, spawn line and Deploy board
  interface (unchanged by this plan).
- docs/plans/halcyon-labs-props.md: the prop model pipeline this plan copies.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| docs/design/images/lantern_post_concept.jpg, docs/design/look-rules.md | new / changed | Look target and its link (this plan PR) |
| tools/levels/lantern_post_scene.py | new (step 1) | The scene generator, moved in from the project folder; writes `levels/lantern_post/lantern_post.tscn`. Same `PlayerSpawn` and `DeployBoardSpot` positions |
| levels/lantern_post/lantern_post.tscn | changed (every step) | Regenerated from the script |
| levels/looks/lantern_post_night.tres | changed (step 1) | Sky shader with stars and aurora, colder fog, glow |
| levels/materials/town_sky.gdshader | new (step 1) | Night sky: gradient, stars, aurora bands; no textures |
| levels/materials/town_surface.gdshader + town_mud.tres | changed / new (step 1) | Wet mud road with puddles and snow edges |
| levels/lantern_post/snowfall.tscn, chimney_smoke.tscn | new (step 1) | `GPUParticles3D` snow around the camera area and smoke columns |
| tools/assets/town_props.py, town_lodges.py, town_stalls.py, town_gate.py | changed / new (steps 2-5) | Blender model scripts, added to `build_models.py` MODELS like the Halcyon prop scripts |
| assets/models/town/*.glb (+ .import), docs/design/turnarounds/town/*.png | new | Lodge kit, stalls, gate, props; `.import` uses `prop_import.gd` with `light_baking=2` |
| tools/assets/prop_import.gd | changed (step 2) | New shared slots `Canvas`, `Logs`, `Snow`, `Banner` pointing at new `levels/materials/town_*.tres` |
| tools/assets/check_models.py, tools/turnarounds.py, .github/workflows/assets.yml | changed | Town budget raised for the gate and lodges (see Performance); turnaround reference becomes the concept image; output list |
| tests/unit/test_lantern_post.gd, tests/content/test_town_models.gd | changed | See steps |
| tools/hub_shot.gd | changed (step 1) | Adds a shot from the concept's camera spot for side-by-side look checks |

Autoloads, managers or base classes added: none.

## Data

- No new Resource types, `.tres` content, save fields or network messages.
- New materials only (`levels/materials/town_*.tres`).
- Save format change: none.
- Content checks to add in `tests/content/`: the new town models in
  `test_town_models.gd` (origin on the ground, front faces +Z, only known
  material slots, glowing parts emit).

## Co-op behaviour

- Who owns the state: no state. The town is static on every peer.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same town. Snow, smoke,
  flames and the spotlight sweep run on each client and need not match.
- Late joiner: nothing to receive beyond the scene.
- Dedicated server: loads the scene for collision; particles and lights skipped
  by having no renderer.

## Performance

Budget: 120 fps at 1440p High with 8 players on the RTX 4080 Super (F-50
target), and the Low preset must stay playable.

- At most 6 shadowed lights (today 6). Total real-time lights stay at or
  under 30 (today 22); string-light bulbs are emissive meshes, not lights.
- Lodges and stalls are one mesh each with up to 4 materials; repeated pieces
  (crates, benches, barrels) are instanced scenes so the renderer batches them.
- Model budget for the `town` folder: 2,500 triangles and 4 materials today.
  The gate and the big lodges need about 8,000; they get their own `town_large`
  entry (8,000 / 4) instead of raising the small-prop limit.
- Snow: one `GPUParticles3D` of at most 4,000 particles near the street,
  smoke: up to 4 emitters of 64. Particles cost no CPU per frame.
- Draw calls: under 600 with the whole street in view (444 today); step 5
  records the count in the PR.
- GPU agent prompt after step 5: fps at 1440p High and Low with 8 players, then
  the lightmap bake.

## Steps

### Step 1: Generator in the repo, ridge sky and wet road

- Build: move the generator into `tools/levels/lantern_post_scene.py`
  (ruff clean) and regenerate the scene with no visible change first, then:
  night sky shader with stars and aurora, distant mountain ridge meshes and the
  radio mast with red lights, mud road with puddles and snow edges, snow drifts,
  falling snow and chimney smoke. `hub_shot.gd` adds the concept camera shot.
  Riskiest look parts (sky, aurora, road) come first so a wrong pick is cheap.
- Files: `tools/levels/lantern_post_scene.py`, `levels/lantern_post/*.tscn`,
  `levels/looks/lantern_post_night.tres`, `levels/materials/town_sky.gdshader`,
  `levels/materials/town_surface.gdshader`, `levels/materials/town_mud.tres`,
  `tools/hub_shot.gd`, `tests/unit/test_lantern_post.gd`.
- Tests: `test_lantern_post.gd` adds: running the generator reproduces the
  committed scene (scene is not hand-edited); the Deploy board stands at
  `DeployBoardSpot` and a ray from the spawn to the board at chest height hits
  nothing; shadowed lights at most 6 and real-time lights at most 30. Existing
  spawn-line tests stay.
- Done when: CI green, side-by-side render with the concept in the PR.

### Step 2: Timber lodges

- Build: `town_lodges.py` kit (log wall, plank wall, balcony, snowy roof with
  icicles, porch with steps) and two hero lodges: "LANTERN POST" (painted sign,
  hanging lantern) and the Common Room (balcony with string lights, dish,
  chimney). Houses in the generator switch to the kit. New shared slots in
  `prop_import.gd`.
- Files: `tools/assets/town_lodges.py`, `build_models.py`, `check_models.py`,
  `turnarounds.py`, `assets.yml`, `prop_import.gd`, `assets/models/town/*`,
  `docs/design/turnarounds/town/*`, `levels/materials/town_*.tres`,
  generator, scene, `tests/content/test_town_models.gd`.
- Tests: model checks (origin, facing, slots, no flat surfaces); the step 1
  spawn and board tests still pass with the new houses.
- Done when: CI green, render in the PR.

### Step 3: Market row

- Build: `town_stalls.py`: stall frame with canvas awning, sign boards with the
  picked names, counters, tool wall, gun rack, monitor, and the Missions board
  with maps and notes. Placed along the west side of the street with 1.5 m
  clearance for players.
- Files: `tools/assets/town_stalls.py`, model lists, `assets/models/town/*`,
  turnarounds, generator, scene, tests.
- Tests: model checks; a test that every stall leaves a 1.5 m walk lane to the
  street (box overlap check against the player capsule line).
- Done when: CI green, render in the PR.

### Step 4: Deploy gate

- Build: `town_gate.py`: concrete wall with walkway and rails, tunnel mouth,
  DEPLOY sign with green chevrons, hazard stripes, banner hangers, floodlights,
  watchtower. Green strip lights inside the tunnel. The watchtower spotlight
  sweeps (a small `AnimationPlayer` loop, no script). The Deploy board moves
  to the tunnel mouth only if `DeployBoardSpot` moves with it in the generator.
- Files: `tools/assets/town_gate.py`, model lists, `assets/models/town/*`,
  turnarounds, generator, scene, tests.
- Tests: model checks; board reachable test from step 1; the tunnel is
  blocked behind the board (players cannot walk out of town).
- Done when: CI green, render in the PR.

### Step 5: Props, light pass, close-out

- Build: fire barrel with flame particles and a flickering light, benches,
  snowy crates, Fenlight sample crates with glowing jars, hanging lanterns,
  string lights. Light pass against the concept; draw-call count in the PR;
  GPU fps and bake prompt into `/mnt/project-files/lantern-post/`.
- Files: `tools/assets/town_props.py`, model lists, assets, generator, scene,
  tests, docs (`DECISIONS.md`, this plan to Done, roadmap row Done).
- Tests: model checks; light budget test from step 1 still passes.
- Done when: CI green, the person approves the look (decision card), GPU
  agent reports fps at or above target.

## Acceptance

- [ ] The town reads as the concept art from the concept's camera spot
      (side-by-side render, the person approves).
- [ ] Ready-up on the Deploy board still sends the whole server to Halcyon
      Labs (existing `test_deploy_board.gd` and co-op tests pass unchanged).
- [ ] 8 players fit on the spawn line (existing test).
- [ ] 120 fps at 1440p High with 8 players on the GPU agent.

## Risks

- Software renders in the cloud are darker than the GPU: judge layout and
  colour there, final light on the GPU agent.
- The concept is a painting: real-time scale of the gate and mountains may
  need cheats (backdrop meshes far away, fog). Step 1 tests the backdrop first.
- Many warm lights: string bulbs are emissive only, and the bake replaces
  most real-time light.
- The generator outside the repo may have drifted from the committed scene:
  step 1 regenerates with no visible change before anything else.

## Open decisions

- [ ] Stall names on the signs: the concept's Trader, Gunsmith, Technician,
      Missions and Common Room, or the design doc's Quartermaster, Workbench,
      Trainer and Contract Board. Decision card.
- [ ] Aurora colour: green as in the concept breaks "the only green in town is
      the Deploy Gate". Decision card.
- [x] Plan as a whole, including restyling the houses as timber lodges and
      the mountain ridge setting: approved, all 5 steps (the person, 2026-11-17).
