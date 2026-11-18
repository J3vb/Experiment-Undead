# Plan: Finish Halcyon Labs

Status: Done
Roadmap: F-13
Phase: P4 (v0.1 Vertical slice), co-op points for P7
Size: M
Approved by: Codex plan review on PR #212 (2026-11-17, five findings fixed), size M, no open decisions

## Goal

Halcyon Labs plays the way `docs/design/maps.md` describes it: rooms you can
read at a glance (the Mess Hall table loop, specimen tanks in the Labs,
generators, cells), co-op-only spawn points that switch on at 3 or 4 players,
the one-way vent from the Containment Wing to the Mess Hall, and the secret
"Signal in the Static". Serves "The pressure always builds" (map flow and
loops) and "Every run pays" (the secret's free Cryo Lance).

## Scope

What is already built and stays as it is (checked against main `b957106`):
all 8 areas plus the Coolant Tunnel, all doors at the maps doc costs (7,000
total, tested), power switch and power-only doors, tunnel shutters that open
with power, 8 Med Dispensers, Reforger, Specimen Vault on 6 spots, 5 wall guns
(Brenner, Kestrel, Vanguard AR, Talon, Coachman), exfil hatch, 16 barriers,
21 spawn points (16 windows, 4 ceiling vents, 1 tunnel grate), emergency
lighting before power, full-map lightmap.

In:

- Room props as data: a `props` list in `layout.json` that the blockout
  builder turns into boxes with collision and navmesh. Mess Hall long tables
  (the early training loop), Labs benches and specimen tanks (bio-green glow,
  the only green on the map), Generator Hall generators, Guard Post desk and
  lockers, Containment Wing cells, Loading Dock crates (moved from map.tscn).
- Co-op-only spawn points: 2 at the Loading Dock truck gaps, 1 Mess Hall vent,
  1 Containment Wing vent. Active only with 3 or more players. Solo and duo:
  burning wreckage sits beside the truck gaps; while 3+ players are in the
  match the fire is out. The wreckage is decoration only (no collision, no
  navmesh change): the gaps are always open, and only the spawn points' own
  `min_players` decides whether zombies come through, so a player leaving
  can never trap a zombie in the yard.
- The vent route: a duct from the Containment Wing up to a ledge in the Mess
  Hall east wall. One-way (a 1.4 m drop the player cannot jump back up). At
  3+ players a step appears so it works as a climb too. It has a grate at each
  end: the Mess Hall grate opens with the Mess Hall, the Containment grate
  opens with the Containment Wing, so the duct is usable only when both areas
  are bought and can never skip a door in either direction.
- Secret "Signal in the Static": three wall radios (Guard Post, Generator
  Hall, Labs), a Cold Room behind a freezer door in the Mess Hall south wall,
  a rack with a free Cryo Lance (each player takes it once per run).
- More map checks from the maps doc "Automatic checks per map", added in the
  step that needs them.
- GPU-agent prompt for the lightmap re-bake and fps check after the layout
  steps (the person's PC).

Not in (non-goals, and where each one goes instead):

- Reforger unlock task (shoot three junction boxes with an explosive or Shock
  ammo): needs grenades or Shock ammo first. Reforger keeps working with
  power only. Later: F-24 (frag grenades) adds the task.
- Halcyon Pin town cosmetic: there is no cosmetic or town save yet. Later: F-45.
- Lore notes and radio lines (`content/lore/`): later, with the Codex board in
  town (F-45).
- Brute arena: later, F-30 (Brute).
- Halcyon Labs Sublevel boss: F-60.
- Ambience and footsteps: F-03 (done) and F-04 (other thread).
- Spawn picking by path distance, view checks and side rotation
  (`docs/design/zombie-ai.md`): not this plan; the Spawner keeps its 12 m rule.
- `MapData` resource (`content/maps/`): only needed with a second map (Kessel
  Dam). One map stays hard-wired in `game_session.tscn`.
- Occluders: the map already runs 400-530 fps at 1440p with 24 zombies
  (2026-11-14 capture). Add them only if the fps check in step 5 drops.
- Exfil rope ladder visual: a polish issue, not needed for play.

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky overall, but this plan only uses the finished
  F-02 interactable path: new types are Interactables with net_state(), nothing new in systems/net/),
  2 Content ids (solid, no id literals: the rack points at cryo_lance.tres by export),
  7 Game tick and randomness (solid: tone order uses GameSession.rng), 9 Tests and CI (solid),
  11 Asset pipeline (solid: tone sound from tools/generate_sfx.py).
- Decision records: 0003 trusted client (server decides puzzle and spawns), 0004 one code path,
  0008 code-built assets first. Goes against one: no.
- Co-op:
  - Who decides: server for spawn points, wreckage, puzzle progress, freezer door and rack;
    owning client for its own gun (rack gives through the existing GIVE grant).
  - How a client triggers it: radios and rack are Interactables, so InteractionSync.request()
    already carries the press; the server runs interact().
  - What other players see: radio pitches, puzzle progress and the open freezer reach every peer
    through Interactable.net_state() / state_changed and Level.removed (late joiners in the snapshot).
    Wreckage and the climb step follow the player count each peer sees.
  - Works on a dedicated server with no local player: yes (no step reads a local player).
- Data: prop boxes, spawn points and secret nodes live in layout.json and map.tscn. No new Resource
  type. Code compares against a specific id: no.
- Save: no change.
```

## Design references

- `docs/design/maps.md#map-1-halcyon-labs-refined`: area table, training
  loops, chokepoints, secret, scaling for 1 to 4 players, blockout heights.
- `docs/design/maps.md#rules-every-map-follows`: co-op-only points at 3 or 4
  players, 21-28 points plus 4-6 co-op points, one secret per map.
- `docs/design/maps.md#automatic-checks-per-map`.
- `docs/design/maps.md#pass-1-the-style-guide-look`: props as boxes, ~12
  shared materials, green only where the experiment leaks.
- `docs/design/look-rules.md` (palette, bio-green glow rule, light rules).
- `docs/design/lore.md#1-halcyon-labs-where-it-broke-out` (secret meaning).
- `docs/DECISIONS.md`: Halcyon Labs blockout, lightmaps (re-bake steps),
  window barriers, emergency lighting, Cryo Lance.
- `docs/adr/0003-trusted-client-co-op.md`.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/blockout_builder.gd | changed | builds `props` (box, material, optional glow, optional baked=false) |
| levels/halcyon_labs/layout.json | changed | props, truck-gap yard, vent duct, Cold Room, openings |
| levels/halcyon_labs/blockout.tscn | regenerated | output of the builder |
| levels/halcyon_labs/map.tscn | changed | spawn points, wreckage, vent grate and step, radios, freezer door, rack, puzzle |
| systems/waves/zombie_spawn_point.gd | changed | `min_players: int = 1` |
| systems/waves/spawner.gd | changed | `_pick_marker()` skips points above the live player count |
| systems/level/coop_wreckage.gd | new | truck-gap wreckage (decoration): fire and debris shown while fewer than 3 players are in the match |
| systems/level/vent_step.gd | new | vent climb step: there (with collision) while 3+ players are in the match |
| systems/interactables/wall_radio.gd + .tscn | new | radio Interactable: plays its tone, forwards presses |
| systems/level/radio_puzzle.gd | new | owns tone order and progress, opens the freezer door |
| systems/interactables/wall_buy.gd | changed | `once_per_player` for the free rack |
| tools/generate_sfx.py, assets/sounds/ | changed | radio tone and static burst |
| tests/content/test_halcyon_labs.gd, tests/integration/test_halcyon_doors.gd | changed | new map checks |
| tests/unit/test_coop_wreckage.gd, tests/unit/test_vent_step.gd, tests/unit/test_radio_puzzle.gd, tests/unit/test_coop_secret.gd | new | unit and two-peer tests |

Autoloads, managers or base classes added: `RadioPuzzle` is a small node that
owns state no existing node owns (tone order and progress), allowed by Keep it
simple rule 6. No autoloads, no base classes. The wreckage and the vent step
each get their own small script (Keep it simple rule 2: no shared helper
before a third use; they share only a one-line count check).

## Data

- `layout.json` `props`: list of `{"id", "room", "box": [x, y, z, sx, sy, sz],
  "material"}`; box = [x, bottom above the room floor, z, size x, y, z] in map
  coordinates. Glow comes from the material (new `specimen_tank.tres`: dim
  bio-green emission). Read only by the builder.
- `ZombieSpawnPoint.min_players: int = 1` (export). Co-op points use 3.
- `CoopWreckage` and `VentStep`: no exports; both use the co-op threshold
  of 3 players from the maps doc as a constant.
- `WallBuy.once_per_player: bool = false`.
- Network: no new message. `WallRadio.net_state()` = `{"pitch": int}`;
  `RadioPuzzle` progress travels on the radios' net_state as `{"pitch": int,
  "lit": bool}`. Freezer door uses Door retire / `Level.removed`.
- Save format change: none.
- Content checks: none (no new Resource type).

## Co-op behaviour

- Who owns the state: server owns spawn-point choice, puzzle order and
  progress, freezer door, rack hand-outs. Each peer toggles the wreckage and
  the vent step from its own `players` group size (every peer has every Player, so they agree).
  Neither toggle changes the navmesh: the wreckage has no collision, and the
  vent step only adds a way up next to a drop that is always walkable down.
- What clients send, what the server sends back: radio and rack presses go
  through `InteractionSync.request()`; the server runs `interact()`, radios
  send `state_changed`, the rack sends the existing GIVE grant to the owner.
- What a client sees that the host sees too: radio tones (each peer plays the
  tone when a radio's net_state says it was pressed, and the idle tone loop
  from its pitch), the freezer opening, wreckage and the vent step.
- Late joiner: radio pitches and lit state in the InteractionSync snapshot,
  freezer door in `Level.removed`, vent grates in `Level.removed`, wreckage
  and vent step from its own player count.
- Dedicated server: tone playback is skipped where there is no audio (headless
  still runs it silently, no cost worth a branch).

## Performance

No per-frame work added in hot paths. `_pick_marker()` adds one int compare
per point per spawn. Wreckage and vent step react to `Events.player_spawned` and
`tree_exiting` of players only. Radios run a cosmetic idle timer (one
`Timer` node each). Props: about 40 boxes, baked into the lightmap; draw calls
stay under the Mess Hall / corridor numbers measured on 2026-11-14, checked in
step 5.

## Steps

### Step 1: Room props as data

- Build: `props` in `layout.json`; `blockout_builder.gd` builds them as
  `Block`s under a `Props` node per room (tank cores use the new dim
  `specimen_tank.tres` material). Mess Hall: two long table rows with a 2 m
  lane around them. Labs: benches and 4 specimen tanks with green glow.
  Generator Hall: 2 generators. Guard Post: desk and lockers. Containment
  Wing: 3 specimen cages. Loading Dock crates, drum and truck stay in
  map.tscn (moving them would drop their baked light until the re-bake). Keep every
  doorway, wall-buy, machine and barrier clear by 1.5 m.
- Files: tools/blockout_builder.gd, levels/halcyon_labs/layout.json,
  blockout.tscn (regenerated), levels/materials/specimen_tank.tres (new),
  tests/content/test_halcyon_labs.gd.
- Tests: every prop lies inside its room; no prop within 1.5 m of an
  opening, interactable or spawn point; a navmesh path exists all the way
  around the Mess Hall tables (two paths from one side of the tables to the
  other, on each side); the existing "blockout up to date" and "every spawn
  reaches the start" tests still pass. Look-check render of the Mess Hall and
  Labs attached to the PR.
- Done when: the map reads as its rooms in the look-check render and all tests
  pass.

### Step 2: Co-op-only spawn points and truck wreckage

- Build: `ZombieSpawnPoint.min_players`; `Spawner._pick_marker()` skips points
  with `min_players` above the `players` group size. `CoopWreckage` script. Layout:
  a truck yard space behind the Dock south wall with two gaps. map.tscn: 4
  co-op points (2 truck gaps, 1 Mess Hall vent, 1 Containment Wing vent),
  burning wreckage beside the two gaps under a `CoopWreckage` (decoration
  only: no collision, never in the navmesh source; shown while fewer than 3
  players are in the match). The gaps stay open, so a zombie already in the
  yard when the squad drops below 3 still walks in. Visibility reads the live
  `players` group size, so nothing needs syncing.
- Files: systems/waves/zombie_spawn_point.gd, systems/waves/spawner.gd,
  systems/level/coop_wreckage.gd (new), layout.json, blockout.tscn, map.tscn,
  tests/unit/test_coop_wreckage.gd (new), tests/unit/test_spawner.gd,
  tests/content/test_halcyon_labs.gd.
- Tests: spawner never picks a 3-player point with 1 or 2 players and can
  pick it with 3; the wreckage hides at 3 players and shows again at 2, and has no
  collision shape; map has 4 co-op points with min_players 3 and 21-28
  normal points; each truck-gap point has a navmesh path to the start with
  any player count (the yard is never closed).
- Done when: a 1-player soak never spawns at a co-op point (soak stays green).

### Step 3: Vent route Containment Wing to Mess Hall

- Build: layout duct from the Containment Wing north wall up a ramp to a
  ledge 1.4 m above the Mess Hall floor in its east wall. Two `Door` grates
  with cost 0: one at the Mess Hall end (`opens_area = mess_hall`), one at the
  Containment end (`opens_area = containment_wing`), so each opens with its
  area's own door and the duct never bypasses a purchase. `VentStep` (new,
  present while 3+ players are in the match) under the ledge.
- Files: systems/level/vent_step.gd (new), layout.json, blockout.tscn,
  map.tscn, tests/unit/test_vent_step.gd (new),
  tests/content/test_halcyon_labs.gd, tests/integration/test_halcyon_doors.gd.
- Tests: each grate opens only when its area's door is bought; with 3
  players, the Mess Hall debris bought and the Containment door shut, there is
  no navmesh path from the Mess Hall into the Containment Wing through the
  duct (and the same the other way);
  the ledge height is above the player's jump height (from `jump_velocity`
  and gravity) and the step makes it climbable; the door cost test ignores
  cost-0 doors and still totals 7,000.
- Done when: a player can drop from the Containment Wing into the Mess Hall
  and, solo, cannot go back that way.

### Step 4: Secret "Signal in the Static"

- Build: tone and static sounds in `tools/generate_sfx.py`. `WallRadio`
  (Interactable): after power it plays its tone every 8 s (staggered);
  interact plays the tone and tells the puzzle. `RadioPuzzle`: on power-on
  the server rolls the three pitches with `GameSession.rng`; pressing radios
  from lowest to highest tone lights each one; a wrong press plays static and
  resets. Solving opens the freezer `Door` (cost 0, `opens_area = cold_room`).
  Layout: Cold Room behind the Mess Hall south-east wall with its own lights.
  Rack: a `WallBuy` with the Cryo Lance and `once_per_player`.
- Files: tools/generate_sfx.py, assets/sounds/ (generated + imports),
  systems/interactables/wall_radio.gd/.tscn (new),
  systems/level/radio_puzzle.gd (new), systems/interactables/wall_buy.gd,
  layout.json, blockout.tscn, map.tscn, tests/unit/test_radio_puzzle.gd (new),
  tests/unit/test_coop_secret.gd (new), tests/unit/coop_interaction_fixture.gd,
  tests/integration/test_halcyon_doors.gd, docs/DECISIONS.md.
- Tests: radios do nothing before power; right order opens the freezer; a
  wrong press resets; the same seed gives the same order; net_state round trip
  restores pitches and lit radios on a client copy; rack gives the Cryo Lance
  once per player and sells no ammo; Cold Room has no spawn points. Two-peer
  test (`tests/unit/test_coop_secret.gd` on `coop_interaction_fixture.gd`, a
  server with no local player and a client): the client presses the radios
  through `InteractionSync.request()`, the server opens the freezer, the
  client sees it open; the client takes the rack and gets the Cryo Lance by
  the GIVE grant, a second take is refused; a late joiner after solving gets
  lit radios and the open freezer in its snapshot.
- Done when: solving the puzzle in a headless run gives the Cryo Lance.

### Step 5: Re-bake, fps check and close-out

- Build: paste-ready GPU-agent prompt in
  `/mnt/project-files/halcyon-labs/` for the lightmap re-bake (props, truck
  yard, duct, Cold Room; wreckage, vent step and freezer door unbaked) and the
  4-spot fps check with 24 zombies. The person's agent opens the bake PR.
  This thread then updates `docs/DECISIONS.md`, ticks Acceptance and sets the
  roadmap row to Done (finish-feature skill).
- Files: docs/DECISIONS.md, docs/ROADMAP.md, this plan, map.exr/.lmbake
  (from the bake PR).
- Tests: the existing lightmap size budget and "moving things not baked"
  tests cover the bake.
- Done when: the bake PR is merged and fps at the 4 spots stays above 120.

## Acceptance

- [x] Mess Hall table loop has a navmesh path all the way round (test: `test_halcyon_labs.gd` `test_mess_hall_tables_make_a_loop`).
- [x] Every prop sits in its room and clear of doors, machines and spawns (test: `test_props_sit_in_their_rooms_clear_of_doors_machines_and_spawns`).
- [x] 4 co-op-only spawn points, unused below 3 players (tests: `test_spawn_points_follow_the_rules`, `test_spawner.gd` `test_coop_points_wait_for_three_players`, `test_zombie_relocate.gd` `test_coop_point_is_not_used_below_three_players`; soak green).
- [x] Vent drop works one way solo, both ways at 3+ (tests: `test_vent_ledge_is_out_of_jump_reach_but_the_step_reaches_it`, `test_vent_step.gd`).
- [x] Secret opens the Cold Room and gives a Cryo Lance once per player (tests: `test_radio_puzzle.gd`, `test_coop_secret.gd`).
- [x] Lightmap re-baked and fps above 120 at the 4 spots (PR #296: Mess Hall 250, Main Corridor 221, Containment 410, Loading Dock 474 avg fps; 1% lows 157 to 266).

Steps merged: 1 #226, 2 #229, 3 #233, 4 #236 and #238, 5 #296.

Follow-ups (look, not blocking): #297 (bake barely shows, Containment very dark, wreckage hard to see from the Dock, vent ledge check, Windows-only `test_screens.gd` failure).

## Risks

- Props break the navmesh or block a window: tests in step 1 check clearance
  and paths before any later step builds on them.
- Zombies stranded by a closing route: avoided by design; no toggle in this
  plan closes a route (wreckage is decoration, the vent step only adds a way
  up, the duct always drains both ways once both grates are open).
- The lightmap goes stale after each layout step: LightmapGI errors when a
  baked node disappears (any new opening renames wall runs), so each layout
  step runs `tools/prune_lightmap_users.gd` (added with the ramp fix) to drop
  those entries. New boxes stay unbaked until the single re-bake in step 5.
- Players find the radio order by trial: wrong presses reset with static, and
  only 6 orders exist; fine for a secret that is "never needed to win".

## Open decisions

- none

Provisional picks (changeable later, recorded in docs/DECISIONS.md when
built): radio pitches random per run; each player takes the Cryo Lance once
per run; truck wreckage follows the live player count.
