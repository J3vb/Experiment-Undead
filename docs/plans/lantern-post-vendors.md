# Plan: Lantern Post vendors

Status: Approved
Roadmap: F-76 / issue none (a slice of F-45 pulled forward, like F-50)
Phase: P9 (town hub), pulled forward with the concept-art passes
Size: L
Approved by: the person on decision cards (cast, plan; 2026-11-18), plan PR #339

## Goal

The four market stalls in Lantern Post get the people who run them: a Cordon
officer at MISSIONS, the Quartermaster at TRADER, the Gunsmith at GUNSMITH and
the ex-HALCYON researcher at TECHNICIAN. Each one is a named character from the
lore with their own look, a working idle at their stall, a head that turns to
you when you walk up, and a short spoken line when you talk to them. The town
stops looking empty, and the shop screens of F-45 later have a face to open
from. Serves the "a place worth coming home to" side of the loot pillar.

## Scope

Superseded for models: F-80 step 3 (PR #379, [tripo-models.md](tripo-models.md))
replaced the code-built NPC pipeline below with Tripo keepers from
`tools/assets/tripo/vendors.json` under ADR 0017. ADR 0016, the `player_body`
refactor, `tools/assets/town_npcs/*`, the costume pieces and the
`character_checks` changes were not kept. Clips, `Vendor` and `VendorData` stand.

In:

- Who the four vendors are, how they look and what they will do: written into
  `docs/design/lore.md#the-stall-keepers` (done in this plan PR).
- Four code-built NPC models on the survivor body pipeline (PR #337): same
  22-bone skeleton, same 16,000-triangle and four-material budget, own head
  shape, hair, clothes and baked maps. New ADR 0016 lets them use baked maps
  like the player body (ADR 0015 covers only `player.glb`).
- Five unarmed vendor clips built in code and exported inside each NPC `.glb`:
  `counter_idle`, `bench_work`, `desk_work`, `board_idle` and a one-shot
  `greet` (a nod and a short hand lift).
- A `Vendor` interactable at each stall: prompt "Talk to Odile Brandt [F]",
  plays `greet`, shows one line over their head for a few seconds, and turns
  the head towards the nearest local player within 4 m.
- `VendorData` content: name, title, stall, idle clip, model and 4 lines each.
- Placement by the town generator `tools/levels/lantern_post_scene.py`.

Not in (non-goals, and where each one goes instead):

- What the stalls actually sell or do: Quartermaster buy and sell, Workbench
  upgrades and mods, the Technician's serum and gear offer, the Contract Board.
  Each is its own F-45 feature and plan; talking to a vendor is the hook they
  will open from. Until then the talk line is all they do.
- Voice for the lines: text only for now. Voice comes with the lore voice pass
  (notes and radio are voiced too, lore.md "How the story is told").
- Lines that change with story milestones (3 to 5 per milestone in lore.md):
  they need saved story progress, which does not exist yet (F-60).
- The other two town people, Pell at the Deploy gate and Bram Ostijn at the
  Wall of Finds, and the infirmary: later F-45 features. Their models reuse
  this plan's builder.
- Walking NPCs, crowds, or the people drinking on the Common Room balcony in
  the concept art: never as AI; a static crowd is a props question for F-74.

## Ready to build

### Ready to build

As built: the model rows below follow ADR 0017 (Tripo), not ADR 0016; see Scope.
- Foundations touched (numbers from docs/FOUNDATIONS.md): 2 interactions (the
  Vendor is an F-02 Interactable). Any of them shaky or missing? No.
- Decision records that apply (docs/adr/): 0003 trusted client, 0008
  code-built assets first, 0015 baked player body. Does this go against one?
  Yes for 0015 (it allows baked maps on `player.glb` only), so step 1 writes
  ADR 0016 first: town NPC bodies may use the same three baked maps.
- Co-op:
  - Who decides: nothing shared. Vendors are static scene parts; talking is
    personal (`is_local()` true), like picking up your own loot.
  - How a client triggers it: interact on the vendor; it runs on that client
    only, no request to the server.
  - What other players see: the same vendor in the same idle on every peer.
    The greet and the line are only shown to the player who talked. That
    matches lore.md "each player sees their own town".
  - Works on a dedicated server with no local player: yes. The server keeps the
    collision and the Area3D; the head turn and lines need a local player and
    do nothing without one.
- Data: new Resource type `VendorData` in `content/vendors/`. Code compares
  against a specific id anywhere: no (the generator reads the stall name from
  the data).
- Save: changes what is saved? no
- Events and UI: no new Events signal, no new screen. The line is a Label3D on
  the vendor.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: no new input, no gameplay. Lines go in order (no randomness);
  idle start offsets are cosmetic and marked `# cosmetic`.
- Tests: `tests/content/test_vendors.gd` (new), `tests/unit/test_vendor.gd`
  (new), `tests/unit/test_lantern_post.gd` grows, character model checks for
  the four `.glb` files.
- Logging: `Log.warn("vendor_clip_missing", ...)` when an NPC `.glb` has no clip
  named by its data. Added to docs/LOGGING.md.
- Performance: see Performance. Fps check on the GPU agent in step 5.
- Out of scope: see "Not in".

## Design references

- docs/design/lore.md#lantern-post-and-its-people: the six town NPCs, their jobs
  and backgrounds. "Swap names or jobs freely."
- docs/design/lore.md#the-stall-keepers (new in this PR): the cast, looks and
  lines this plan builds.
- docs/design/game-design.md#town-hub-lantern-post: market row signs map to
  Contract Board, Quartermaster, Workbench and the serum and gear job.
- docs/design/images/lantern_post_concept.jpg: people behind the counters in
  heavy winter clothes, warm lamp light from above, monitors at the Technician.
- docs/design/images/player_gear_concept.jpg and the survivor body (PR #337):
  the base character style (realistic proportions, worn field clothes).
- docs/design/look-rules.md: sodium `#FF9A42` warm light, bio-green `#8DFF3A`
  only for Fenlight, lab coat `#8A918C`, shirt `#2F393B`, trousers `#1C2122`.
  Rarity colours are not used on NPC clothes.
- docs/design/lantern-post-assets.md: stall layout S1-S7 (counter front at +Z,
  back wall at -Z, `tech_desk`, `workbench`, `missions_board` positions).
- docs/adr/0015-baked-player-body.md, docs/adr/0008-code-built-assets-first.md.
- docs/plans/teammate-animations.md: clips keyframed in Blender by script and
  exported inside the `.glb`.

## Systems touched

As built: the ADR 0016, `player_body`, `town_npcs/` and `character_checks` rows
were replaced by F-80 step 3 (`tools/assets/tripo/vendors.json`, ADR 0017).

| Folder or file | New / changed | What changes |
|---|---|---|
| docs/adr/0016-baked-town-npcs.md | new | Town NPC bodies may carry the three baked maps |
| tools/assets/player_body/head.py, outfit.py, build.py | changed | Take a look description (head shape, hair, beard, clothes colours) instead of fixed values; the player stays the default |
| tools/assets/town_npcs/build.py | new | Builds, bakes, checks and exports one NPC per look |
| tools/assets/town_npcs/looks.py | new | The four looks as plain dicts (head morphs, hair, beard, costume pieces, colours) |
| tools/assets/town_npcs/costume.py | new | Pieces the player has not got: long coat, shawl, apron, lab coat, parka, caps, glasses, headset |
| tools/assets/npc_clips.py | new | The five vendor clips on the shared skeleton |
| tools/assets/character_checks.py | changed | Checks the NPC clip list and loop ends |
| assets/models/characters/npc_*.glb | new | Four NPC models (bake output) |
| systems/hub/vendor_data.gd | new | `VendorData` Resource |
| systems/hub/vendor.gd, vendor.tscn | new | Interactable: prompt, greet, line, head turn |
| content/vendors/*.tres | new | Four vendors |
| tools/levels/lantern_post_scene.py | changed | Places a vendor in each stall |
| levels/lantern_post/lantern_post.tscn | changed | Generator output |

Autoloads, managers or base classes added: none. `Vendor` extends the existing
`Interactable` (named in the architecture doc).

## Data

`VendorData` (new, `systems/hub/vendor_data.gd`), one `.tres` per vendor in
`content/vendors/`, file name = id:

| Field | Type | Default | Read by |
|---|---|---|---|
| `display_name` | String | "" | prompt and line label |
| `title` | String | "" | not read by game code (as built, the prompt is "Talk to <name> [F]" from `display_name`) |
| `stall` | StringName | &"" | generator: which stall sign it stands in (TRADER, ...) |
| `model` | PackedScene | null | vendor scene |
| `idle_clip` | StringName | &"counter_idle" | vendor scene |
| `lines` | Array[String] | [] | vendor: next line on each talk |

Files: `quartermaster.tres` (TRADER), `gunsmith.tres` (GUNSMITH),
`technician.tres` (TECHNICIAN), `cordon_liaison.tres` (MISSIONS). Ids are job
names so a recast later changes only the data.

- Save format change: none.
- Content checks to add in `tests/content/`: `test_vendors.gd`: every vendor
  has a name, title, a model that loads, an idle clip present in that model,
  4 lines of at most 90 characters, and a stall that is one of the four sign
  names; no two vendors share a stall.

## Co-op behaviour

- Who owns the state (server / owning client / each client): each client.
  Vendors hold no game state; the next-line index is per client.
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too (and what only the owner sees):
  everyone sees the vendors and their idle clips. Only the talker sees the
  greet, the line and the head turn towards them.
- Late joiner: nothing to receive; vendors are part of `lantern_post.tscn`.
- Dedicated server (no screen, no local player): head turn and lines skipped;
  the AnimationPlayer may run but nothing draws.

## Performance

Hub only, no zombies. Four skinned meshes at up to 16,000 triangles and four
materials each (as built: Tripo keepers, ADR 0017): 16 draw calls plus their shadow passes, under the hub's current
headroom (hub had no fps issue in F-50). Head turn uses Godot's
`LookAtModifier3D` with its target moved in `_process` only while a local
player is within 4 m; the nearest-player search runs every 0.25 s (as built it
calls `get_nodes_in_group` each time the peer has no own player, which is
always on a dedicated server: a small allocation, not a hot path). No new lights (the hub shadow
budget is full); the Technician monitors stay emissive. Each `.glb` is about
3 MB with JPEG maps (four files, about 12 MB, no Git LFS). The fps check in
step 5 must keep the hub at the F-74 target with 8 players.

## Steps

### Step 1: Builder and the first vendor (Quartermaster)

Replaced by F-80 step 3 (docs/plans/tripo-models.md, 2026-11-19): all four keepers are Tripo models from
`tools/assets/tripo/vendors.json`; the code-built builder from PR #341 was removed. Steps 3-5 stay.

The risky part first: a second head shape (older woman) and a long coat on the
survivor pipeline. If it fails the look card, steps 2-5 change, not throw away.

- Build: ADR 0016. Make `player_body` head, outfit and build take a look dict
  (default = today's player, output byte-identical in checks).
  `town_npcs/build.py` + `looks.py` + `costume.py` with the Quartermaster look:
  head morphs from the same CC0 base head (softer jaw, older skin bake), grey
  hair in a bun, reading glasses on a cord, long charcoal wool coat, maroon knit
  shawl, fingerless gloves. Export `assets/models/characters/npc_quartermaster.glb`
  (T-pose only in this step). Turnaround, model checks, booth render next to the
  concept for a look card.
- Files: docs/adr/0016-baked-town-npcs.md, tools/assets/player_body/*.py,
  tools/assets/town_npcs/*.py, assets/models/characters/npc_quartermaster.glb,
  docs/design/turnarounds/ (the `characters` budget of 16,000 / 4 in
  `character_checks.BUDGETS` already covers NPCs; each NPC keeps the `Eyes`
  empty on the head bone that check requires),
  docs/CREDITS.md line if the base head is reused (same CC0 file, note only).
- Tests: character checks on the new `.glb` (budget, 22 bones with the same
  names, four materials, facing +Z); a check that the player `.glb` build is
  unchanged by the refactor (same triangle count and bone list).
- Done when: the look card is answered and the model passes Assets CI.

### Step 2: The other three vendors

Replaced by F-80 step 3 (see step 1).

- Build: looks for the Gunsmith (bald, thick grey-brown beard, ear defenders
  round the neck, tan canvas apron over olive overalls, rolled sleeves), the
  Technician (short black hair, padded parka under a stained Oriel lab coat
  with the logo scratched out, blue-grey radio headset) and the Cordon liaison
  (snow-grey Cordon parka, officer fur hat with the Cordon badge, black armband
  with a white Cordon mark, tablet in hand). Export three `.glb` files,
  turnarounds, a line-up render of all four.
- Files: tools/assets/town_npcs/looks.py, costume.py,
  assets/models/characters/npc_{gunsmith,technician,cordon_liaison}.glb,
  docs/design/turnarounds/.
- Tests: character checks on the three files.
- Done when: line-up render posted, Assets CI green.

### Step 3: Vendor clips

- Build: `npc_clips.py` with `counter_idle` (hands on the counter, weight
  shifts), `bench_work` (filing at a vice), `desk_work` (typing, glancing at
  the screens), `board_idle` (arms crossed, turning to the board now and then),
  all 60-120 frame loops, and the one-shot `greet`. Every NPC `.glb` carries all
  five. Re-export the four NPCs.
- Files: tools/assets/npc_clips.py, tools/assets/tripo_rig.py (clip set per manifest row:
  `"clips": "keeper"` in `tools/assets/tripo/vendors.json`, since F-80 replaced `town_npcs/`),
  tools/assets/tests/test_npc_clips.py, the four `.glb` files.
- Tests: character checks: the five clips exist, loops end where they start,
  `greet` ends in the `counter_idle` start pose (blend-safe).
- Done when: a short GIF per clip posted, Assets CI green.

### Step 4: Vendors in town

- Build: `VendorData`, `vendor.gd`/`vendor.tscn` (Interactable, `is_local()`
  true; `interact()` returns at once unless `player` is this peer's own
  player, because `Player._physics_process` also calls `interact()` on the
  host for remote players, prompt "Talk to <name> [F]", interact plays `greet` then returns to the
  idle, shows the next line in a Label3D over the head for 4 s, head turn via
  `LookAtModifier3D`), four `.tres` files with the lines from lore.md, the
  generator places one vendor per stall behind the counter (spot per stall in
  `STALLS`), regenerated `lantern_post.tscn`.
- Since F-80 (2026-11-19): the Tripo stalls have no room behind the counter, so each keeper stands inside
  on a hidden step (spot per stall in `STALL_MODELS["keeper"]`), and `Vendor.reach` stretches the talk area
  just past the stall's one big collider. Town checks live in `tests/unit/test_lantern_post_keepers.gd`.
- Files: systems/hub/vendor_data.gd, systems/hub/vendor.gd, vendor.tscn,
  content/vendors/*.tres, tools/levels/lantern_post_scene.py,
  levels/lantern_post/lantern_post.tscn, docs/LOGGING.md.
- Tests: `tests/content/test_vendors.gd` (see Data); `tests/unit/test_vendor.gd`:
  prompt holds the name, two talks give line 1 then line 2 and wrap after 4,
  `is_local()` is true, a talk by a non-local player shows nothing, head target only set inside 4 m;
  `tests/unit/test_lantern_post.gd`: four vendors, one per stall, each inside
  its stall's bounds and not inside a collider; `tools/ci/test_lantern_post_scene.py`
  still matches the generator.
- Done when: tests green, a hub render with the four vendors posted.

### Step 5: Look check, fps check and close-out

- Build: look-check renders against the concept, GPU agent prompt for the hub
  fps check with 8 players, fixes from both. DECISIONS.md entry, roadmap row
  Done, game-design Change log row.
- Files: docs/DECISIONS.md, docs/ROADMAP.md, docs/design/game-design.md,
  /mnt/project-files/lantern-post-vendors/ (renders and the GPU prompt).
- Tests: none new beyond fixes (each fix with a test).
- Done when: the person has seen the renders, fps target held.
- Look check (2026-11-20, cloud Forward+ software render): all four keepers
  read behind their counters in their own idle, warm-lit like the concept's
  market row; Raes's face at MISSIONS is the darkest of the four (lit from
  the hanging lantern above), kept as is. Market row with the keepers: 662
  draw calls and 751k primitives at 100 fov, 649 and 552k without (13 calls,
  about 50k triangles per keeper). Renders `f76_step5_keepers_close.jpg` and
  `f76_step5_market_row.jpg` in the project files. GPU fps check: prompt
  `f76-step5-gpu-fps-prompt.md` for the person's PC, result goes here.

## Acceptance

- [x] Four named vendors stand behind the four stall counters, each in their
      own idle (test_lantern_post_keepers, step 5 render).
- [ ] Walking up turns their head to you; talking plays the greet and shows
      their next line, only for you (test_vendor, co-op play-test).
- [x] Every NPC model passes the character checks and has all five clips
      (Assets CI, tests/content/test_tripo_vendors.gd).
- [ ] Hub fps target held with 8 players and the vendors in (GPU agent).
- [ ] The person approved the look on the step 1 and step 2 renders.

## Risks

- A second head from the same base mesh may look like the player in a wig.
  Step 1 builds the hardest face first and goes to a look card before the
  other three are built.
- The `player_body` refactor could change the player model by accident. Step 1
  adds a check that the player build is unchanged.
- Unarmed clips are new for this skeleton (all F-41 clips hold a gun). If the
  arms look wrong behind a counter, the counter hides the hands; step 3 GIFs
  show it early.
- The 4 m head-turn range, 4 s line time and 90-character line cap are feel
  values with no design number; they start as constants in `vendor.gd` and
  the step 5 renders and play-test confirm them (no data field, nobody tunes
  them for balance).
- Repo size grows about 12 MB. Fine without LFS for now (asset policy); the
  maps can drop to 1024 px if it becomes a problem.

## Open decisions

- [x] Who runs which stall: the lore cast (Odile Brandt at TRADER, Teun Maes
      at GUNSMITH, Dr. Lien Corvelyn at TECHNICIAN, Lt. Raes at MISSIONS),
      the person, 2026-11-18.
- [x] Plan approval: all five steps, people and talk now, shop screens
      later in F-45 (the person, 2026-11-18).
