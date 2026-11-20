# Plan: Co-op interactions (doors, wall-buys, machines)

Status: Done
Roadmap: F-02 / issue #138 (also foundation fix 2 in docs/FOUNDATIONS.md, part of #126)
Phase: P7
Size: M
Approved by: Codex plan review on PR #175 (2026-11-16), size M, no open decisions

## Goal

Every player in a co-op match, and every player on a dedicated server, can
open doors, turn on the power, repair barriers, buy wall guns and use the Med
Dispenser, Reforger, Specimen Vault and exfil hatch, and everyone sees the same
result. Today only the host can (issue #138). Serves "The pressure always
builds": spending points on the map is half the core loop.

## Scope

In:

- One request path: a client presses interact, the server checks the request
  and runs the same `interact()` it runs in solo.
- World state that interactables change reaches every client: open doors and
  areas, power, barrier planks, Med Dispenser sales, Specimen Vault state and
  spot, exfil hatch open and hold.
- Owner-only results reach the buyer: a bought gun, a refill, a Reforged gun.
- The buyer hears buy or denied from their own interaction, also on a
  dedicated server.
- Late joiners get the current world state.
- One two-peer test per interactable that runs the action from a client.

Not in (non-goals, and where each one goes instead):

- Power-ups in co-op (who collects, Resupply for remote players): F-40 (#126).
- Round number, intermission and `round_started` on clients, if they are not
  synced yet: F-40 (#126). Exfil gets its own state here so it does not wait.
- Hold-to-buy (0.3 s hold in `docs/design/controls.md`): stays a tap for now;
  it is a feel change for the Rebind controls work (F-05) or its own issue.
- Item effects for co-op clients (#145, #147): foundation fix 3, own plan.
- Ids into data (`owned.data.id == weapon.id` compares two data refs, not a
  literal, so it is fine here): foundation fix 4, own plan.
- Hearing other players' buy sounds: not needed; door, power and repair sounds
  already play on every peer through the state sync.

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky: this plan is its fix), 4 Events (solid),
  2 Content ids (shaky, not made worse: no new id literals), 10 Exported builds (Build green on main since #174).
  Any of them shaky or missing? 1 is fixed by this plan. 2 is untouched.
- Decision records: 0003 trusted client, 0004 one code path, 0007 signals and events. Goes against one: no.
- Co-op:
  - Who decides: server for points, world state and prices; owning client for its own guns and ammo (ADR 0003).
  - How a client triggers it: InteractionSync.request() -> RPC with the interactable's path and the owner's
    weapon facts; server checks sender, alive, range, rate and the interactable's own rules, then calls interact().
  - What other players see: world state RPC to all peers on every change; the owner gets grants by rpc_id.
  - Dedicated server with no local player: yes, the two-peer tests run the server side with no local player.
- Data: no new ids or numbers. Costs stay on the scenes and WeaponData/SerumData. Code compares a specific id: no.
- Save: no change.
- Events and UI: no new Events. Events.exfil_called and exfil_opened now also fire on clients (from the
  exfil state sync), so the HUD works there. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (Vault already).
- Tests: tests/unit/test_interaction_sync.gd (two peers), one client-side test per interactable, solo tests stay.
- Logging: Log.warn interaction_rejected (reason, peer, path), interaction_rate_limited.
- Performance: one reliable RPC per key press and per state change; no per-frame work added.
- Out of scope: see Not in above.
```

## Design references

- docs/FOUNDATIONS.md#1-co-op-authority: "client sends the request, server
  checks sender, range and state, then calls the same `interact()`".
- docs/MULTIPLAYER.md "Who owns what": points, wall buys, machines, doors are
  server owned; client sends a request RPC; server runs `Economy.try_spend()`.
- docs/adr/0003-trusted-client-co-op.md: each PC owns its own guns; the server
  owns shared state.
- docs/adr/0004-one-code-path.md: solo is a server with one player, so solo
  and host use the same `interact()` call with no request.
- docs/DECISIONS.md: Reforger (5000 / 2500, wall ammo 4000), Kestrel wall ammo,
  Specimen Vault, power-ups, co-op step 4 (Serums synced in the
  `PlayerStateSync` snapshot).
- docs/design/controls.md: interact key (hold time is out of scope).
- No new numbers. `REACH_SLACK` and the request rate are technical limits
  (like `HitClaims.SLACK`), not balance.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/net/interaction_sync.gd | new | Request RPC and checks, world state relay, late-join snapshot, owner grants and buy/denied result |
| systems/game/game_session.gd | changed | Creates `InteractionSync` next to `HitClaims` in `_setup_shooting()` (keep under 350 lines) |
| systems/player/player.gd | changed | `apply_frame()`: client sends a request instead of skipping; local interactables (loot) still run locally |
| systems/interactables/interactable.gd | changed | `state_changed` and `retired` signals, `net_state()` / `apply_net_state()`, `retire()`, `is_local()`, `owner_facts()`; `_pay()` reports the result to the buyer |
| systems/weapons/weapon_holder.gd | changed | `replace(old, data)` keeps the slot of the gun a grant names; `replace_current()` calls it |
| systems/interactables/door.gd | changed | Navmesh rebake only on the authority; clients open doors from the level state |
| systems/level/level.gd | changed | New `area_opened` signal; `net_state()` / `apply_net_state()` for power and open areas |
| systems/interactables/power_switch.gd | changed | Power sound on every peer via level state |
| systems/interactables/barrier.gd | changed | Planks in `net_state()`; tear/repair sound by plank change on clients |
| systems/interactables/wall_buy.gd | changed | Decides from owner facts; gives gun / refill through grants |
| systems/interactables/reforger.gd | changed | Decides from owner facts; Reforge / refill through grants |
| systems/interactables/med_dispenser.gd | changed | `sales` in `net_state()`; sells out through `retire()` |
| systems/interactables/specimen_vault.gd | changed | State, offer, buyer and spot in `net_state()`; held guns from owner facts; take = grant |
| systems/interactables/exfil_hatch.gd | changed | Open and holding in `net_state()`; emits its Events on clients when the state changes |
| systems/loot/loot_service.gd | changed | Delete the client-only LootDrop hack in `_physics_process()` (now `is_local()`) |
| docs/MULTIPLAYER.md, docs/FOUNDATIONS.md, docs/DECISIONS.md | changed | Last step: co-op interactions done, foundation 1 row updated |

Autoloads, managers or base classes added: one node, `InteractionSync`, a
child of `GameSession` like `HitClaims`. Keep it simple rule 6 allows it: it
owns a rule no node owns today (who may use which interactable from where)
and the relay of interactable state. No autoload, no new base class
(`Interactable` already exists and gets four small methods).

## Data

No new Resource types, `.tres` files or save fields.

Network messages (all on `InteractionSync`, all reliable):

- `request_interact(path: NodePath, facts: Dictionary)` client -> server.
  `path` is relative to the `Level` node (same scene on every peer). `facts`
  is what only the owner knows about its own guns, from
  `Interactable.owner_facts(player)`, default `{}`:
  - WallBuy: `{"owned": StringName (held id of this gun or its Reforged
    tier, or &""), "slot": int, "full": bool}`
  - Reforger: `{"current": StringName, "slot": int, "full": bool}`
  - SpecimenVault: `{"held": Array[StringName], "slot": int}`
  `slot` is an index in the owner's `weapons.weapons`: the owned gun for an
  ammo buy or Reforge, so two guns with the same base id (possible with Pack
  guns) are told apart; for a new gun (wall-buy or Vault take) it is the gun
  in hand at the moment of the press, the one a full holder gives up.
  The server only accepts ids that exist in `Content` weapons and that match
  the interactable (WallBuy: `weapon.id` or `weapon.upgraded.id`). Prices and
  the next tier always come from the server's own data.
- `_receive_result(path: NodePath, paid: bool)` server -> requester: plays
  `BuySound` or `DeniedSound` on the requester's copy.
- `_receive_grant(kind: int, weapon_id: StringName, from_id: StringName,
  from_slot: int)` server -> owner. `kind` is an enum on `InteractionSync`: `GIVE`, `UPGRADE`,
  `REFILL`. `from_id` names the gun the purchase was for (the one in the
  owner's facts), never "the gun in hand", so switching guns while the reply
  is on its way cannot hit the wrong gun:
  - `GIVE`: if the holder has a free slot, `weapons.give(weapon_id)`;
    if it is full, replace the gun at `from_slot` (the gun in hand at the
    press) with `WeaponHolder.replace(old, data)`, never whatever is in hand
    when the grant arrives.
  - `UPGRADE`: replace the gun at `from_slot` if its `data.id == from_id`
    (otherwise the first held gun with that id), in its own slot, with
    `weapon_id` (new `WeaponHolder.replace(old: Weapon, data)`;
    `replace_current()` becomes a call to it). If that gun is no longer held,
    `give()` the upgraded gun instead, so the points are never lost.
  - `REFILL`: `refill_all()` plus `ammo_changed` on the gun found the same
    way (`from_slot`, then `from_id`); nothing if it is gone.
  On the server's own player (solo, host) the same function runs directly,
  no RPC.
- `_grant_applied()` owner -> server, sent right after the owner applies a
  grant. While a peer has a grant outstanding, the server rejects that
  peer's purchases that use owner facts (WallBuy, Reforger, Vault take) with
  reason `grant_pending` and charges nothing, so a second press cannot be
  paid with facts that are already out of date. Cleared on ack and on
  disconnect. Doors, power, barriers and Serums do not wait.
- `_receive_state(path: NodePath, state: Dictionary)` server -> all clients,
  on every `state_changed`. Path `.` means the `Level` itself.
- `_request_snapshot()` client -> server once after join, answered with one
  `_receive_snapshot(states: Dictionary)` (path -> state) to that client.

Protocol: steps 1, 2 and 3 each add or change these RPCs, so each bumps
`Build.PROTOCOL_VERSION` in `core/build.gd` by one, and the handshake refuses
an older build before any player spawns (existing `test_handshake.gd` and
`test_net_match.gd` cover the refusal; each step asserts its new number).

`net_state()` per type (empty = not synced):

- Level: `{"power": bool, "areas": Array[StringName], "removed":
  Array[NodePath]}`. Interactables that leave the map on the server (an
  opened door, a sold-out Med Dispenser) are freed there, so they cannot
  carry their own state. Before freeing itself an interactable calls the new
  `Interactable.retire()`, which emits `retired`; `InteractionSync` adds its
  path to the level's `removed` list and broadcasts the level state. Clients
  call `retire()` on each listed node they still have, which runs the type's
  leaving effect (door: open sound, free; dispenser: free) without paying or
  rebaking. Late joiners get the full list, so nothing that is gone on the
  server comes back.
- Barrier: `{"planks": int}`.
- MedDispenser: `{"sales": int}` (only while it still exists; selling out
  goes through `removed`).
- SpecimenVault: `{"state": int, "offer": StringName, "buyer": int (net id),
  "spot": NodePath}`.
- ExfilHatch: `{"open": bool, "holding": bool, "hold_left": float,
  "counting": bool}`. `counting` is true while a living player is in the zone
  (the server already pauses the hold otherwise). The server emits
  `state_changed` when open, holding or counting changes, not every tick;
  clients count `hold_left` down locally while `counting` is true, so the
  HUD countdown (`Hud._update_exfil()` reads `hold_left`) moves and pauses
  like the server's. Each state message resets the client's `hold_left` to
  the server's value, so drift is at most one zone change.

- Save format change: none.
- Content checks to add in `tests/content/`: none (no new content type).

## Co-op behaviour

- Who owns the state: server for points, doors, power, planks, sales, Vault
  and exfil. Owning client for its guns and ammo (ADR 0003), changed only
  when the server sends a grant after taking the points.
- What clients send, what the server sends back: client sends
  `request_interact(path, facts)`. Server checks, in order: sender has a
  player, player alive and not downed, match not over, path resolves to an
  `Interactable` under the level, distance from the server's copy of the
  player to the interactable <= `interact_range + REACH_SLACK` (2.0 m:
  pose lag plus big areas), at most one request per 0.1 s per peer, facts
  valid. Any failure: `Log.warn(&"net", &"interaction_rejected", ...)` (as built: at most
  one warning per second across all peers) and a
  denied result. Otherwise `interact(player, facts)`. Back: result to the
  requester, grants to the owner, state to everyone.
- What everyone sees: doors open, power lights, planks, dispensers that run
  out, the Vault label, spot and offer, exfil glow and hold. Only the buyer
  hears buy/denied and gets the gun or ammo. Only the Vault buyer sees
  "Take ..." (prompt compares `buyer` with the viewer's net id).
- Late joiner: the snapshot holds the level state and every interactable
  with a non-empty `net_state()`, so doors opened before joining are gone,
  power is on, planks and Vault are right.
- Dedicated server: no local player, so no result sounds or grants run on
  the server itself. The navmesh rebake runs only on the server (clients run
  no zombie AI). Prompts and labels are skipped there already (no HUD).

## Performance

One reliable RPC per interact key press, per barrier plank change and per
Vault or exfil state change. With 24 zombies tearing planks that is a few
small messages per second. No per-frame work: `state_changed` is a signal,
`net_state()` builds a small Dictionary only when the state changed.
Clients stop baking the navmesh when a door opens, which removes a main-thread
hitch on clients. Budget: no measurable frame cost (under 0.1 ms per frame on
the server with 4 players).

## Steps

### Step 1: Request path, doors and power

- Build: `InteractionSync` with `request()`, `request_interact` and its
  checks, rate limit, `_receive_result`, `_receive_state`, the snapshot RPCs,
  and the state relay for the `Level`. `Interactable` gets `is_local()`
  (false; `LootDrop` returns true), `owner_facts()` (returns `{}`),
  `state_changed`, `net_state()` / `apply_net_state()`, and an optional
  `facts: Dictionary = {}` argument on `interact()` in the base and every
  subclass. `Interactable.accepts_requests()` returns false by default; the
  server rejects requests for any type that returns false (reason
  `not_networked_yet`, nothing charged), so a type is only reachable from a
  client once its own step has moved it to grants and state. Door and
  PowerSwitch return true in this step. `Player.apply_frame()`: if `Net.is_authority()` or
  `focus.is_local()` call `interact()` as today, otherwise
  `session.interactions.request(focus)`. Delete the client LootDrop branch
  in `LootService._physics_process()`. `Level` emits `area_opened` and
  `power_turned_on` (exists); on clients `apply_net_state()` turns power on,
  opens areas and retires every node in `removed`. `Interactable.retire()`
  and the `retired` signal; `Door.open()` calls it, and its navmesh rebake
  runs only where `Net.is_authority()`. `_pay()` sends the result to a
  remote buyer. Bump `Build.PROTOCOL_VERSION`.
- Files: core/build.gd, systems/net/interaction_sync.gd (new), systems/game/game_session.gd,
  systems/player/player.gd, systems/interactables/interactable.gd,
  door.gd, power_switch.gd, systems/level/level.gd,
  systems/loot/loot_drop.gd, systems/loot/loot_service.gd,
  tests/unit/test_interaction_sync.gd (new).
- Tests: `test_interaction_sync.gd` with two ENet peers in one process
  (pattern: `tests/unit/test_zombie_sync.gd`, server side has no local
  player): a client with 1000 points opens a door, server points drop by the
  cost, the door is gone on both peers and the area's spawn points join on the
  server; a client turns the power on and a power door opens on both; rejects
  for out of range, downed player, not enough points (denied result reaches
  the client), unknown path, a second request inside 0.1 s, and a wall-buy
  request (not migrated yet) that charges nothing and gives nothing; a client that
  connects after a door opened does not see that door (removed list in the
  snapshot). Existing
  `test_halcyon_doors.gd` and loot drop tests still pass in solo.
- Done when: a co-op client can open doors and turn on power on a listen
  server and on a dedicated server, everyone sees it, and solo is unchanged.

### Step 2: Wall-buys, Reforger and Med Dispenser

- Build: `_receive_grant` and `InteractionSync.grant(player, kind, data,
  from_id)` (direct call for the server's own player, `rpc_id` otherwise);
  `WeaponHolder.replace(old, data)` with `replace_current()` calling it.
  `_grant_applied()` and the outstanding-grant check. WallBuy, Reforger and
  MedDispenser return true from `accepts_requests()`.
  Bump `Build.PROTOCOL_VERSION` (core/build.gd).
  `WallBuy.owner_facts()` and `Reforger.owner_facts()`; their `interact()`
  reads `facts` (built from the local player when empty, so solo and old
  tests keep working) and grants instead of touching `player.weapons`.
  Server checks that fact ids exist and match. `MedDispenser`: `sales` in
  `net_state()`, `state_changed` after a sale, `retire()` instead of a bare
  `queue_free()` when `sales == max_sales`. The Serum itself already
  reaches the owner through the `PlayerStateSync` snapshot.
- Files: systems/net/interaction_sync.gd, systems/interactables/wall_buy.gd,
  reforger.gd, med_dispenser.gd, tests/unit/test_interaction_sync.gd
  (or tests/unit/test_coop_machines.gd if the first file nears 350 lines).
- Tests: two peers: a client buys a wall gun (points drop on the server, the
  gun appears only in the client's holder); buys ammo for a held gun at half
  cost and for a held Reforged gun at 4000; a full gun is not charged; a
  client Reforges the gun in hand (5000, upgraded data in hand) and refills a
  top-tier gun (2500); a client with forged facts (an id it does not match, or
  an unknown id) is rejected and not charged; a client buys a Serum from a
  powered dispenser, and a `max_sales = 1` dispenser vanishes on both peers
  and stays gone for a client that joins after the last sale; a client asks
  to Reforge gun A, switches to gun B before the grant arrives (delay the
  server reply in the test), and A is upgraded in its own slot while B is
  untouched; a refill grant for a gun the client no longer holds changes
  nothing; a client presses Reforge twice with the first grant still
  delayed, is charged 5000 once and gets one upgrade; a client holding two
  guns with the same base id Reforges the second and only the second is
  upgraded; a client with a full holder buys a wall gun, switches guns
  before the delayed grant arrives, and the gun that was in hand at the
  press is the one replaced.
  Existing `test_reforger.gd`, `test_med_dispenser.gd`,
  `test_kestrel_smg.gd`, `test_talon_dmr.gd` pass in solo.
- Done when: a co-op client can buy guns, ammo, Reforges and Serums, pays
  the same prices as solo, and nobody else's guns change.

### Step 3: Barriers, Specimen Vault and exfil

- Build: `Barrier.net_state()` with planks, `state_changed` from
  `_set_planks()`, clients play the tear or repair sound by the change.
  `SpecimenVault`: `owner_facts()` with held ids, `net_state()` with state,
  offer, buyer net id and spot path, `state_changed` from `_start_roll()`,
  the timer branches and `_close()`; clients set `global_transform` from the
  spot and run only the label `_process()`; taking the offer is a `GIVE`
  grant to the buyer; the refund when the Vault moves stays on the server.
  `ExfilHatch.net_state()` with open, holding, hold_left and counting;
  the server emits `state_changed` when any of open, holding or counting
  changes; on clients `apply_net_state()` sets the glow, resets `hold_left`,
  emits `Events.exfil_opened` / `Events.exfil_called` on the change, and a
  client-side countdown runs only while `counting` (visual, so in
  `_process()`; the server's hold stays in `_physics_process()`).
  All interactables are now networked, so delete `accepts_requests()` and
  its check (dead code). Bump `Build.PROTOCOL_VERSION` (core/build.gd).
- Files: systems/interactables/barrier.gd, specimen_vault.gd,
  exfil_hatch.gd, systems/net/interaction_sync.gd (only if needed),
  tests/unit/test_coop_world_state.gd (new).
- Tests: two peers: a client repairs a plank (server planks +1, points paid
  up to the round cap, client planks match); a server-side tear reaches the
  client; a client rolls the Vault (points taken), sees the offer on its
  copy, takes it and gets the gun; another client cannot take it; the move
  refund goes to the buyer; the Vault moves on both peers; exfil opens on
  round 10 on the server and the client sees open and gets `exfil_opened`; a
  client calls exfil and the hold runs on the server; the client's
  `hold_left` counts down while a player stands in the zone and stops when
  they step out (within 0.5 s of the server's value); a late joiner gets
  planks, Vault state and exfil state including the remaining hold time. Solo tests `test_barriers.gd`,
  `test_specimen_vault.gd`, `test_vault_guns.gd`, `test_exfil.gd` pass.
- Done when: every interactable works from a client and late joiners see the
  same map as everyone else.

### Step 4: Close out the foundation fix

- Build: docs only, plus nothing else unless the play-test finds a bug.
  `docs/MULTIPLAYER.md` "Who owns what" and build order: interactions done;
  `docs/FOUNDATIONS.md` foundation 1: the interaction part is fixed (item
  effects still shaky, #145); `docs/DECISIONS.md` short entry; close #138;
  tick #126's interactable lines; roadmap F-02 Done. Run the `finish-feature`
  skill. Two-instance check on the person's PC
  (`godot --path . -- --host` and `--join=127.0.0.1:7777`): client opens a
  door, buys a wall gun, rolls the Vault.
- Files: docs/MULTIPLAYER.md, docs/FOUNDATIONS.md, docs/DECISIONS.md,
  docs/ROADMAP.md, docs/plans/coop-interactions.md.
- Tests: none new (docs only); the full suite runs once.
- Done when: acceptance below is ticked and the plan is Done.

## Acceptance

- [x] A client opens a door and turns on power; both peers see it (step 1 test).
- [x] Every interactable has a two-peer test that runs it from a client (steps 1-3).
- [x] Clients pay the same prices as solo; forged or out-of-range requests are rejected and logged.
- [x] A late joiner sees open doors, power, planks, Vault and exfil state.
- [x] Everything works on a dedicated server with no local player.
- [x] All solo interactable tests pass unchanged.
- [x] Two-instance play-test: moved to follow-up issue #191 (the person chose to close F-02 first).

## Risks

- **Node paths differ between peers.** All interactables are placed in the
  map scene, so paths under `Level` match. The Vault moves but keeps its
  node. Step 1 tests path lookup first, so a bad idea fails cheap.
- **Server copy of a remote player lags.** The range check uses
  `REACH_SLACK`; a false reject only costs a second press and is logged, so a
  play-test shows if 2.0 m is too tight.
- **Guns live on the owner, prices on the server.** Owner facts keep the
  server from guessing what a client holds; the server still picks the price
  and next tier from its own data, so a forged fact can at worst buy ammo for
  a gun the client really holds. Fine for friends-only servers (ADR 0003).
- **Freed interactables.** Doors and sold-out dispensers are freed on the
  server, so they live on as paths in the level's `removed` list. Tested by
  the late-join cases in steps 1 and 2.
- **Grants racing the player's own actions.** Grants name the gun they are
  for (`from_id`), never the gun in hand. Tested by the switch-before-reply
  case in step 2.
- **Half-migrated builds.** Each step merges alone, so a type a client
  cannot use correctly yet is refused by `accepts_requests()` instead of
  taking points for nothing. Removed in step 3.
- **Big step sizes.** If step 1 passes 400 lines, split the snapshot and late
  join into its own PR before doors; the order of the rest does not change.

## Open decisions

- none
