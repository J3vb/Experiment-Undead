# Zombie Behaviour and AI

Source: copy of the design doc as of Nov 14, 2026. Where this file and the code differ, the code and `docs/DECISIONS.md` win.

## Goals and rules

Zombies are simple on purpose: one shared brain, five bodies, and a director that decides who goes where. The numbers (health, speed, damage) come from the [Game Design Doc](game-design.md); this doc says how they behave and how to build it.

1. **Pressure always builds.** Zombies never stand still, never give up, and arrive from more than one side as rounds climb.
2. **Every threat is readable.** Each dangerous move has a sound and a pose before it lands (a "tell"). If a player dies, they should know why.
3. **Fair, not cheap.** No hits from off-screen without a sound first. No spawning in view. Attacks only land if the zombie is still in range when the swing finishes.
4. **Cheap to run.** 24 zombies alive at 120 fps (stress test 48 at 90+). Far zombies think less often and use cheaper movement.
5. **Server decides, clients show.** All choices happen in one place (the authority), so co-op later needs no AI rewrite.
6. **Data, not code.** Each type is a `EnemyData` resource. A new zombie type is a new `.tres` file plus, at most, one new state script.

Out of scope: smart group tactics, cover use, ranged enemies. Zombies are a crowd, not soldiers.

## Shared brain

Every zombie runs the same small state machine; types only add one "special" state or change numbers. Each state is its own script under `systems/enemies/states/`, so a new behaviour never touches the others.

| State | What it does | Leaves when |
| --- | --- | --- |
| Spawning | Plays the entry animation (climb out of vent, rise, drop from ceiling). Cannot be hit for the first 0.3 s, then takes damage. | Animation ends |
| Entering | Walks to its assigned barrier, waits in the queue, tears planks (one per 1.5 s), vaults through. | Inside the play area |
| Chasing | Follows the path to its approach slot near the target player. | In attack range, or a special triggers |
| Attacking | Wind-up (the tell), strike (damage check at the end), recover. | Recover ends |
| Special | Type-only moves: Stalker climb and pounce, Brute charge. | Move ends or is interrupted |
| Staggered | Knockback, freeze, gravity well, head-plate break, big hit. | Timer ends |
| Relocating | Hidden, moved to a fresh spawn point out of sight (stuck handling). | Re-enters as Spawning |
| Dying | Death animation or ragdoll, drops, returns to the pool. | Removed |

**Two rules keep it fair.** Damage is checked when the strike lands, not when the wind-up starts, so stepping back during a tell always works. And a zombie never starts an attack from behind a player without its tell sound already playing.

**Moving attacks.** Run and Sprint zombies swing while still moving (speed drops to 60% for the swing) instead of stopping dead. That stops fast zombies from stuttering and keeps the crowd pushing forward.

_(Diagram not copied: zombie state machine · 8 states.)_

A zombie enters once, then loops between Chasing and its attacks; Relocating sends a stuck zombie back through Spawning.

## Enemy types

Health, speed, first round and damage are from the design doc. Numbers marked *(new)* are first guesses for the balance sheet, to tune in play-tests.

| Type | Moves | Attack | Tell (warning) | Counter |
| --- | --- | --- | --- | --- |
| Shambler | Speed rolled at spawn from the round's speed mix (1.2 / 2.6 / 4.2 / 5.6 m/s) | Swipe, 40 damage, 1.6 m reach, 0.45 s wind-up, 1.2 s between swings *(new)* | Groan, arm raised | Headshots, back-pedal |
| Crawler | 1.0 m/s, low body (0.5 m tall) | Bite, 25 damage, 1.2 m reach, 0.5 s wind-up *(new)* | Scrape sound | Aim low |
| Bloater | 1.4 m/s, never runs | Punch, 35 damage, 1.8 m reach, 0.7 s wind-up *(new)*. On death: gas cloud, 4 m wide, 6 s, 10 damage/s, slows 30% | Gurgle, glowing belly | Kill at range |
| Stalker | 5.8 m/s, uses climb routes on walls and ceilings | Pounce from 3 to 8 m, 50 damage. Swipe 30 when close *(new)* | Rising shriek 1 s before the pounce | Shoot it during the shriek, or slide sideways |
| Brute | 2.2 m/s, charge at 7 m/s | Charge 60 damage plus knockback; slam 50 damage in 2.5 m *(new)* | Ground thud, 1.2 s charge wind-up | Sidestep, shoot the head once the plate breaks |
| Glower (Blackout only) | 5 m/s, packs of 4 to 6 | Swipe, 20 damage *(new)* | Green glow, chittering | Flashlight, spray |

