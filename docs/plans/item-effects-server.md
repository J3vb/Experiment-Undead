# Plan: Item effects run on the server

Status: Review
Roadmap: F-00 foundation fix 3 / issues #145, #147
Phase: P7
Size: M
Approved by:

## Goal

Gear and item guns work the same for every player in co-op as in solo:
a client's vest raises its health, its loot luck counts, and its leech and
points-per-hit guns heal and pay. Today they only work for the host (#145).
Serves "Every run makes you stronger": loot that does nothing for half the
squad breaks the reason to play.

## Scope

In:

- The owner tells the server what it has equipped (gear and item guns); the
  server applies the gear to its copy of the player.
- On-hit item effects (`points_per_hit`, `leech`) run where the server applies
  the hit, for host, solo and clients alike.
- Hit claims for item guns are checked against the item gun's real numbers.
- One public equip function in `ItemLoadout`; equipping from the Pack runs in
  a physics tick, not in the overlay's key handler (#147).
- Delete the separate loot luck RPC once the server knows the gear.

Not in (non-goals, and where each one goes instead):

- Pack overlay reading raw keys (#146): foundation fix 6, Rebind controls (F-05).
- Regen in `_process` (#144): foundation fix 6.
- Trait and Legendary on-hit effects: Legendaries and traits (F-31, #116),
  which will reuse the server hit hook built here.
- Set bonuses: Item sets (F-32, #117).
- Showing other players' item guns in third person: Gear in first person and
  later visuals (F-42).
- Checking that a client really owns the items it sends: never in v1 (trusted
  client, friends-only servers, ADR 0003).

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky: this is its item part), 2 Content ids (no new literals),
  3 Save format (read only), 6 Input (Pack equip moves into a tick; raw keys stay until fix 6).
  Any of them shaky or missing? 1 is what this fixes. 6's raw-key leak is out of scope and not made worse.
- Decision records: 0003 trusted client, 0004 one code path, 0005 saves, 0010 personal loot. Goes against one: no.
- Co-op:
  - Who decides: owning client picks what it equips (trusted); server owns health, points and luck from it.
  - How a client triggers it: PlayerStateSync.submit_loadout RPC with gear dicts and item-gun dicts on spawn and
    on every equip; server sanitises through ItemInstance and applies.
  - What other players see: health and points through the existing PlayerStateSync snapshot. Nothing new.
  - Dedicated server with no local player: yes, the server only applies remote loadouts.
- Data: no new ids or numbers; affix values come from the item dicts and content/loot. Code compares a specific id: no.
- Save: no change. Items are read, never written, by this work.
- Events and UI: no new Events. Uses Events.enemy_damaged, emitted on the server where the hit is applied.
  New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes after step 3.
- Tests: two-peer tests for loadout, luck, leech, points per hit, claim bounds; Pack equip in the tick.
- Logging: Log.warn loadout_rejected (peer, reason) for malformed or oversized loadouts.
- Performance: one reliable RPC per equip; the hit hook is one dictionary lookup per server hit.
- Out of scope: see Not in above.
```

## Design references

- docs/FOUNDATIONS.md#1-co-op-authority and fix 3: "item effects run where
  the server applies the hit; one public equip function in `ItemLoadout`,
  called from the player's tick".
- docs/MULTIPLAYER.md "Who owns what": health and points are server owned;
  saves and items stay on the player's PC.
- docs/adr/0003-trusted-client-co-op.md, 0004-one-code-path.md,
  0010-personal-loot-kept-on-death.md.
- docs/design/affixes.md: what `leech` and `points_per_hit` do (values come
  from the rolled items, nothing new here).
- docs/DECISIONS.md: weapon loot roller, gear loot, co-op step 5 (luck is
  sent by the client today).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/net/player_state_sync.gd | changed | `submit_loadout` RPC (owner -> server), server applies gear and stores item guns; server hit hook on `Events.enemy_damaged` |
| systems/player/player.gd | changed | `item_guns: Dictionary[String, ItemInstance]` (uid -> item), filled on the server |
| systems/loot/item_loadout.gd | changed | Public `equip_weapon(player, item, carried)`, `apply_hit(player, item)`; `apply()` uses them; no more `hit_landed` binding |
| systems/loot/pack_overlay.gd | changed | `_equip()` only asks `LootService.request_equip(uid)`; ammo carry map moves out |
| systems/loot/loot_service.gd | changed | Runs queued equips in `_physics_process()`; owns the run ammo carry map; luck RPC deleted, server reads luck from its own copy |
| systems/damage/damage_info.gd | changed | `item_uid: String` field |
| systems/weapons/weapon.gd | changed | Sets `info.item_uid` from `item` when it builds a hit |
| systems/net/hit_claims.gd | changed | `claim_hit` carries `item_uid`; bounds use the item gun's data when the server knows it |
| systems/game/game_session.gd | changed | Owner sends its loadout after `ItemLoadout.apply()` |
| docs/FOUNDATIONS.md, docs/DECISIONS.md, docs/MULTIPLAYER.md | changed | Last step: foundation 1 item part fixed |

Autoloads, managers or base classes added: none. The work goes into the
nodes that already own the data: `PlayerStateSync` (server-side player
state), `LootService` (Pack and run state), `ItemLoadout` (item wiring).

## Data

- New field `DamageInfo.item_uid: String = ""`. Read by the server hit hook
  and `HitClaims`.
- New field `Player.item_guns: Dictionary[String, ItemInstance] = {}`. Server
  side: the owner's equipped item guns. On the owner it mirrors what it holds.
- Network messages:
  - `PlayerStateSync.submit_loadout(gear: Array, guns: Array)` owner ->
    server, reliable. `gear` is up to 3 item dicts (vest, charm, implant),
    `guns` up to `weapon_slots` item dicts. Sent on spawn and after every
    equip. Server rebuilds from scratch each time (no deltas). Rejected and
    logged when not an Array of Dictionaries, too many entries, or a gun base
    that is not in `Content` weapons. Unknown affix ids are already skipped by
    `ItemInstance._affix()`.
  - `HitClaims.claim_hit(..., item_uid: String = "")`: one new last
    argument.
  - `LootService._receive_luck` RPC: deleted.
  - Protocol: steps 1 and 2 each change the RPC contract, so each bumps
    `Build.PROTOCOL_VERSION` in `core/build.gd` by one. The handshake then
    refuses an older build before any player spawns (existing
    `tests/unit/test_handshake.gd` and `tests/integration/test_net_match.gd`
    cover the refusal; each step adds an assert on the new number).
- Save format change: none.
- Content checks to add in `tests/content/`: none.

## Co-op behaviour

- Who owns the state: the owning client owns what is equipped (it holds the
  save). The server owns the effects: max health and regen from gear, loot
  luck, healing from leech, points from points-per-hit.
- What clients send, what the server sends back: client sends
  `submit_loadout`. The server calls `player.equip_gear(gear)` (server path:
  `_refresh_stats()` then the health snapshot goes out as today) and fills
  `player.item_guns`. Client hits carry `item_uid`; the server's hit hook
  pays and heals; points and health reach the owner through the existing
  snapshot.
- What others see: the player's health and points, as today.
- Late joiner: nothing extra; each player sends its own loadout when its
  player spawns, and the server keeps it for the match.
- Dedicated server: no local player, so it only applies remote loadouts and
  hits. The owner-only `ItemLoadout.apply()` path does not run there.
- Disconnect: the player node is freed with its `item_guns`; nothing to
  clean up.

## Performance

One reliable RPC per equip (a few per run). The server hit hook runs once
per applied hit: one `attacker == player` check and one dictionary lookup.
No per-frame work. Budget: no measurable cost.

## Steps

### Step 1: Server knows the owner's equipment

- Build: `PlayerStateSync.submit_loadout` RPC with the checks above;
  `send_loadout()` on the owner (direct call on the server's own player).
  The server applies gear with `equip_gear()` and fills `Player.item_guns`
  from the gun dicts. `GameSession._on_player_added()` sends the loadout after
  `ItemLoadout.apply()`. `LootService` reads luck from the server's copy with
  `player_luck()`; delete `_sync_luck`, `_receive_luck`, `_peer_luck`,
  `_last_luck`. Bump `Build.PROTOCOL_VERSION`.
- Files: core/build.gd, systems/net/player_state_sync.gd, systems/player/player.gd,
  systems/game/game_session.gd, systems/loot/loot_service.gd,
  tests/unit/test_gear_health_sync.gd, tests/unit/test_loot_service.gd.
- Tests: two peers (pattern: `test_gear_health_sync.gd`): a client's
  loadout with a +40 max health vest raises the server's max health to 140
  and the owner sees 140 through the snapshot; a loot-luck charm counts on the
  server roll; a malformed loadout (not dicts, 4 gear entries, unknown gun
  base) is rejected, logged and changes nothing; sending a new loadout without
  the vest drops max health back to 100.
- Done when: client gear changes server-side stats in co-op, and the luck RPC
  is gone.

### Step 2: Item hit effects on the server

- Build: `DamageInfo.item_uid`; `Weapon` sets it from `item`;
  `HitClaims.submit_hit()` sends it and `claim_hit()` puts it on the
  server's `DamageInfo` only when `player.item_guns` has that uid.
  `_valid_hit()` uses `item.weapon_data(base, player.stats)` for that uid
  instead of the plain content gun. `PlayerStateSync` on the server connects
  `Events.enemy_damaged` and calls `ItemLoadout.apply_hit(player, item)` when
  `info.attacker` is its player and the uid is known. Pack guns must keep
  working in this step: `PackOverlay._equip()` adds the gun to
  `player.item_guns` and calls `send_loadout()` right where it binds the hook
  today (step 3 moves that call into the tick), and `ItemLoadout.apply()`
  adds the sidearm to `player.item_guns`. Only then delete the
  `hit_landed` binding and `_on_hit` from `ItemLoadout.apply()` and
  `PackOverlay._equip()`. Effects that replace the primary hit keep the
  uid: `Frost._shatter()` builds the primary damage through
  `Frost._damage()`, which copies `weapon_id` today and must copy
  `item_uid` too, but only for the primary hit, never for collateral
  shatter or `Chain` damage, so one shot pays and heals once, as it does
  today through `hit_landed`. Bump `Build.PROTOCOL_VERSION`.
- Files: core/build.gd, systems/damage/damage_info.gd, systems/weapons/weapon.gd,
  systems/weapons/effects/frost.gd,
  systems/net/hit_claims.gd, systems/net/player_state_sync.gd,
  systems/loot/item_loadout.gd, systems/loot/pack_overlay.gd,
  tests/unit/test_hit_claims.gd, tests/unit/test_item_effects_coop.gd (new).
- Tests: two peers: a client hit with a leech item gun heals the server's
  copy and the owner sees it; a points-per-hit gun pays the client on the
  server; a hit with an unknown uid pays only the normal hit points; a claim
  that fits the item gun's damage but not the plain gun is accepted; solo and
  host still get leech and points (`test_item_loadout.gd` or a new solo case);
  a leech gun equipped from the Pack heals in solo and for a client (so the
  step does not break Pack guns before step 3); a leech item gun that
  shatters a frozen zombie heals once, and the collateral targets add
  nothing.
- Done when: leech and points-per-hit work for host, solo and clients
  through one server path.

### Step 3: One equip function, run from the tick

- Build: `ItemLoadout.equip_weapon(player, item, carried: WeaponInstance)`
  gives the gun, sets `weapon.item`, carries ammo and records it in
  `player.item_guns`; `apply()` uses it for the sidearm. `PackOverlay._equip()`
  calls `service.request_equip(uid)` and does nothing else. `LootService`
  keeps the queued uid and the run ammo carry map (moved from
  `PackOverlay._run_weapons`) and runs `equip_weapon()` in
  `_physics_process()`, then `send_loadout()`. Update foundation 1 and
  foundation 6 text in docs/FOUNDATIONS.md, a docs/DECISIONS.md entry, close
  #145 and #147, and set this plan to Done (run `finish-feature`).
- Files: systems/loot/item_loadout.gd, systems/loot/pack_overlay.gd,
  systems/loot/loot_service.gd, tests/unit/test_pack_overlay.gd (or the
  existing Pack test file), tests/unit/test_item_effects_coop.gd,
  docs/FOUNDATIONS.md, docs/DECISIONS.md, docs/MULTIPLAYER.md,
  docs/plans/item-effects-server.md.
- Tests: pressing equip in the overlay does not change the player's guns
  until the next physics tick; equipping the same Pack gun twice re-selects
  it; ammo carries over after drop and re-equip; in two peers a client equips
  a leech gun from the Pack and its hits heal on the server.
- Done when: no gameplay runs in the overlay's key handler and every Pack
  equip reaches the server.

## Acceptance

- [ ] A client's gear raises its server-side max health and loot luck (step 1 test).
- [ ] Leech and points-per-hit work for clients, host and solo through one path (step 2 tests).
- [ ] Item-gun hit claims are bounded by the item gun's numbers (step 2 test).
- [ ] Pack equips run in a physics tick and reach the server (step 3 tests).
- [ ] `LootService` has no luck RPC; `PackOverlay` has no gameplay code.
- [ ] Foundation 1 in docs/FOUNDATIONS.md no longer lists #145 / #147.

## Risks

- **Trusted loadouts.** A modified client could send any item. Accepted for
  friends-only servers (ADR 0003); the size and base checks stop crashes, not
  cheats. A stricter check comes with public servers, if ever.
- **Gear applied twice on the host.** The host's own player gets gear through
  `ItemLoadout.apply()` on the server already; `send_loadout()` on the
  server's own player must not double-apply. Step 1 tests the host case.
- **Claim bounds change.** Using item numbers may reject claims that pass
  today if `weapon_data()` differs from the gun the client fires. Step 2
  tests an affixed gun end to end so a mismatch shows early.
- **Step 3 touches the Pack while fix 6 (#146) will move it.** This step
  keeps the overlay where it is and only removes gameplay from it, so fix 6
  stays a move plus input actions.

## Open decisions

- none
