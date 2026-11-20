# Plan: Existing zombies to Tripo models

Status: Done
Roadmap: F-86 / issue none (person's ask in the project thread, 2026-11-20)
Phase: P4
Size: M
Approved by: Claude plan review on PR #436 (Codex out of quota), fixes applied, 2026-11-20 (size M, no open decisions; built on the person's ask)
Lore link: Shambler, Crawler and Bloater rows in [lore.md](../design/lore.md#story-links-for-game-content). The two Shambler looks are Halcyon's own dead: lab staff who turned first on Day 0 and Oriel security who held the doors (backstories in the Tripo character list). The Crawler is a Shambler whose legs were blown off. The Bloater's belly glows because the pods do. No new names, signs or text.

## Goal

The Shambler, Crawler and Bloater look like the person's Tripo zombies (the
same look as the new Glower) instead of the code-built grey bodies, with the
same moves, hit zones and gore. Pillar: "Cold Containment look" (art matches
the concept work).

## Scope

In:

- Run the person's Tripo sources (already made, no new Tripo credits) through
  the zombie intake from F-28 step 1 (`tripo_intake.py --kind zombie`, PR #422):
  `tripo/sources/bloater.glb`, `shambler_labtech.glb`, `shambler_guard.glb`.
- Two Shambler looks: Walkers (and runners from the speed mix) show the lab
  tech or the guard, picked from the zombie's synced `net_id`, so every peer
  shows the same look with no new message.
- Bloater: Tripo model, the belly pulse on hit and the pod glow kept through a
  small shader on the baked material (the Tripo body is one mesh, so the
  separate `Belly` mesh goes away).
- Crawler: the lab tech Shambler with its legs cut off at mid-thigh and laid
  prone, the way `zombie_model.py` does it now, with the `Crawler` marker so
  `ZombieRig` keeps its crawl poses. It is still not spawned (that is F-27).
- Delete the code-built zombie builder (`zombie_model.py`, `zombie_details.py`
  and their tests) once nothing uses it.

Not in (non-goals, and where each one goes instead):

- Brute and Stalker models (F-30 and F-29 plans own them).
- Spawning the Crawler, its rules and numbers (F-27).
- Real animation clips for zombies (DECISIONS "Procedural animation" stays).
- New zombie sounds (current ones stay).
- More Shambler looks or per-map looks (later, when other maps get rounds).

## Ready to build

```
### Ready to build
- Foundations touched: 2 (content as data: model scenes in .tscn/.tres), 7 (no
  per-frame allocations). Any of them shaky or missing? no. Needs the zombie
  intake from F-28 step 1 (PR #422, merged 2026-11-20).
- Decision records that apply: 0008 code-built art (superseded for these models
  by 0017), 0017 Tripo models ("code-built stay for done features until a plan
  moves them": this plan moves the three zombies; step 1 adds the line to 0017),
  0003 trusted-client co-op. Does this go against one? no
- Co-op:
  - Who decides: server, as today (spawns, damage). The look is visual only.
  - How a client triggers it: it does not.
  - What other players see: the Shambler look comes from net_id, which the
    Spawner already sends; every peer picks the same model. Late joiners get
    net_id in the same spawn data.
  - Works on a dedicated server with no local player: yes (the server loads the
    same scene; looks cost nothing there beyond today's model).
- Data: model scenes stay in systems/enemies/*.tscn; no EnemyData field. Code
  compares against a specific id anywhere: no
- Save: changes what is saved? no
- Events and UI: none. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (the look uses net_id, not randomness)
- Tests: tests/unit/test_zombie_rig.gd (every posed bone, head zone at head
  height, look from net_id, belly pulse), tools/assets/tests/test_tripo_zombies.py
  (budgets, heights, markers), tests/content model checks.
- Logging: none new (a missing bone already fails loudly in _cache_bone).
- Performance: per-instance shader parameter for the belly pulse (no material
  copy per Bloater). Triangle budget per zombie 9,000 (zombies folder budget).
- Lore link: see the header line.
- Out of scope: see Not in.
```

## Design references

- docs/design/lore.md#story-links-for-game-content (Shambler, Crawler, Bloater rows)
- /mnt/project-files/tripo/characters.md "Priority 3: the Lit" (looks and backstories)
- docs/adr/0017-tripo-models.md
- docs/plans/blackout-glowers.md step 1 (the zombie intake this plan reuses)
- docs/DECISIONS.md "Procedural animation" line (poses stay in code)

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| assets/models/zombies/ | changed | shambler, bloater, crawler .glb from the intake; new shambler_guard .glb; baked JPEG maps |
| tools/assets/tripo/zombies.json | changed | manifest rows for the four models |
| tools/assets/tripo_intake.py / tripo_rig.py | changed | crawler option (cut legs, prone rest, `Crawler` marker), step 2 only |
| systems/enemies/zombie_rig.gd | changed | `extra_models` export, look picked from net_id; belly pulse through the shader parameter |
| systems/enemies/zombie.gd | changed | `setup()` sets `($Visual as ZombieRig).look = hash(net_id)` (`visual` is @onready, still null there; `_ready` is too late) |
| systems/enemies/zombie.tscn, bloater.tscn, glower.tscn | changed | hit zone sizes fitted to the new bodies; zombie.tscn lists the guard look; bloater.tscn and glower.tscn override `extra_models = []` so they never inherit the Shambler looks |
| tools/assets/zombie_import.gd, assets/materials/ | changed / new | Bloater pod glow + pulse shader on its baked material; the Shambler looks get a plain baked material (no vein glow) |
| tools/assets/zombie_checks.py | changed | `shambler_guard` stem; shambler/crawler/bloater budgets 9,000; step 2 lets crawler stumps through (reweighted to pelvis) |
| tools/assets/build_models.py | changed | shambler and bloater entries removed in step 1, crawler in step 2 (one source per .glb) |
| tests for the code-built finish | changed / deleted | step 1: test_zombie_finish.gd, test_model_finish.gd, test_gear_import.gd zombie cases and test_zombie_rig.gd `CoatSkirt` lose their shambler/bloater cases; the .glb.import files switch from zombie_finish_import.gd to zombie_import.gd |
| tools/assets/zombie_model.py, zombie_details.py, zombie_finish_import.gd, zombie_finish.gdshader and tests | deleted | step 3, once all three are swapped |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: `systems/enemies/zombie_rig.gd` (314).
Step 1 deletes `_attach_belly` and `_belly` (about 20 lines), which pays for the look pick and the shader pulse; if F-29 step 1 has split it
first, the change goes into the split file. If a step would pass 350 lines, it
moves the crawl poses to `zombie_crawl_pose.gd` first (split by job).

## Data

- No Resource type or field changes. `ZombieRig` gains `@export var
  extra_models: Array[PackedScene]` (scene data, empty by default).
- No network message changes (net_id is already in the spawn data). Protocol
  stays.
- Save format change: none.
- Content checks: the existing generated-model checks in `tests/content/` cover
  the new .glb files (with the baked-zombie rules from PR #422).

## Co-op behaviour

- Who owns the state: server (spawns and damage, unchanged). The look is a pure
  function of net_id on each peer.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same Shambler look per zombie,
  the same belly pulse (it already runs from the synced hit).
- Late joiner: net_id in the spawn data, as today.
- Dedicated server: loads the models as today; the shader parameter is set but
  never drawn.

## Performance

Same draw calls per zombie as the Glower (one mesh, one material). 9,000
triangles each, under the zombies folder budget. The belly pulse sets an
instance shader parameter from a tween, no allocation per hit beyond today's
tween. Checked by the existing benchmark job (24 zombies).

## Steps

### Step 1: Shambler looks and the Bloater from Tripo

- Build: intake `bloater`, `shambler` (lab tech) and `shambler_guard` with
  `--kind zombie` and manifest rows. `ZombieRig.extra_models` and the look pick
  `([model] + extra_models)[look % size]`, where `look` (default 0, so `ZombieRig.new()` in tools still works) is `hash(net_id)` set in `Zombie.setup()` before the rig enters the tree. `hash` because `Net.allocate_id` is one counter for every zombie type, so a plain `% 2` with an alternating Walker/Bloater mix would give every Walker the same look. Delete `_attach_belly` and `_belly`. All Tripo zombies import through
  `zombie_import.gd` and share the Glower vein glow (lore: every Lit has faint green eyes and veins; changed
  while building, see DECISIONS). `glower_veins.gdshader` gets an `instance uniform float pulse` that pushes
  the green area out along the normal, gated by `ZombieRig.pulse_size` (Bloater only);
  `pulse_belly()` tweens `instance_shader_parameters/pulse` on the `Body` mesh; the pod mask comes from `textureLod` of the albedo in `vertex()`. Fit the Body hit zones and capsules to the new
  heights. Turnarounds approved in `docs/design/turnarounds/zombies/`. ADR 0017
  line: these three zombies are Tripo now.
- Files: assets/models/zombies/* (and their .glb.import), tools/assets/tripo/zombies.json,
  systems/enemies/zombie_rig.gd, zombie.gd, zombie.tscn, bloater.tscn, glower.tscn,
  tools/assets/zombie_import.gd, zombie_checks.py, build_models.py,
  assets/materials/glower_veins.gdshader, tests/content/test_zombie_finish.gd,
  test_model_finish.gd, tests/unit/test_gear_import.gd,
  docs/adr/0017-tripo-models.md, docs/design/turnarounds/zombies/.
- Tests: test_zombie_rig.gd: Walkers with two looks values get the two looks; a Bloater and a Glower with any look keep their own model;
  every posed bone exists on each; the head zone sits on the head; a hit sets
  the Bloater pulse parameter and it returns to 0; head pop still shrinks the
  head. test_tripo_zombies.py: the three models pass the model rules, heights
  within 5% of the manifest, HeadCenter on the head bone.
- Done when: a round on Halcyon Labs shows both Shambler looks and the Tripo
  Bloater; soak and coop-soak pass.

### Step 2: Crawler from the lab tech Shambler

- Build: intake option `--crawler` for zombies: drop vertices weighted mostly to
  shin and foot bones, cap the cut, set thigh/shin/foot to non-deform, rest
  the pelvis prone the way `zombie_model._rest_pose` does, add the `Crawler`
  marker, reweight the thigh stumps to the pelvis (zombie_checks rejects thigh weights). Output `crawler.glb` from `shambler_labtech.glb`. Remove the crawler entry from build_models.py.
- Files: tools/assets/tripo_intake.py, tripo_rig.py, tools/assets/tripo/zombies.json,
  assets/models/zombies/crawler.glb (+ maps), docs/design/turnarounds/zombies/crawler.png.
- Tests: test_tripo_zombies.py: no vertex below the cut, Crawler marker present,
  model lies under 0.8 m tall. tests/unit/test_crawler_pose_clearance.gd keeps
  passing on the new model.
- Done when: the crawl poses look right in the lineup render.

### Step 3: Delete the code-built zombies

- Build: remove `zombie_model.py`, `zombie_details.py`, `zombie_finish_import.gd`,
  `assets/materials/zombie_finish.gdshader`, `test_zombie_finish.gd`, the zombie cases in
  `test_gear_import.gd`, the non-baked branch of `zombie_checks.py`, their tests, the
  `zombie_model.py` comments in `zombie_rig.gd` and `tripo_rig.py`, and the code-built
  paths in `zombie_pose_capture.gd`; point `zombie_lineup.gd`, `zombie_review.gd` and
  the look reference scene at the new models; update CREDITS and the model list.
- Files: tools/assets/*, tools/zombie_*.gd, levels/look_reference/, docs/.
- Tests: check_outputs and test_scripts_compile pass with the builder gone.
- Done when: no code path builds a zombie in Blender; roadmap row Done.
- Built (with step 2, one PR): once the Crawler was Tripo, every code-built zombie test lost its subject, so the
  steps went together. Deleted the files above, the non-baked branch of `zombie_checks.py`, and the now-unused
  `Zombie*` finishes in `gear_import.gd` / `gear.gdshader` with their tests. Checked, nothing left to change:
  `zombie_pose_capture.gd`, `zombie_review.gd`, `zombie_lineup.gd` and `levels/look_reference/` load the zombies
  by file name, so they show the Tripo models already.

## Acceptance

- [x] Both Shambler looks and the Tripo Bloater show in a Halcyon Labs round, the same on host and client (test + soak).
- [x] Head pop, blood pool, belly pulse and Bloater burst still work (tests).
- [x] Crawler model is Tripo and its crawl poses pass the clearance test.
- [x] No code-built zombie builder left.
- [x] Lineup render posted to the person in the build thread (step 1 and step 2 renders).

## Risks

- The Tripo body has no separate belly: the pulse moves to a shader. If the
  pod mask from the albedo is too loose (the shirt is green-grey), the shader
  uses a sphere mask around the belly instead. Checked in step 1's render.
- Hit zones fitted to code bodies may miss the bulkier Tripo Bloater: step 1
  test checks the head zone height, and the Body box is refitted to the mesh bounds.
- Cutting the Crawler's legs can leave holes: the cut is capped and checked in
  the lineup render; fallback is a cut at the knee with the thighs kept.

## Open decisions

- none

Provisional picks (listed in DECISIONS in their step): two Shambler looks picked from net_id; Crawler made from the lab tech Shambler with its legs cut.