### Shambler

The crowd and the default. All other types reuse its states. Run and Sprint speeds use moving attacks. Shamble and Jog speeds path to where the player is now, not where they will be, so training zombies in a loop works. Run and Sprint lead the player by up to 0.5 s, so loops get tense later.

### Crawler

A Shambler turns into a Crawler when explosive damage to the legs is at least 40% of its max health and it survives *(new rule)*. It keeps its remaining health (capped at 0.6x). It uses the same navmesh and still counts for the round. Its low body slips under the aim line, which is its whole job.

### Bloater

A slow wall of health that punishes killing it up close. It prefers the middle of the crowd: when choosing an approach slot it takes the outer ring if other zombies are ahead, so it walks in behind them. Other zombies ignore the gas. Explosives burst it at once.

### Stalker

No true wall-walking navigation (too costly and buggy). Each map has authored **climb routes**: navigation links on a Stalker-only navigation layer that run up walls, across ceilings and down again, plus a few **perches** (ceiling spots above rooms).

1. **Chase:** uses climb routes when they are shorter, so it arrives from above or an odd angle.
2. **Perch:** if a perch is within 10 m of the target, it may hang there for 1 to 3 s (quiet clicking) before dropping.
3. **Pounce:** needs line of sight, 3 to 8 m range and no pounce in the last 6 s. Shriek 1.0 s: it turns to follow the player for 0.6 s, then locks the landing point. It leaps on a fixed arc and hits only if the player is within 1.2 m of the landing point.
4. **Miss:** 1.0 s stumble on landing. That is the reward for dodging.
5. **Interrupt:** taking 20% of its max health during the shriek cancels the pounce into a stagger.

### Brute

Mini-boss, first at round 15, then every 4 to 6 rounds. The head plate absorbs 75% of damage until 25% of its health is gone, then breaks (1.5 s stagger, plate flies off) and it walks 20% faster.

1. **Charge:** needs a clear straight line (shape cast) of 6 to 20 m. 1.2 s wind-up with thud, then the direction locks and it charges up to 20 m. Hitting a wall stuns it for 2 s, an open window for headshots.
2. **Slam:** when within 2.5 m, 0.9 s wind-up, hits everyone in 2.5 m.
3. **Barriers:** smashes a whole barrier in one 2 s hit instead of tearing planks.
4. **Aggro:** targets whoever did the most damage to it in the last 10 s (see target choice).

The Brute spawn plays its own music sting, per the audio plan.

### Glower

Only in Blackout rounds. A pack shares one target and one approach route, arrives together from one direction, then splits left and right around the player inside 6 m. That makes Blackout feel like a different fight without new systems.

## Spawning and entry

The Spawner places zombies at authored spawn points, never in view, and spreads them over different sides of the player so pressure comes from more than one direction.

