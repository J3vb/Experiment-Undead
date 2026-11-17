# Plan: Core loop gaps

Status: Review
Roadmap: F-12 / no issue (audit of the v0.1 slice against the design docs)
Phase: P2-P4
Size: M
Approved by:

## Goal

Close the gaps between the playable build and the core loop in
`docs/design/game-design.md`: rounds scale the way the design says, rounds never
stall on a lost zombie, and the gun and movement basics (weapon swap, reload
cancel, melee, slide, jump) work as written. Serves pillars 1 (Gunplay first),
2 (Readable escalation) and the session loop ("best round saved per map").

## Scope

In (audit of 2026-11-17, design rule then what the build does today):

1. Round scaling. Design: counts 6/8/13/18 then floor(0.09r² + 0.6r + 15);
   health 120 + 90 per round to round 9, then x1.09; spawn delay 2.0 s x0.95
   per round, min 0.3 s; speed mix per zombie (Shamble 1.2 / Jog 2.6 / Run
   4.2 / Sprint 5.6 m/s by round band); co-op count x(1 + 0.5 per extra
   player), max alive +6 per extra player; zombie damage does not grow with
   rounds. Build: linear count 6 + 3(r-1) + 0.3(r-1)², linear health
   +15%/round, spawn delay -0.15 s/round, a separate Runner enemy plus +4%
   speed per round, +4 zombies and +4 alive per extra player, +3% damage per
   round. (balance `issues.csv` #4, `sync.csv`.)
2. Stuck zombies. Design: a zombie that cannot reach a player for 20 s, or is
   over 60 m away for 15 s, relocates to a spawn out of sight; the last 1 or 2
   zombies sprint after 30 s. Build: `ZombieStuckWatch` only logs.
3. Weapon handling. Design: swap takes 0.4 s (Quickhands 40% faster), slot
   keys 1/2/3, sprinting cancels a reload and keeps the magazine. Build: swap
   is instant, no slot keys, Quickhands only scales reload, reload keeps
   running while sprinting.
4. Melee. Design: knife, 150 damage, 0.6 s, key V, melee kill pays 130.
   Build: no melee input or attack (Economy already pays the melee bonus for
   `DamageInfo.Type.MELEE`).
5. Movement. Design: walk 4.5, sprint 6.8, crouch 2.2 m/s; slide from sprint
   (0.8 s, starts at 8 m/s, can hip-fire; Stride +25%); crouch is a toggle;
   each jump in a row is 20% lower. Build: walk 5.0, sprint 7.6, crouch hold,
   no slide, no jump fall-off.
6. Best round per map. Design: "Your best round and stats are saved per map."
   Build: not saved.

Not in (and where it goes):

- Grenades, mantle, more power-ups, Crawler, Blackout, Stalker, Brute, skills:
  roadmap v0.2 rows F-24 to F-30, F-20.
- Balance numbers (gun damage, zombie round-1 health, regen 35 vs 25 HP/s,
  serum prices): F-07, `.tres` only, after step 1 merges.
- Losing Serums when downed in co-op: co-op thread (player_state_sync.gd).
- Spawn point scoring (12-35 m path distance, side rotation) and co-op-only
  spawn points: Halcyon Labs thread / later.
- Reforger Tiers II and III, junction-box task, Vault pity rule: not on the
  roadmap yet; listed in DECISIONS.md "Not started".
- Game feel layer (FeelData, trauma shake, hitstop, FOV punch, damage arcs,
  round transition timeline): its own plan later; feel is the person's
  playtest call.
- Third-person melee and slide animations: F-41.

## Ready to build

- Foundations touched (numbers from docs/FOUNDATIONS.md): input (solid),
  tick/RNG (solid), co-op authority (fixes 2-3 done), saves (solid), ids in
  data (fix 4 done). None shaky for this work.
- Decision records that apply: 0002 content as resources, 0003 trusted client
  co-op, 0004 one code path, 0005 local versioned saves. Goes against one: no.
- Co-op:
  - Who decides: server for rounds, spawns, AI, relocate, damage and points;
    owning client for its own movement, swap, reload and melee trace (0003).
  - How a client triggers it: melee hits use the existing `HitClaims.claim_hit`
    with the knife's `WeaponData` (range and rate checks reuse
    `_valid_hit`/`_take_claim`); the server marks the hit as melee from
    `WeaponData.slot`. Everything else is local to the owner or server-only.
  - What other players see: zombie position, state and health through the
    existing `ZombieSync`/`MultiplayerSpawner`; players through the existing
    pose sync. No new messages.
  - Works on a dedicated server with no local player: yes (steps 1, 2 are
    server-only; 3-5 run on the owning client; 6 is skipped, as saves are).
