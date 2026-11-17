# Plan: Round state and power-ups in co-op

Status: Review
Roadmap: F-40 / issue #126
Phase: P7
Size: M
Approved by:

## Goal

Every player in a co-op match, also on a dedicated server, sees the same round
number, round start and end, intermission and power-up drops, and a power-up
works for whoever picks it up. Today only the server sees any of it: a client's
HUD stays on round 0, its music never changes, and drops are invisible to it.
Serves "The pressure always builds": the round count is the score and the
clock of the whole run.

## Scope

In:

- Round state on clients: `round_started`, `round_ended` and
  `intermission_started` fire on every peer with the server's numbers, so the
  HUD, music and logs work unchanged.
- Late joiners get the current round, phase and intermission time left.
- Power-up pickups appear on every peer, and vanish on every peer when picked
  up or timed out.
- Any player can pick one up (the server decides who touched it first).
- The effect reaches the players it is for: Resupply refills every player's
  guns on their own PC; an ammo pack adds a magazine to the collector's guns.
- Everyone sees the "RESUPPLY" flash and hears the pick-up sound.
- Power-up effect becomes a data field, so `power_up.gd` no longer names
  content ids (two lines leave `tools/ci/content_id_baseline.txt`).

Not in (non-goals, and where each one goes instead):

- Doors, barriers, wall buys, power, Vault, serums, Reforger, Med Dispenser:
  already done in F-02 (`docs/plans/coop-interactions.md`). Issue #126 closes
  with this plan.
- New power-up types (Payday, Overkill and the rest of the drop deck): F-26.
  The effect field is an enum so they slot in, but only the two current
  effects are built.
- The Scavenger id check in `power_up_drops.gd` (`has_serum(&"scavenger")`):
  server-only and unchanged; it leaves the baseline with the serum rework, not
  here.
- Pause, squad cards, play again and the co-op soak: `docs/plans/coop-full-match.md`.

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky only for "no standard request pattern"; this plan adds
  no client request, only server -> client state), 2 Content ids (solid; this plan removes two baseline
  ids), 4 Events (solid), 7 Game tick and randomness (solid).
  Any of them shaky or missing? 1: safe, no new client request path.
- Decision records: 0003 trusted client, 0004 one code path, 0007 signals and events. Goes against one: no.
- Co-op:
  - Who decides: server for rounds, drops, pick-ups and who collected; owning client applies ammo to its
    own guns (ADR 0003: ammo lives on the owner's PC).
  - How a client triggers it: walking into the pickup. The server's copy of that player (moved by pose
    sync) enters the server's Area3D; no client request.
  - What other players see: round events relayed by RPC to all peers; pickups replicated by a
    MultiplayerSpawner; a "collected" RPC to all peers for the flash and sound; an effect RPC to each
    owner whose ammo changes.
  - Works on a dedicated server with no local player: yes, tests run the server with no local player.
- Data: new enum field PowerUpData.effect on the two existing .tres files. Code compares a specific id: no
  (removes two existing ones).
- Save: no change.
- Events and UI: no new Events. Existing round_started, round_ended, intermission_started and
  power_up_collected now also fire on clients. No new screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes.
- Tests: two-peer ENet tests (pattern tests/unit/coop_interaction_fixture.gd) from a client; solo tests
  stay green; content check for the new field.
- Logging: Log.warn net.round_state_ignored when a client gets a round message from a non-server sender.
- Performance: three reliable RPCs per round; one spawn and one despawn per drop (max 4 a round).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#power-up-drops: 2.5% chance per kill, max 4 a
  round, shuffled deck, floats 25 s, blinks the last 5 s. Resupply = full ammo
  for all guns. These numbers stay where they are (`PowerUpDrops` exports,
  `PowerUp.LIFETIME`, `PowerUp.BLINK_TIME`).
- docs/design/game-design.md: Scavenger serum, ammo pack = one magazine per
  gun (current `PowerUp.collect()` behaviour, unchanged).
