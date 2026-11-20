# Plan: Mantle

Status: Review
Roadmap: F-25 / issue #120
Phase: P1
Size: M
Approved by:
Lore link: none: a movement move; nothing new to see or read (the step 2 sound is a hand-on-metal thump with no story content)

## Goal

Push into a waist- to chest-high ledge and jump, and the player climbs over it
in one smooth move instead of a clumsy jump. Serves the pillar "Guns feel
great" (P1 gun feel: player controller, sprint, slide, mantle).

## Scope

In:

- Auto mantle onto ledges 0.5 to 1.2 m above the floor you left, when you hold
  jump and push forward into them (game-design.md, Movement table).
- A refusal for ledges over 1.2 m, ledges with no room to stand on, and ledges
  a zombie or teammate stands on.
- Timings and limits in one data file, `content/feel/mantle_rules.tres`.
- No firing while mantling; the gun dips like a sprint, the camera dips like a
  landing (follows the Head bob comfort setting); one generated sound.

Not in (non-goals, and where each one goes instead):

- The "Auto mantle" accessibility toggle (controls.md, Toggle or hold): mantle
  without pressing jump (later: next accessibility pass in Settings, F-48
  follow-up row).
- A third-person mantle clip for teammates: they see the body rise and slide
  over in the synced position, which reads fine at 0.4 s (later: when F-41
  clips get a follow-up).
- Teammates hearing your mantle: remote footsteps are silent too (DECISIONS,
  Simplified, "Sound"); fixed together in the sound foundation step.
- Mantling over gaps, ledge hangs, wall climbs, crouch-only landing spots
  (never in v0.2; not in the design).
- Zombies mantling: zombies vault through windows already; Stalker climbing is
  F-29.

## Ready to build

- Foundations touched (numbers from docs/FOUNDATIONS.md): 1 co-op authority,
  6 input, 7 game tick, 12 hot paths. All solid.
  Any of them shaky or missing? no.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (the
  owner moves its own player, as it does today), 0002 content as resources
  (rules in a `.tres`), 0004 one code path (solo and co-op run the same
  mantle code). Does this go against one? no