- Data: speed mix bands and health curve in `content/waves/default_waves.tres`
  (new WaveRules fields); knife in `content/weapons/knife.tres`; slide and
  swap numbers as Player/WeaponHolder exports (fixed rules stay constants).
  Code compares against a specific id anywhere: no.
- Save: step 6 adds `best_runs` to the character file. Per ADR 0005 it bumps
  `SaveFile.CURRENT_VERSION` 1 -> 2 with one migration step (adds
  `best_runs: {}`) and a test that loads a version-1 sample. Renames or
  removes a saved id: no.
- Events and UI: new `Events.zombie_relocated(zombie)` (server only, for logs
  and tests). No new screens; the results screen gets one label.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes. New InputFrame bits: MELEE, SLOT_1..3; crouch toggle is
  resolved in LocalInput so the frame still carries "crouching".
- Tests: unit per step (below); integration `test_session.gd` for round
  counts; soak must stay PASS.
- Logging: `Log.warn(&"enemies", &"zombie_relocated", ...)` with map position
  and reason (AI doc: every relocate logs); existing `zombie_stuck` stays.
- Performance: relocate and last-zombie checks run in the existing per-zombie
  tick on timers already there; knife trace is one ray per swing, query object
  cached. No per-frame allocations.
- Out of scope: see "Not in".

## Design references

- docs/design/game-design.md#round-scaling (counts, health, delay, max alive,
  co-op, speed mix table)
- docs/design/game-design.md#enemy-types (zombie rules: relocate 20 s / 60 m
  15 s; player health)
- docs/design/game-design.md#gunfeel-and-movement (movement table, ADS, reload
  cancel, melee 150 / 0.6 s, swap 0.4 s)
- docs/design/game-design.md#serums-perks (Quickhands reload and swap 40%,
  Stride slide 25% further)
- docs/design/game-design.md#points-economy-and-buyable-areas (melee kill 130)
- docs/design/zombie-ai.md#stuck-handling (relocate, last zombies sprint after
  30 s, logging)
- docs/design/controls.md#keyboard-and-mouse (V melee, 1/2/3 slots, C crouch
  toggle and slide)
- docs/design/balance/rounds.csv (rounds 1-50 counts, health, delay, mix),
  issues.csv #4 and #14, sync.csv
