# Plan: More power-ups in the drop deck

Status: Review
Roadmap: F-26 / issue #118
Phase: P3
Size: M
Approved by:
Lore link: docs/design/lore.md "Power-ups, points and buying from walls": Payday (Oriel bonus chit), Overkill (Cordon hot-round belt), Purge (Oriel pulse breaker), Scrap Kit (carpenter's repair kit), Stasis (Oriel cryo charge), Supply Crate (Oriel Vault key card). All rows exist (provisional picks); no new rows needed.

## Goal

The six missing power-ups from the game design drop from the shuffled deck,
so a drop is a real "what will it be?" moment and a lucky one can save a bad
round. Timed ones show an icon with a shrinking ring at the bottom centre of
the HUD. Serves "The pressure always builds": drops are the short breathers
inside rising rounds.

## Scope

In:

- Payday: double points for 30 s.
- Overkill: every bullet or melee hit kills for 30 s.
- Purge: kills every zombie alive now, +400 points.
- Scrap Kit: rebuilds every barricade, +200 points.
- Stasis: freezes every zombie alive now in place for 8 s.
- Supply Crate: rare (in 1 of 3 decks), a free Specimen Vault roll delivered
  on the spot.
- Timer icons with a shrinking ring, bottom centre of the HUD.
- Drop rate back to the design numbers (2.5% per kill, at most 4 a round)
  once the deck is full.
- Everything works in co-op and on a dedicated server, late joiners included.

Not in (non-goals, and where each one goes instead):

- Resupply refilling grenades: F-24 frag grenades adds it.
- Overkill on Brutes (20% of max health per hit): F-30 Brute adds an
  `EnemyData` field for it when the Brute exists.
- Night Shift trait (longer power-up timers): town NPC traits, later.
- Voice line and 0.4 s screen tint on pickup (game-feel.md), and the drop
  arpeggio loop (sound.md): F-04 audio follow-up / game feel pass. Pickups
  keep the current chime.
- Separate pickup models per power-up: they stay the glowing core, light and
  label, coloured per power-up (as Resupply and the ammo pack today).

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (solid: written pattern + rpc-rules CI from F-79), 2 Content
  ids (solid; no new id checks in code), 4 Events (solid), 7 Game tick and randomness (solid).
  Any of them shaky or missing? no.
- Decision records: 0003 trusted client, 0004 one code path, 0007 signals and events. Goes against one: no.
- Co-op:
  - Who decides: the server, for every effect, every timer and every point.
  - How a client triggers it: walking into the pickup (server Area3D, as today). Opening a Supply
    Crate is a normal interact request with facts (held guns, slot), checked like the Vault's.
  - What other players see: timers start on every peer by RPC (HUD rings); zombie Stasis is a synced
    flag on each zombie; Purge kills and Scrap Kit planks reach clients through the existing zombie
    and barrier sync; the crate spawns through the pickups' MultiplayerSpawner.
  - Works on a dedicated server with no local player: yes, effects run on the server; HUD skipped.
- Data: new Effect values and fields on PowerUpData; one .tres per power-up in content/power_ups/.
  Code compares against a specific id anywhere: no (effects switch on PowerUpData.effect).
- Save: no change.
- Events and UI: new Events.power_up_timer_started(power_up, seconds), emitted on every peer. No new
  screens; the timer row is part of the HUD.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes.
- Tests: unit tests per effect, deck test, two-peer tests from a client (coop_side.gd helper) for
  timers, Stasis and the crate; content check for the new fields.
- Logging: Log.warn power_ups.timer_ignored (timer RPC from a non-server sender) and
  power_ups.crate_expired_unopened (a crate timed out; tells us if players miss it).
- Performance: no per-frame allocations; timers are a small fixed Dictionary; Purge/Stasis loop the
  Spawner's live zombie array once.
- Lore link: see the Lore link line above.
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#power-up-drops: the drop table (Payday 30 s,
  Overkill 30 s, Purge +400, Scrap Kit +200, Stasis 8 s, Supply Crate 1 in 3
  decks), 2.5% chance per kill, max 4 a round, shuffled deck, 25 s float,
  5 s blink.
- docs/design/balance/prices.csv rows 37-45 (same table), settings.csv
  `pu_chance` 0.025 and `pu_max` 4.
