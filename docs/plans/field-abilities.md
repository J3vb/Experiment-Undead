# Plan: Field abilities

Status: Building
Roadmap: F-22 / issue #114
Phase: P5
Size: L
Approved by: the person (decision card "Approve all five abilities", 2026-11-20); plan review on PR #467 by a fresh Claude review (Codex out of quota): 2 blocking and 9 suggestions, all fixed
Lore link: Salvager kit built from Oriel scrap (docs/design/lore.md#story-links-for-game-content, row "Field abilities"; the turret's new name Watchdog and the siren canister are added there, provisional, by this plan)

## Goal

One active field ability on a key, on a cooldown, that you bring into a run:
Shock Pulse, Med Burst, Watchdog (the design's Sentry turret), Adrenal Rush
and Decoy Siren, unlocked by level, shortened by kills and by the Gadgeteer
skill, working the same in solo and co-op. Pillar: every run makes you
stronger (issue #114).

## Scope

In:

- `AbilityData` resources in `content/abilities/`, one per ability, with the
  design's unlock level, cooldown and effect numbers.
- One ability per player per run: the one picked under the Research tree
  (step 7), else the highest ability your level has unlocked (provisional).
  Levels 1 and 2 have none.
- `field_ability` input action on **X** and D-pad down, a new `InputFrame` bit,
  a row on the controls screen.
- Cooldown: design cooldown x (1 - reduction), reduction from the
  `ability_cooldown` stat (Gadgeteer, Implant affix) capped at 40%; every kill
  by the user takes 0.5 s off.
- Server owns the cooldown and every effect. A client asks; the server checks,
  runs the effect and tells everyone to show it.
- The five effects, the HUD ability icon with a cooldown sweep, sounds, a
  pulse ring, and Tripo models for the Watchdog turret and the siren canister.
- Fix the cap key: `stat_caps.tres` has `ability_cooldown_reduction`, but the
  stat is `ability_cooldown`, so the 40% cap never applies today.

Not in (non-goals, and where each one goes instead):

- The `ability_power` Implant affix, Overclock, Conductor, Fenlight Circuit
  and other legendary or set ability rules (F-31, F-32). The stat stays in
  the stack; DECISIONS line.
- Showing the picked ability on the Loadout screen (with the Loadout tabs,
  F-88; the pick is in the save from step 7).
- Brute and boss resistance to stun and lure (F-30 Brute plan).
- Abilities in the Lantern Post hub: none, the same rule as grenades.
- Sending live turrets and sirens to a late joiner: they last at most 20 s
  (DECISIONS line).
- Balance pass on the provisional numbers (F-23 levelling pace check).

## Ready to build

```
### Ready to build
- Foundations touched: 1 co-op authority, 2 content in data, 4 events,
  5 UI (HUD only), 6 input, 7 tick and randomness, 8 logging, 9 tests,
  10 dedicated server, 11 assets (Tripo, ADR 0017), 12 performance. All
  solid. Needs F-20: Done.
- Decision records: 0002 content as resources, 0003 trusted client,
  0004 one code path, 0007 signals and events, 0011 UI router (no new
  screen), 0017 Tripo models. Goes against none.
- Co-op:
  - Who decides: server: cooldown, every effect (stun, push, heal, buff,
    lure, turret shots and damage). Owner: the key press, the aim point it
    sends, its own HUD countdown between snapshots.
  - How a client triggers it: `AbilityClaims.request_use(player, aim)`;
    the server checks alive, not downed, not in the hub, ability known,
    cooldown done (0.25 s slack), level from the handshake reaches the unlock,
    aim point within reach of the eyes, not twice in 0.5 s.
  - What other players see: `show_use` (reliable, one per use) plays the
    ring, sound, turret or siren on every peer; turret shots relay unreliable
    like RemoteShots; zombie movement already syncs through ZombieSync.
  - Works on a dedicated server with no local player: yes (no sound, no HUD).
- Data: ids and numbers in content/abilities/*.tres; provisional numbers
  listed below go in DECISIONS. Code compares against a specific id: no
  (code switches on `AbilityData.Effect`, like `PowerUpData.Effect`).
- Save: changes what is saved? step 7 adds `field_ability` (String, default
  "", meaning the highest unlocked); version bump, migration and old-sample
  test as ADR 0005 asks.
- Events and UI: no new Events. HUD only, no new screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (no randomness needed).
- Tests: unit per ability and for the cooldown; content checks for every
  AbilityData; co-op tests where a client uses each server effect.
- Logging: refusals go through `HitClaims.reject` (`hit_claim_rejected`
  with `ability_*` reasons, at most once a second);
  `Log.warn(&"net", &"ability_unknown")` when a loadout names a missing or
  locked ability. Catalogue lines in docs/LOGGING.md (step 1).
- Performance: no per-frame allocations; the turret scans every 0.2 s from
  the Spawner's array; stun and lure are two floats per zombie.
- Lore link: above.
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#field-abilities: the five abilities, unlock
  levels 3, 8, 15, 22, 30, cooldowns 60, 75, 120, 90, 90 s, effects; one
  ability on a key; each kill -0.5 s; pick one per run.
- docs/design/game-design.md#skill-tree: Gadgeteer -8% cooldown per rank (3).
- docs/design/affixes.md: Ability cooldown Implant suffix 5-15%, cap
  "Ability cooldown reduction 40%"; Ability power (not in).
- docs/design/balance/xp_and_levels.csv: "Ability unlocked" column (same
  levels).
- docs/design/controls.md: field ability F / D-pad down. F is interact in
  the game (and in game-design.md and ui-hud.md), so this plan moves the
  ability to X and fixes controls.md.
- docs/design/ui-hud.md: "Field ability icon ... come with their features"
  (vitals panel, bottom left); P5 row "field ability icon".
- docs/design/lore.md: "Field abilities" row; open-question list names the
  Sentry clash with the Sentry burst rifle.
- docs/DECISIONS.md: "Skills waiting on their feature" (Gadgeteer),
  "Skill tree", "Co-op hit bounds".
- docs/MULTIPLAYER.md "Writing co-op code" patterns 2, 5, 6; reference
  `GrenadeClaims`.
- docs/adr/0003, 0004, 0017.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/abilities/ability_data.gd | new | `AbilityData` Resource |
| systems/abilities/field_ability.gd | new | Per-player node: ability, cooldown, press, kill credit, timed buff |
| systems/abilities/ability_effects.gd | new | One static function per effect (server), like `PowerUpEffects` |
| systems/abilities/ability_claims.gd | new | Session node: request, check, run, `show_use` relay |
| systems/abilities/watchdog.gd + .tscn | new | Turret: targets heads, server damage, relayed shots |
| systems/abilities/decoy_siren.gd + .tscn | new | Siren canister: lure point, sound, lifetime |
| systems/abilities/pulse_ring.gd | new | Cosmetic ring for Shock Pulse and Med Burst |
| content/abilities/*.tres | new | Five abilities |
| content/loot/stat_caps.tres | changed | `ability_cooldown_reduction` 0.4 becomes `ability_cooldown` 1.4 |
| systems/input/input_frame.gd, local_input.gd | changed | `FIELD_ABILITY` press bit |
| project.godot | changed | `field_ability` action (X, D-pad down), one block |
| systems/ui/key_bindings.gd | changed | Controls row |
| systems/player/player.gd | changed | `abilities` node, tick line, buff multiplier in `get_stat`; stamina moves out |
| systems/player/player_moves.gd | changed | `tick_stamina(player, delta)` moved in from player.gd |
| systems/enemies/zombie.gd | changed | `stun(seconds, push)`, `lure(point, seconds)` |
| systems/net/loadout_sync.gd | changed | sends and checks the ability id |
| systems/net/player_state_sync.gd | changed | `ability_cooldown` in the snapshot |
| systems/game/game_session.gd | changed | picks the profile player's ability, adds `AbilityClaims` |
| core/build.gd | changed | `PROTOCOL_VERSION` +1 in steps 2, 4, 5 and 6 |
| systems/ui/hud/ability_icon.gd | new | Icon, key, cooldown sweep, ready flash |
| systems/ui/hud.gd | changed | adds the icon (hook only, as the issue asks) |
| assets/ui/hud/ability_*.svg, assets/audio/ability_*.wav | new | Icons, generated sounds |
| assets/models/abilities/ | new | Tripo turret and canister |
| Research screen (F-21), systems/progression/character_profile.gd, systems/save/save_file.gd | changed | Step 7: ability picker and the saved pick |

Autoloads, managers or base classes added: none. `AbilityClaims` owns the
server's rate limit and the relay, the same job `GrenadeClaims` has for
grenades (Keep it simple 6). No ability base class: five effects are five
static functions switched on an enum (Keep it simple 3, 7).

Files over 300 lines this plan grows: `systems/player/player.gd` (350, at the
limit) and `systems/enemies/zombie.gd` (308). Step 1 moves `_tick_stamina`
(16 lines) into `PlayerMoves` first; player.gd then gains 4 lines over the
plan. zombie.gd gains about 25 lines (two timers, two functions, one check in
`_tick_chasing`), staying under 340.

## Data

`AbilityData` (Resource, `systems/abilities/ability_data.gd`):

| Field | Type | Default | Read by |
|---|---|---|---|
| id | StringName | &"" | Content, LoadoutSync |
| display_name | String | "" | HUD tooltip, key row |
| description | String | "" | picker (step 7) |
| unlock_level | int | 1 | `FieldAbility.pick_for_level` |
| cooldown | float | 60.0 | FieldAbility |
| effect | enum Effect { SHOCK_PULSE, MED_BURST, WATCHDOG, ADRENAL_RUSH, DECOY_SIREN } | SHOCK_PULSE | AbilityEffects |
| radius | float | 0.0 | pulse, heal, lure |
| duration | float | 0.0 | stun, turret, buff, lure |
| amount | float | 0.0 | heal (teammates), buff (+fraction), turret share of max health per shot |
| icon | Texture2D | null | HUD (kept out of the content fingerprint, as for Serums) |
| sound | AudioStream | null | everyone, on use |

Files and numbers (design numbers unless marked provisional):

| File | Unlock | Cooldown | radius | duration | amount |
|---|---|---|---|---|---|
| shock_pulse.tres | 3 | 60 | 6 m | 2 s stun | push 6 m/s (provisional) |
| med_burst.tres | 8 | 75 | 10 m (provisional) | - | 50 teammate heal; self to full |
| watchdog.tres | 15 | 120 | 25 m range (provisional) | 20 s | 0.4 of max health per head shot, one shot every 0.6 s (provisional) |
| adrenal_rush.tres | 22 | 90 | - | 8 s | 0.3 (move speed and fire rate) |
| decoy_siren.tres | 30 | 90 | 20 m | 6 s | placed up to 20 m along the aim (provisional) |

- Fixed rules as constants next to their code (Keep it simple 10): 0.5 s per
  kill, 40% cap (the cap file), 0.6 s turret shot gap.
- `stat_caps.tres`: key `ability_cooldown` with 1.4 (the stack result with
  base 1.0, like `reload_pct` 1.6). Cooldown = `cooldown * (2.0 -
  get_stat(&"ability_cooldown"))`, the shape `damage_reduction` uses.
- Adrenal Rush acts in `Player.get_stat` **outside** `ItemInstance.stat_value`
  (Serum multipliers sit inside it, before the cap): `move_speed` x1.3 and
  `fire_interval` / 1.3 (guns read `fire_interval`), so +30% is not cut to
  the 15% move cap. One line in `Player.get_stat`.
- Network: `LoadoutSync.submit_loadout(gear, guns, skills, ability)` gains a
  String id; `AbilityClaims.use_on_server(aim: Vector3)`,
  `show_use(peer_id, effect_id, at, object_id)` (object_id names a turret or
  siren, 0 otherwise), `show_turret_shot(turret_id, from, to)`;
  snapshot key `"ability_cooldown"`. Steps 2 and 6 change the wire and bump
  `PROTOCOL_VERSION` (one above main when they merge); 4 and 5 reuse
  `show_use` unchanged.
- Save format change: step 7 adds `CharacterProfile.field_ability` (String id,
  default ""); `SaveFile.CURRENT_VERSION` +1 with a migration that adds the
  empty field, and a test that a version-3 sample still loads.
- Content checks: new `tests/content/test_abilities.gd`: every file loads,
  id = file name, unlock levels strictly rise and match the design table,
  cooldown > 0, each `Effect` used by exactly one file, icon and sound set
  (from step 3). `test_loot_content.gd` exact caps dictionary updated.

## Co-op behaviour

- Who owns the state: the server owns each player's cooldown, buff timer,
  turrets, sirens, and the zombie stun and lure timers. The owner owns its
  pick (from its level) and sends it with its loadout.
- What clients send, what the server sends back: the owner sends its ability
  id with every loadout and a use request with its aim point. The server
  sends the cooldown in the player snapshot (on use and on kills, which
  already publish for points), and `show_use` to every peer.
- What a client sees that the host sees too: the ring, turret, siren and
  sounds; zombies stunned, pushed and lured (positions sync); teammates healed
  (health syncs). Only the owner: the ability icon and its countdown; its own
  faster movement and fire (the buff reaches the owner through `show_use`).
- Late joiner: gets its own ability through its first loadout and its
  cooldown in its first snapshot. Live turrets and sirens are not sent (at
  most 20 s; DECISIONS line).
- Dedicated server: no local player, no profile; it only applies received
  ids and runs effects. No sound, ring or HUD (`Build.is_server()`).
- Trust: the server checks the id exists and that `Handshake.player_level(peer)`
  reaches its unlock level (the level the client sent at join, ADR 0003).
- Timers on the server: the server's copy of a client player runs no physics
  (`set_physics_process(local)`), so `FieldAbility` counts down its cooldown
  and buff in its own `_physics_process` on the server, the way
  `PlayerStateSync` counts the bleed-out. `tick(frame)` only reads the owner's
  press. The owner shows the snapshot's cooldown counting down; it never
  presses early because it only asks when its shown cooldown is 0, and the
  server allows 0.25 s slack.
- Hit bounds: Adrenal Rush lowers `fire_interval` on the server's copy too;
  `HitClaims.take_claim` gains a rate factor so the faster shots pass.

## Performance

Per frame with 24 zombies and 4 players: `FieldAbility` is a float
subtract and one bit test per player. Zombies check two floats. A live
turret scans `Spawner.zombies` every 0.2 s (24 distance checks, one ray to
the best target), not per frame. Rings, turret and siren scenes are preloaded;
a ring is a short Tween on one mesh. Turret shots reuse the existing tracer
effect. Budget: under 0.1 ms per frame on the server with 4 turrets up.

## Steps

### Step 1: Shock Pulse, solo and host

- Build: `AbilityData`; `content/abilities/shock_pulse.tres`. `FieldAbility`
  node made in `Player._ready` like `GrenadeThrower`: `ability`,
  `cooldown_left` counted down in its own `_physics_process` (server and
  owner), `tick(frame)` (the press, owner only), `use(aim)` on the server
  (in step 1 a co-op client's press does nothing; step 2 adds the request), kill credit from `Events.enemy_killed` when
  `info.attacker` is its player (server), `static pick_for_level(level)`.
  `GameSession._on_player_added` sets the profile player's ability from its
  level. `AbilityEffects.shock_pulse(spawner, at, data)`: every live zombie
  within 6 m gets `Zombie.stun(2.0, push)`. `Zombie.stun` zeroes movement and
  attacks while it lasts, after a short push away from the user. Rules: the
  stun timer runs down even while frozen or in Stasis (checked before the
  early return); a zombie in SPAWNING or ENTERING (rising, at or vaulting a
  window) is stunned but not pushed; `_stuck_watch` does not tick while
  stunned (or, from step 5, lured), so no `zombie_stuck` warnings. Cap key fix.
  `field_ability` action on X and D-pad down, `InputFrame.FIELD_ABILITY`,
  key bindings row, controls.md fixed. Move `_tick_stamina`, `can_sprint` and
  `_sprint_cooldown_left` to PlayerMoves (player keeps a `can_sprint()`
  forwarder if the vitals panel needs it); update the tests that use them.
  `docs/LOGGING.md` catalogue lines for `ability_*` reasons.
  Roadmap row to Building; DECISIONS lines for the key, the pick and
  Gadgeteer (rewrite "Skills waiting on their feature").
- Files: systems/abilities/ability_data.gd, field_ability.gd,
  ability_effects.gd (new), content/abilities/shock_pulse.tres,
  content/loot/stat_caps.tres, systems/player/player.gd, player_moves.gd,
  systems/enemies/zombie.gd, systems/input/input_frame.gd, local_input.gd,
  project.godot, systems/ui/key_bindings.gd, systems/game/game_session.gd,
  docs/design/controls.md, docs/DECISIONS.md, docs/ROADMAP.md, docs/LOGGING.md,
  tests/unit/test_field_ability.gd (new), tests/content/test_abilities.gd
  (new), tests/content/test_loot_content.gd, tests/unit/test_stat_block.gd
  (old cap key), tests/unit/test_player_stamina.gd,
  tests/integration/test_item_loadout.gd, tests/unit/test_vitals_panel.gd.
- Tests: `test_field_ability.gd`: pick by level (2 none, 3 Shock Pulse, 50
  the highest); a press uses it once and starts the 60 s cooldown; a second
  press during cooldown does nothing; a kill by the user takes 0.5 s, a
  teammate's kill does not; Gadgeteer 3 gives 60 x 0.76 = 45.6 s; gear plus
  skill stops at 40% (36 s), which fails without the cap fix; Shock Pulse
  stuns a zombie at 5 m for 2 s and not one at 7 m; a stunned zombie does
  not attack and logs no `zombie_stuck`; a zombie at a window is stunned, not
  pushed; downed or in the hub: no use. Stamina tests still pass.
- Done when: in solo a level 3+ character presses X, nearby zombies are
  pushed and stand still for 2 s, and the cooldown runs; CI green.

### Step 2: Co-op use

- Build: `AbilityClaims` under the session (made in
  `GameSession._setup_shooting` next to `GrenadeClaims`). `FieldAbility.tick`
  calls `claims.request_use(player, aim)` when there is a session; the
  server checks (`check()` returns a reason: `ability_not_alive`,
  `ability_cooling`, `ability_locked`, `ability_bad_aim`, `ability_too_fast`)
  and runs `FieldAbility.use`; refusals go through `HitClaims.reject` (logged
  as `hit_claim_rejected` with the reason). `show_use` reliable to every
  other peer (moved to step 3, where the ring first needs it). `LoadoutSync`
  sends the id; the server checks it exists and against
  `Handshake.player_level`, and logs `ability_unknown` otherwise. Snapshot key
  `ability_cooldown`. Protocol bump. (The co-op soak bot moved to step 8: soak
  bots join at level 1, below every unlock, so they need the soak profile
  step 8 sets up.)
- Files: systems/abilities/ability_claims.gd (new), field_ability.gd,
  systems/net/loadout_sync.gd, player_state_sync.gd,
  systems/game/game_session.gd, core/build.gd, docs/MULTIPLAYER.md (adds
  AbilityClaims as a second pattern 2 reference with relay),
  tests/unit/test_ability_claims.gd (new).
- Tests: two-peer ENet test (the shape of `test_grenade_claims.gd`): a
  client's Shock Pulse stuns a server zombie; the client's cooldown arrives
  in its snapshot; a second request inside the cooldown is refused with
  `ability_cooling` (asserted on the reason, not the throttled log); after
  the cooldown runs out on the server the client's next use is accepted;
  a level-2 client's Shock Pulse is refused;
  a downed client is refused; an unknown ability id in a loadout is dropped
  and logged; the server's own player uses it without an RPC.
- Done when: a client and the host both use Shock Pulse in one match; CI
  green including `coop-soak` if it runs.

### Step 3: HUD icon, ring and sounds

- Build: `AbilityIcon` in the vitals panel row (ui-hud.md bottom left):
  ability icon, key label from the binding, a dark sweep for the cooldown,
  seconds left under 10, a short brass flash when ready; hidden with no
  ability. `PulseRing` (cosmetic, on `show_use` and the server's own use).
  Icons as SVG in `assets/ui/hud/` in the HUD concept's line style; five
  sounds from `tools/generate_sfx.py` (pulse, heal, turret deploy, rush,
  siren). Look check against hud_concept.jpg.
- Files: systems/ui/hud/ability_icon.gd (new), systems/ui/hud.gd,
  systems/abilities/pulse_ring.gd (new), field_ability.gd,
  ability_claims.gd, assets/ui/hud/ability_*.svg, assets/audio/ability_*.wav,
  tools/generate_sfx.py, content/abilities/shock_pulse.tres,
  tests/unit/test_ability_icon.gd (new), tests/content/test_abilities.gd.
- Tests: `test_ability_icon.gd`: hidden at level 2; sweep share follows
  `cooldown_left / cooldown`; ready state after it ends; key label follows a
  rebind. Content: every ability has icon and sound.
- Done when: the icon reads clearly at 1440p next to the vitals panel (look
  check image in the PR); CI green.
- Built: `show_use(peer_id, ability_id, at)` reliable from the server
  (protocol bump); step 6 adds the turret's object id. The sound plays on the
  SFX bus (there is no Effects bus).

### Step 4: Med Burst and Adrenal Rush

- Build: `med_burst.tres`, `adrenal_rush.tres`. `AbilityEffects.med_burst`:
  the user heals to full, living teammates within 10 m heal 50 (server,
  through `HealthComponent.heal`; downed players are not revived). Adrenal
  Rush: `FieldAbility` holds a buff timer and `multiplier(stat)` (1.3 for
  `move_speed`, 1 / 1.3 for `fire_interval` while it runs, else 1.0), applied
  in `Player.get_stat` outside `ItemInstance.stat_value`; set on the server's
  copy on use and on the owner by `show_use`. Ends early when downed.
  `HitClaims.take_claim(sender, weapon, rate: float = 1.0)` multiplies its
  shot limit by `rate`; HitClaims and WellClaims pass the shooter's
  `1.0 / get_stat(&"fire_interval")` (today gear fire rate plus the rush can
  pass the 1.5 slack). No wire change.
- Files: content/abilities/med_burst.tres, adrenal_rush.tres,
  systems/abilities/ability_effects.gd, field_ability.gd, ability_claims.gd,
  systems/player/player.gd (one line), systems/net/hit_claims.gd,
  systems/net/well_claims.gd,
  tests/unit/test_field_ability.gd, tests/unit/test_hit_claims.gd,
  tests/unit/test_ability_claims.gd.
- Tests: Med Burst heals self to full and a teammate at 8 m by 50, not one at
  12 m, not past max; Adrenal Rush: walk speed x1.3 even with gear at the
  15% move cap, fire rate x1.3, both end after 8 s; co-op: a client's rush
  reaches the server copy, and a client's faster shots pass `HitClaims`.
- Done when: both work in solo and from a client; CI green.

### Step 5: Decoy Siren

- Build: `decoy_siren.tres`. The siren lands where the user aims, up to 20 m
  (ray from the eyes, else 20 m out, dropped to the floor). Server: every
  live zombie within 20 m of it gets `Zombie.lure(point, 6.0)`: it paths to
  the point and does not swing at players until the lure ends (zombies at a
  window keep tearing planks, provisional). `DecoySiren` scene on every
  peer: canister model, blinking light, siren sound (Audio bus SFX), freed
  after 6 s. Canister model made in Tripo with `tools/assets/tripo_make.py`
  and the intake (ADR 0017), prompt row in docs/design/tripo-prompts.md; if the
  API cannot be reached from the thread, a grey box ships and the model
  follows in its own PR (DECISIONS line).
- Files: content/abilities/decoy_siren.tres, systems/abilities/decoy_siren.gd
  + .tscn (new), ability_effects.gd, systems/enemies/zombie.gd,
  assets/models/abilities/decoy_siren.glb, docs/design/tripo-prompts.md,
  docs/design/lore.md, tests/unit/test_field_ability.gd,
  tests/unit/test_ability_claims.gd.
- Tests: zombies within 20 m walk toward the point and do not attack a player
  in reach for 6 s, then chase again; one at 25 m is not lured; the aim point
  is capped at 20 m; the server refuses an aim point farther than 20 m plus
  slack from the eyes.
- Done when: a siren pulls a crowd off a downed teammate in co-op; CI green.

### Step 6: Watchdog turret

- Build: `watchdog.tres`. `Watchdog` scene placed 1.5 m in front of the user
  on the floor. Server: every 0.2 s it picks the nearest live zombie within
  25 m with a clear line to the head; every 0.6 s it shoots it in the head for
  0.4 of that zombie's max health, divided by the head zone's
  `damage_multiplier` as `HitClaims` does (attacker = the user, so hit and
  kill points, XP and the 0.5 s cooldown credit go to the user; weapon id
  `watchdog`). The turret's id comes in `show_use`'s object_id.
  `show_turret_shot` relays the tracer unreliably; clients turn the cosmetic
  turret toward it. Freed after 20 s. Model from Tripo as in step 5.
- Files: content/abilities/watchdog.tres, systems/abilities/watchdog.gd +
  .tscn (new), ability_effects.gd, ability_claims.gd, core/build.gd,
  assets/models/abilities/watchdog.glb, docs/design/tripo-prompts.md,
  tests/unit/test_watchdog.gd (new).
- Tests: targets the nearest visible zombie, skips one behind a wall; a
  head shot every 0.6 s; three shots kill any zombie; kills credit the user
  (points, XP, cooldown -0.5 s); gone after 20 s; a client's turret damages
  only on the server.
- Done when: the turret clears a window for 20 s in solo and co-op; CI green.

### Step 7: Ability picker under the Research tree

The F-21 plan (plans/skill-tree-screen.md) leaves the picker to this feature.
Build after F-21's screen has merged.

- Build: under the tree on the Research screen, 5 slots in unlock order
  (ui-hud.md): icon and name, locked ones dim with "Level N", the picked one
  outlined; a click on an unlocked slot picks it. `CharacterProfile.field_ability`
  saves the id (save version bump and migration). `GameSession` uses the saved
  pick when it is unlocked, else `pick_for_level`.
- Files: the F-21 Research screen script, systems/progression/character_profile.gd,
  systems/save/save_file.gd, systems/game/game_session.gd,
  systems/abilities/field_ability.gd, tests/unit/test_field_ability.gd, the save
  migration test, the Research screen test.
- Tests: a saved pick is used; a saved pick above the level falls back to the
  highest unlocked; a locked slot cannot be picked; an old save loads with no
  pick.
- Done when: a player picks Med Burst at level 20 and brings it into a run; CI
  green.

### Step 8: Close-out

- Build: tick Acceptance, `Status: Done`, roadmap row Done, DECISIONS lines
  checked, finish-feature skill. Soak with abilities on: soak bots have no
  profile (level 1), so the soak run gives each bot a level-50 hello (a soak
  argument to `Handshake.setup`) and an ability directly
  (solo soak: Shock Pulse; co-op soak bots: a different one each) and the bot
  presses the ability bit when it is ready.
- Files: docs/plans/field-abilities.md, docs/ROADMAP.md, docs/DECISIONS.md,
  tools/soak/soak_bot.gd, coop_soak_bot.gd, soak_run.gd, their test.
- Tests: the soak bot test checks it presses the ability when ready.
- Done when: `quality`, `test`, `soak` green; play-test checklist posted.

## Acceptance

- [ ] Abilities are data files with cooldowns - `tests/content/test_abilities.gd`
- [ ] The highest unlocked ability is used, from level 3 - `test_field_ability.gd`
- [ ] Cooldown: kills take 0.5 s, Gadgeteer and the Implant affix shorten it, 40% cap - `test_field_ability.gd`
- [ ] Each ability has a unit test on its effect - steps 1, 4, 5, 6
- [ ] A client's use runs on the server and everyone sees it - `test_ability_claims.gd`, `test_watchdog.gd`
- [ ] HUD shows the ability and its cooldown - `test_ability_icon.gd`, look check image
- [ ] Soak passes with abilities in use, no new warnings - CI `soak`, `coop-soak`
- [ ] Play-test: the person tries each ability (recorded in the close-out PR)

## Risks

- player.gd is at the 350-line limit. Step 1 moves stamina out first; if the
  move breaks a stamina test, that shows in step 1, not later.
- Zombie stun and lure fight the AI's own state machine (window entry,
  attacking). Step 1 builds stun, the simpler of the two, so the AI hook is
  proven cheaply; lure reuses the same spot.
- Fire-rate rate limits in `HitClaims` could refuse Adrenal Rush shots from a
  client. Step 4 tests a client's buffed shots pass.
- A client's timers on the server: the server's player copy runs no physics,
  so FieldAbility counts its own time (review finding); step 2 tests a second
  use after the cooldown.
- `PROTOCOL_VERSION` clashes with other open PRs: each step merges main and
  takes one above main's value.
- Tripo API not reachable or out of credit: a grey box ships so the feature is
  not blocked, and the model follows.
- The turret's share-of-max-health damage could trivialise late rounds; F-23
  levelling pace check and play-tests tune it (provisional, in data).

## Open decisions

Provisional picks (reversible, DECISIONS lines in the step that builds them):

- [x] Provisional: field ability key is X (F is interact in the game and in
  two design docs); D-pad down on gamepad as designed. Rebindable.
- [x] Provisional: until you pick one (step 7), you bring the highest ability
  your level has unlocked.
- [x] Provisional: the design's "Sentry" turret is named **Watchdog**, so it
  no longer clashes with the Sentry burst rifle or the Gate Nine boss "The
  Sentry" (lore.md open list).
- [x] Provisional: numbers the design does not give: Shock Pulse push 6 m/s,
  Med Burst teammate radius 10 m, Watchdog range 25 m and 0.4 of max health
  per head shot every 0.6 s, siren placed up to 20 m along your aim.
- [x] Provisional: Watchdog hits and kills count as the user's (hit points,
  kill points, XP, cooldown credit).
- [x] Provisional: Adrenal Rush's +30% goes past the move and fire-rate caps,
  like Serums.

For the person:

- [x] Approve this plan (size L): all five abilities in seven steps (eight with the picker F-21 left here), with the
  provisional picks above: approved (the person, decision card 2026-11-20).