- docs/DECISIONS.md: weapon damage uses the roster x0.57 scale; Second Wind
  and Stride entries; "Zombie AI tiers"

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/waves/wave_rules.gd | changed | design count, health, delay, speed mix and co-op formulas |
| systems/waves/speed_band.gd | new | `SpeedBand` resource: first round + four weights |
| systems/waves/spawner.gd | changed | speed from the mix; `relocate(zombie)` picks an out-of-sight marker |
| systems/waves/wave_director.gd | changed | last-zombies timer |
| systems/enemies/enemy_data.gd | changed | `uses_speed_mix: bool` |
| systems/enemies/zombie.gd, zombie_stuck_watch.gd | changed | unreachable/far timers trigger relocate; `sprint_now()` |
| content/waves/default_waves.tres, content/enemies/*.tres | changed | new fields; Runner removed from the mix and deleted |
| systems/weapons/weapon_holder.gd, weapon.gd | changed | swap delay, slot select, reload cancel |
| systems/weapons/weapon_data.gd | changed | `Slot.MELEE` |
| systems/weapons/melee.gd | new | knife swing on the owner: cooldown, trace, hit path |
| content/weapons/knife.tres, content/serums/quickhands.tres | new / changed | knife data; Quickhands `swap_time` 0.6 |
| systems/net/hit_claims.gd | changed | claims from a MELEE weapon become `DamageInfo.Type.MELEE` (2-3 lines) |
| systems/input/input_frame.gd, local_input.gd, project.godot | changed | MELEE, SLOT_1..3 bits and actions; crouch toggle |
| systems/player/player.gd | changed | slide, jump fall-off, design speeds, melee/slot input |
| systems/progression/character_profile.gd | changed | `best_runs` per map |
| systems/game/game_session.gd, systems/ui/results_screen.gd | changed | record best run; "New best" label |

Autoloads, managers or base classes added: none. `Melee` is a small child
node of WeaponHolder that owns the knife cooldown (rule 6: it owns state no
node owns).

## Data

- `WaveRules` (changed): replaces `count_linear`, `count_quadratic`,
  `extra_per_player`, `health_growth_per_round`, `speed_growth_per_round`,
  `max_speed_multiplier`, `damage_growth_per_round`, `spawn_interval_step`
  with: `early_counts: PackedInt32Array = [6, 8, 13, 18]`, `count_a: float =
  0.09`, `count_b: float = 0.6`, `count_c: float = 15.0`,
  `coop_count_per_player: float = 0.5`, `max_alive_per_extra_player: int = 6`,
  `base_health: float = 120.0`, `health_step: float = 90.0`,
  `linear_until_round: int = 9`, `health_growth: float = 1.09`,
  `spawn_interval_factor: float = 0.95`, `spawn_interval_min: float = 0.3`,
  `speed_tiers: PackedFloat32Array = [1.2, 2.6, 4.2, 5.6]`,
  `speed_bands: Array[SpeedBand]` (six bands from the design table).
  `get_health_multiplier(r)` = round health / round-1 health, so
  `EnemyData.max_health` keeps meaning "health at round 1" and F-07 can tune
  it per type. Damage multiplier is 1.0 (design; issues.csv #14 resolved for
  the doc).
- `SpeedBand` (new Resource): `first_round: int`, `weights:
  PackedFloat32Array` (4 values summing to 1).
- `EnemyData.uses_speed_mix: bool = false` (walker true). Spawn data keeps its
  current wire format: the rolled speed is sent as `speed_mult = tier /
  move_speed`, so no network change and no protocol bump.
- `zombie_runner.tres` deleted (design has no Runner); content hash changes
  as for any content change.
- `WeaponData.Slot.MELEE` (appended, so saved enum values stay valid);
  `content/weapons/knife.tres`: damage 150, min 150, head x1.0 (design says
  150 flat), `max_range` 2.0, 100 rpm (0.6 s), no loot tags, not in any Vault
  pool, no viewmodel scene.
- `SerumData` stat `swap_time` added to `STATS`; Quickhands multipliers
  `{reload_time: 0.6, swap_time: 0.6}`, description updated.
- Character save: `best_runs: {<map>: {"round": int, "kills": int}}`, map key =
  the level scene's folder name. Save version 2; the 1 -> 2 migration adds
  `best_runs: {}`; unknown fields kept.
- Content checks to add: `test_content_rules.gd` speed bands sum to 1 and
  rise in first_round; knife is MELEE, not loot-eligible, not in any Vault
  pool; WaveRules reproduces `rounds.csv` counts, health and delay for rounds
  1-30.

## Co-op behaviour

- Who owns the state: server owns rounds, zombie speed rolls, relocate, damage
  and points; each owning client owns its swap timer, reload, slide, jump and
  knife cooldown; each client owns its own save.
- What clients send, what the server sends back: melee hits go through the
  existing reliable `claim_hit`; nothing new. Server sends nothing new
  (relocated zombies move through `ZombieSync` position).
- What a client sees that the host sees too: zombie speeds, relocations, round
  counts and health bars (via the synced health). Only the owner sees its own
  knife swing and swap lowering (no third-person animation until F-41).
- Late joiner: nothing new; spawn data already carries each zombie's speed
  multiplier.
- Dedicated server: skips step 6 saves (as today) and has no local input.

## Performance

Speed roll: one RNG call per spawn. Relocate: two float timers per zombie in
the existing chase tick, one sight ray per relocate attempt (at most once per
second per stuck zombie). Last-zombies check: one int compare per director
tick. Knife: one cached `PhysicsRayQueryParameters3D` per swing. Budget: no
measurable change at 24 zombies.

## Steps

### Step 1: Round scaling from the design

- Build: new WaveRules fields and formulas above; `SpeedBand`; Spawner rolls
  the tier with `GameSession.rng` for `uses_speed_mix` enemies and keeps
  today's ±10% jitter off for them (tiers are exact); remove Runner from the
  mix and delete it; co-op count and max alive rules; damage multiplier 1.0.
  Walker keeps `max_health` 100 (round-1 health) until F-07 tunes it, so
  round 1 plays the same.
- Files: systems/waves/wave_rules.gd, speed_band.gd (new), spawner.gd,
  systems/enemies/enemy_data.gd, content/waves/default_waves.tres,
  content/enemies/zombie_walker.tres, zombie_runner.tres (deleted), tests,
  docs/DECISIONS.md.
- Tests: `tests/unit/test_wave_rules.gd` checks counts 6/8/13/18/20/30/63 at
  rounds 1-5/10/20, health multiplier 1.0 / 7.0 / 7.63 at rounds 1/9/10,
  delay 2.0 / 1.26 and min 0.3, co-op 2 players = floor(count x 1.5) and max
  alive 30, band weights per round; `test_spawner.gd` a seeded round-1 spawn is
  1.2 m/s and a round-20 spawn is one of the band's tiers. Fail without the
  step (old formulas give 57 at round 10). Soak stays PASS.
- Done when: CI green incl. soak; DECISIONS.md entry; F-07 told it can tune.

### Step 2: Relocate stuck zombies, hurry the last ones

- Build: `ZombieStuckWatch` tracks "no progress": every 2 s window in which a
  chasing zombie outside attack reach moved less than 0.3 m adds 2 s to an
  unreachable timer (a window with progress resets it). This counts whether or
  not the NavigationAgent says its path is finished, so a finished path that
  ends short of the player (direct steering into a wall) still counts. It also
  tracks "over 60 m from every player"; at 20 s / 15 s the zombie asks `Spawner.relocate(self)`,
  which picks a marker none of the players can see (one ray per player from
  the camera) and away from players (`min_spawn_distance`), moves the zombie
  there through the navmesh closest point, keeps its health, and puts it back
  to CHASING (windows are skipped: it re-enters as a chaser). Falling below the
  kill height relocates at once. `WaveDirector` starts a 30 s timer when
  spawning is done and 1-2 zombies are alive; when it fires, those zombies
  `sprint_now()` (Sprint tier 5.6 m/s, groan volume +6 dB). Server only.
- Files: systems/enemies/zombie.gd, zombie_stuck_watch.gd,
  systems/waves/spawner.gd, wave_director.gd, core/events.gd (one signal),
  docs/LOGGING.md catalogue, tests.
- Tests: `tests/unit/test_zombie_relocate.gd` (new): a zombie with an
  unreachable target relocates after 20 s simulated, keeps health, emits
  `zombie_relocated`; the same with the navigation path finished but the
  zombie blocked short of the player; a zombie that keeps moving never
  relocates; a far zombie after 15 s; a fallen zombie at once; a
  marker in a player's view is not chosen. `test_wave_rules.gd` or a director
  test: with 2 left after 30 s both run at 5.6 m/s. Fail without the step.
- Done when: CI green incl. soak; LOGGING.md lists `zombie_relocated`.

### Step 3: Weapon swap time, slot keys, reload cancel

- Build: `WeaponHolder.equip()` starts a swap: the old gun lowers for half of
  `SWAP_TIME` (0.4 s x `swap_time` stat), the new gun raises for the other
  half; no firing or ADS while swapping. Actions `weapon_slot_1/2/3` (keys
  1/2/3) set InputFrame SLOT bits; slot 3 only with Mule. Sprinting while
  reloading cancels the reload (magazine count unchanged; per-round reloads
  keep loaded shells). Quickhands gains `swap_time` 0.6.
- Files: systems/weapons/weapon_holder.gd, weapon.gd, round_reload.gd (if
  needed), systems/input/input_frame.gd, local_input.gd, project.godot,
  systems/serums/serum_data.gd, content/serums/quickhands.tres,
  systems/player/player.gd, rebind display names (if the F-05 table exists by
  then), tests.
- Tests: `test_weapon_holder.gd` or existing weapon tests: cannot fire for 0.4 s
  after a swap, 0.24 s with Quickhands; slot key picks the slot; sprint
  during reload cancels and keeps `ammo_in_mag`. Fail without the step.
- Done when: CI green; DECISIONS.md updated (swap no longer instant).

### Step 4: Knife melee

- Build: `Melee` node under WeaponHolder: on InputFrame MELEE (key V) and not
  downed, swing if the 0.6 s cooldown is over: the gun dips, one ray 2.0 m
  from the camera against hit zones; on hit build `DamageInfo` (150,
  `Type.MELEE`, weapon id from the knife data) and use the same path as guns:
  host/solo `HitClaims.apply_host_hit`, client `session.hit_claims.submit_hit`.
  `claim_hit` sets `Type.MELEE` when the claimed weapon's slot is MELEE. A
  swing cancels a reload and blocks firing for its duration. Reuses an existing
  generated swipe sound if one fits; otherwise silent until the audio thread
  adds one.
- Files: systems/weapons/melee.gd (new), weapon_holder.gd, weapon_data.gd,
  content/weapons/knife.tres (new), systems/net/hit_claims.gd,
  systems/input/input_frame.gd, local_input.gd, project.godot,
  systems/player/player.gd, tests.
- Tests: `tests/unit/test_melee.gd` (new): a swing at a zombie 1.5 m away deals
  150 as MELEE and a kill pays 130; 2.5 m misses; second swing inside 0.6 s does
  nothing; a client claim from the knife is accepted at 1.5 m and rejected at
  6 m (range + 2 m slack) and arrives as MELEE. Content test: knife is MELEE
  and not loot or Vault eligible. Fail without the step.
- Done when: CI green incl. soak.

### Step 5: Slide, crouch toggle, jump fall-off, design speeds

- Build: Player walk 4.5, sprint 6.8, crouch 2.2 m/s (crouch multiplier
  0.49). Crouch action becomes a toggle in LocalInput (press flips; sprint or
  jump clears it); pressing crouch while sprinting on the floor starts a slide:
  0.8 s, starts at 8 m/s and eases to crouch speed, steering locked, hip fire
  allowed (sprint block cleared), crouch camera height; Stride makes it 1.0 s
  (25% further). Jump: each jump within 0.4 s of landing is 20% lower than the
  last (velocity x sqrt(0.8) per chain step), reset after 0.4 s on the floor.
- Files: systems/player/player.gd, player_camera.gd (slide height),
  systems/input/local_input.gd, content/serums/stride.tres (slide stat),
  systems/serums/serum_data.gd, tests. player.gd is at the 350-line limit:
  move slide and jump into `systems/player/player_moves.gd` (new, split by
  job, not a manager).
- Tests: `test_player_moves.gd` (new): slide from sprint covers 3.5 to 5 m in
  0.8 s and allows firing; crouch toggle; second chained jump peaks 80% as
  high; walk/sprint/crouch top speeds 4.5/6.8/2.2. Fail without the step.
- Done when: CI green; feel check (slide, jump, speeds) listed for the person.

### Step 6: Best round per map

- Build: `SaveFile.CURRENT_VERSION` 2 with a 1 -> 2 step adding
  `best_runs: {}`; `CharacterProfile.best_runs` and
  `record_run(map, round, kills) -> bool` (true when it is a new best).
  Recording does not use the XP banking hook, because a client's final XP
  grant can arrive before the results: a new `_record_best_run(stats)` runs in
  `GameSession._receive_match_end()` (results received, on every peer with a
  local character, skipped on a dedicated server) and uses the server's
  `stats["round"]` and `stats["kills"]` (the squad's kills, which the server
  already sends), then saves the profile once and sets `stats["new_best"]`.
  Results screen shows "New best" next to the round when set. Keep the
  game_session.gd edit to a few lines (the co-op thread also edits it).
- Files: systems/save/save_file.gd, systems/progression/character_profile.gd,
  systems/game/game_session.gd, systems/ui/results_screen.gd,
  results_screen.tscn, tests.
- Tests: `test_save_file.gd`: a version-1 sample migrates to 2 with
  `best_runs: {}` and keeps its other fields; `test_character_profile.gd`: a
  better round replaces, a worse one does not, round-trips through save;
  `test_run_end_grants.gd` (client path): the final XP grant arrives before
  the match results and the best run is still recorded from the results;
  `test_results_screen.gd` shows the label only when `new_best`. Fail without
  the step.
- Done when: CI green; roadmap F-12 Done; DECISIONS.md updated.

## Acceptance

- [ ] Round counts, health and spawn delay match `rounds.csv` for rounds 1-30
  (unit test).
- [ ] Zombies roll speed tiers per the design mix; no Runner type (unit test).
- [ ] A lost or far zombie relocates and the last zombies hurry (unit test;
  soak PASS).
- [ ] Swap takes 0.4 s, 1/2/3 select guns, sprint cancels reloads (unit tests).
- [ ] Knife deals 150, pays 130 on a kill, works for co-op clients (unit tests).
- [ ] Slide, crouch toggle, jump fall-off and design speeds (unit tests; feel
  check by the person).
- [ ] Best round per map saved and shown (unit tests).

## Risks

- Step 1 makes mid rounds tougher than today (round 10 health x7.6 of round 1
  instead of x2.35, with fewer zombies: 30 instead of 57). Guns use the x0.57
  roster scale, so rounds 7-10 may feel too hard until F-07 tunes the walker's
  round-1 health or gun damage. Mitigation: F-07 runs right after step 1 and
  the soak (PASS) gates it. Step 1 goes first so this shows early.
- Soak runtime: higher health means more shots per kill for the soak bot, but
  rounds 1-10 have about 40% fewer zombies; checked in step 1's CI.
- Removing the Runner changes the content hash; co-op peers must run the same
  build (already enforced by the handshake).
- Other threads edit nearby files: Halcyon Labs adds `min_players` in
  `Spawner._pick_marker()` (step 2 builds on it); co-op may edit
  hit_claims.gd (rebase before step 4); F-05 rebind adds a display-name table
  (steps 3-4 add a line each if it exists).

## Open decisions

- none (all numbers come from the design doc; feel checks go to the person's
  playtest after steps 3-5)