- docs/design/ui-hud.md#7-match-hud: round number top left, round flash.
- docs/MULTIPLAYER.md: "Waves, round number, power-ups: server, synced to all".
- docs/adr/0003-trusted-client-co-op.md: guns and ammo live on the owner.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/waves/wave_director.gd | changed | Server relays round start, end and intermission to clients by RPC; answers a late joiner's snapshot request |
| systems/diagnostics/health_watch.gd | changed | Round stall check runs only on the authority (clients have no kill events) |
| systems/power_ups/power_up_data.gd | changed | New `effect` enum field |
| content/power_ups/*.tres | changed | Set `effect` |
| systems/power_ups/power_up.gd | changed | Effect by `data.effect`, not id; only the server frees it; `apply_effect()` static for owners |
| systems/power_ups/power_up_drops.gd | changed | Spawns through a MultiplayerSpawner; sends "collected" to all and effect grants to owners |
| core/build.gd | changed | PROTOCOL_VERSION +1 in each step that adds RPCs |
| tools/ci/content_id_baseline.txt | changed | Two power-up lines removed |
| docs/MULTIPLAYER.md, docs/DECISIONS.md, docs/ROADMAP.md | changed | Close-out in step 2 |

Autoloads, managers or base classes added: none. No new nodes except the
built-in MultiplayerSpawner child of PowerUpDrops (Keep it simple rule 8).

## Data

- `PowerUpData.effect: Effect` (new enum `Effect { RESUPPLY, AMMO_PACK }`,
  default `RESUPPLY`). Read by `PowerUp.apply_effect()`.
  `resupply.tres` = RESUPPLY, `ammo_pack.tres` = AMMO_PACK.
- Network messages (all on existing nodes at the same path on every peer):
  - `WaveDirector._receive_round(kind: int, round_number: int, value: float)`
    authority to all; kind = started / ended / intermission; value = enemy
    count or intermission seconds.
  - `WaveDirector._request_round_state()` any peer to server, and the reply
    `_receive_round_state(phase: int, round_number: int, time_left: float)`.
  - Pickups: `MultiplayerSpawner` spawn data `[pickup_id: int, data_id: StringName, position: Vector3]`,
    plus a spawn-only `MultiplayerSynchronizer` on each pickup that sends its current `age`
    whenever the pickup is spawned on a peer (also a late joiner, which gets the age at join time).
  - `PowerUpDrops._receive_collected(data_id: StringName, collector_net_id: int, position: Vector3)` authority to all.
  - `PowerUpDrops._receive_effect(data_id: StringName)` authority to one owner.
- Save format change: none.
- Content checks to add in `tests/content/`: every power-up has a valid
  `effect` and a non-empty `display_name` (extend the existing power-up check
  if there is one, else add `test_power_ups.gd`).

## Co-op behaviour

- Who owns the state: server (`WaveDirector` phase, round, timer; pickups,
  their age and who collected them). Owning client: the ammo in its own guns.
- What clients send, what the server sends back: a client sends only one
  snapshot request when it connects. The server sends round events to all,
  spawns and despawns pickups, "collected" to all, and an effect to each
  owner it applies to.
- What a client sees that the host sees too: round number, round flashes,
  intermission blink, music changes, pickups, their blink, pick-up flash and
  sound. Only the owner: its own refilled ammo.
- Late joiner: current phase, round and intermission time left (snapshot), and
  every live pickup (MultiplayerSpawner does this; the spawn-only synchronizer sends the current age so
  the blink is in step).
- Dedicated server: no HUD or music; relays and spawns still run. It has no
  local player, so effects only go out by RPC.

## Performance

Round sync: 3 reliable RPCs per round. Pickups: at most 4 drops plus Scavenger
packs a round, one spawn and one despawn each. The client copy of a pickup runs
only its spin and blink in `_process` (no physics, no Area checks). Nothing per
frame is allocated. No measurable cost at 24 zombies and 4 players.

## Steps

### Step 1: Round state on clients

- Build: in `WaveDirector`, after each `Events.round_started`,
  `Events.round_ended` and `Events.intermission_started` emit on the server,
  send `_receive_round.rpc(...)` when peers exist. On a client,
  `_receive_round` (sender must be 1, else `Log.warn`) sets `round_number`
  and emits the same Event locally. A client asks `_request_round_state` on
  `connected_to_server` and when it enters a running match; the reply sets
  the fields and emits `intermission_started` (with time left) or
  `round_started` (count 0) so the HUD and music catch up. `Hud._on_intermission`
  sets the round label to the round just survived (next round - 1, from round 2
  on), so a client joining in a break sees the number at once.
  `WaveDirector._physics_process` gets an authority guard
  (`if not multiplayer.is_server(): return`), so a client never advances a
  replicated phase, spawns, counts down `to_spawn` or emits round events of
  its own; it only stores what the server sends. Client-side listeners that must stay server-only are checked: `Economy`,
  `ProgressionService`, `PlayerStateSync`, `ExfilHatch` already guard on
  `multiplayer.is_server()`; `PowerUpDrops` resets a counter (harmless);
  `HealthWatch.check_stall` gets an authority guard so clients do not report
  a false `waves.round_stalled`. PROTOCOL_VERSION +1.
- Files: systems/waves/wave_director.gd, systems/diagnostics/health_watch.gd,
  systems/ui/hud.gd, tests/unit/test_hud.gd,
  core/build.gd, tests/unit/test_coop_round_state.gd (new),
  tests/unit/test_health_watch.gd.
- Tests: two-peer test: the server starts a round, the client's
  `round_started` fires with the same number and count and its
  `WaveDirector.round_number` matches; `round_ended` and
  `intermission_started` likewise; a late joiner connected mid-round gets the
  round number, and one connected in intermission gets the time left within
  0.2 s; a client running HealthWatch with a relayed round and no kills logs
  no `waves.round_stalled`; a client that got an intermission snapshot with
  0.1 s left and one that got a spawning snapshot emit no `round_started`
  and keep the same `round_number` and `to_spawn` over 1 s with no server
  message; the HUD shows "7" after `intermission_started(8, ...)` with no
  earlier round event. Solo wave tests and the soak stay green.
- Done when: a joined client's HUD shows the server's round number and
  flashes; tests above pass.

### Step 2: Power-ups on every peer, and close-out

- Build: add `PowerUpData.effect` and set it on both `.tres` files. Move the
  effect out of `PowerUp.collect()` into `static func apply_effect(player,
  data)` that touches only that player's guns (RESUPPLY: refill all; AMMO_PACK:
  one magazine each). `PowerUpDrops` gets a MultiplayerSpawner (spawn path:
  the level node it already adds pickups to, so the path matches on every
  peer; `spawn_function` builds a PowerUp from `[pickup_id, data_id, position]`
  with a spawn-only synchronizer for `age`
  through `Content`). On the server, `collect()` decides the targets
  (RESUPPLY: every player in `session.get_players()`; AMMO_PACK: the
  collector), applies to the server's own player directly, sends
  `_receive_effect` to each remote owner, sends `_receive_collected` to all
  (sound at the position, `Events.power_up_collected` with the collector
  found by net id), then frees the pickup. A client's PowerUp never frees
  itself and never collects (`_physics_process` timeout and `body_entered`
  only on the server). PROTOCOL_VERSION +1. Remove the two power-up lines from
  `content_id_baseline.txt`. Close-out: MULTIPLAYER.md build order gets a
  step 8 "Round state and power-ups (done)", DECISIONS.md entry, ROADMAP F-40
  Done, plan Status Done, close #126.
- Files: systems/power_ups/power_up_data.gd, power_up.gd, power_up_drops.gd,
  content/power_ups/resupply.tres, ammo_pack.tres, core/build.gd,
  tools/ci/content_id_baseline.txt, tests/unit/test_coop_power_ups.gd (new),
  tests/unit/test_power_ups.gd (update if present), tests/content/ power-up
  check, docs/MULTIPLAYER.md, docs/DECISIONS.md, docs/ROADMAP.md, this plan.
- Tests: two-peer: a server drop appears on the client with the same data id
  and position; the client's player (moved on the server) collects it; the
  pickup is gone on both peers; the client's half-empty gun is full after a
  Resupply, and the server's own player too; an ammo pack adds one magazine
  only to the collector; `power_up_collected` fires on both peers with the
  right collector; a pickup that times out disappears on the client; a late
  joiner who arrives when a pickup is 21 s old gets age 21 (it is already
  blinking). Solo collect test still passes.
- Done when: a joined client sees, collects and benefits from drops; tests
  pass; F-40 and #126 closed.

## Acceptance

- [ ] A client sees the same round number, flashes and intermission as the host (step 1 test).
- [ ] A late joiner sees the current round and live pickups (steps 1 and 2 tests).
- [ ] Any player can collect a drop and the effect lands on the right players (step 2 test).
- [ ] No content id literals left in `power_up.gd` (baseline shrinks).
- [ ] Solo and the rounds 1-10 soak stay green.

## Risks

- Client listeners of round events that assume the server. Step 1 checks each
  listener (list above) and puts the HealthWatch guard in the same PR.
- Ordering between the despawn and the "collected" RPC. The collected message
  carries data id and position, so it never needs the pickup node.
- A client freeing a replicated node breaks the spawner. Step 2 makes the
  client copy passive and tests the timeout path.

## Open decisions

- none
