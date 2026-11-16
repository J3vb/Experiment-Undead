# Plan: Ids into data (foundation fix 4)

Status: Approved
Roadmap: F-00 foundation fix 4 / issues #140, #143, #148, #149, #154, #163
Phase: P7
Size: M
Approved by: Codex plan review on PR #177 (2026-11-16), size M with no open decisions

## Goal

A new gun, zombie or serum `.tres` works the moment it is added: it gets
arms, its on-hit effect, its loot drop rules and its HUD badge without a code
edit. Content lookups stop reloading files from disk mid-match. Serves "Easy
to add content" (the scale goal in docs/PROCESS.md) and keeps the frame rate
steady.

## Scope

In:

- `Content` keeps each resource after its first load, and gets a cheap
  `has(type, id)` (#140). Step 1, so the suspected loot-drop hitch is tested
  first.
- Arm grip numbers move from `player_arm_profiles.gd` into a `GripData`
  resource per gun, and the shot-peak flag moves onto it (#149, #163).
- On-hit and fire effects (chain, frost, gravity well) become a `WeaponData`
  field instead of id checks (#143).
- Loot drop chance and minimum rarity per enemy move onto `EnemyData`;
  the `zombie_brute` and `zombie_stalker` literals go (#148).
- Serum badge text and colour move onto `SerumData` (#154).
- A CI rule `no-content-id-literals` with a baseline that may only shrink.

Not in (non-goals, and where each one goes instead):

- Serum effects chosen by id (`second_wind`, `scavenger` in `player.gd`,
  `power_up_drops.gd`) and power-up kinds by id (`resupply`, `ammo_pack` in
  `power_up.gd`): they stay in the baseline. A new serum or power-up with a
  new effect needs code anyway. Later: issue to open when More power-ups
  (F-26) is planned.
- Gear base to visual map (`look_builder.gd` `BASE_VISUALS`,
  `GearVisual.BASES`) and the starting sidearm id in `player_state_sync.gd`:
  stay in the baseline. Later: Gear in first person (F-42) or Dyes (F-46).
- The zombie round drop curve (1.5% + 0.1% per round, max 5%): stays as
  constants in `LootService`; only per-enemy overrides move to data. Later:
  balance pass (F-07) if a designer wants to tune it.
- Rarity tier names (`common` ... `prototype`) in `ItemRoller.RARITIES`: an
  ordered fixed rule, not content to add. Never.
- Other first-use hitches (shader compile on the first loot drop, per-drop
  materials): foundation fix 7 (#141, #142, #150, #151).
- Brute and Stalker `.tres` files: Brute (F-30) and Stalker (F-29) create
  them and set the new fields.

## Ready to build

```
### Ready to build
- Foundations touched: 2 Content and ids (shaky: this is the fix), 1 Co-op authority (well RPC gains
  a weapon id), 12 Performance (content cache). Any of them shaky or missing? 2 is what this fixes.
  1: the well request already runs on the server; only its weapon lookup changes. 12: the cache removes
  repeat disk loads, nothing new per frame.
- Decision records: 0002 content as resources, 0003 trusted client, 0004 one code path, 0005 saves,
  0009 CI is the gate. Goes against one: no.
- Co-op:
  - Who decides: unchanged. Server applies hits, effects and loot; each client builds its own arms.
  - How a client triggers it: the gravity well RPCs (`well_at`, `well_orb`) gain a `weapon_id`
    argument; the server checks that weapon's effect is WELL before opening a well.
  - What other players see: unchanged (same RPCs and snapshots).
  - Dedicated server with no local player: yes. Arms and HUD are client only and skipped there already.
- Data: new fields on WeaponData, EnemyData, SerumData; new GripData type in content/grips/*.tres.
  Numbers move as they are from code into .tres; bloater drop 5% matches docs/design/balance/enemies.csv.
  Code compares against a specific id anywhere: no new ones; the CI rule stops new ones.
- Save: no change. Saves store weapon, gear and affix ids; none are renamed or removed.
- Events and UI: no new Events. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (unchanged).
- Tests: unit tests per step (content cache, arm profile snapshot, hit effects by field, loot per enemy,
  serum badge), content checks for every new field, a two-peer well test with the new argument,
  Python tests for the new CI rule.
- Logging: Log.warn weapon_has_no_grip (weapon id) when a gun has no GripData.
- Performance: fewer disk loads; no per-frame or per-hit allocations added.
- Out of scope: see Not in above.
```

## Design references

- docs/FOUNDATIONS.md#2-content-and-ids-in-data: the list of id checks and
  "Fixed when: each of these is a field on the matching data type, and CI
  fails when a content id literal appears in `core/` or `systems/` (with a
  shrinking baseline, like `tested-scripts`)."
- docs/adr/0002-content-as-resources.md: id = file name, new content = new
  `.tres`.
- docs/design/balance/enemies.csv: Bloater drop 5%.
- docs/design/balance/settings.csv rows `loot_base` 0.015, `loot_step` 0.001,
  `loot_max` 0.05 (the round curve that stays in code).
- docs/design/balance/loot.csv: "Brute (Rare+)", Brute drops 1 per run (for
  F-30 to set on its `.tres`).
- docs/design/gun-roster.md: Synapse chains, Cryo Lance freezes, Siphon opens
  a gravity well (the three effects).
- docs/CODE_RULES.md and `tools/ci/check_rules.py` `check_tested_scripts`: the
  baseline pattern the new rule copies.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| core/content.gd | changed | Cache loaded resources; `has(type, id)`; `reload()` clears the cache |
| systems/** (about 20 call sites) | changed | `Content.ids(t).has(id)` becomes `Content.has(t, id)` |
| systems/player/grip_data.gd | new | `GripData` resource: hand anchors, directions, shoulders, shot-peak flag |
| content/grips/*.tres | new | 22 grip files, one per base gun, numbers copied from code |
| systems/weapons/weapon_data.gd | changed | `grip: GripData`, `effect: Effect` |
| content/weapons/*.tres | changed | 43 guns point at their grip; 5 set `effect` |
| systems/player/player_arm_profiles.gd | changed | Reads `GripData`; `IDS`, `RIGHT`, `LEFT` and id branches deleted |
| systems/player/player_arm_view.gd | changed | Passes the `WeaponData`; warns when there is no grip |
| tools/character_contact_export.gd | changed | Shot peak from `grip.shot_peak`, not an id list |
| systems/net/hit_claims.gd | changed | Chain, frost and well picked by `effect`; well RPCs carry `weapon_id` |
| systems/weapons/weapon.gd, gravity_well.gd | changed | Well chosen by `effect`; the well keeps the firing gun's data |
| core/build.gd | changed | `PROTOCOL_VERSION` 2 -> 3 (well RPC arguments change) |
| systems/enemies/enemy_data.gd | changed | `loot_drop_chance`, `loot_min_rarity` |
| content/enemies/zombie_bloater.tres | changed | `loot_drop_chance = 0.05` |
| systems/loot/loot_service.gd | changed | `drop_chance(enemy, round)` and `_rarity()` read `EnemyData` |
| systems/serums/serum_data.gd, content/serums/*.tres | changed | `badge`, `badge_colour` |
| systems/ui/hud.gd | changed | `SERUM_STYLES` deleted; badge from the `SerumData` |
| tools/ci/check_rules.py, tools/ci/content_id_baseline.txt (new), tools/ci/test_check_rules.py | changed | `no-content-id-literals` rule |
| docs/CODE_RULES.md, docs/FOUNDATIONS.md, docs/LOGGING.md, docs/DECISIONS.md, docs/HOW_TO_ADD.md, AGENTS.md | changed | Rule text, foundation 2 marked solid, warning catalogue, recipes mention the new fields |

Autoloads, managers or base classes added: none. `GripData` is a plain
Resource (Keep it simple rule 12: data a script points to).

## Data

- `Content`: private `_loaded: Dictionary[String, Resource]` keyed by path.
  `get_item()` loads once and returns the kept resource. New
  `has(type: StringName, id: StringName) -> bool`. `ids()` stays for loops.
- `GripData` (new, `systems/player/grip_data.gd`), files in
  `content/grips/<base gun id>.tres`, id = file name (it is also the key in
  `assets/models/characters/player_arm_grips.json`):
  - `id: StringName`
  - `right_anchor: Vector3`, `left_anchor: Vector3` (today's `RIGHT`/`LEFT`)
  - `right_forward`, `right_dorsal`, `right_shoulder`, `left_forward`,
    `left_dorsal`, `left_shoulder: Vector3` (defaults = today's rifle values;
    stock, handgun and per-gun cases write their own values)
  - `right_shoulder_lift: Vector2 = (0.07, 0.112)`,
    `left_shoulder_lift: Vector2 = (0.07, 0.112)`,
    `left_shoulder_sway: Vector2 = (0, 0)`,
    `right_sprint_offset: Vector3 = (0, 0, 0)`
  - `support_part: NodePath = ""` (Brenner: `Shotgun/Receiver/Bolt`)
  - `shot_peak: bool = false` (true for brenner_trench, fieldhand_lever,
    coachman_2b, grubber_sawnoff, bastion_lmg)
  - `Hand.shoulder_drop` (0.35 left, 0 right) stays a code constant: the rig's
    rule, not per gun.
- `WeaponData.grip: GripData = null`. A gun and its `_reforged` copy point at
  the same grip file. Reforged guns already share the base `hip_position`.
- `WeaponData.effect: Effect = NONE`, `enum Effect { NONE, CHAIN, FROST, WELL }`.
  Synapse and its reforged copy CHAIN, Cryo Lance and its reforged copy FROST,
  Siphon WELL.
- `EnemyData.loot_drop_chance: float = -1.0` (below 0 = use the round curve),
  `EnemyData.loot_min_rarity: StringName = &"common"`. Bloater sets 0.05.
  Brute (F-30) will set 1.0 and `rare`; Stalker (F-29) 0.05.
- `SerumData.badge: String = ""`, `SerumData.badge_colour: Color = Color("596b80")`
  (the default is today's Scavenger colour, so no new colour is invented).
  The eight serums copy today's `SERUM_STYLES` text and colours exactly.
- Network: `HitClaims.well_at(point, weapon_id)` and
  `HitClaims.well_orb(origin, direction, weapon_id)`. `PROTOCOL_VERSION` goes
  from 2 to 3, so the handshake refuses an older build before anyone spawns.
  If the item-effects plan bumped it first, bump from whatever main has.
- Save format change: none.
- Content checks to add in `tests/content/`: every grip loads and its id
  matches its file and a JSON profile; every non-reforged gun with a
  viewmodel has a grip; a reforged gun has the same grip, effect and
  `hip_position` as its base; enemy `loot_drop_chance` is -1 or in 0..1 and
  `loot_min_rarity` is a rarity id; every serum has a non-empty badge of at
  most 2 characters and the 8 badges are unique.

## Co-op behaviour

- Who owns the state: unchanged. Server applies hits, chain, frost, well
  damage and loot rolls. Each client builds its own arms and HUD badges.
- What clients send, what the server sends back: well requests now include
  the weapon id; the server looks it up in its own `Content` and rejects
  (existing `well_out_of_bounds` path, new reason `well_wrong_weapon`) when
  that gun's effect is not WELL. Nothing else changes on the wire.
- What a client sees that the host sees too: same as today.
- Late joiner: nothing new; all new data is in `.tres` files every build has.
- Dedicated server: arms and HUD do not exist there; the cache, effects and
  loot fields work the same headless.

## Performance

The cache turns repeat `load()` calls (a dozen per look change or join, #140)
into one dictionary lookup. `Content.has()` avoids the keys array that
`ids().has()` builds per call. Effect checks are one enum compare per server
hit. Memory: every content resource that is used stays loaded (under 300
small `.tres` files today, their scenes were already kept by the weapons in
use). Budget: no new per-frame work.

## Steps

### Step 1: Content cache

- Build: `Content.get_item()` keeps each loaded resource; add
  `Content.has(type, id)`; `reload()` clears the cache. Replace every
  `Content.ids(x).has(y)` in `core/` and `systems/` with `Content.has(x, y)`
  (GearVisual.find, LootDrop.item_name, item_tooltip, character_screen,
  results_screen, inventory, item_loadout, item_instance, pack_overlay,
  debug_console). After merge, re-run the loot-drop check from the
  2026-11-15 play-test (kill until a drop, watch `HealthWatch` long-frame
  warnings in the log) and write the result in the PR.
- Files: core/content.gd, the call sites above, tests/unit/test_content_cache.gd (new),
  docs/FOUNDATIONS.md (strike #140 from foundation 2's list).
- Tests: `test_content_cache.gd`: `get_item` twice returns the same instance
  even when the test drops its own reference between calls (fails today,
  because `load()` re-reads an unreferenced file); `has()` true for a real id,
  false for a missing id and a missing type, and prints no error; `reload()`
  gives a fresh instance.
- Done when: tests green; no `Content.ids(...).has(` left in `core/` or
  `systems/`; the PR says whether the 141 ms / 67 ms loot-drop spikes are gone.

### Step 2: Grip data for the arms

- Build: write the snapshot test first, against today's code. Then add
  `GripData`, 22 files in `content/grips/` holding the exact numbers that
  `player_arm_profiles.gd` computes today, `WeaponData.grip` on all 43 guns,
  and rewrite `PlayerArmProfiles.profile(data: WeaponData)` to read the grip.
  `weapon_ids()` returns the sorted grip ids. `hip_position` comes from the
  `WeaponData` (no more `load()` by path). A gun with no grip: no arms,
  `Log.warn(&"player", &"weapon_has_no_grip", {"weapon": id})` once.
  `tools/character_contact_export.gd` exports `shot_peak` when
  `grip.shot_peak` is true. Delete `IDS`, `RIGHT`, `LEFT` and every
  `id == ...` branch.
- Files: systems/player/grip_data.gd (new), content/grips/*.tres (new),
  systems/weapons/weapon_data.gd, content/weapons/*.tres,
  systems/player/player_arm_profiles.gd, systems/player/player_arm_view.gd,
  tools/character_contact_export.gd, tests/unit/test_player_arm_profiles.gd (new),
  tests/content/test_grip_content.gd (new), docs/LOGGING.md, docs/HOW_TO_ADD.md (gun recipe:
  add a grip file).
- Tests: `test_player_arm_profiles.gd` holds a frozen snapshot of every
  profile's wrist, rotation, shoulder, shoulder_lift, shoulder_sway,
  sprint offset, morph and support part for all 22 guns, taken from today's
  code, and compares within 1e-5; plus a test gun built in code with a custom
  `GripData` and an id no code knows gets a profile (fails today:
  `push_error` and null). Content checks listed under Data. The existing arm
  tests (`test_player_arm_*`) and the character contact check stay green
  with no approved snapshot changed.
- Done when: snapshot test green, no weapon id literal left in
  `player_arm_profiles.gd` or `character_contact_export.gd`, contact check
  exports the same 5 shot peaks.

### Step 3: Weapon effects as data

- Build after step 2 of `docs/plans/item-effects-server.md` (foundation
  fix 3, plan in PR #176) has merged, because both edit `hit_claims.gd`,
  `weapon.gd` and `PROTOCOL_VERSION`. Check on main: `HitClaims.claim_hit`
  takes an `item_uid` argument. If that plan is Dropped instead, build on
  main as it is; nothing in this step needs its changes, the wait only
  avoids merge clashes. Add `WeaponData.effect`; set it on the 5
  guns. `HitClaims.apply_server_hit` picks chain and frost from
  `_weapons[info.weapon_id].effect` (no `_reforged` trimming).
  `Weapon._trace` launches a well when `data.effect == WELL`.
  `GravityWell` keeps the `WeaponData` it was launched with and uses its id
  and damage (no `&"siphon"`). The well RPCs carry the weapon id; the server
  checks the effect and rejects with `well_wrong_weapon`. Bump
  `PROTOCOL_VERSION`.
- Files: systems/weapons/weapon_data.gd, content/weapons/{synapse,synapse_reforged,
  cryo_lance,cryo_lance_reforged,siphon}.tres, systems/net/hit_claims.gd,
  systems/weapons/weapon.gd, systems/weapons/gravity_well.gd, core/build.gd,
  tests/unit/test_hit_claims.gd, tests/unit/test_well_claims.gd,
  tests/unit/test_gravity_well.gd, tests/content/test_prototype_guns.gd, docs/LOGGING.md
  (new reject reason).
- Tests: a test gun built in code with id `test_chain` and `effect = CHAIN`,
  added to `HitClaims._weapons`, chains on a server hit (fails today: only
  the id `synapse` chains); same for FROST. Two-peer well test: a client
  well request with a WELL gun opens a well; with a non-WELL gun it is
  rejected with `well_wrong_weapon`. Content check: reforged effect equals
  base effect; exactly the three prototype guns have a non-NONE effect.
- Done when: no `synapse`, `cryo_lance` or `siphon` literal left in
  `systems/`; existing chain, frost, siphon and well tests green.

### Step 4: Enemy loot rules and serum badges as data

- Build: add `EnemyData.loot_drop_chance` and `loot_min_rarity`; set
  Bloater to 0.05. `LootService.drop_chance(enemy: EnemyData, round_number)`
  returns the enemy's chance when it is 0 or more, else the round curve.
  `_rarity()` rerolls up to the enemy's `loot_min_rarity`. Delete the
  `zombie_brute`, `zombie_bloater`, `zombie_stalker` matches. Add
  `SerumData.badge` and `badge_colour`, fill all 8 serums from today's
  table, delete `Hud.SERUM_STYLES`, build the badge from the `SerumData`.
- Files: systems/enemies/enemy_data.gd, content/enemies/zombie_bloater.tres,
  systems/loot/loot_service.gd, systems/serums/serum_data.gd,
  content/serums/*.tres, systems/ui/hud.gd, tests/unit/test_loot_service.gd,
  tests/unit/test_hud.gd, tests/content/test_content.gd (enemy and serum checks),
  docs/HOW_TO_ADD.md (enemy and serum recipes).
- Tests: an `EnemyData` built in code with an unknown id,
  `loot_drop_chance = 1.0` and `loot_min_rarity = &"rare"` always drops and
  never below rare with a fixed-seed `GameSession.rng` (fails today: unknown
  ids get the round curve and any rarity); Bloater still 0.05; a walker
  still follows the curve at rounds 1, 10 and 40. HUD: a `SerumData` built in
  code with an unknown id and badge `XX` shows a badge (fails today: it
  returns early).
- Done when: no enemy or serum id literal left in `loot_service.gd` or
  `hud.gd`; content checks green.

### Step 5: CI rule against content id literals

- Build: rule `no-content-id-literals` in `tools/ci/check_rules.py`. It
  collects ids (file names) from `content/weapons`, `content/enemies`,
  `content/serums`, `content/power_ups`, `content/gear_visuals`,
  `content/loot/gear`, `content/grips`, `content/skills` and
  `content/waves`, and flags any string or StringName literal equal to one
  of them in `core/**/*.gd` and `systems/**/*.gd` (comments ignored). Left
  out on purpose, with the reason in the rule's docstring: affixes (their ids
  are also stat keys code must name), rarities and rarity looks (a fixed
  ordered rule), singletons loaded by one name (economy, progression, stat
  caps) and UI screens (screen flow is code). Known leftovers go in
  `tools/ci/content_id_baseline.txt` as `path: id` lines; the checker also
  holds them in a frozen `INITIAL_CONTENT_ID_BASELINE`, so an entry can only
  be removed: a new pair fails, and a pair that no longer appears must be
  deleted from the file, like `tested-scripts`. Document it in
  `docs/CODE_RULES.md` and the AGENTS.md rule list. Mark foundation 2 solid
  in `docs/FOUNDATIONS.md` and add a `docs/DECISIONS.md` line.
- Files: tools/ci/check_rules.py, tools/ci/content_id_baseline.txt (new),
  tools/ci/test_check_rules.py, docs/CODE_RULES.md, AGENTS.md,
  docs/FOUNDATIONS.md, docs/DECISIONS.md, docs/ROADMAP.md, this plan (Status: Done).
- Tests: `test_check_rules.py` cases: a new literal fails; a literal in a
  comment passes; a baseline entry that is no longer found fails; a baseline
  entry not in the frozen set fails; a literal of an excluded type (an affix
  id) passes. The rule passes on main with the baseline (expected about 30
  lines: serum and power-up effects, gear visual fallbacks, starting
  sidearm).
- Done when: `python tools/ci/check_rules.py` green, Acceptance ticked,
  roadmap and FOUNDATIONS updated.

## Acceptance

- [ ] `Content.get_item()` returns one kept instance per id (test_content_cache.gd).
- [ ] A gun with a `GripData` and an unknown id gets arms; all 22 guns' arm profiles match the old numbers (test_player_arm_profiles.gd).
- [ ] A gun with `effect = CHAIN` or `FROST` and an unknown id chains or freezes; a well opens only for a WELL gun, from a client too (test_hit_claims.gd, test_well_claims.gd).
- [ ] An enemy with drop fields and an unknown id follows them (test_loot_service.gd).
- [ ] A serum with an unknown id shows its badge (test_hud.gd).
- [ ] CI fails on a new content id literal in `core/` or `systems/` (test_check_rules.py).
- [ ] Loot-drop hitch re-checked after step 1, result written in the step 1 PR.

## Risks

- **The loot-drop hitch is not Content.** The 2026-11-15 spikes may be a
  first-use shader compile (LootDrop makes a new material per drop) rather
  than disk loads. Step 1 is first and its PR records the re-check; if the
  spikes stay, open a performance issue for foundation fix 7 instead of
  growing this plan.
- **Arms move by a hair.** Hand-copying 22 guns' numbers could shift a hand.
  The snapshot test is written against today's code before the rewrite and
  must pass unchanged, and the character contact check must not need a new
  approved snapshot.
- **Merge clashes with the item-effects plan** (`docs/plans/item-effects-server.md`,
  PR #176). Both edit `hit_claims.gd` and `weapon.gd`, and both bump the
  protocol. Step 3 waits for that plan's step 2 (or for it to be Dropped).
- **Cache keeps a stale resource in tests** that edit content on disk. Tests
  that need fresh data call `Content.reload()`, which clears the cache.
- **The CI rule is too noisy.** Short ids such as `common` could match normal
  strings; the rule leaves out rarity and affix folders for this reason, and
  step 5's tests include an excluded-type case.

## Open decisions

- none
