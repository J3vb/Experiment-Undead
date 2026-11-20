# Plan: Stalker

Status: Review
Roadmap: F-29 / issue #123
Phase: P4
Size: L
Approved by:
Lore link: Stalker row in [lore.md](../design/lore.md#story-links-for-game-content): a light, young host rewired for climbing; warm air gathers under ceilings, so they hunt along pipes and vents up there. Their climb routes follow the Labs and Containment Wing ceiling pipes and vents that already exist in the map.

## Goal

A fast zombie that climbs walls and ceilings on set routes, hunts whoever strays
from the group, and pounces from up to 8 m after a rising 1 s shriek. Shoot it
during the shriek or step out of the landing spot. Pillar: "pressure always
builds" (danger from above and from odd angles, from round 12).

Second of the three enemy plans. Builds on [blackout-glowers.md](blackout-glowers.md)
(F-28): the Tripo zombie intake (its step 1) and `ZombieTargeting` (its step 4).
Build only after F-28 is done; [brute.md](brute.md) (F-30) comes after this one and
reuses the special-move hook, the stagger state and the spawn tags built here.

## Scope

In:

- Stalker model from the person's Tripo `Stalker.glb` through the zombie intake,
  `stalker.tscn`, `content/enemies/zombie_stalker.tres`, Stalker sounds (clicks and
  chitter, rising shriek, pounce scream, death).
- In the round mix from round 12.
- Swipe 30 when close; pounce 50 from 3 to 8 m with the 1.0 s shriek, locked
  landing point, 1.2 m hit radius, 6 s cooldown, 1.0 s stumble on a miss, shriek
  cancelled into a stagger by 20% of its max health.
- The special-move hook shared with the Brute: `EnemyData.special_moves` (a script
  the data points to), `Zombie.State.SPECIAL` and `STAGGERED`, synced
  `special_move` and `special_point`.
- Climb routes (a curve on walls and ceilings, linked into navigation on a
  Stalker-only layer) and perches (hang 1 to 3 s, then pounce from above).
- ISOLATED targeting: Stalkers prefer a player with no ally within 8 m.
- Spawn tags: Stalkers prefer ceiling vent spawn points.
- Halcyon Labs: climb routes, perches and ceiling vents in the Labs and the
  Containment Wing.
- Room first: `zombie_rig.gd` (314 lines) split by job before it grows.

Not in (non-goals, and where each one goes instead):

- Free wall-walking navigation (never: zombie-ai.md decided authored routes).
- Shriek subtitles ("Stalker shriek, left") (with the subtitles setting, later).
- High-shelf "above you" filter and the Tell bus (later audio pass).
- Per-type alive caps (`max_alive` per EnemyData): not needed while the round mix
  keeps Stalkers rare; revisit if the F-33 run-length check shows packs of them.
- Contract Board "Kill 40 Stalkers" (with the Contract Board).
- Climb routes on other maps (each map's own build plan).

## Ready to build

```
### Ready to build
- Foundations touched: 2 (content as data), 5 (co-op: synced zombie state),
  7 (no per-frame allocations).
  Any of them shaky or missing? no. F-28 must be Done first (intake and ZombieTargeting).
  Needs F-11 on the roadmap: the person moved on to v0.2 on 2026-11-20; nothing here
  depends on the release tag.
- Decision records that apply: 0002, 0003, 0004, 0017 (Tripo zombie, per F-28 step 1).
  Does this go against one? no
- Co-op:
  - Who decides: server (AI, routes, shriek, landing point, pounce hit, stagger).
  - How a client triggers it: it does not (shots reach the server through HitClaims,
    which is how the 20% interrupt damage arrives).
  - What other players see: position and rotation (already synced at 30 Hz, which
    carries the upside-down ceiling pose), plus synced `state`, `special_move` and
    `special_point`; every peer plays the shriek and poses from those.
  - Works on a dedicated server with no local player: yes.
- Data: zombie_stalker.tres, enemy_mix row in default_waves.tres, numbers from
  game-design.md, zombie-ai.md, enemies.csv. Code compares against a specific id
  anywhere: no (behaviour comes from `special_moves` and `targeting` in data).
- Save: changes what is saved? no
- Events and UI: no new Events (tells play from synced state). New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
- Tests: unit (pounce timing, interrupt, landing hit, climb follow, isolated target),
  content (Stalker data, climb route checks), integration (Stalker round runs headless),
  co-op (client sees the shriek state and locked point).
- Logging: Log.warn stalker_route_off_navmesh (a route end is over 0.5 m from the
  navmesh at load), stalker_climb_stuck (a climb took 2x its expected time).
- Performance: climbing follows a curve with no physics; the pounce line-of-sight ray
  runs at most every 0.25 s; no per-frame allocations.
- Lore link: Stalker row in lore.md (provisional, exists).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#enemy-types: Stalker row (round 12, 0.6x, 5.8 m/s,
  pounce up to 8 m for 50, shriek 1 s, "shoot or slide out").
- docs/design/zombie-ai.md#stalker (routes, perches within 10 m for 1 to 3 s,
  pounce 3 to 8 m with line of sight and 6 s cooldown, 0.6 s tracking then lock,
  1.2 m hit radius, 1.0 s stumble, 20% interrupt), the attack table (swipe 30
  *(new)*), target choice (bonus for players with no ally within 8 m), spawn tags
  ("Stalkers prefer ceiling and vent points"), AttackData `interrupt_damage 0.2`,
  "Why the tells are long" (wind-up at least 0.4 s).
- docs/design/balance/enemies.csv row Stalker: 0.6x, 5.8 m/s, 50 damage, 5% loot.
- docs/design/game-design.md: "ceiling vents in the Labs and Containment Wing where
  Stalkers enter"; loot table row "Bloater, Stalker: 5%".
- docs/design/sound.md: Stalker row (6 click/chitter variations, rising shriek exactly
  1.0 s before a pounce, pounce scream + impact, snapped shriek, fast scratching).
- docs/design/look-rules.md Shambler/Bloater rows (faint green eyes; bio-green only
  for the experiment).
- docs/DECISIONS.md: "Zombie AI tiers", "Procedural animation", "Stuck zombies",
  "Model looks".

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/enemies/zombie_rig.gd | changed | death job moved out (step 1); shriek, leap and climb poses |
| systems/enemies/zombie_corpse.gd | new | fall over, head pop and dead pose, moved from the rig |
| systems/enemies/zombie.gd | changed | SPECIAL and STAGGERED states, `special_move`, `special_point`, special hook |
| systems/enemies/enemy_data.gd | changed | `special_moves: Script`, `spawn_tags`, `nav_layers` |
| systems/enemies/stalker_moves.gd | new | pounce, climb and perch (RefCounted, data points to it) |
| systems/enemies/zombie_targeting.gd | changed | ISOLATED mode |
| systems/enemies/zombie_voice.gd | changed | tell sound on special start, stagger |
| systems/enemies/stalker.tscn | new | inherits zombie.tscn, Stalker model |
| systems/level/climb_route.gd | new | Path3D curve + NavigationLink3D on the climb layer, perch offsets |
| systems/waves/zombie_spawn_point.gd, spawner.gd | changed | `tags` on points; prefer matching tags |
| systems/net/zombie_sync.gd | changed | sync `special_move`, `special_point` |
| content/enemies/zombie_stalker.tres, content/waves/default_waves.tres | new / changed | data and round mix |
| levels/halcyon_labs/map.tscn | changed | routes, perches, ceiling vent points |
| assets/models/zombies/stalker.glb, assets/audio/ | new | intake output, sounds |
| core/build.gd | changed | PROTOCOL_VERSION bump (step 2) |

Autoloads, managers or base classes added: none. `StalkerMoves` is the "smallest
script data can point to" (Keep it simple rule 12, zombie-ai.md `special_state`);
it is duck-typed with `try_start(zombie)` and `tick(zombie, delta) -> bool`, no base
class. `ClimbRoute` is a map node like `ZombieSpawnPoint`.

Files over 300 lines this plan grows: `systems/enemies/zombie_rig.gd` (314). Step 1
moves its death job (fall_over, pop_head, pose_dead, about 50 lines) into
`zombie_corpse.gd` before any pose is added.

## Data

- `EnemyData` new fields (all with defaults that keep Walker and Bloater as they are):
  `special_moves: Script = null`; `spawn_tags: Array[StringName] = []` (preferred
  spawn point tags); `nav_layers: int = 1` (Stalker 3 = ground + climb layer);
  `pounce_damage`, `pounce_min`, `pounce_max`, `pounce_cooldown` stay as constants
  in `stalker_moves.gd` (one user; Keep it simple rule 10) except damage, which is
  `special_damage: float = 0.0` so balance can tune it (F-30's charge uses it too).
- `Targeting` enum gains `ISOLATED`.
- `zombie_stalker.tres`: max_health 60 (0.6 x Walker's 100), move_speed 5.8 fixed,
  attack_damage 30 (swipe), attack_range 1.5, windup 0.45, special_damage 50,
  loot_drop_chance 0.05, xp_reward 30 (provisional, same as the Bloater's),
  targeting ISOLATED, spawn_tags [&"ceiling"], nav_layers 3, special_moves
  stalker_moves.gd.
- Round mix row: first_round 12, weight 0.05, weight_per_round 0.01 (provisional,
  the Bloater's curve).
- `Zombie.special_move: int` (0 none; the moves script names its own values) and
  `Zombie.special_point: Vector3`, synced always by ZombieSync.
- `ZombieSpawnPoint.tags: Array[StringName] = []`.
- `ClimbRoute` (Path3D): `perches: PackedFloat32Array` (offsets along the curve,
  metres); its NavigationLink3D child uses navigation layer 2 (`Layers.NAV_CLIMB`
  constant, new).
- Network: two new synced properties (step 2): protocol bump. Spawn data unchanged.
- Save format change: none.
- Content checks: Stalker data (special_moves set, nav_layers includes 2, sounds);
  every ClimbRoute in Halcyon Labs has both ends within 0.5 m of the navmesh and
  every perch offset inside the curve length.

## Co-op behaviour

- Who owns the state: server (all AI, route choice, perch time, landing point, hits).
- What clients send, what the server sends back: clients send their shots as today
  (HitClaims); the server syncs `state`, `special_move`, `special_point`, position
  and rotation.
- What a client sees that the host sees too: the climb (pose from synced rotation),
  the shriek (voice and pose on `special_move` change), the leap arc (from position
  sync plus the locked point), stagger and stumble.
- Late joiner: zombies come from the MultiplayerSpawner with their synced
  properties, so a Stalker mid-climb or mid-shriek shows right on first sync.
- Dedicated server: no poses or sounds; the AI runs as usual.

## Performance

At most a few Stalkers alive (weight about 0.05 to 0.3 of the mix). Climbing sets
the transform from the baked curve (no `move_and_slide`). The pounce check (range,
cooldown, then one line-of-sight ray) runs at most every 0.25 s per Stalker. No
allocations per frame; the moves object is created once per zombie at setup. Budget:
the horde stays at 60 fps with 24 zombies, checked in the step 4 headless round run.

## Steps

### Step 1: Room in the rig, Stalker model and data

- Build: move the death job from `zombie_rig.gd` into `zombie_corpse.gd` (behaviour
  unchanged). Intake `Stalker.glb` (copy to `tripo/sources/stalker.glb`, manifest
  row, height 1.75 m provisional) to `assets/models/zombies/stalker.glb`.
  `stalker.tscn`, `zombie_stalker.tres` with the swipe only (no special moves yet),
  ISOLATED targeting in `ZombieTargeting`, Stalker sounds (free sources with CREDITS
  lines, or generated in `zombie_sfx.py` with a DECISIONS line). Round mix row from
  round 12. DECISIONS lines: Stalker XP 30, mix weights, height.
- Files: systems/enemies/zombie_rig.gd, zombie_corpse.gd (new), zombie_targeting.gd,
  enemy_data.gd, stalker.tscn, content/enemies/zombie_stalker.tres,
  content/waves/default_waves.tres, tools/assets/tripo/zombies.json,
  assets/models/zombies/stalker.glb, assets/audio/, docs/CREDITS.md,
  docs/design/turnarounds/, docs/DECISIONS.md.
- Tests: content check for zombie_stalker; unit `test_zombie_targeting.gd` ISOLATED
  picks the lone player over a nearer pair; existing death and head-pop tests pass
  on `ZombieCorpse`; Assets and Turnarounds checks.
- Done when: from round 12 fast Stalkers run, swipe and die on host and client;
  `zombie_rig.gd` is under 300 lines.

### Step 2: The pounce, the special-move hook and the stagger

- Build: `EnemyData.special_moves` and `special_damage`; Zombie creates the moves
  object at setup, asks `try_start(self)` from CHASING and runs `tick()` in the new
  SPECIAL state; new STAGGERED state with a timer (used by the interrupt, and by the
  Brute later). `StalkerMoves` pounce: needs line of sight, 3 to 8 m, 6 s since the
  last pounce; SHRIEK 1.0 s (faces the target for 0.6 s, then locks `special_point`
  at the target's feet); LEAP on a fixed arc (0.6 s, apex 1.5 m, provisional) to
  the point; on landing, server damages every living player within 1.2 m for
  `special_damage` once; a miss gives a 1.0 s stumble; 20% of max health taken during
  SHRIEK cancels into a 1.0 s stagger (provisional). ZombieSync syncs `special_move`
  and `special_point`; voice plays the shriek on SHRIEK start on every peer; rig
  shriek and leap poses. Bump PROTOCOL_VERSION.
- Files: systems/enemies/zombie.gd, enemy_data.gd, stalker_moves.gd (new),
  zombie_voice.gd, zombie_rig.gd, systems/net/zombie_sync.gd,
  content/enemies/zombie_stalker.tres, core/build.gd, docs/DECISIONS.md.
- Tests: unit `test_stalker_moves.gd` with a fake target and fixed seed: no pounce
  under 3 m, over 8 m, without sight or inside the cooldown; the point locks at 0.6 s
  and later target moves do not change it; landing within 1.2 m hits once for 50,
  outside misses and stumbles 1.0 s; 20% damage in SHRIEK staggers, 19% does not.
  Co-op test: a client copy shows SHRIEK and the same `special_point`.
- Done when: a Stalker shrieks, leaps and can be dodged or shot out of it, the same on
  host and client; the shriek always starts 1.0 s before the leap.

### Step 3: Climb routes and perches

- Build: `ClimbRoute` (Path3D; on ready it adds a NavigationLink3D from its first to
  its last point on the climb layer, bidirectional). Stalker agents use
  `nav_layers` 3, so routes are used when shorter. On `link_reached` the moves object
  enters CLIMB: follows the curve at move speed, orients the body to the curve's
  up vector, no gravity, then chases again at the far end. Each perch offset on the
  route: if the target is within 10 m and visible, PERCH for 1 to 3 s (session RNG,
  quiet clicking) then pounce from there (same SHRIEK and LEAP). Rig climb pose
  (reuses the crawl pose, rotated). A tiny test level with one route.
- Files: systems/level/climb_route.gd (new), core/layers.gd (NAV_CLIMB),
  systems/enemies/stalker_moves.gd, zombie.gd (agent layers from data), zombie_rig.gd,
  tests/integration/scenes/climb_test.tscn (new), docs/LOGGING.md (two warnings).
- Tests: unit: CLIMB moves along the curve at speed and ends at the last point;
  PERCH waits within 1 to 3 s only with the target in 10 m; integration: in the test
  level a Stalker chasing a player on the far side takes the route (Walker does not).
- Done when: in the test level Stalkers run up the wall, along the ceiling, perch and
  drop onto the player.

### Step 4: Halcyon Labs routes, ceiling vents and close-out

- Build: spawn tags (`ZombieSpawnPoint.tags`, Spawner prefers points whose tags
  match the enemy's `spawn_tags`, falls back to any usable point). Author in
  `map.tscn`: 3 to 5 climb routes and 2 to 4 perches in the Labs and the
  Containment Wing along existing ceiling pipes and vents, plus one ceiling vent
  spawn point tagged `ceiling` per room (spawned Stalkers drop to the floor under
  gravity during SPAWNING). Route check test. Renders or a GIF of a Stalker on a
  route for the PR. Finish-feature close-out: Acceptance, roadmap Done, plan Done.
- Files: systems/waves/zombie_spawn_point.gd, spawner.gd, levels/halcyon_labs/map.tscn,
  tests/content/ (route check), docs/ROADMAP.md, docs/plans/stalker.md.
- Tests: unit: Spawner picks a tagged point when one is usable and falls back
  otherwise; content: every Halcyon route end within 0.5 m of the baked navmesh;
  integration: headless GameSession skipped to round 12 runs 90 s with Stalkers and
  no SCRIPT ERROR; soak rounds 1-10 unchanged.
- Done when: Stalkers come out of the Labs and Containment ceilings, climb, perch and
  pounce in a real round; CI and soak green; play-test recorded.

## Acceptance

- [ ] Stalker model passes Assets and Turnarounds checks (step 1)
- [ ] Stats per game-design.md: round 12+, 0.6x health, 5.8 m/s, 50 pounce damage (steps 1-2)
- [ ] Unit tests for the shriek tell and the pounce (step 2)
- [ ] Climbs walls and ceilings on Halcyon Labs routes and perches (steps 3-4)
- [ ] Client and late joiner see the same shriek and landing point as the host (step 2 test)
- [ ] Solo play-test: the shriek is heard in time to dodge, no unfair deaths (close-out)

## Risks

- `link_reached` timing on NavigationAgent3D can skip a link at high speed: step 3
  tests it in a small level first; fallback is to start CLIMB when the next path
  point is a route start within 0.6 m.
- Hit zones on a ceiling Stalker: the body zone rides the root transform, which the
  climb rotates; tested in step 3 (shoot it on the ceiling in the test level).
- Lag: the hit is judged on the server against the client-reported position. The
  1.0 s shriek and fixed landing point give clients far more than the 0.4 s minimum
  warning (zombie-ai.md).
- Tripo body on the crawl pose may clip on the ceiling: look checked in step 3, fix
  in the pose or the route offset, not the model.

## Open decisions

The plan is size L, so the person approves it as a whole (decision card). Agent picks,
marked provisional in DECISIONS as their steps land: leap arc 0.6 s with a 1.5 m apex,
1.0 s interrupt stagger, XP 30, mix weight 0.05 + 0.01 per round, height 1.75 m.

- none