- Co-op:
  - Who decides: the owning client, the same as walking, jumping and sliding.
    `Player._set_local()` only runs `_physics_process` on the owner.
  - How a client triggers it: no request. It is movement, and movement is
    trusted to the owner (ADR 0003, MULTIPLAYER.md).
  - What other players see, and how it reaches them: the existing `PoseSync`
    MultiplayerSynchronizer sends `position` every tick, so teammates and the
    server see the climb. No new synced property, no new RPC, no protocol bump.
  - Works on a dedicated server with no local player: yes (nothing runs there;
    the server's copies of client players do not run physics).
- Data: `content/feel/mantle_rules.tres` (new type `MantleRules`). Code
  compares against a specific id anywhere: no
- Save: changes what is saved? no. Renames or removes a saved id: no
- Events and UI: no new Events (only the owner cares, so the player signals
  nothing game-wide). No new screen: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (reads `InputFrame.JUMP` and `frame.move`; runs inside
  `Player.apply_frame()`; no randomness).
- Tests: `tests/unit/test_player_mantle.gd` (physics, like
  `test_player_moves.gd`), `tests/content/test_feel_data.gd` (rules file),
  `tests/integration/test_halcyon_mantle.gd` (the vent ledge stays one-way).
  Co-op: no new message, so no client-run test; step 1 checks a remote copy
  never starts a mantle.
- Logging: `Log.warn("player", "mantle_landed_blocked", ...)` when a mantle
  ends with the capsule overlapping world collision (the clearance check
  missed something). Listed in `docs/LOGGING.md`.
- Performance: two raycasts and two shape queries, only on ticks where jump is
  held while pushing forward near a wall; query objects are built once in
  `PlayerMantle._init()`. Nothing per frame otherwise.
- Lore link: none (see header).
- Out of scope: see Scope.

## Design references

- docs/design/game-design.md#gunfeel-and-movement, Movement table: "Mantle |
  Up to 1.2 m high | Auto when you push into a low wall and jump"; "Jump |
  1.0 m".
- Issue #120: "Mantle ledges 0.5-1.2 m high; timings in a data file";
  "Movement test mantles a test ledge and refuses a too-high one"; "New
  systems/player/mantle.gd; player.gd gets only a hook".
- docs/design/controls.md: Jump and mantle share Space / A / Cross (no new
  binding).
- docs/design/game-feel.md, Accessibility: landing dip is cosmetic and follows
  the comfort setting, so the mantle camera dip uses `head_bob` too.
- docs/design/maps.md, Halcyon Labs scaling: the vent drop from the
  Containment Wing to the Mess Hall is one-way under 3 players. Its sill is
  1.4 m (`layout.json` room `vent_ledge`, floor 1.4), above the 1.2 m cap, so it
  stays one-way. A test guards it.
- docs/DECISIONS.md: "Sound" (remote footsteps silent), "Procedural animation".
- docs/adr/0003-trusted-client-co-op.md, 0002, 0004.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/player/mantle.gd | new | `PlayerMantle` (RefCounted, like `PlayerMoves`): ledge check, the climb, cancel rules |
| systems/player/mantle_rules.gd | new | `MantleRules` Resource: heights, reach, timings |
| content/feel/mantle_rules.tres | new | The numbers below |
| systems/player/player.gd | changed | Hook only: `@export var mantle_rules`, `var mantle`, one call at the top of `_move()`, trigger off while mantling (about 6 lines; file is 335, cap 350) |
| systems/player/player.tscn | changed | `mantle_rules = ExtResource(...)` on the root node |
| systems/player/player_camera.gd | changed (step 2) | `dip(metres, seconds)` for the mantle camera dip, scaled by `head_bob` |
| systems/weapons/weapon_holder.gd | unchanged | Mantle passes `sprinting = true` to the existing `set_state()` for the lowered gun |
| tools/generate_sfx.py, assets/audio/player_mantle.wav | changed / new (step 2) | One generated sound |
| docs/LOGGING.md | changed | `player.mantle_landed_blocked` |
| docs/DECISIONS.md | changed | Provisional picks line for the mantle numbers |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: `systems/player/player.gd` (335) by
about 6 lines, to stay under 350. The issue asks for exactly this: a hook only,
all logic in `mantle.gd`. If the hook would cross 350, move `_tick_stamina()`
into `player_moves.gd` first in the same step (split by job).

## Data

New Resource type `MantleRules` (`systems/player/mantle_rules.gd`), one file
`content/feel/mantle_rules.tres`, read by `PlayerMantle` through
`Player.mantle_rules`:

| Field | Type | Value | Source |
|---|---|---|---|
| `min_height` | float | 0.5 m | issue #120 |
| `max_height` | float | 1.2 m | game-design.md, issue #120 |
| `reach` | float | 0.45 m (in front of the capsule edge) | agent pick, provisional |
| `base_time` | float | 0.22 s | agent pick, provisional |
| `time_per_metre` | float | 0.18 s (so 0.31 s at 0.5 m, 0.44 s at 1.2 m) | agent pick, provisional |

Fixed rules stay constants in `mantle.gd` (KEEP_IT_SIMPLE rule 10): rise
share of the time 0.6, forward push needed `move.y <= -0.5`, exit speed half
of walk speed, clearance margin 0.02 m.

- Save format change: none.
- Content checks to add in `tests/content/test_feel_data.gd`: the file loads as
  `MantleRules`; `0 < min_height < max_height`; `max_height` is 1.2 (the
  design cap; a change must update game-design.md first); all times > 0;
  the longest mantle is under 0.6 s.

## Co-op behaviour

- Who owns the state (server / owning client / each client): the owning
  client. `PlayerMantle` state lives in the owner's `Player.mantle`; other
  peers' copies never run `_physics_process`, so they never mantle.
- What clients send, what the server sends back: nothing new. Position goes
  through the existing `PoseSync` (`replication_mode = 1`, always).
- What a client sees that the host sees too (and what only the owner sees):
  everyone sees the body rise and move onto the ledge. Only the owner sees the
  camera dip, the lowered gun and hears the sound.
- Late joiner: nothing; a mantle lasts under 0.5 s and the synced position is
  already right.
- Dedicated server (no screen, no local player): nothing runs.
- Server rules that read player position: zombie targeting uses the flat
  distance (`Zombie._try_hit_target()`), so a player on a 1.2 m ledge is still
  hit from beside it. Hit claims cannot happen mid-mantle (no firing).
  `BodyAnimator` treats jumps over its teleport distance as respawns; a mantle
  moves at most about 1.7 m over 0.3 s, far under it.

## Performance

Idle cost: one boolean check per tick (jump held and pushing forward). When
that is true: one forward ray, one down ray, at most two capsule shape queries
with prebuilt `PhysicsRayQueryParameters3D` / `PhysicsShapeQueryParameters3D`.
Under 0.05 ms per player on the ticks it runs; no allocation. Budget: 0.1 ms
per player per tick.

## Steps

### Step 1: Mantle over a ledge

- Build:
  - `MantleRules` and `content/feel/mantle_rules.tres` with the table above.
  - `PlayerMantle.try_start(player, frame) -> bool`: only if not mantling,
    not downed, not crouching or sliding, input enabled, `JUMP` held and
    `frame.move.y <= -0.5`. Remembers the floor height while on the floor;
    airborne starts measure from that height, so jumping first never raises
    the cap. Checks, all against `WORLD | BARRIER` (so barrier Blockers and
    window frames count as walls):
    1. Down ray from `max_height + 0.1` above the remembered floor, at
       `radius + reach` in front, to `min_height` above it. Hit with a normal
       of `y >= 0.7` gives the ledge top `h`.
    2. Forward ray at `h - 0.05` finds the wall face, so the landing spot is
       the face plus `radius + 0.05` forward, at height `h`.
    3. Capsule query at the player raised to `h` (room to rise) and at the
       landing spot (room to stand), masks `WORLD | BARRIER | ENEMY | PLAYER`,
       excluding the player's own RID.
  - `PlayerMantle.step(player, delta)`: moves `global_position` straight up
    for the first 60% of the time, then forward to the landing spot, with
    velocity zero. Ends with velocity = facing * walk speed * 0.5. Cancels on
    going down (`is_downed`) and on `Player.teleport()`. After it ends, logs
    `mantle_landed_blocked` if a capsule query at the end spot hits world.
  - `player.gd` hook in `_move()`: `if mantle.try_start(self, frame) or
    mantle.is_active(): mantle.step(self, delta); weapons.set_state(false,
    true, 0.0); return`, plus `weapons.set_trigger(false)` in `_read_input()`
    while mantling, and `mantle.cancel()` in `teleport()`.
  - `docs/LOGGING.md` row, `docs/DECISIONS.md` provisional line.
- Files: `systems/player/mantle.gd` (new), `systems/player/mantle_rules.gd`
  (new), `content/feel/mantle_rules.tres` (new), `systems/player/player.gd`,
  `systems/player/player.tscn`, `tests/unit/test_player_mantle.gd` (new),
  `tests/content/test_feel_data.gd`, `tests/integration/test_halcyon_mantle.gd`
  (new), `docs/LOGGING.md`, `docs/DECISIONS.md`.
- Tests:
  - `test_player_mantle.gd` (floor and box ledges built in code, InputFrames
    through `apply_frame()`): mantles a 0.5, 0.9 and 1.2 m ledge and ends
    standing on top within the timing from the rules; refuses 1.4 m;
    a 0.3 m step never starts a mantle; no forward push, no mantle; a 1.2 m
    ledge under a 1.5 m-high ceiling slab refuses (no room); a static body on
    the `ENEMY` layer standing on the top refuses; a barrier-layer Blocker in
    front refuses; jumping first then pushing into a 1.3 m wall still refuses
    (cap measured from the floor); fire held during a mantle fires no shot;
    a teleport mid-mantle cancels it; a player with physics off (remote copy)
    never mantles.
  - `test_feel_data.gd`: the content checks above.
  - `test_halcyon_mantle.gd`: loads `levels/halcyon_labs/map.tscn`, puts a
    player in the Mess Hall facing the vent ledge sill and runs the mantle
    input; the player stays on the Mess Hall floor.
- Done when: all three test files pass, the boot test and soak pass, and in
  play a jump into a waist-high crate climbs onto it.

### Step 2: Mantle feel and close-out

- Build:
  - `PlayerCamera.dip(metres, seconds)`: a short down-and-back camera offset
    (about 0.06 m over the mantle time), scaled by `head_bob`, started by
    `PlayerMantle` on the owner only.
  - A generated `player_mantle.wav` (hand on metal plus a cloth rustle) in
    `tools/generate_sfx.py` using the existing `handling()` helper, played from
    a new `MantleSound` AudioStreamPlayer on the `Player` bus in
    `player.tscn`, owner only.
  - Roadmap row F-25 Done, plan Done, run the `finish-feature` skill.
- Files: `systems/player/player_camera.gd`, `systems/player/mantle.gd`,
  `systems/player/player.tscn`, `tools/generate_sfx.py`,
  `assets/audio/player_mantle.wav` (+ `.import`),
  `tests/unit/test_player_mantle.gd`, `tests/content/test_generated_sounds.gd`,
  `docs/ROADMAP.md`, `docs/plans/mantle.md`.
- Tests: `test_player_mantle.gd`: a mantle starts the dip and the sound on the
  owner; `head_bob = 0` gives no camera offset; a remote copy plays neither.
  `test_generated_sounds.gd`: the new file exists, is mono, under 0.5 s and
  not silent.
- Done when: tests pass and the person's next play-test has a "mantle feels
  right" line (timings tuned in the `.tres` only).

## Acceptance

- [ ] Ledges from 0.5 to 1.2 m are mantled by pushing forward and jumping
  (test_player_mantle.gd).
- [ ] A 1.4 m ledge, a ledge with no headroom and a blocked ledge are refused
  (test_player_mantle.gd).
- [ ] The Halcyon vent ledge stays one-way (test_halcyon_mantle.gd).
- [ ] All timings live in `content/feel/mantle_rules.tres` (test_feel_data.gd).
- [ ] No shots while mantling; a teleport or going down cancels it
  (test_player_mantle.gd).
- [ ] Mantle feels smooth and quick in the person's play-test.

## Risks

- **New out-of-bounds or camping spots.** Props up to 1.2 m become reachable.
  Zombies hit by flat distance, so a player on a table or crate is still hit
  from beside it; tables at 0.9 m are already reachable by jumping. Barrier
  Blockers are on `BARRIER` and count as walls, so windows stay closed. The
  only height-gated route in Halcyon (vent ledge, 1.4 m) gets a test. If a
  play-test finds a bad spot, raise that prop or add an invisible wall in the
  map; no "no mantle" tag until a third case (KEEP_IT_SIMPLE rule 2).
- **Moving through geometry.** The climb sets position directly, so a bad
  clearance check could put the player in a wall. Two capsule queries before
  starting, `move_and_slide()` resumes after, and `mantle_landed_blocked`
  logs any miss. Tested with a ceiling slab and a blocked top.
- **player.gd line cap.** About 6 lines under a 350 cap with 15 left; the
  split fallback is named above.
- **Feel.** The numbers are agent picks; they live in data, so tuning is a
  `.tres` change, no code.

## Open decisions

- [x] Mantle timings, reach and the camera dip size: agent picks, provisional,
  tuned in play-test (working mode 2026-11-14: reversible picks are made by
  the thread). Recorded in docs/DECISIONS.md, Provisional picks.