**Spawn point kinds** (a `SpawnPoint` node in the map, with a zone id so it only works once that area's door is open):

| Kind | Entry | Time to enter |
| --- | --- | --- |
| Barrier window | Tear planks, then vault through | 1.5 s per plank, 1.0 s vault |
| Vent | Crawl out, no barrier | 1.2 s |
| Ground rise | Claw up from soil (outdoor maps) | 1.5 s |
| Ceiling drop | Stalkers and Glowers only | 0.6 s |
| Hidden door | Walk in from a closed side room | 0 s |

**Picking a spawn point.** Each time the round's spawn timer fires, every active point gets a score and the best one wins:

- Best between 12 and 35 m path distance from the nearest player; outside 8 to 50 m it is not used.
- Not visible to any player (camera cone check, then one raycast). Never broken, even if it means waiting.
- Not used in the last 3 s.
- Each point belongs to a **side** (north, east, etc.). The side used least in the last 10 spawns gets a bonus, so arrivals rotate.
- Type tags filter it: Brutes need a wide entry, Stalkers prefer ceiling and vent points.

If no point qualifies, the zombie waits in the queue and the next tick tries again. The 24-alive cap and the spawn interval stay in `WaveRules`.

**Barriers.** Each barrier has 6 planks *(new)* and 3 attack slots along the window. Extra zombies wait at queue points outside, 2 m back. A zombie in a slot with a player within 2 m of the window swipes through the gap instead of tearing (classic window fight). The player repairs planks as in the design doc; a zombie loses its slot if it waits 4 s without a plank to tear and goes to the next barrier with free slots.

**Warning.** Each spawn plays its entry sound at the spawn point (plank crack, vent rattle, soil). Players learn to hear where the next one comes from.

## Crowd behaviour

Without help, every zombie takes the same shortest path and you get a single-file line that one gun mows down. Four cheap tricks turn that line into a crowd that wraps around the player.

1. **Approach slots.** Each player has an inner ring of 6 slots at 1.4 m (who may attack) and an outer ring of 10 at 3 m (who waits and shoves). A zombie claims the nearest free slot on its side of the player. When an inner slot frees up, the closest outer zombie steps in. Moving players drag their rings with them.
2. **Path offset.** Each zombie gets a fixed sideways offset of up to 0.8 m from the path's centre line, rolled at spawn. In wide corridors they spread into a pack; in doorways the offset shrinks to zero so nobody snags.
3. **Flankers.** When 5 or more zombies chase the same player, the Director marks about 30% of the newest as flankers. A flanker first walks to an authored **flank point** on a different route (each map has a few per area), then joins the chase. It skips this if the detour adds more than 15 m.
4. **Separation.** Zombies do not collide with each other (Godot avoidance is off for performance). Instead, a 2 m grid finds neighbours within 0.9 m and pushes them apart gently. This is much cheaper than physics and gives the shoulder-to-shoulder look.

**Keeping training possible.** Flankers never path through the player's current loop area (the room they have been circling for 10 s), and Shamble and Jog zombies do not predict movement. Herding in the Mess Hall stays possible, but later rounds' faster zombies and the odd flanker make it tense, matching the "pressure always builds" pillar.

## Target choice in co-op

Each zombie picks the player with the best score, then sticks with them. In solo the only player always wins, so this code runs from day one.

- **Distance:** path distance counts most (closer is better). Straight-line distance is used for far-tier zombies to save path queries.
- **Crowding:** minus points for each zombie already in that player's inner ring, so the horde spreads across the squad instead of piling on one person.
- **Stickiness:** +20% for the current target. No switch within 3 s unless the target goes down, leaves the map area, or another player is 40% closer.
- **Down players are ignored.** Zombies leave a downed player alone and go for whoever can revive them, which creates the classic "cover me" moment.

Re-scoring happens every 2 s per zombie (spread across frames) and right away when any player goes down, is revived, or dies.

**Type quirks:** Brutes target whoever did the most damage to them in the last 10 s. Stalkers add a bonus for players with no ally within 8 m, so they hunt whoever strays. Glower packs share one target picked by the pack leader.

## Stuck handling

A stuck zombie gets three quiet tries to fix itself, then the design doc's relocate rule takes over. The player should never notice any of it.

| Step | Trigger | Fix |
| --- | --- | --- |
| 1. Repath | Moved less than 0.3 m in 2 s while chasing (not attacking or waiting for a slot) | New path, plus a 1 m random sidestep |
| 2. Snap | Still stuck at 5 s, or more than 0.5 m off the navmesh | Move to the nearest navmesh point, only if no player can see it |
| 3. Relocate | Can't reach the target for 20 s, or more than 60 m away for 15 s (design doc rule) | Hide, move to a valid spawn out of sight, re-enter. Keeps its health |
| Fell out | Below the map's kill height | Relocate at once |

**Last zombies.** When only 1 or 2 zombies are left for 30 s, they switch to Sprint speed and their groan plays at double volume, so the round never stalls on a hunt *(new rule)*.

**Finding the cause.** Every relocate logs the map, position and state. The debug console's `ai_debug` command draws paths, states, slots and stuck counters. A map validator test spawns a test zombie at every spawn point and checks a path exists to every player start, so broken navmesh is caught before play-testing.

## Performance

Budget: all zombie thinking and movement under 1.5 ms of CPU per frame with 24 alive, out of the 8.3 ms frame at 120 fps. The trick is that most zombies don't need to think every frame.

| Tier | When | Thinks | New path every | Movement | Animation |
| --- | --- | --- | --- | --- | --- |
| Near | Under 15 m, or attacking, or in a tell | 20 times/s | 0.25 s | Full `move_and_slide` | Every frame |
| Mid | 15 to 35 m | 10 times/s | 0.5 s | Full `move_and_slide` | 30 times/s |
| Far | Over 35 m, or out of sight and over 20 m | 4 times/s | 1.0 s | Slide along path points, snap to navmesh height, no collision | 10 times/s, paused off-screen |

Tier is checked twice a second. A zombie that becomes Near jumps up at once.

**How it is built:**

- One `EnemyManager` runs all zombies from a single loop instead of 24 separate `_physics_process` calls. It spreads thinking across frames so no frame does everyone at once.
- Path requests go through a queue, at most 4 per frame. `NavigationAgent3D` with avoidance off.
- Zombies don't collide with each other (own physics layer); the separation grid replaces that.
- Hitboxes are a few simple shapes (head, torso, limbs) on bones, only on the hitbox layer that bullets raycast against.
- Animation uses `AnimationTree` in manual mode and is advanced by the manager at the tier's rate. One shared animation library.
- Zombies come from the `Pool` autoload and go back on death. Max 4 live ragdolls; older bodies freeze. Max 12 bodies; each fades after 8 s.
- Custom monitors (`ai/think_ms`, `ai/path_queue`, `ai/alive`) show in the debug overlay and profiler.

If profiling still shows AI too slow, the next step is moving target scoring and separation to `WorkerThreadPool`, then GDExtension, as the architecture doc allows.

## Network-friendly design

Only the authority (the server, or the local game in solo) runs zombie AI. Clients only draw what they are told. Solo uses the exact same path, so co-op in P7 adds sending, not a second AI.

**What is sent per zombie:**

| Data | How | Rate |
| --- | --- | --- |
| Spawn: net id, type id, spawn point, speed roll | Reliable event | Once |
| Position (packed to cm) and facing | Unreliable snapshot | 20 per second near any player, 10 far |
| State plus the server tick it started | Reliable event | On change |
| Tells: Stalker shriek with locked landing point, Brute wind-up with locked direction | Reliable event | On start |
| Damage taken, limb lost, plate broken, death and drops | Reliable event | On change |

Clients show zombies about 100 ms in the past and smooth between snapshots. Animations play from state plus start tick, so every client sees the same swing at the same moment.

**Why the tells are long.** The shortest wind-up is 0.45 s. With up to 150 ms of lag, a client still gets at least 0.3 s of warning. Any new attack must keep a wind-up of at least 0.4 s for the same reason.

**Shooting zombies online.** The client sends its shot in its `InputFrame` and shows a hit marker straight away. The server rewinds Near-tier hitboxes to what that player saw (up to 200 ms, 12 stored frames) and confirms the damage. Random rolls (speed mix, Crawler chance, drops) use the session RNG on the server only.

**Bandwidth estimate:** 24 zombies x 20 snapshots x about 12 bytes is roughly 6 KB/s per player, easy for a home server.

## Data fields

Each type is one `EnemyData` resource in `content/enemies/<id>.tres`. Attacks are separate `AttackData` sub-resources so a type can have one or several. Example values are the Shambler's.

**EnemyData**

| Field | Type | Shambler | What it does |
| --- | --- | --- | --- |
| `id` | String | shambler | Taken from the file name |
| `display_name` | String | Shambler | For debug and kill feed |
| `scene` | PackedScene | shambler.tscn | Body, hitboxes, animations |
| `health_mult` | float | 1.0 | x the round's base health |
| `armor_zones` | Dictionary | none | Brute: head 0.25 until 25% health lost |
| `hit_mult` | Dictionary | head 2.5, torso 1.0, limbs 0.75 | Body part damage |
| `speed_source` | enum | ROUND\_MIX | ROUND\_MIX or FIXED |
| `move_speed` | float | 0 (uses mix) | m/s when FIXED |
| `lead_time` | float | 0 to 0.5 | Seconds of player prediction, by speed tier |
| `first_round` | int | 1 | Earliest round it can appear |
| `spawn_weight` | Curve | flat | Share of spawns by round |
| `max_alive` | int | 24 | Cap for this type (Brute: 1 solo) |
| `spawn_kinds` | Array | window, vent, ground | Spawn points it may use |
| `nav_layers` | int | 1 | Stalker adds the climb layer |
| `plank_time` | float | 1.5 | Seconds per plank torn |
| `attacks` | Array of AttackData | swipe | See below |
| `special_state` | Script | none | Stalker pounce, Brute charge |
| `targeting` | enum | NEAREST | NEAREST, MOST\_DAMAGE, ISOLATED, PACK |
| `slot_ring` | enum | INNER | Bloater prefers OUTER |
| `can_flank` | bool | true | Brute false |
| `stagger_threshold` | float | 0.3 | Share of max health in one hit that staggers |
| `turn_into` | Dictionary | crawler on 40% leg explosive | Crawler rule |
| `on_death` | Array | none | Bloater: gas cloud |
| `points_kill` | int | from economy | Points |
| `loot_table` | String | default | Loot drop table id |
| `xp` | int | 10 *(new)* | Character XP per kill |
| `sounds` | Dictionary | idle, tell, attack, death | Audio set |
| `silhouette_tag` | String | standard | For art and readability checks |

**AttackData**

| Field | Type | Shambler swipe |
| --- | --- | --- |
| `id` | String | swipe |
| `damage` | int | 40 |
| `range_min` / `range_max` | float | 0 / 1.6 m |
| `windup` | float | 0.45 s (minimum 0.4 for the network rule) |
| `recover` | float | 0.6 s |
| `cooldown` | float | 1.2 s |
| `hit_shape` | enum | ARC 90 degrees (or CIRCLE, LEAP) |
| `needs_line_of_sight` | bool | false |
| `move_while_attacking` | float | 0.6 for Run and Sprint, 0 otherwise |
| `knockback` | float | 0 |
| `interrupt_damage` | float | 0 (Stalker pounce 0.2) |
| `tell_sound` / `tell_anim` | String | groan / swipe\_windup |

**Map nodes** used by the AI: `SpawnPoint` (kind, zone id, side, type tags), `Barrier` (planks, slots, queue points), `FlankPoint` (area id), `ClimbLink` and `Perch` (Stalker only). The map validator checks all of these exist and connect.

## Build order and provisional decisions

Build the Shambler and the shared brain first, prove 48 of them run fast, then add types one at a time.

1. **P2 Wave loop:** `EnemyManager`, state machine, Shambler with speed mix, spawn point scoring, barriers, approach slots, separation, stuck steps 1 to 3, performance tiers. Gate: 48 Shamblers at 90+ fps in the test range.
2. **P3 Map systems:** map nodes (flank points, climb links, perches) and the map validator test.
3. **P4 Map 1:** Crawler, Bloater, Stalker, Brute, Glower and Blackout packs, all tells with sound, `ai_debug` overlay.
4. **P7 Co-op:** target scoring with crowding, sending and smoothing, hitbox rewind.

**Provisional decisions** (picked 2026-11-14 to keep work moving; change any of them after play-tests):

- Downed players are ignored by zombies in co-op.
- Crawler rule: explosive leg damage of 40% of max health.
- The last 1 or 2 zombies sprint after 30 s.
- Stalkers use authored climb routes, not free wall-walking.
- Barriers have 6 planks (about 9 s per window).
- Bloaters do not burst themselves in v0.1; try it in play-tests.
