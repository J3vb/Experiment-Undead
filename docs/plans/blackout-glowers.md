# Plan: Blackout rounds and Glowers

Status: Building
Roadmap: F-28 / issue #122
Phase: P4
Size: M
Approved by: Claude plan review on PR #411 (Codex out of quota), fixes applied, 2026-11-20 (size M, no open decisions)
Lore link: Glower row in [lore.md](../design/lore.md#story-links-for-game-content): hosts so full of Fenlight they shine and shun light, so they only come in force when the lights fail (the Blackout round). The lights-out itself is the facility power failing again; no new signs or text.

## Goal

From round 6, every 5 to 7 rounds the lights fail and fast, glowing Glower packs
attack. It breaks the round rhythm and tests your flashlight and aim. Pillar:
"pressure always builds".

This is the first of three enemy plans that share the zombie AI and the Spawner
(F-28, then [Stalker](stalker.md) F-29, then [Brute](brute.md) F-30). They are
built one at a time in that order, never in parallel. This plan builds the
shared groundwork the other two use: the Tripo zombie intake (step 1) and target
choice moved out of `zombie.gd` (step 4).

## Scope

In:

- Tripo zombie intake: `tripo_intake.py --kind zombie` (9,000-triangle zombie
  budget, our 22-bone skeleton, one `ZombieBaked` material) and the
  zombie model checks accepting it. F-29 and F-30 reuse it.
- Glower model from the person's Tripo `Glower.glb`, green glow from an import
  script, `glower.tscn`, `content/enemies/zombie_glower.tres`, Glower sounds.
- Lights-out state on Halcyon Labs: ceiling lights and the baked bounce go
  dark, Fenlight leaks and flashlights stay. Same on every peer and for late
  joiners.
- Blackout schedule in `WaveRules`: first at round 6, then every 5 to 7 rounds
  (session RNG). Only Glowers spawn, in packs of 4 to 6 from one spawn point,
  1.5x the round's normal count.
- Clearing a Blackout round drops one Resupply.
- Pack behaviour: a pack shares one target picked by its leader, arrives
  together, then splits left and right inside 6 m.
- Target choice moved from `zombie.gd` into `ZombieTargeting` (with the
  `NEAREST` and `PACK` modes), so F-29 and F-30 add their modes there.

Not in (non-goals, and where each one goes instead):

- Blackout music track and the +0.25 music intensity (later: music is made on
  the person's GPU; `MusicPlayer` keeps its stems).
- Blackout ambience bed swap (DECISIONS "Ambience" line stays; audio pass).
- A Tell audio bus (later audio pass; tells stay on the zombie voice, louder).
- Blackouts on Lantern Post or other maps (only Halcyon Labs has rounds now).
- Nightjar SD "no flash in Blackout" perk (with that gun's roster row).
- Swapping the code-built Bloater for the person's Tripo `Bloater.glb` (a small
  follow-up task once step 1's intake exists; not part of F-28).

## Ready to build

```
### Ready to build
- Foundations touched: 2 (content as data: new EnemyData .tres), 5 (co-op round state
  via WaveDirector), 7 (no per-frame allocations).
  Any of them shaky or missing? no. Needs F-11 (v0.1.0 release) on the roadmap: the
  person moved the project on to v0.2 on 2026-11-20 (solo play-test done); no code
  in this plan depends on the release tag.
- Decision records that apply: 0002 content as resources, 0003 trusted-client co-op,
  0004 one code path, 0017 Tripo models (this plan moves the three new zombies to
  Tripo, which 0017 allows "until a plan moves them"; step 1 adds that line to 0017).
  Does this go against one? no
- Co-op:
  - Who decides: server (Blackout rounds, spawns, pack targets, the Resupply drop).
  - How a client triggers it: it does not.
  - What other players see: WaveDirector relays `blackout` with the round-start
    message and in the late-joiner snapshot; every peer runs the lights-out visuals.
    Glowers are normal synced zombies.
  - Works on a dedicated server with no local player: yes (lights are visuals only).
- Data: zombie_glower.tres; Blackout fields in WaveRules (default_waves.tres); numbers
  from game-design.md and enemies.csv. Code compares against a specific id anywhere: no
  (WaveRules points at the Glower EnemyData; the Resupply is a PowerUpData export).
- Save: changes what is saved? no
- Events and UI: Events.blackout_started(round_number) and Events.blackout_ended(round_number),
  every peer. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
- Tests: unit (wave rules schedule, targeting), content (Glower data), integration
  (a Blackout round runs headless and drops a Resupply), co-op (client gets blackout).
- Logging: Log.warn blackout_pack_waiting (a pack waited over 10 s for room under the cap).
- Performance: one shared glow material from import, no per-frame allocation; lights off
  lowers the cost. Fps check with 24 Glowers in step 2/3.
- Lore link: Glower row in lore.md (provisional, exists).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#enemy-types: Blackout round paragraph (round 6, every 5
  to 7, Glowers only, 0.4x health, 5 m/s, packs of 4 to 6, 1.5x count, guaranteed
  Resupply).
- docs/design/balance/enemies.csv row Glower: 0.4x health, 5 m/s, 20 damage (assumed
  in the sheet), loot 1.5% + 0.1%/round (max 5%).
- docs/design/zombie-ai.md#glower (pack shares a target and route, splits inside
  6 m), "Ceiling drop" spawn kind (Stalkers and Glowers), target choice "Glower packs
  share one target picked by the pack leader".
- docs/design/look-rules.md: bio-green `#8DFF3A` reserved for the experiment;
  Glower row "Thin, fast, hunched; full-body green veins; lights the room, Blackout
  only"; "new light only comes from Fenlight, fire".
- docs/design/sound.md: Glower chitter (zombie-ai.md tell: "green glow, chittering").
- docs/DECISIONS.md: "Power-up drops" (Resupply is the deck's only power-up),
  "Emergency lighting", "Ambience", "Zombie AI tiers", "Model looks".
- docs/adr/0017-tripo-models.md, 0003, 0004.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/tripo_intake.py, tripo_rig.py | changed | `--kind zombie`: 9,000 tris, `ZombieBaked` material, character rig |
| tools/assets/zombie_checks.py | changed | accept `ZombieBaked`; triangle rows for glower, stalker, brute |
| tools/assets/tripo/zombies.json | new | manifest rows (glower now; stalker, brute later) |
| tools/assets/zombie_import.gd | new | import script: Glower emission from its albedo, bio-green |
| assets/models/zombies/glower.glb (+ import) | new | intake output |
| systems/enemies/glower.tscn | new | inherits zombie.tscn, thin capsule, Glower model |
| content/enemies/zombie_glower.tres | new | Glower stats and sounds |
| tools/assets/zombie_sfx.py or CC0 files | changed | Glower chitter, attack, death |
| systems/waves/wave_rules.gd | changed | Blackout fields and `is_blackout(round)` from a pre-rolled schedule |
| systems/waves/wave_director.gd | changed | `blackout` flag, relay, snapshot, pack spawning, reward |
| systems/waves/spawner.gd | changed | `spawn_pack()`: N zombies at one marker, one leader |
| systems/level/ceiling_light.gd | changed | goes dark on Blackout, back after |
| systems/level/blackout_dimmer.gd | new | darkens the baked bounce on Blackout (spike picks how) |
| core/events.gd | changed | blackout_started, blackout_ended |
| systems/power_ups/power_up_drops.gd | changed | drops the Blackout reward at the last kill |
| systems/enemies/zombie_targeting.gd | new | target choice moved out of zombie.gd; NEAREST and PACK |
| systems/enemies/zombie.gd | changed | uses ZombieTargeting; `pack_leader`, `pack_side` |
| systems/enemies/enemy_data.gd | changed | `targeting` enum |
| systems/debug/debug_console.gd | changed | `blackout on/off` (server, debug builds) |
| core/build.gd | changed | PROTOCOL_VERSION bump (step 2) |

Autoloads, managers or base classes added: none. `ZombieTargeting` is a job split
of `zombie.gd` (Keep it simple rule 4), like `ZombieEntry` and `ZombieStuckWatch`.

Files over 300 lines this plan grows: none (`zombie.gd` 290 shrinks in step 4;
`zombie_rig.gd` 314 is not touched: the glow comes from the import script).

## Data

- `EnemyData.targeting: Targeting` enum `{ NEAREST, PACK }`, default NEAREST (step 4).
  F-29 adds ISOLATED, F-30 MOST_DAMAGE.
- `zombie_glower.tres`: id `zombie_glower`, display "Glower", max_health 40 (0.4 x
  the Walker's 100, the same way the Bloater's 300 is 3 x 100), move_speed 5.0,
  uses_speed_mix false, attack_damage 20, attack_range 1.4, windup 0.45, cooldown 1.0,
  xp_reward 10 (design: 10 per kill), loot curve default (-1), body_scale 1.0.
- `WaveRules` (Blackout group): `blackout_enemy: EnemyData`, `blackout_first_round: int
  = 6`, `blackout_gap_min: int = 5`, `blackout_gap_max: int = 7`, `blackout_count_mult:
  float = 1.5`, `pack_min: int = 4`, `pack_max: int = 6`, `blackout_reward: PowerUpData`
  (resupply.tres). Schedule: the server rolls the Blackout rounds once at match start
  from the session RNG (round 6, then + 5..7 each time) and keeps them in
  `WaveDirector`; `WaveRules.roll_blackouts(rng, up_to)` is pure for tests.
- `Zombie.pack_leader: Zombie` and `pack_side: int` (-1/+1), server only, not synced.
- Network: `_receive_round` STARTED gains a `blackout: bool` argument and
  `_receive_round_state` gains `blackout: bool` (step 2, protocol bump).
- Save format change: none.
- Content checks: `tests/content/` enemy checks cover `zombie_glower` (scene set,
  health > 0, speed fixed, sounds present); wave content check: blackout_enemy and
  blackout_reward set, pack_min <= pack_max.

## Co-op behaviour

- Who owns the state: server owns the schedule, `WaveDirector.blackout`, spawns,
  pack leader and target. Each client owns only its lights-out visuals.
- What clients send, what the server sends back: clients send nothing. The server
  sends `blackout` with the round-start relay and `Events.blackout_ended` on round end
  (the ENDED message already exists; clients emit blackout_ended when a Blackout round
  ends).
- What a client sees that the host sees too: dark rooms, Glowers (synced zombies),
  the Resupply drop (existing networked PowerUpDrops).
- Late joiner: `_receive_round_state` carries `blackout`, so a player who joins mid
  Blackout gets dark lights at once.
- Dedicated server: lights and dimmer do nothing visible (no camera); the schedule and
  spawns run as usual.

## Performance

24 Glowers alive at 9,000 tris each is about 216k tris, under the current horde (24 x
6-9k). One shared emissive material from import (no per-zombie material). Lights out
turns spot lights off, which lowers cost. Pack spawning adds no per-frame work (one
marker pick per pack). Budget: 60 fps with 24 Glowers in the dark (issue #122),
checked in step 2 (dark, horde) and in the step 3 soak.

## Steps

### Step 1: Tripo zombie intake and the Glower

- Build: `tripo_intake.py --kind zombie` (9,000-tri budget, our skeleton through
  `tripo_rig.py`, material `ZombieBaked`). The intake adds a `HeadCenter` marker on
  the head bone (ZombieRig `_attach_head` reads it; then only the code-built zombie script made
  it). Each `zombie_checks.py` / `check_models.py` rule for a baked zombie, decided:
  - `JOINTS` and `TRIANGLES` rows for `glower`, `stalker`, `brute`: added.
  - Separate `Body`, `EyeL`, `EyeR` meshes: skipped for `ZombieBaked` (one baked
    mesh, eyes in the texture); the one mesh is named `Body`.
  - `ZombieSkinHead` material, head lighter than the rest, gear zone data on every
    face: skipped for `ZombieBaked` (one material; zombies have no dye zones,
    DECISIONS "Gear looks"), with a one-line reason in the check.
  - Triangle budget, facing, feet at origin, skeleton bone names: kept.

  Then: Copy `/mnt/project-files/Glower.glb` to
  `tripo/sources/glower.glb` in the project files, add a `zombies.json` manifest row
  (height 1.7 m, provisional) and run the intake to `assets/models/zombies/glower.glb`.
  `zombie_import.gd` gives the Glower emission (its albedo, tinted bio-green). New
  `glower.tscn` (inherits zombie.tscn), `zombie_glower.tres`, Glower sounds (chitter
  idles, swipe, death; footsteps reuse the Shambler set) from the free sources (Sonniss GDC, Freesound CC0, a CREDITS
  line each) or, if the thread cannot download them, generated in `zombie_sfx.py` with
  a DECISIONS line. Not in any wave mix yet. ADR 0017 gets one line: the three v0.2
  zombies are Tripo. Turnaround rendered and approved in the PR (agent look, "Model
  looks" line).
- Files: tools/assets/tripo_intake.py, tripo_rig.py, zombie_checks.py,
  tripo/zombies.json, zombie_import.gd, assets/models/zombies/glower.glb(.import),
  systems/enemies/glower.tscn, content/enemies/zombie_glower.tres, assets/audio/,
  docs/adr/0017-tripo-models.md, docs/CREDITS.md, docs/design/turnarounds/.
- Tests: `tests/content/` enemy check covers zombie_glower (`test_content.gd` needs
  footsteps); a unit test spawns a
  Glower scene and checks ZombieRig finds every posed bone and the head zone; Assets
  CI (glTF validator, zombie checks) and Turnarounds pass.
- Done when: `debug spawn zombie_glower` (or the lineup tool) shows a glowing Glower
  that walks, swipes and dies with its sounds; CI green.

### Step 2: Lights out on Halcyon Labs

- Build: `WaveDirector.blackout: bool` and `set_blackout(on)` (server), relayed in
  `_receive_round` STARTED and `_receive_round_state`; Events `blackout_started` and
  `blackout_ended` on every peer. CeilingLight goes fully dark on Blackout (spot off,
  dark tube, spot hidden so FlickerLight cannot bring it back) and back to its power
  state after; the delayed power-on restore checks the Blackout flag first, so turning
  the power on mid-Blackout keeps the room dark. New `BlackoutDimmer` node in the Level
  darkens the baked bounce: spike the cheapest way that works in Forward+ and the
  Compatibility renderer (first try the LightmapGI node's visibility or `light_data`
  swap, then Environment adjustment brightness with the flashlight and Glower emission
  kept bright) and record the pick in DECISIONS. Fenlight leak lights and flashlights
  stay. Debug console `blackout on/off`. Bump PROTOCOL_VERSION. Before/after renders
  with look-check, fps with 24 zombies in the dark (headless timing here, GPU prompt
  for the person's PC if numbers look close).
- Files: core/events.gd, systems/waves/wave_director.gd, systems/level/ceiling_light.gd,
  systems/level/blackout_dimmer.gd (new), levels/halcyon_labs/map.tscn (adds the
  dimmer node), systems/debug/debug_console.gd, core/build.gd,
  tests/unit/test_coop_round_state.gd (calls `_receive_round` with the old
  arguments), docs/LOGGING.md if a
  warning is added, docs/DECISIONS.md.
- Tests: unit: CeilingLight dark on blackout_started and back after, with power on
  and off, and stays dark when the power comes on mid-Blackout; co-op test: a client gets `blackout` from the round-start relay and from the
  late-joiner snapshot (fails without the new argument).
- Done when: `blackout on` darkens the whole map on host and client, `off` restores it,
  60 fps held with 24 zombies; renders in the PR.

### Step 3: Blackout schedule, Glower packs and the Resupply reward

- Build: WaveRules Blackout fields and `roll_blackouts()`; WaveDirector rolls the
  schedule at `start()`, sets `blackout` at round start, counts
  `floor(normal count x 1.5)`, and spawns packs: each spawn tick rolls a pack size
  4..6 (capped by what is left), waits until `alive + pack <= max_alive`, then calls
  `Spawner.spawn_pack(enemy, size, round, rules)`, which places every Glower at one
  marker (small jitter; prefers markers with no barrier, since a window has only 3
  attack slots and the pack must arrive together), marks the first as `pack_leader` of the rest and gives each a
  `pack_side`. The next pack waits `spawn interval x pack size` (provisional, keeps the
  round's pace). Round end clears `blackout`. PowerUpDrops remembers the last kill
  position and on a server `blackout_ended` drops `blackout_reward` there (outside the
  1-per-round cap). Glowers join the round only through this path (not in
  `enemy_mix`). The schedule is rolled when empty, so `skip_to_round` (debug and
  tests, which never call `start()`) works too. DECISIONS lines: first Blackout exactly round 6; pack spacing.
- Files: systems/waves/wave_rules.gd, wave_director.gd, spawner.gd,
  content/waves/default_waves.tres, systems/power_ups/power_up_drops.gd,
  docs/DECISIONS.md, docs/LOGGING.md (blackout_pack_waiting).
- Tests: unit `test_wave_rules.gd`: schedule from seed 1 has round 6 first and gaps of
  5..7 to round 50; Blackout count is 1.5x. Integration: a headless GameSession skipped
  to round 6 spawns only Glowers in packs of 4..6 and drops one Resupply when cleared.
  Soak (rounds 1-10) still passes.
- Done when: round 6 on Halcyon Labs is a dark Glower round that ends with a Resupply;
  soak green.

### Step 4: Pack behaviour and target choice out of zombie.gd

- Build: move `_update_target` and its timer from `zombie.gd` into
  `ZombieTargeting` (RefCounted, `tick(zombie, delta)`), behaviour unchanged for
  NEAREST. Add `EnemyData.targeting` and the PACK mode: a follower takes its leader's
  target (and picks its own if the leader is dead); within 6 m of the target it steers
  to a point 1.5 m to its `pack_side` of the target, then attacks as usual.
  `zombie_glower.tres` sets PACK. DECISIONS line: 1.5 m split offset.
- Files: systems/enemies/zombie_targeting.gd (new), zombie.gd, zombie_entry.gd
  (calls `zombie._update_target` while in a window slot), enemy_data.gd,
  content/enemies/zombie_glower.tres, docs/DECISIONS.md.
- Tests: unit `test_zombie_targeting.gd`: NEAREST picks the nearest living player
  (same as before); PACK follower copies the leader's target, falls back when the
  leader dies, and its split point is on its side. Existing zombie tests still pass.
- Done when: Glower packs arrive together and wrap left and right around the player;
  `zombie.gd` is shorter than before.

## Acceptance

- [ ] Glower model and data (0.4x health, 5 m/s, packs of 4 to 6) pass Assets and
      Turnarounds checks (step 1)
- [ ] Lights-out state on Halcyon Labs keeps 60 fps with 24 Glowers (step 2, step 3 soak)
- [ ] Wave rules tests check the Blackout schedule and the 1.5x count (step 3)
- [ ] A client and a late joiner see the same Blackout as the host (step 2 test)
- [ ] Clearing a Blackout round drops a Resupply (step 3 integration test)
- [ ] Solo play-test: a Blackout round reads as a different fight and the flashlight
      matters (recorded on the close-out PR)

## Risks

- Baked bounce may not darken cheaply (lightmaps are baked into the map). Step 2 is
  early so a bad option fails cheap; fallback is the Environment brightness route,
  which works on every renderer.
- Tripo skeleton fit on ZombieRig's procedural poses: tested in step 1 before any
  spawning depends on it. Fallback: adjust `tripo_rig.py` bone fit, as for vendors.
- A Blackout landing on a Brute round (F-30): F-30 moves the Brute to the next round.
- 24 emissive bodies plus glow in the dark could bloom too much: look-check renders in
  step 2 and 3.

## Open decisions

Agent picks, marked provisional in DECISIONS as their steps land: first Blackout at
exactly round 6, pack spacing, the 1.5 m split offset, Glower height 1.7 m, darkness
level. The darkness renders go to the person in the step 2 PR.

- none