- docs/design/ui-hud.md: "Bottom centre: power-up timers"; colour
  `experiment` #8DFF3A for power-ups.
- docs/design/look-rules.md: pickups visible from 30 m; Bio-green for the
  experiment; Sodium #FF9A42, Fluorescent #CDEEE8, Headshot gold #FFC845.
- docs/DECISIONS.md: "Power-ups: only Resupply and the Scavenger ammo pack"
  (removed by this plan) and "Power-up drops: 1% per kill, at most 1 a round
  ... raise with F-26" (removed in step 4).
- docs/plans/coop-round-state-power-ups.md: how pickups, effects and the
  "collected" message already work in co-op.
- docs/adr/0003-trusted-client-co-op.md: the server decides shared state;
  guns live on the owner's PC.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/power_ups/power_up_data.gd | changed | New Effect values; `duration`, `team_points`, `deck_chance` fields |
| content/power_ups/*.tres | new | payday, overkill, purge, scrap_kit, stasis, supply_crate |
| systems/power_ups/power_up_drops.gd | changed | Server effects run here; timers (tick, RPC, late-join request); deck honours `deck_chance`; drops only from player kills |
| systems/power_ups/power_up_effects.gd | new | One static function per server-side effect (Purge, Scrap Kit, Stasis start/end, crate spawn), so power_up_drops.gd stays small |
| systems/economy/economy.gd | changed | Payday doubles hit and kill points (`PAYDAY_MULTIPLIER = 2`) |
| systems/net/hit_claims.gd | changed | Overkill: `apply_server_hit` raises the hit to the zombie's remaining health |
| systems/enemies/zombie.gd | changed | New synced `stasis` flag: stands still, no attacks, ice look (reuses `Frost.show_frozen`) |
| systems/net/zombie_sync.gd | changed | Syncs `stasis` |
| systems/interactables/specimen_vault.gd | changed | `needs_power`, `single_use` exports so a crate can be a one-roll, free, unpowered Vault |
| systems/power_ups/supply_crate.tscn | new | Crate scene: SpecimenVault script, cost 0, single use, grey-box crate with bio-green glow |
| systems/net/interaction_sync.gd | changed | `watch(target)` so an interactable spawned mid-match sends its state |
| systems/ui/power_up_timers.gd | new | Bottom-centre row: one icon per running timer, ring drawn with `draw_arc` |
| systems/ui/hud.gd, hud.tscn | changed | Holds the timer row; connects `power_up_timer_started` |
| core/events.gd | changed | `power_up_timer_started(power_up: PowerUpData, seconds: float)` |
| core/build.gd | changed | PROTOCOL_VERSION +1 in each step that adds or changes RPCs or synced properties |
| systems/game/game_session.tscn | changed | Deck lists the new .tres; step 4 sets drop_chance 0.025, max_per_round 4 |
| docs/DECISIONS.md, docs/LOGGING.md, docs/ROADMAP.md | changed | Provisional picks, warnings, status |

Autoloads, managers or base classes added: none. `power_up_effects.gd` is a
file of static functions (no node, no state), split out by job so
`power_up_drops.gd` stays under the size limit. The timer row is a plain
Control owned by the HUD.

Files over 300 lines this plan grows: `systems/ui/hud.gd` (321). The timer row
is its own script (`power_up_timers.gd`); hud.gd only gains a node reference
and one connect, so it stays under 350.

## Data

- `PowerUpData.Effect` gains `PAYDAY, OVERKILL, PURGE, SCRAP_KIT, STASIS,
  SUPPLY_CRATE`, appended after `AMMO_PACK` so saved `.tres` ints stay valid.
- `PowerUpData.duration: float = 0.0`: seconds a timed power-up lasts; 0 =
  instant. Payday 30, Overkill 30, Stasis 8. Read by PowerUpDrops and the HUD.
- `PowerUpData.team_points: int = 0`: points every player gets on pickup.
  Purge 400, Scrap Kit 200.
- `PowerUpData.deck_chance: float = 1.0`: chance this power-up is in each new
  deck. Supply Crate 0.333. Read by `PowerUpDrops._next()`.
- Colours (provisional, from look-rules): Payday #FFC845 (headshot gold),
  Overkill #C3201B (blood/alarm), Purge #8DFF3A (bio-green), Scrap Kit
  #FF9A42 (sodium), Stasis #CDEEE8 (fluorescent), Supply Crate #3FE0C8.
- `Zombie.stasis: bool = false`, synced by ZombieSync.
- `SpecimenVault.needs_power: bool = true`, `single_use: bool = false`.
- Network messages:
  - `PowerUpDrops._receive_timer(data_id: StringName, seconds: float)`
    authority to all.
  - `PowerUpDrops._request_timers()` any peer to server; the server answers
    with one `_receive_timer` per running timer.
  - Crates: the pickups' MultiplayerSpawner gets a kind in its spawn data
    (`[id, data_id, position, kind]`), so the same spawner makes pickups and
    crates on every peer and late joiner.
- Save format change: none.
- Content checks to add in `tests/content/`: every power-up has
  `duration >= 0`, `team_points >= 0`, `deck_chance` in (0, 1], a unique
  colour, and a timed effect (Payday, Overkill, Stasis) has `duration > 0`.

## Co-op behaviour

- Who owns the state: the server owns every timer, every zombie's `stasis`,
  barrier planks, points and the crate's roll. Owning client: only its own
  guns (the crate's gun arrives as a normal GIVE grant).
- What clients send, what the server sends back: clients send one timer
  request on connect and a normal interact request to open or take a crate.
  The server sends timers to all, syncs `stasis` and deaths through
  ZombieSync, planks through barrier `net_state()`, points through Economy's
  existing points sync, and the gun grant to the crate's opener.
- What a client sees that the host sees too: pickups, the flash name, timer
  rings, frozen zombies, Purge deaths, rebuilt planks, the crate and its
  rolling name. Only the opener can take the crate's gun.
- Late joiner: running timers (request on connect), `stasis` on each zombie
  (synced property), planks (InteractionSync snapshot), live pickups and
  crates (MultiplayerSpawner).
- Dedicated server: no HUD; effects, timers and RPCs still run. No local
  player, so team points loop over `session.get_players()`.

## Performance

Timers: a Dictionary of at most 3 entries ticked once per physics frame on
the server; clients only count down for the HUD in `_process`. Payday and
Overkill are one Dictionary lookup per hit. Purge and Stasis loop the
Spawner's live zombie array once (24 zombies). The timer row redraws only
while a timer runs and reuses its icon nodes. No new per-frame allocations.

## Steps

### Step 1: Timers, Payday and the HUD ring

- Build: Effect values and the three new fields; `payday.tres`. Server timer
  table in PowerUpDrops (`start_timer`, `is_active(effect)`, tick in
  `_physics_process`, re-pickup resets to full time), `_receive_timer` and
  `_request_timers`, `Events.power_up_timer_started`. Economy doubles hit and
  kill points while Payday runs. Drops only roll for kills by a player.
  `power_up_timers.gd` timer row in the HUD (coloured disc, short label,
  shrinking `draw_arc` ring, last 5 s blink). Protocol +1.
- Files: power_up_data.gd, power_up_drops.gd, economy.gd, core/events.gd,
  core/build.gd, systems/ui/power_up_timers.gd (new), hud.gd, hud.tscn,
  content/power_ups/payday.tres, game_session.tscn, docs/DECISIONS.md,
  docs/LOGGING.md.
- Tests: tests/unit/test_power_up_timers.gd (timer starts, counts down,
  ends, re-pickup resets; Payday doubles hit and kill points and stops after
  30 s); tests/unit/test_coop_power_ups.gd (a client gets the timer, a late
  joiner gets the time left); content check for the new fields.
- Done when: a Payday pickup doubles points for 30 s for every player, and a
  ring shows on every peer.

### Step 2: Overkill and Stasis

- Build: `overkill.tres`, `stasis.tres`. `HitClaims.apply_server_hit` raises
  the hit to the zombie's remaining health while Overkill runs (after claim
  checks, so the claim limits still hold). `Zombie.stasis` (synced): no
  movement, no attack, no plank tearing, ice look through
  `Frost.show_frozen`; hits on a Stasis zombie do normal damage (no Cryo
  shatter). `PowerUpEffects.set_stasis(spawner, on)` at timer start and end.
  Protocol +1.
- Files: overkill.tres, stasis.tres, power_up_effects.gd (new),
  power_up_drops.gd, hit_claims.gd, zombie.gd, zombie_sync.gd, frost.gd if
  needed, core/build.gd, game_session.tscn, docs/DECISIONS.md.
- Tests: tests/unit/test_power_up_effects.gd (Overkill: one body shot kills
  at round 20 health, ends after 30 s; Stasis: zombie does not move or
  attack for 8 s, then moves again; a hit on a Stasis zombie does not
  shatter); tests/unit/test_coop_power_ups.gd (a client sees `stasis`; a
  client's hit claim kills under Overkill).
- Done when: both work from host and client, and a Stasis zombie cannot
  hurt anyone.

### Step 3: Purge and Scrap Kit

- Build: `purge.tres`, `scrap_kit.tres`. Purge kills every live zombie with
  a server DamageInfo whose attacker is null (no kill points or XP, round
  progress counts, no power-up rolls), then pays `team_points` to every
  player. Scrap Kit sets every node in the `barriers` group to full planks
  (`Barrier.rebuild()`), then pays `team_points`.
- Files: purge.tres, scrap_kit.tres, power_up_effects.gd, power_up_drops.gd,
  barrier.gd, game_session.tscn, docs/DECISIONS.md.
- Tests: tests/unit/test_power_up_effects.gd (Purge kills all alive, no kill
  points, +400 each player, round can still end; Scrap Kit: broken barriers
  full, +200 each player); tests/integration/test_power_ups.gd (Purge
  mid-round in a real GameSession, round ends when the rest are killed).
- Done when: both work in solo and co-op, and a Purge never stalls a round.

### Step 4: Supply Crate, design drop rate, close-out

- Build: `supply_crate.tres` (`deck_chance` 0.333). `_next()` builds each
  deck from power-ups that pass their `deck_chance` roll. Picking up a crate
  drop spawns `supply_crate.tscn` (SpecimenVault with `cost` 0,
  `needs_power` false, `single_use` true) at the spot through the pickups'
  spawner; anyone may open it (free roll, 2.5 s), only the opener takes the
  gun (10 s), then it is removed; unopened it vanishes after 25 s.
  `InteractionSync.watch()` for runtime interactables. Drop rate to 2.5% and
  4 a round. Protocol +1. Run the finish-feature skill; close #118.
- Files: supply_crate.tres, supply_crate.tscn (new), specimen_vault.gd,
  interaction_sync.gd, power_up_drops.gd, power_up_effects.gd,
  core/build.gd, game_session.tscn, docs/DECISIONS.md, docs/ROADMAP.md,
  this plan.
- Tests: tests/unit/test_power_up_drops.gd (deck: no repeats before every
  type came out; Supply Crate in about 1 of 3 decks over 300 seeded decks);
  tests/unit/test_coop_power_ups.gd (a client opens and takes a crate gun; a
  second client cannot take it; a late joiner sees the crate); soak stays
  green at the new drop rate.
- Done when: all seven power-ups drop in a full Halcyon Labs run and soak
  passes.

## Acceptance

- [ ] Each power-up is a PowerUpData file; its effect is a small function (test per effect).
- [ ] Timed ones show an icon with a shrinking ring, bottom centre (HUD test + play-test).
- [ ] Deck test: no repeats before every type came out; Supply Crate in about 1 of 3 decks.
- [ ] Every effect works from a co-op client and for a late joiner (two-peer tests).
- [ ] Drop rate is 2.5% per kill, max 4 a round; soak rounds 1-10 pass.

## Risks

- Overkill and Cryo/Shock both hook `apply_server_hit`; order matters. Step 2
  tests a Cryo gun under Overkill so the shatter path cannot double-kill.
- Reusing SpecimenVault for the crate could drag in power and moving rules.
  Step 4 keeps both behind exports defaulting to today's behaviour, and the
  Vault's existing tests must stay green. If it grows past 30 lines of
  changes, copy the roll into a small crate script instead (second use, rule 2).
- More drops (2.5% x4) could swing soak balance. Step 4 runs the soak and
  records the result; balance follow-ups go to F-33.

## Open decisions

- none (all picks below are reversible and go in docs/DECISIONS.md as
  provisional: timers are team-wide and reset on re-pickup; Payday doubles
  hit and kill points only; Purge kills give no kill points or XP;
  team_points go to every player; Stasis freezes only zombies alive at
  pickup and hits on them do not shatter; anyone may open a crate, only the
  opener takes the gun; colours as listed in Data)
