# Plan: Frag grenades

Status: Building
Roadmap: F-24 / issue #119
Phase: P3
Size: M
Approved by: the person (decision card, 2026-11-20, damage model); plan review on PR #407 by a separate Claude review (Codex out of quota): 2 blocking and 9 suggestions, all fixed
Lore link: Army and Cordon issue frags left in the zone by the evacuation force, the same source as the wall guns (docs/design/lore.md#story-links-for-game-content, row "Frag grenades", provisional, added by this plan)

## Goal

The player carries 2 frag grenades that refill each round. Hold G to cook,
release to throw; the blast clears a crowd, falls off with distance and is
stopped by walls. Serves the "guns feel great" pillar (issue #119) and is the
explosive that makes Crawlers (F-27 waits on this).

## Scope

In:

- Lethal slot with frag grenades: hold `lethal` (G, gamepad RB) to pull the
  pin and cook, release to throw. Holding past the fuse blows up in hand.
- Carry 2, refilled to 2 at the start of every round and by Resupply
  (game-design.md "Weapons", "Power-ups").
- Blast damage with linear falloff, blocked by walls, own grenade hurts the
  thrower (capped), teammates take none.
- Explosives burst a Bloater at once (zombie-ai.md "Bloater").
- New damage type `EXPLOSIVE` so later rules (Crawler, Sturdy skill,
  Explosion guard affix) can read it.
- HUD grenade slot (icon, count, key) next to the ammo panel (ui-hud.md
  screen 10), cook ticks, explosion effect, sounds, screen shake.
- Co-op: client asks, server throws the real grenade and applies damage,
  everyone sees the throw and the blast.
- Code-built frag model and a first-person hold and throw.

Not in (non-goals, and where each one goes instead):

- Crawlers from leg damage (F-27; this plan sets `damage_type` and
  `position` on every blast hit so F-27 can read them)
- Scavenger serum's +1 grenade (F-26 power-ups; its DECISIONS line stays)
- Grenade damage and Extra grenade affixes, Sturdy skill, Explosion guard,
  Twin Pin (gear and skill effects F-20 and later; they read `EXPLOSIVE`)
- Tactical slot and Lure Beacon (later row, not planned)
- Third-person throw clip on teammates (follow-up to F-41 if play-tests ask)
- Grenade indicator on the HUD for nearby live grenades (play-test first)
- Barrels and other explosives (later content reusing the blast function)

## Ready to build

```
### Ready to build
- Foundations touched: 1 co-op authority, 2 content in data, 4 events,
  6 input, 7 tick and randomness, 9 tests, 10 dedicated server, 11 assets,
  12 performance. All solid. Needs F-11 (v0.1.0 release) is Todo only for the
  tag; the person said on 2026-11-20 that v0.1 counts as done and v0.2 starts.
- Decision records: ADR 0003 trusted client, 0004 one code path, 0002 content
  as resources, 0008 code-built assets, 0017 Tripo models (a small held item
  like a gun part stays code-built, as the issue asks). Goes against none.
- Co-op:
  - Who decides: server owns grenade count, the real grenade and all damage.
    The owner owns its cook timer and aim.
  - How a client triggers it: `GrenadeClaims.request_throw(origin, velocity,
    fuse_left)`; server checks alive, count > 0, origin within 2 m of the
    camera, speed within the frag's throw speed + slack, fuse_left within
    0..fuse, at most one throw per 0.4 s.
  - What other players see: an `unreliable` relay of the throw (cosmetic
    grenade flies the same arc) and a `reliable` blast message with the
    server's blast position (effect, sound, shake).
  - Dedicated server: yes. The real grenade is a physics body with no mesh
    needs; effects and sounds are skipped by `Build.is_server()`.
- Data: content/throwables/frag.tres (ThrowableData). Code never compares a
  throwable id.
- Save: no. Count is per run and refills.
- Events and UI: no new Events. HUD slot is part of the match HUD, no new
  screen. Count changes reach the HUD through `PlayerStateSync`.
- Input through InputFrame (new LETHAL held bit), gameplay in
  _physics_process, no randomness (the arc is fixed by origin and velocity): yes
- Tests: unit (cook timer, falloff, wall block, self cap, refill, throw
  checks), content (frag.tres fields), integration (host throw kills a
  Shambler; client throw kills on the server and both see the blast).
- Logging: `grenade_rejected` (through HitClaims.reject, once a second),
  `grenade_lost` (fell below the map before it went off).
- Performance: scene and blast effect preloaded; no per-frame allocations;
  blast is one loop over the enemies group plus one ray per enemy in radius.
- Lore link: Army and Cordon issue, provisional row added in this PR.
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#weapons: "2 frag grenades that refill each round"
- docs/design/game-design.md power-ups table: Resupply "grenades refilled"
- docs/design/controls.md: Lethal (grenade) G, gamepad RB / R1, hold to cook;
  action name `lethal`
- docs/design/ui-hud.md screen 10: grenade slot (icon, count, key G) next to
  the ammo panel
- docs/design/game-feel.md shake table: Explosion 0.6 at 0 m, linear to 0 at
  15 m; on the "shake from explosions and hits" slider
- docs/design/zombie-ai.md: "Explosives burst it at once" (Bloater);
  Crawler rule (F-27)
- docs/design/game-design.md skills: Sturdy "own explosive damage", and
  docs/design/affixes.md Explosion guard "your own grenades": own grenades
  hurt the thrower
- docs/design/balance/rounds.csv "Base health" column: a fixed 1000 kills a
  Shambler at the centre up to about round 10 (915.6 health), then fades
- docs/DECISIONS.md lines 43 (Crawler waits on grenades) and 46 (Scavenger
  +1 grenade waits)
- docs/adr/0003-trusted-client-co-op.md, docs/MULTIPLAYER.md patterns 2, 5, 6

Numbers the docs do not give yet (provisional, added to game-design.md and
the Change log in step 1, one DECISIONS line):

| Number | Value | Why |
|---|---|---|
| Fuse | 3.0 s from pin pull | Genre standard; cooking eats into it |
| Throw speed | 15 m/s along aim, tilted up 10 degrees, plus player velocity | Reaches about 20 m on flat ground |
| Blast radius | 7 m, full damage inside 1.5 m, linear to 0 at 7 m | Clears a doorway crowd, not a room |
| Centre damage | 1000, fixed (person's pick, 2026-11-20) | One-shots crowds to about round 10, then fades like classic zombie games; gear grenade damage carries it later |
| Own damage | at most 60, same falloff | Cooking too long hurts, never downs a full-health player alone |
| Gun down after throw | 0.5 s | Same feel as the knife swing |
| Server throw checks | origin within 2 m of the camera, speed at most throw_speed + 10 m/s (player speed), one throw per `recover_time` | Constants in GrenadeClaims, step 2 |
| Cook tick | every 0.5 s | Step 3 sound |
| Wall ray start | 0.3 m above the blast | So a frag on the floor sees past its own floor |

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/throwables/throwable_data.gd | new | `ThrowableData` Resource |
| systems/throwables/grenade.gd + grenade.tscn | new | `Grenade` RigidBody3D: fuse, flight, blast |
| systems/throwables/blast.gd | new | `Blast` static functions: falloff, wall check, apply damage |
| systems/throwables/grenade_thrower.gd | new | `GrenadeThrower` node on the player: cook, release, gun down |
| systems/throwables/blast_effect.gd + .tscn | new (step 3) | flash, smoke, sound, shake |
| systems/net/grenade_claims.gd | new (step 2) | client request, relay, blast broadcast |
| content/throwables/frag.tres | new | frag numbers |
| systems/damage/damage_info.gd | changed | `Type.EXPLOSIVE` |
| systems/enemies/zombie.gd | changed | Bloater burst on explosive damage (via `EnemyData` flag) |
| systems/enemies/enemy_data.gd, content/enemies/bloater.tres | changed | `burst_by_explosives: bool` |
| systems/input/input_frame.gd, local_input.gd | changed | `LETHAL` held bit |
| project.godot | changed | `lethal` action (G, joypad button 10 RB) appended to [input] by hand |
| systems/ui/key_bindings.gd | changed | "Lethal (grenade)" row |
| systems/net/player_state_sync.gd | changed | server-owned `grenades` count in the snapshot, refill on round start |
| systems/power_ups/power_up_drops.gd | changed | Resupply refills grenades for every target in `on_collected` (server side) |
| systems/power_ups/power_up.gd | changed | same refill in `collect()`'s no-drops branch (tests, standalone) |
| systems/weapons/weapon_holder.gd | changed | `lower(seconds)` pulled out of `swing()`: gun down, no firing, cancels a reload |
| tools/soak/soak_bot.gd, coop_soak_bot.gd | changed (steps 1, 2) | bots throw one frag a round |
| systems/player/player.gd | changed | add the GrenadeThrower child, pass presses (2-3 lines; file is 335 lines) |
| systems/game/game_session.gd | changed (step 2) | add `GrenadeClaims` to the session systems list |
| systems/net/hit_claims.gd | changed (step 2) | rename `confirm_well_hit`/`well_hit` to `confirm_area_hit`/`area_hit` (second user) |
| core/build.gd | changed (step 2) | bump `PROTOCOL_VERSION` |
| systems/ui/grenade_slot.gd | new (step 3) | HUD slot, its own Control so hud.gd (321 lines) does not grow |
| tools/generate_sfx.py, assets/audio/ | changed (step 3) | pin, cook tick, bounce, blast near/far |
| tools/assets/frag_model.py, assets/models/throwables/frag.glb | new (step 4) | code-built frag |
| systems/player/player_arm_view.gd (or a small new grenade_hold.gd) | changed (step 4) | hold and throw motion |

Autoloads, managers or base classes added: none. `GrenadeClaims` is a session
node like `WellClaims`: it owns the throw rate state on the server, which no
existing node owns (Keep it simple rule 6).

Files over 300 lines this plan grows: `player.gd` (335) by 2-3 lines only,
all grenade logic lives in `GrenadeThrower`; `hud.gd` (321) by one line to
add the slot scene. If either would pass 350, step 1 or 3 moves an existing
job out first.

## Data

- `ThrowableData` (new Resource, `content/throwables/`, file name is the id):
  `id: StringName`, `display_name: String`, `carry: int = 2`,
  `fuse: float = 3.0`, `throw_speed: float = 15.0`,
  `throw_lift_degrees: float = 10.0`, `radius: float = 7.0`,
  `full_radius: float = 1.5`, `centre_damage: float = 1000.0`,
  `self_damage_max: float = 60.0`, `recover_time: float = 0.5`,
  `scene: PackedScene` (the grenade). Read by GrenadeThrower, Grenade, Blast,
  GrenadeClaims.
- `EnemyData.burst_by_explosives: bool = false`; true on bloater.tres.
- `DamageInfo.Type.EXPLOSIVE` (appended, so BULLET and MELEE keep their
  values).
- `PlayerStateSync` snapshot gets `"grenades": int`; clients missing the key
  keep their count (the protocol bump in step 2 stops old builds anyway).
- Network messages (step 2, protocol bump): `GrenadeClaims.throw_on_server`
  (any_peer, reliable), `show_throw` (authority, unreliable),
  `show_blast` (authority, reliable).
- Blast hits leave `DamageInfo.item_uid` empty, so the thrower's loot-gun
  on-hit effects never run from a frag. A blast kill pays the normal
  `points_per_kill` (no headshot or melee bonus) and XP as usual.
- Save format change: none.
- Content checks to add in `tests/content/`: `test_throwables.gd`, every
  throwable has carry >= 1, fuse > 0, radius > full_radius > 0, a scene, and
  self_damage_max below player max health.

## Co-op behaviour

- Who owns the state: server owns each player's grenade count, the real
  grenade, blast damage, points and XP. Owning client owns the cook timer and
  aim. Each client owns its cosmetic copies.
- The client never writes its count: it only checks count > 0 before a
  throw, and its HUD follows the snapshot. A mid-run joiner starts with
  `carry`.
- What clients send, what the server sends back: owner sends
  `throw_on_server(origin, velocity, fuse_left)`. Server checks (alive,
  count, origin near camera, speed, fuse range, rate), spawns the real
  grenade, takes one from the count and publishes the snapshot; it relays
  `show_throw(peer, origin, velocity, fuse_left)` to the other clients and,
  when the grenade goes off, `show_blast(peer, position)` to everyone. A
  rejected throw changes nothing on the server; the owner's cosmetic
  grenade ends quietly at its fuse end when no `show_blast` arrives
  within 1 s. A grenade that blows up in hand goes through the same
  request with velocity 0 and fuse_left 0.
- What a client sees that the host sees too: the flying grenade (cosmetic,
  same arc), the blast, damage numbers and kills. Only the owner sees its
  own hit markers (through `confirm_area_hit`) and its own count on the HUD.
- Late joiner: nothing extra; a live grenade lasts at most 3 s. The joiner's
  own count comes in the existing snapshot request.
- Dedicated server (no screen, no local player): real grenades run as
  physics bodies; blast effects, sounds and shake are skipped.

The owner throws its cosmetic copy at once so the throw feels instant; it
shows the blast only when `show_blast` arrives, at the server's position. In
solo and on the host, the owner's grenade is the real one.

## Performance

At most 2 live grenades per player (16 with 8 players). A grenade is one
RigidBody3D on the WORLD mask only (it ignores zombies and players), with
continuous collision. The blast runs once: one loop over the `enemies` group,
filtered to the grenade's own multiplayer (tests and spectating can hold
another session in the tree), plus the thrower only, with a distance check, then
one ray for each target inside 7 m (at most the 24 alive zombies in v0.1).
Scene, effect and sounds are preloaded on first use; no allocation per
physics tick. Budget: under 0.5 ms on the blast frame with 24 zombies.

## Steps

### Step 1: Throw and blow up (solo and host)

- Build: `ThrowableData`, `frag.tres`, `DamageInfo.Type.EXPLOSIVE`,
  `EnemyData.burst_by_explosives`, `LETHAL` bit and `lethal` action,
  key binding row, `GrenadeThrower` (press starts cook, release or fuse end
  throws, gun lowered and no firing while cooking and for `recover_time`,
  cook cancels a reload), `Grenade` (RigidBody3D, grey sphere mesh, fuse
  counts down, goes off), `Blast.apply()` (falloff, wall ray, own-damage cap,
  no teammate damage, Bloater burst, points and XP through the normal
  damage path), grenade count in `PlayerStateSync` (refill on round start
  and Resupply). In co-op (client and host) the key does nothing yet, so nobody sees a
  blast they cannot explain (one temporary DECISIONS line, removed in
  step 2). The solo soak bot throws one frag a round. Numbers into
  game-design.md, its Change log and one DECISIONS line.
- Files: systems/throwables/*, content/throwables/frag.tres,
  systems/damage/damage_info.gd, systems/enemies/{enemy_data,zombie}.gd,
  content/enemies/bloater.tres, systems/input/*, project.godot,
  systems/ui/key_bindings.gd, systems/net/player_state_sync.gd,
  systems/power_ups/{power_up,power_up_drops}.gd, systems/weapons/weapon_holder.gd,
  systems/player/player.gd, tools/soak/soak_bot.gd, docs.
- Tests: `tests/unit/test_grenades.gd` (cook timer: release at 1 s leaves
  2 s, holding to 3 s blows up in hand; falloff at 0, 1.5, 4, 7, 8 m;
  wall blocks; own damage capped at 60; teammate takes 0; Bloater bursts;
  refill to carry on round start and Resupply, never above carry; no throw
  at 0 count). `tests/content/test_throwables.gd`.
  `tests/integration/test_grenade_throw.gd`: a real GameSession, the player
  throws at a Shambler, it dies and the thrower gets kill points.
- Done when: in solo you can cook and throw 2 frags a round, they kill
  crowds and the soak stays green.

### Step 2: Co-op throws

- Build: `GrenadeClaims` session node (patterns 2 and 6 in
  docs/MULTIPLAYER.md): request path with server checks, cosmetic relay,
  blast broadcast; rename `confirm_well_hit` to `confirm_area_hit` and use it
  for blast hit markers; `Build.PROTOCOL_VERSION` bump; remove the step 1
  DECISIONS line.
- Files: systems/net/grenade_claims.gd, systems/net/hit_claims.gd,
  systems/weapons/gravity_well.gd (rename call), systems/game/game_session.gd,
  systems/throwables/grenade_thrower.gd, systems/throwables/grenade.gd,
  core/build.gd, tools/soak/coop_soak_bot.gd (one throw a round),
  docs/MULTIPLAYER.md (add GrenadeClaims as a pattern 2 example),
  docs/LOGGING.md.
- Tests: `tests/unit/test_grenade_claims.gd` (each server check rejects
  the bad case and accepts the good one; rate limit; count goes down once).
  `tests/integration/test_coop_grenades.gd` (a real server process and a
  client, like `test_net_match.gd` with `net_match_server.tscn`: a client throw kills a Shambler on the server,
  the client sees the blast, the client count syncs back).
- Done when: on a dedicated server with 2 clients, both can throw, damage
  happens only on the server, and the co-op bot soak stays green.

### Step 3: HUD slot and feel

- Build: `GrenadeSlot` HUD control (icon, count, key name from Settings,
  dims at 0) placed per ui-hud.md; cook tick sound every 0.5 s while cooking;
  blast effect (flash light, smoke puff, decal-free), near and far blast
  sound on the Weapons_World bus, pin pull and bounce sounds (generated in
  `tools/generate_sfx.py`); screen shake 0.6 at 0 m to 0 at 15 m on the
  explosions slider. look-check skill renders before and after.
- Files: systems/ui/grenade_slot.gd (+ .tscn), systems/ui/hud.gd (one line),
  systems/throwables/blast_effect.gd + .tscn, tools/generate_sfx.py,
  assets/audio/sfx/grenade_*.wav, docs/LOGGING.md if a warning is added.
- Tests: `tests/unit/test_grenade_slot.gd` (count and key text follow the
  player, dims at 0); `tests/unit/test_grenades.gd` adds shake falloff at 0,
  7.5, 15 m and slider scaling.
- Done when: the HUD shows the count, cooking ticks, the blast reads at a
  glance and shake follows the setting.

### Step 4: Frag model, hold and throw, close-out

- Build: `tools/assets/frag_model.py` (blender-model skill, Cold Containment
  colours from look-rules.md, olive body, safety lever and pin ring), export
  `assets/models/throwables/frag.glb` (light_baking 3), swap the grey sphere
  in grenade.tscn; first-person: the gun dips, the left hand brings the frag
  into view while cooking and flicks it forward on release (arm IK in
  `PlayerArmPose`, like the reload motion). Run finish-feature, tick
  acceptance, roadmap row Done.
- Files: tools/assets/frag_model.py, assets/models/throwables/frag.glb
  (+ .import), systems/throwables/grenade.tscn, systems/player/ arm view or a
  small `grenade_hold.gd`, docs/design/turnarounds if the model check needs
  it, docs/plans/frag-grenades.md, docs/ROADMAP.md.
- Tests: model rule checks in Assets CI (budget, facing); a unit test that
  the hold motion puts the left-hand target on the frag at full cook and
  returns to the grip after `recover_time`.
- Done when: the frag looks like the style guide, the hold and throw read in
  first person, every acceptance line below is ticked.

## Acceptance

- [x] Hold G cooks, release throws; holding 3 s blows up in hand (unit test: test_grenades.gd cook, release and blow-up-in-hand tests)
- [x] 2 frags per round, refilled at round start and by Resupply, count on the HUD (unit tests)
- [x] Damage falls off from 1.5 m to 0 at 7 m and is blocked by walls (unit tests)
- [x] Own grenade hurts the thrower up to 60, teammates take none (unit test)
- [x] A Bloater bursts from any explosive hit (unit test)
- [x] A client's throw does damage only on the server and both see the blast (two-peer test: test_grenade_claims.gd, client frag kills on the server)
- [x] Soak and co-op bot soak green with grenades in the build
- [ ] Solo play-test: throwing and cooking feel good (recorded by the person)

## Risks

- Cosmetic and real grenades land in different places (physics differs per
  machine, or a door moved). The blast always uses the server position, and
  grenades only collide with the static world, so they rarely differ.
  Step 2's co-op test checks the client's blast position is the server's.
- Grenades tunnel through thin walls at 15 m/s. Continuous collision on the
  body; step 1 test throws at a wall and checks it stops.
- A blast in a doorway hits zombies behind the door frame. The wall ray goes
  from 0.3 m above the blast to the target's chest; step 1 test covers a wall
  between blast and zombie.
- With fixed damage, late-round frags stop making Crawlers (F-27 needs 40%
  of max health from explosives: about 2,500 health, so round 20 still
  works at the centre, not at the edge). F-27's plan checks this against
  rounds.csv and asks the person if Crawlers get too rare.
- The bot soak never throws, so a grenade crash would not show. Step 2 adds
  a throw to the co-op soak bot once per round.

## Open decisions

- [x] Grenade damage over a run: fixed 1000 at the centre that fades after about round 10 like classic zombie games (person's pick on the decision card, 2026-11-20)
