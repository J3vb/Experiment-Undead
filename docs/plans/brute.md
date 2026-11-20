# Plan: Brute

Status: Review
Roadmap: F-30 / issue #124
Phase: P4
Size: L
Approved by:
Lore link: Brute row in [lore.md](../design/lore.md#story-links-for-game-content): Oriel security and army riot troops who turned in full kit; Fenlight grew the body huge and fused the riot helmet into a bone plate, which is the head plate.

## Goal

A mini-boss from round 15, then every 4 to 6 rounds: huge, slow, with a head plate
that soaks damage until it breaks and a charge you see coming (1.2 s wind-up) and
sidestep. Killing it always drops Rare or better loot. Pillar: "pressure always
builds" (a set-piece fight inside a normal round).

Third of the three enemy plans. Builds on [blackout-glowers.md](blackout-glowers.md)
(F-28: Tripo zombie intake, `ZombieTargeting`, the Blackout schedule) and
[stalker.md](stalker.md) (F-29: `special_moves` hook, SPECIAL and STAGGERED states,
synced `special_move` and `special_point`, spawn tags). Build only after F-29 is done.

## Scope

In:

- Brute model from the person's Tripo `Brute.glb` through the zombie intake, with
  the helmet plate as its own part so it can fly off; `brute.tscn` (wide capsule,
  bigger hit zones); `content/enemies/zombie_brute.tres`; Brute sounds (huge breaths,
  roar + stamp tell, charge thunder and impact, long death roar, sub-bass footsteps).
- Brute schedule in WaveRules: round 15, then every 4 to 6 rounds; one Brute per
  Brute round on top of the round's count.
- Head plate: absorbs 75% of damage until the Brute has lost 25% of its health, then
  breaks (1.5 s stagger, plate flies off) and the Brute walks 20% faster.
- Charge: clear straight line of 6 to 20 m, 1.2 s wind-up with thud, locked
  direction, up to 20 m at 7 m/s, 60 damage and knockback; a wall hit stuns it 2 s.
- Slam: within 2.5 m, 0.9 s wind-up, 50 damage to every player in 2.5 m.
- Barriers: smashes a whole barrier in one 2 s hit.
- MOST_DAMAGE targeting: goes for whoever did the most damage to it in the last 10 s.
- Always drops Rare or better (data that already exists: `loot_drop_chance` 1.0,
  `loot_min_rarity` rare).
- Spawn roar heard on the whole map.

Not in (non-goals, and where each one goes instead):

- Brute music sting and +0.25 music intensity (later, with music on the person's GPU).
- Map-wide screen rumble at spawn (later game-feel pass; the roar carries it now).
- Overkill power-up (20% per hit on Brutes) and Execution Line (under 5%): they come
  with F-26 and F-20, which read `EnemyData` for the Brute rule then.
- Ironwood .50 plate-splitter trait (with that gun's roster row).
- `hit_armour` hitmarker cue (with the hitmarker sound pass).
- More than one Brute per Brute round in co-op (revisit at the F-43 4-player
  play-test).

## Ready to build

```
### Ready to build
- Foundations touched: 2 (content as data), 3 (item effects on the server: loot drop),
  5 (co-op: synced zombie state, server-to-owner knockback), 7 (no per-frame allocations).
  Any of them shaky or missing? no. F-28 and F-29 must be Done first.
  Needs F-11 on the roadmap: the person moved on to v0.2 on 2026-11-20; nothing here
  depends on the release tag.
- Decision records that apply: 0002, 0003 (knockback: server tells the owner, the owner
  moves itself), 0004, 0010 (personal loot: the Rare+ drop goes through LootService as
  today), 0017 (Tripo zombie). Does this go against one? no
- Co-op:
  - Who decides: server (schedule, plate, charge, slam, targeting, damage, drop).
  - How a client triggers it: shots through HitClaims (damage, plate break) only.
  - What other players see: synced `state`, `special_move`, `special_point` and
    `Plate:broken`; knockback reaches the hit player's own client through a
    server-to-owner RPC on a server-owned node under the Player (MULTIPLAYER.md
    pattern 5).
  - Works on a dedicated server with no local player: yes.
- Data: zombie_brute.tres, Brute fields in WaveRules (default_waves.tres), numbers from
  game-design.md, zombie-ai.md, enemies.csv. Code compares against a specific id
  anywhere: no (`brute_enemy` is a WaveRules export; moves come from `special_moves`).
- Save: changes what is saved? no
- Events and UI: no new Events (enemy_spawned already fires on every peer; the roar
  plays from the voice). New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
- Tests: unit (schedule, plate, charge, slam, barrier smash, MOST_DAMAGE), content
  (Brute data), integration (a Brute round headless with a Rare+ drop), co-op (plate
  break and knockback reach a client).
- Logging: Log.warn brute_charge_blocked (no clear line for 15 s while it has a target),
  brute_skipped (a Brute round found no usable spawn point for 10 s).
- Performance: one Brute alive; the charge shape cast runs at most every 0.5 s.
- Lore link: Brute row in lore.md (provisional, exists).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#enemy-types: Brute row (round 15 then every 4 to 6,
  12x, 2.2 m/s, charges at 7 m/s, plate absorbs 75% until 25% health lost, thud,
  1.2 s wind-up, sidestep); loot table "Brute: 100%, Rare or better".
- docs/design/zombie-ai.md#brute (plate break: 1.5 s stagger, plate flies off, 20%
  faster; charge 6 to 20 m shape cast, 1.2 s, up to 20 m, wall stun 2 s; slam 2.5 m,
  0.9 s; barrier smash 2 s; aggro last 10 s), attack table (charge 60 + knockback,
  slam 50 in 2.5 m *(new)*), `can_flank false`, "Brutes need a wide entry".
- docs/design/balance/enemies.csv row Brute and the plate note; issues.csv row 11
  (health curve and plate rule, see Open decisions); settings.csv brute_first 15,
  brute_every 5; rounds.csv Brutes column (one at rounds 15, 20, 25, 30).
- docs/design/sound.md: Brute row; "Brute spawn: a distant roar ... Footsteps carry
  40 m".
- docs/design/lore.md Brute row; Army and Cordon issue row (Ironwood .50 and Bastion are
  the answer to Brutes, not built here).
- docs/DECISIONS.md: "Zombie AI tiers", "Procedural animation", "Model looks".

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/tripo_intake.py | changed | `--part plate` splits the helmet plate into its own mesh |
| assets/models/zombies/brute.glb, assets/audio/ | new | intake output, sounds |
| systems/enemies/brute.tscn | new | inherits zombie.tscn: wide capsule, big zones, Plate node |
| systems/enemies/brute_plate.gd | new | plate absorb, break, fly-off, speed boost |
| systems/enemies/brute_moves.gd | new | charge, slam (RefCounted, data points to it) |
| systems/enemies/zombie_targeting.gd | changed | MOST_DAMAGE mode |
| systems/enemies/zombie_entry.gd | changed | smash a whole barrier in one hit when the data says so |
| systems/enemies/enemy_data.gd | changed | `smashes_barriers`, `spawn_sound`, late health growth fields (if picked) |
| systems/enemies/zombie_voice.gd | changed | spawn roar at long range |
| systems/waves/wave_rules.gd, wave_director.gd | changed | Brute schedule and spawn |
| systems/net/zombie_sync.gd | changed | syncs `Plate:broken` when the zombie has a Plate |
| systems/net/player_push.gd | new | server-to-owner knockback (pattern 5) |
| systems/player/player_moves.gd | changed | applies a push to the owner's velocity |
| content/enemies/zombie_brute.tres, content/waves/default_waves.tres | new / changed | data and schedule |
| core/build.gd | changed | PROTOCOL_VERSION bump (steps 2 and 3) |

Autoloads, managers or base classes added: none. `BruteMoves` is the second script
behind `special_moves` (duck-typed like `StalkerMoves`). `PlayerPush` is a small
pattern 5 node because `player_state_sync.gd` (294) and `player.gd` (335) must not
grow.

Files over 300 lines this plan grows: none (`player.gd` and `player_state_sync.gd`
are left alone on purpose, see above).

## Data

- `zombie_brute.tres`: max_health 1200 (12 x Walker's 100), move_speed 2.2 fixed,
  attack (slam) damage 50, range 2.5, windup 0.9, special_damage 60 (charge),
  loot_drop_chance 1.0, loot_min_rarity rare, xp_reward 100 (provisional), targeting
  MOST_DAMAGE, spawn_tags [&"wide"], smashes_barriers true, special_moves
  brute_moves.gd, body height 2.3 m (provisional).
- `EnemyData` new fields: `smashes_barriers: bool = false`, `spawn_sound: AudioStream`
  (played at 40 m range on every peer).
- `WaveRules` Brute group: `brute_enemy: EnemyData`, `brute_first_round: int = 15`,
  `brute_gap_min: int = 4`, `brute_gap_max: int = 6`. The server rolls the schedule
  at match start with the session RNG (like Blackouts); a Brute round that falls on a
  Blackout round moves to the next round (provisional). The Brute spawns once half
  the round's zombies have spawned (provisional) and is added to the round's count.
- Plate: `BrutePlate` sets the head zone's multiplier (and the body's, if the person
  picks "all damage") to 25% of its normal value while whole; `broken: bool` synced.
- Health curve: as the person picks (Open decisions). If "flatter after round 20":
  `EnemyData.late_growth_from_round: int = 0` and `late_growth: float = 0.0`
  (0 = use the round curve), Brute 20 and 1.05.
- Network: `Plate:broken` sync (step 2), `PlayerPush` RPC (step 3): protocol bumps.
- Save format change: none.
- Content checks: zombie_brute (scene has a Plate node, loot 1.0 and min rare,
  special_moves set); WaveRules brute_enemy set, gap_min <= gap_max.

## Co-op behaviour

- Who owns the state: server (schedule, health, plate, moves, damage, drop, target).
- What clients send, what the server sends back: clients send shots (HitClaims). The
  server syncs state, `special_move`, `special_point` (charge end point), `Plate:broken`;
  sends `PlayerPush` to a hit player's owner, who adds the push to its own velocity.
- What a client sees that the host sees too: wind-up pose and roar, the charge, the
  plate flying off, the stun, the slam. Only the hit player feels the knockback; the
  others see it through that player's synced position.
- Late joiner: the Brute arrives through the MultiplayerSpawner with its synced
  properties, so a broken plate stays broken.
- Dedicated server: no poses or sounds; AI, damage and drops run as usual.

## Performance

One Brute alive at a time. Charge check: distance and cooldown first, then one box
shape cast along the line, at most every 0.5 s. Slam: one loop over the players group
(no physics query). Plate fly-off spawns one pooled-free rigid copy per Brute (once
per Brute, not per frame). Budget: 60 fps with 24 zombies plus the Brute.

## Steps

### Step 1: Brute model with a breakable plate, data and sounds

- Build: `tripo_intake.py --part plate` keeps the helmet plate as its own mesh,
  skinned to the head bone (select faces mostly weighted to the head above a cut
  height; tune per model in the manifest). If the cut looks bad on the turnaround,
  fall back to a code-built plate over a Tripo head without the helmet and say so in
  DECISIONS. Intake `Brute.glb` (copy to `tripo/sources/brute.glb`, manifest row,
  height 2.3 m) to `assets/models/zombies/brute.glb`. `brute.tscn` (capsule radius
  0.6, height 2.3, head and body zones scaled up, `Plate` node holding the plate mesh
  path), `zombie_brute.tres` with the slam as a plain single-target swing for now,
  sounds (free sources with CREDITS lines, or generated with a DECISIONS line), the
  spawn roar. Not scheduled yet. DECISIONS lines: height, XP 100.
- Files: tools/assets/tripo_intake.py, tripo/zombies.json,
  assets/models/zombies/brute.glb, systems/enemies/brute.tscn,
  content/enemies/zombie_brute.tres, enemy_data.gd (`spawn_sound`), zombie_voice.gd,
  assets/audio/, docs/CREDITS.md, docs/design/turnarounds/, docs/DECISIONS.md.
- Tests: content check for zombie_brute; unit: the scene's Plate node finds its mesh
  and the head zone; Assets and Turnarounds checks.
- Done when: `debug spawn zombie_brute` shows a Brute with a separate plate mesh that
  walks, swings and dies, and roars on spawn.

### Step 2: Brute rounds and the head plate

- Build: WaveRules Brute fields and `roll_brutes()`; WaveDirector rolls the schedule
  at `start()` and spawns the Brute once half the round has spawned (count + 1),
  skipping Blackout rounds to the next round. `BrutePlate`: while whole the head zone
  (and body zone, if picked) multiplier is 25% of normal; when the Brute has lost 25%
  of max health it breaks: multipliers back, STAGGERED 1.5 s, plate mesh hidden and a
  copy thrown off (visual, every peer), speed x 1.2 on the server. ZombieSync adds
  `Plate:broken` when a Plate node exists. Tag the Halcyon spawn points a 0.6 m
  capsule fits through as `wide`. Late health growth fields if picked. Bump
  PROTOCOL_VERSION.
- Files: systems/waves/wave_rules.gd, wave_director.gd, content/waves/default_waves.tres,
  systems/enemies/brute_plate.gd (new), brute.tscn, enemy_data.gd, wave_rules.gd
  (health), systems/net/zombie_sync.gd, levels/halcyon_labs/map.tscn (wide tags),
  core/build.gd, docs/LOGGING.md (brute_skipped),
  docs/DECISIONS.md.
- Tests: unit `test_wave_rules.gd`: Brute rounds from seed 1 are 15 then gaps of 4..6,
  never on a Blackout round; unit `test_brute_plate.gd`: a 100-damage head hit takes
  25 while whole; the plate breaks at exactly 25% health lost, staggers 1.5 s and
  speeds up 20%; after the break the full multiplier applies. Co-op test: a client
  copy sees `broken` after the server breaks it. Integration: headless round 15 has
  one Brute and its kill drops Rare or better.
- Done when: round 15 has a Brute whose plate soaks then breaks, the same for every
  player, and its kill drops Rare+.

### Step 3: The charge and knockback

- Build: `BruteMoves.try_start`: target 6 to 20 m, a box shape cast along the line is
  clear (checked at most every 0.5 s), not in the last 4 s (provisional). WIND-UP
  1.2 s facing the target (stamp and roar tell, pose), then locks `special_point`
  20 m ahead (or the wall in front), CHARGE at 7 m/s with `move_and_slide`; every
  player within 1.5 m of the Brute during the charge is hit once for `special_damage`
  and pushed (8 m/s away and up, provisional) through `PlayerPush` to the owner;
  hitting a wall stops it with a 2 s STAGGERED stun. `PlayerPush` (server-owned node
  added in `Player._ready()`, pattern 5) calls the owner, whose `PlayerMoves` adds the
  push to velocity. Bump PROTOCOL_VERSION.
- Files: systems/enemies/brute_moves.gd (new), zombie_rig.gd (wind-up and charge
  poses), content/enemies/zombie_brute.tres, systems/net/player_push.gd (new),
  systems/player/player_moves.gd, player.tscn or player.gd (one line to add the node),
  core/build.gd, docs/LOGGING.md (brute_charge_blocked), docs/DECISIONS.md.
- Tests: unit `test_brute_moves.gd`: no charge under 6 m, over 20 m or with a blocked
  line; direction locks at 1.2 s and does not follow a moving target; a player in the
  path is hit once for 60; a wall stops it into a 2 s stun. Co-op test: the push RPC
  reaches the owning client and changes its velocity; a push from a non-server
  sender is ignored.
- Done when: the Brute winds up, charges in a straight line, can be sidestepped,
  knocks back the player it hits (host or client) and stuns itself on walls.

### Step 4: Slam, barrier smash, aggro and close-out

- Build: the slam replaces the plain swing: within 2.5 m, 0.9 s wind-up, hits every
  living player within 2.5 m for 50. ZombieEntry: with `smashes_barriers`, one 2 s hit
  removes all planks. MOST_DAMAGE targeting in `ZombieTargeting`: the server keeps a
  small per-zombie table of damage by attacker for the last 10 s (from the zombie's own
  `damaged` signal) and targets the top one, nearest when none. Finish-feature
  close-out: Acceptance, roadmap Done, plan Done, a GIF of a charge and a plate break.
- Files: systems/enemies/brute_moves.gd, zombie_entry.gd, zombie_targeting.gd,
  enemy_data.gd (`smashes_barriers`), content/enemies/zombie_brute.tres,
  docs/ROADMAP.md, docs/plans/brute.md.
- Tests: unit: slam hits two players inside 2.5 m and not one at 2.6 m; barrier smash
  clears all planks after 2 s; MOST_DAMAGE switches to the player who out-damaged the
  current target within 10 s and forgets damage older than 10 s. Integration: headless
  round 15 to 16 with the Brute and no SCRIPT ERROR; soak rounds 1-10 unchanged.
- Done when: the full Brute fight plays on Halcyon Labs; CI and soak green; play-test
  recorded.

## Acceptance

- [ ] Brute model passes Assets and Turnarounds checks (step 1)
- [ ] Round 15 then every 4 to 6 rounds, 12x health, 1.2 s charge wind-up, plate absorbs
      75% until 25% health lost (steps 2-3)
- [ ] Unit tests for plate break and charge; always drops Rare or better (steps 2-3)
- [ ] Plate break and knockback reach clients and late joiners (step 2 and 3 tests)
- [ ] Solo play-test: the wind-up is readable, sidestepping works, the fight is not a
      bullet sponge at round 20 (close-out)

## Risks

- Cutting the plate out of one Tripo mesh may leave a hole or a bad edge: step 1 is
  first so the code-built plate fallback costs one step, not a redo.
- 12x health on the exponential round curve (over 45,000 at round 27, issues.csv
  row 11) can make it a bullet sponge: an Open decision below, and the close-out
  play-test checks round 20.
- Knockback with owner-moved players: a lost or late push only looks soft; damage is
  still applied on the server.
- Windows too narrow for a 0.6 m capsule: the Brute prefers `wide` points (F-29 tags);
  step 2 tags the Halcyon points it can use and logs brute_skipped if none.

## Open decisions

The plan is size L, so the person approves it as a whole. Agent picks, marked
provisional in DECISIONS as their steps land: one Brute per Brute round, spawns at half
the round, skips a Blackout round, 4 s charge cooldown, push 8 m/s, XP 100, height 2.3 m.

- Head plate rule: does the plate cut only head damage, or all damage? (balance sheet
  issues.csv row 11 recommends head only)
- Brute health: keep 12x on the normal round curve, or grow slower after round 20?
  (issues.csv row 11 recommends 1.05 per round after round 20)
