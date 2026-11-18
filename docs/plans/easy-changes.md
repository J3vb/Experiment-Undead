# Plan: Easy, safe changes (co-op request pattern, short agent docs, audit fixes)

Status: Approved
Roadmap: F-79 / no issue
Phase: P7 (co-op foundation) and process; no gameplay change
Size: L
Approved by: the person, four decision cards in the F-79 thread (2026-11-18); independent Claude review on PR #347 (Codex out of quota): 4 blocking and 9 suggestions fixed

## Goal

Adding or changing a feature should not mean re-inventing co-op plumbing or
digging through 20,000 words of notes. This plan makes the two **shaky**
foundations in `docs/FOUNDATIONS.md` solid (1: co-op authority, 13: rules and
docs agents read), then fixes the audit findings the person picked. It serves
every pillar indirectly: features land faster and with fewer co-op bugs.

## Scope

In:

- **Co-op (foundation 1):** the six co-op message patterns written down once
  with a reference file each, one way for new code to ask "am I the server", a
  co-op recipe, a CI rule that enforces the shape of every RPC, and the two
  co-op scripts at the 350-line cap split by job. No new helper class: the
  shared parts are two-line idioms, and the one real copied block (the
  once-a-second refusal warning) has only two copies (Keep it simple rule 2).
- **Docs (foundation 13):** `docs/DECISIONS.md` cut from a 15,400-word build log
  to short one-line lists; `AGENTS.md` becomes the one entry point with a
  reading map per task, stale lines fixed and the agent gotchas moved into the
  repo; CI keeps both short and in sync.
- **Audit fixes** the person picked on 2026-11-18 (steps 6 to 10: audit ranks 1 to 3).

Not in (non-goals, and where each one goes instead):

- Rewriting the state RPCs as `MultiplayerSynchronizer`s: they work and are
  tested; a rewrite is risk with no player gain (never, unless a bug needs it).
- A shared request helper (a `RequestGate` class was drafted and dropped in
  review: handlers differ for good reasons, so it saved no code). Extract the
  refusal warning when a third request handler needs it.
- New rate limits or new refusal warnings: the co-op soak fails on unexpected
  net warnings, and in-flight shots after a down are normal.
- Prediction, interpolation or lag compensation (ADR 0003; new ADR first).
- `MapData` and one session scene, and one map-building pipeline: wait for the
  next match map (step 5 writes the trigger into the deferred table).
- Audit items marked "not now" below.

## Audit findings (ranked by payoff)

Checked 2026-11-18 on main `e3c1b65`. Numbers are counted from the code.

| Rank | Finding | Evidence | Fix | Pick |
|---|---|---|---|---|
| 1 | Core scripts sit exactly at the 350-line cap | `weapon.gd`, `zombie.gd`, `game_session.gd`, `hit_claims.gd`, `player_state_sync.gd` all 350; `net.gd` 349, `player.gd` 346. v0.2 grenades, new zombies, skills and legendaries all edit them, so each would be forced into a rushed split mid-feature | Split by job now, one small PR per file with no behaviour change; existing tests prove it. The two co-op files are steps 2 and 3; the other three are steps 6 to 8 | picked |
| 2 | Co-op tests hand-build their own session | 17 test files have their own side builder; 12 of them (10 tests, 2 fixtures) copy `GameSession` wiring by hand (World, Economy, Progression, Spawner, HitClaims, RemoteShots, PlayerSpawner). `no-triple-copy` skips tests, so CI never flagged it. When the wiring changes, these tests keep passing against a session the game no longer has | One helper in `tests/helpers/` that builds a co-op side from the same wiring; move the 12 onto it (step 9) | picked |
| 3 | A new model is listed by hand in four places | `build_models.py` `MODELS`, `JOINTS` in `check_models.py` (`{}` for every static prop), a hand list of ~130 files in `.github/workflows/assets.yml`, and the F-77 catalogue. `assets.yml` changed in 13 of the last 50 commits; F-77 adds about 75 models | Assets CI derives the required files from `MODELS` and checks every committed `.glb` is in it; static props need no `JOINTS` line (step 10) | picked |
| 4 | Co-op code has no written pattern | 39 RPCs in 15 scripts, each shaped by hand; "am I the server" asked as `Net.is_authority()` (19), `multiplayer.is_server()` (99) and both (5) while AGENTS rule 5 names only the first; nothing checks that an `any_peer` RPC starts with a server check | Steps 1 to 3 | in plan |
| 5 | The rules agents read are long and partly stale | `DECISIONS.md` 15,400 words (38 lines over 1,000 characters), read "before you start" by every agent; `AGENTS.md` still says "P7 co-op is being built now" and requires a Codex review that has been out of quota; agent gotchas live only in team memory, which Codex never sees | Steps 4 and 5 | in plan |
| 6 | Recipes miss co-op | `HOW_TO_ADD.md` "A buyable or machine" and "A new system" never mention `InteractionSync`, `owner_facts()` / `check_facts()` / `net_state()` or a client test, which is exactly how #138 happened | Step 1 | in plan |
| 7 | Log catalogue drifts | 3 `Log.warn` events in code are missing from `docs/LOGGING.md` (`connection_lost`, `join_failed`, `spawn_points_missing`); nothing checks it | CI rule in step 1 | in plan |
| 8 | A map is a copied session scene | `game_session.tscn` and `hub_session.tscn` differ in 2 lines; the results screen hardcodes "Halcyon Labs"; Halcyon Labs is built from `layout.json` by a GDScript tool, Lantern Post by a Python `.tscn` writer | `MapData` + one session scene, and an ADR picking one map builder, as the first step of the next match map (third use) | not now |
| 9 | Only gun damage is checked against the balance sheet | `test_sheet_damage.gd` checks damage; RPM, mag, reload are not | Wait until the v0.2 balance pass; the design-change skill covers it meanwhile | not now |
| 10 | Changing an RPC without bumping `Build.PROTOCOL_VERSION` | Editor builds all report version "dev", so only the protocol number separates them | The step 1 recipe says "bump the protocol"; a generated RPC list is more upkeep than it saves | not now |

Already planned elsewhere (not repeated here): gear visuals by id in
`look_builder.gd` (F-71 step 1 removes them), Co-op soak as a required check
(the person decides after a week of green runs; 20 of 20 recent runs green).

## Ready to build

```
### Ready to build
- Foundations touched: 1 co-op authority (shaky, this plan fixes it), 13 rules and docs
  (shaky, this plan fixes it), 9 tests and CI (solid; new rules), 2 content ids (solid; melee
  added to the id check), 11 asset pipeline (solid; step 10 only).
- Decision records: 0003 trusted client, 0004 one code path, 0007 signals, 0009 CI is the
  gate. Goes against none: who owns what does not change.
- Co-op:
  - Who decides: unchanged (server owns shared state, owners their movement and hits).
  - How a client triggers it: the same RPCs. Steps 2 and 3 move the well and loadout RPCs to
    new nodes (protocol +1 each); step 8 moves the match-end RPC (protocol +1).
  - What other players see: unchanged.
  - Works on a dedicated server with no local player: yes, nothing here needs one.
- Data: none. Code compares against a specific id anywhere: no.
- Save: no change.
- Events and UI: no new Events or screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
  (unchanged).
- Tests: tools/ci/test_check_rules.py for each new CI rule; every existing two-peer test
  stays green, with only node renames where a step moves code; tested-scripts needs a test
  naming each new file; soak and co-op soak.
- Logging: no new warnings; the three uncatalogued ones get rows (step 1).
- Performance: no runtime cost; steps only move code and add CI checks.
- Out of scope: see Scope.
```

## Design references

- `docs/adr/0003-trusted-client-co-op.md` (client asks, server decides),
  `docs/adr/0004-one-code-path.md` (solo is a server with one player),
  `docs/adr/0007-signals-and-events.md`, `docs/adr/0009-ci-is-the-gate.md`
- `docs/MULTIPLAYER.md` "Who owns what" (unchanged by this plan)
- `docs/FOUNDATIONS.md` rows 1, 9 and 13; `docs/KEEP_IT_SIMPLE.md` rules 2, 6, 11
- Project rule: CI green is the merge gate (the person's standing instruction);
  `AGENTS.md` "Merging" is brought in line with it in step 5.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| docs/MULTIPLAYER.md, HOW_TO_ADD.md, CODE_RULES.md, LOGGING.md, FOUNDATIONS.md, AGENTS.md (rule 5) | changed (step 1) | co-op patterns, recipe, rule docs, three log rows, row 1 |
| tools/ci/check_rules.py, test_check_rules.py | changed (steps 1, 4) | rules `rpc-rules`, `log-catalogue`, `decisions-short`; melee in `ID_FOLDERS` |
| systems/net/player_state_sync.gd, progression/progression_service.gd | changed (step 1) | first line of two RPCs is the server check |
| systems/damage/health_component.gd, weapons/gravity_well.gd, net/hit_claims.gd | changed (step 1) | `Net.is_authority() and multiplayer.is_server()` becomes `multiplayer.is_server()` |
| systems/net/well_claims.gd (new), hit_claims.gd, weapons/gravity_well.gd, game/game_session.gd, core/build.gd | changed (step 2) | gravity-well claims get their own node |
| systems/net/loadout_sync.gd (new), player_state_sync.gd, player/player.gd, loot/item_loadout.gd, loot/loot_service.gd, game/game_session.gd, core/build.gd, docs/plans/four-gear-slots.md | changed (step 3) | loadout submission gets its own node |
| docs/DECISIONS.md and the files that point to it | changed (step 4) | short lists |
| AGENTS.md, docs/PROCESS.md, docs/KEEP_IT_SIMPLE.md, docs/plans/TEMPLATE.md | changed (step 5) | reading map, stale lines, gotchas |
| systems/enemies/zombie.gd, weapons/weapon.gd, game/game_session.gd | changed (steps 6 to 8) | split by job into a new file each |
| tests/helpers/coop_side.gd | new (step 9) | shared co-op test side |
| .github/workflows/assets.yml, tools/assets/check_models.py | changed (step 10) | required models from `MODELS`; `JOINTS` default for static folders |

Autoloads, managers or base classes added: none. The new nodes in steps 2, 3
and 8 own state and RPCs that already exist; they are moved, not invented
(Keep it simple rule 4: split by job).

## Data

- No Resource types, `.tres` files or save fields change.
- Network: no RPC changes its name or arguments. Moving an RPC to another
  node changes its path on the wire, so each such step bumps
  `Build.PROTOCOL_VERSION` by one (step 2: `well_at`, `show_well`, `well_orb`,
  `show_well_orb` move to `WellClaims`; step 3: `submit_loadout` moves to
  `LoadoutSync`; step 8: `_receive_match_end` moves to `MatchEnd`). Old and new
  builds refuse each other cleanly. Tests compare against
  `Build.PROTOCOL_VERSION`, not a literal.
- Save format change: none.
- Content checks to add in `tests/content/`: none.

## Co-op behaviour

- Who owns the state: unchanged (`docs/MULTIPLAYER.md` "Who owns what").
- What clients send, what the server sends back: unchanged messages; some
  move node (see Data).
- What a client sees that the host sees too: unchanged.
- Late joiner: unchanged (session nodes ask on `connected_to_server`, nodes
  under a player ask in `_ready()` when not the server; step 1 writes both down).
- Dedicated server: nothing skipped.

## Performance

No runtime cost. Steps move code between nodes; the moved code keeps its
cached lookups (`HitClaims._weapons`, `find_player`), and no step adds work per
frame, per shot or per hit.

## Steps

One step = one PR = one fresh thread. Each step leaves the game playable and CI
green. Lanes that touch different files can run at the same time:

- Co-op: step 1, then 2, then 3.
- Docs: step 4, then 5 (both edit `AGENTS.md`, and step 1 edits rule 5:
  whichever lands later merges main first).
- Models: step 10 any time, ideally before F-77 step 2.
- Splits: steps 6 and 7 any time; step 8 after step 2 (both edit `game_session.gd`).
- Tests: step 9 after step 3 (steps 2 and 3 rename nodes those tests call).

### Step 1: The written co-op pattern and its CI checks

- Build:
  - `docs/MULTIPLAYER.md` new section "Writing co-op code", one short
    paragraph and a reference file each: (1) the server check: new node code
    asks `multiplayer.is_server()` (true in solo: the offline peer is the
    server), `Net.is_authority()` is for code with no node, never both; (2) a
    client request: a public `request_x()` that runs directly on the host and
    sends `rpc_id(1, ...)` from a client, an `@rpc("any_peer", "call_remote",
    "reliable")` handler whose first line returns unless `multiplayer.is_server()`,
    then the sender, the checks, the once-a-second refusal warning, then the
    same code solo runs (`InteractionSync`); (3) shared state plus the
    late-joiner snapshot (`WaveDirector`, `DeployVote`); (4) a grant to one
    owner with an ack (`InteractionSync.grant`, run XP); (5) a server-owned
    node under a client-owned Player (`set_multiplayer_authority(1)` in
    `_init()`, added in `Player._ready()`; `PlayerStateSync`, `Revive`);
    (6) a cosmetic relay (`RemoteShots`); plus "any network change bumps
    `Build.PROTOCOL_VERSION`".
  - `docs/HOW_TO_ADD.md`: new recipe "A co-op request or synced state"; co-op
    lines in "A buyable or machine" (`owner_facts()`, `check_facts()`,
    `net_state()`, a test that runs it from a client) and "A new system".
  - `AGENTS.md` code rule 5: the server check wording.
  - Code: the first line of `PlayerStateSync.submit_loadout` and
    `ProgressionService._acknowledge_run_xp` becomes the server check (both
    run only as RPCs, so behaviour is the same); the five `Net.is_authority()
    and multiplayer.is_server()` double checks become `multiplayer.is_server()`
    (one multiplayer in the game; in `TwoPeers` tests the root is offline, so
    the `Net` half was always true). `ProgressionService._is_authority()` stays
    (it also covers a node outside the tree, `test_xp_rules.gd`). The eight
    older `Net.is_authority()` calls in nodes stay as they are; converting them
    changes what client-side test subtrees do, for no player gain.
  - CI rule `rpc-rules` in `tools/ci/check_rules.py`, documented in
    `docs/CODE_RULES.md`: (a) every `@rpc` names its mode and a transfer mode
    (Godot's default transfer is unreliable, a silent trap for state); (b) the
    first code line of an `any_peer` RPC's body (after a multi-line signature,
    skipping comments) contains `multiplayer.is_server()`.
  - CI rule `log-catalogue`: every event name in `Log.warn(&"<system>",
    &"<event>"` in `core/` and `systems/` appears as a word in
    `docs/LOGGING.md`; add the three missing rows. Events passed as variables
    are not checked (say so in CODE_RULES).
  - Add `content/melee/` to `ID_FOLDERS` in `check_rules.py`.
  - `docs/FOUNDATIONS.md` row 1: solid.
- Files: the docs above, player_state_sync.gd, progression_service.gd,
  health_component.gd, gravity_well.gd, hit_claims.gd, check_rules.py,
  test_check_rules.py.
- Tests: `tools/ci/test_check_rules.py`: (a) and (b) each fail on a bad sample
  and pass on a good one (including a multi-line signature and a comment
  before the check); an uncatalogued warning fails, a catalogued one passes;
  a melee id literal fails. Existing two-peer tests pass unchanged.
- Done when: `check_rules.py` passes with the new rules; foundation 1 is solid.

### Step 2: Gravity-well claims get their own node

- Build: new `systems/net/well_claims.gd` (`WellClaims`), a session child next
  to `HitClaims`, owns the well requests and their state: `request_well`,
  `well_at`, `_well_weapon`, `_accept_well`, `show_well`, `send_well_orb`,
  `well_orb`, `_relay_well_orb`, `show_well_orb`, `_remember_well_launch`,
  `_well_in_range`, `_take_orb_claim`, `_orb_claims`, `_well_launches`, plus
  its own `_time` and peer cleanup. It keeps a reference to `HitClaims` for
  what both share: the per-gun claim window and the refusal warning become
  public `take_claim()` and `reject()` (rename the `RecordingClaims` override
  in `well_claims_fixture.gd` with it) and the cached guns. `confirm_well_hit`
  and `well_hit` stay in `HitClaims` (collateral kills use them too).
  `GravityWell` calls by name and string, so a miss only fails at run time:
  orbs look up `"WellClaims"` (gravity_well.gd lines 43, 50, 217), while an
  opened well keeps the `HitClaims` reference for its hit confirm (line 194),
  which `WellClaims._accept_well` passes to `GravityWell.open`. Protocol +1.
- Files: hit_claims.gd, well_claims.gd (new), gravity_well.gd,
  game_session.gd (`_setup_shooting` adds the node), core/build.gd,
  tests/unit/well_claims_fixture.gd and the well tests.
- Tests: `test_well_claims`, `test_well_weapon_claims`, `test_siphon_orb`
  pass with only the fixture wiring changed; a new assertion that an orb and
  a well opened from a client reach the server through `WellClaims`
  (fails if `GravityWell` still looks for `HitClaims`). `test_handshake` passes.
- Done when: hit_claims.gd under 260 lines; both soaks green.

### Step 3: Loadout submission gets its own node

- Build: new `systems/net/loadout_sync.gd` (`LoadoutSync`), a server-owned
  child of the Player like `PlayerStateSync` (authority 1 in `_init()`), owns
  `gear`, `GEAR_SLOTS`, `send_loadout`, `submit_loadout`, `_loadout_problem`
  and `_apply_loadout`. Callers switch to it: `item_loadout.gd:12`,
  `loot_service.gd:59`, `game_session.gd:171` and the tests. The
  `loadout_rejected` warning stays unthrottled (`test_gear_health_sync`
  expects three in a row). Protocol +1. Update `four-gear-slots.md` step 1
  (it edits this code): `loadout_sync.gd` instead of `player_state_sync.gd`.
- Files: player_state_sync.gd, loadout_sync.gd (new), player.gd,
  item_loadout.gd, loot_service.gd, game_session.gd, core/build.gd,
  docs/plans/four-gear-slots.md, tests naming the moved functions.
- Tests: `test_gear_health_sync`, `test_item_effects_coop`,
  `test_loot_service` pass after only renaming the node they call; a
  `LoadoutSync` test (tested-scripts) that a client's loadout reaches the server.
- Done when: player_state_sync.gd under 300 lines; both soaks green.

### Step 4: DECISIONS.md becomes short lists

- Build: rewrite `docs/DECISIONS.md` as three lists, one line per entry (at
  most 300 characters, a link to the plan, ADR or issue for detail):
  **Differs from the design on purpose** (what the design-change skill writes;
  this stays the one home for design overrides, so the design docs' "DECISIONS
  wins" headers stay true), **Simplified on purpose** (each with "fix when"),
  **Provisional picks** (agent picks the person may change). Each of today's
  122 entries is either deleted (the plan, ADR, recipe or a code comment
  already says it; the PR lists where) or cut to one line in a list. The
  "Built" and "Not started" sections go (plans and `docs/ROADMAP.md` hold
  them). Update every pointer so it still reads right: `AGENTS.md` (read the
  entries for the systems you touch, not the whole file), `README.md`,
  `docs/PROCESS.md` definition of done ("one line per simplification or
  design difference"), `docs/FOUNDATIONS.md` row 13 ("stays the build log"),
  `docs/MULTIPLAYER.md`, `docs/HOW_TO_ADD.md`, `docs/adr/README.md` and
  `0010`, `docs/plans/TEMPLATE.md`, `docs/design/README.md` and the design
  docs that cite a specific entry (`gear-visuals.md`, `controls.md`,
  `gun-roster.md`), `tests/content/test_look_reference.gd`, and the
  finish-feature, design-change and write-plan skills
  (`python tools/ci/check_skills_mirror.py --fix`). CI rule `decisions-short`:
  every list entry in `DECISIONS.md` is one line of at most 300 characters.
- Files: docs/DECISIONS.md, the files above, check_rules.py,
  test_check_rules.py, docs/CODE_RULES.md.
- Tests: `test_check_rules.py`: a long or wrapped entry fails, a short one
  passes. The PR description has a table: every old entry and where it went.
- Done when: DECISIONS.md under 2,500 words; `rg -n DECISIONS` shows no
  pointer that describes the old build log; CI green.

### Step 5: AGENTS.md is the one entry point

- Build: `AGENTS.md` opens with a reading map: for every task this file;
  feature: roadmap row, plan, foundations; co-op: MULTIPLAYER.md "Writing
  co-op code"; new content: HOW_TO_ADD.md; visual: design/README.md and
  look-rules.md; bug or crash: LOGGING.md. Fix stale lines ("P7 co-op is being
  built now"; "Merging" follows the person's standing rule that CI green is
  the merge gate, with the Codex review fixed in the PR when it arrives, else
  in a follow-up). New short "Gotchas" section from team memory: `godot -s`
  scripts skip autoloads (use a temp scene); run `--import` after pulling
  main; never commit an editor-churned `project.godot` or editor-local uids;
  the game pauses on focus loss; kit models use light_baking 2, dynamic actors
  3. One home per rule: the Keep it simple list stays in AGENTS.md and
  `KEEP_IT_SIMPLE.md` keeps examples only; CI details stay in `CODE_RULES.md`.
  `KEEP_IT_SIMPLE.md` deferred table: "`MapData` and one session scene: when
  the second match map starts" and "an ADR picking one map builder: before the
  next map plan". `docs/plans/TEMPLATE.md` Systems touched: "Files over 300
  lines this plan grows: split by job first, as its own step".
  `docs/FOUNDATIONS.md` row 13: solid; "Last full check" date.
- Files: AGENTS.md, docs/KEEP_IT_SIMPLE.md, docs/plans/TEMPLATE.md,
  docs/FOUNDATIONS.md.
- Tests: none (docs only); `check_plans.py` still passes on the template change.
- Done when: `AGENTS.md` under 2,300 words with the map and gotchas;
  foundation 13 solid.

### Step 6: Split zombie.gd

- Build: window entry and vault (`_tick_entering`, `_tick_vault`,
  `vault_progress` and their state) move to `systems/enemies/zombie_entry.gd`,
  owned by the zombie. Callers of `vault_progress` switch (`zombie_rig.gd`,
  `test_barriers.gd`, `test_zombie_rig.gd`). No behaviour change.
- Files: zombie.gd, zombie_entry.gd (new), zombie_rig.gd, the tests above.
- Tests: barrier and window-spawn tests pass with only the call renamed; a
  test names `ZombieEntry` (tested-scripts); soak green.
- Done when: zombie.gd under 300 lines.

### Step 7: Split weapon.gd

- Build: viewmodel pose and visuals (`_update_pose`, `_pose_moving_parts`,
  `_find_moving_parts`, `_set_flash`, `_play_mech`, the `_process` body) move
  to `systems/weapons/weapon_pose.gd`, a child the weapon owns. Callers in
  tests switch (`test_loot_rifles.gd` calls `_set_flash`). No behaviour change.
- Files: weapon.gd, weapon_pose.gd (new), tests.
- Tests: viewmodel, recoil and fire tests pass with only the call renamed; a
  test names `WeaponPose` (tested-scripts).
- Done when: weapon.gd under 300 lines.

### Step 8: Split game_session.gd

- Build: match end and results (`check_squad`, `_end_match`,
  `_receive_match_end`, `bank_run_xp`, `finish_exfil` and the kill counters)
  move to `systems/game/match_end.gd` (`MatchEnd`), a child node the session
  wires. Callers switch: `player_state_sync.gd` (`check_squad`),
  `exfil_hatch.gd` (`finish_exfil`), `tests/integration/net_deploy_server.gd`,
  `tests/manual/main_menu_flow.gd` (calls by string), `test_squad_game_over`,
  `test_character_save`. The `_receive_match_end` RPC moves node: protocol +1.
- Files: game_session.gd, match_end.gd (new), player_state_sync.gd,
  exfil_hatch.gd, core/build.gd, the tests above.
- Tests: run-end, squad game over, exfil and results tests pass after
  renaming the node they call; a test names `MatchEnd` (tested-scripts).
- Done when: game_session.gd under 300 lines; both soaks green.

### Step 9: Shared co-op test side

- Build: `tests/helpers/coop_side.gd` (`CoopSide`): makes a `TwoPeers` side
  with a `GameSession` and the parts a test asks for, wired the way
  `GameSession._setup_level()` and `_setup_shooting()` wire them. Move the
  files that build a two-peer session side by hand onto it: `test_chain`
  (sides built in `before_each`), `test_double_barrel_coop`, `test_hit_claims`,
  `test_item_effects_coop`, `test_loot_service`, `test_pierce_claims`,
  `test_prototype_claims` (`_side`), `test_remote_impacts`,
  `test_remote_shots`, `test_zombie_sync`, and the two fixtures
  `well_claims_fixture.gd` and `coop_interaction_fixture.gd`. Sides that need
  no session keep their short `TwoPeers` calls.
- Files: tests/helpers/coop_side.gd (new), the tests and fixtures above.
- Tests: the same assertions pass.
- Done when: no two-peer test builds a `GameSession` side by hand outside
  `tests/helpers/`.

### Step 10: Assets CI lists models from the registry

- Build: the "Build every model headless" step checks every `MODELS` entry
  was built and every committed `.glb` under `assets/models/` is a `MODELS`
  entry or a known hand-over (gun intake); the hand list in `assets.yml` goes.
  `check_models.py` treats a model with no `JOINTS` line as `{}` only in the
  static folders (kit, props, props_large, dressing, doors, machines, town,
  town_large); guns, zombies, characters and gear still need their entry. The
  `{}` lines for static models go. Land before F-77 step 2 if possible.
- Files: .github/workflows/assets.yml, tools/assets/check_models.py, a small
  `tools/assets/check_outputs.py` (new), its pytest.
- Tests: pytest: a missing build output fails, a stray committed `.glb` fails,
  a static prop with no `JOINTS` line passes, a gun with no entry still fails.
- Done when: adding a static prop touches only its family script and the
  catalogue.

## Acceptance

- [ ] `docs/FOUNDATIONS.md` rows 1 and 13 say solid, with the reason.
- [ ] Every `any_peer` RPC starts with the server check; `rpc-rules` enforces it.
- [ ] `docs/MULTIPLAYER.md` "Writing co-op code" and the HOW_TO_ADD co-op recipe exist.
- [ ] `docs/DECISIONS.md` is short lists only; `decisions-short` enforces it.
- [ ] `AGENTS.md` has the reading map and gotchas; `log-catalogue` keeps the catalogue in sync.
- [ ] Steps 6 to 10 merged; audit ranks 8 to 10 stay listed as "not now".
- [ ] Soak and co-op soak green after every step.

## Risks

- **A split changes behaviour by accident.** Steps 2, 3, 6, 7 and 8 move code;
  the existing tests, the soak and the nightly co-op soak are the proof. A step
  that needs to change a test assertion (not just a node name) stops and says why.
- **Calls by name or string miss a moved function.** `GravityWell` finds
  `"HitClaims"` by name and calls by string; `main_menu_flow.gd` calls by
  string. Each step lists them and adds a test that fails if the lookup misses.
- **Steps 2, 3 and 8 move RPCs to new nodes.** Wrong node paths fail loudly
  in the two-peer tests; each protocol bump keeps old builds out.
- **DECISIONS cut loses a rule.** The step 4 PR lists every old entry and
  where it went; design overrides stay in DECISIONS as one-liners.
- **Parallel threads edit the same files.** F-71 step 1 edits loadout code:
  step 3 updates its plan; whichever lands later merges main first and bumps
  the protocol again.
- **CI rule too strict for a real case.** Each rule has a test for the good
  case; a real exception gets a one-line reason in the rule, not a weaker rule.

## Open decisions

- [x] Approve steps 1 to 5 (foundations 1 and 13)? Approved by the person on the decision card, 2026-11-18.
- [x] Audit 1: split zombie.gd, weapon.gd and game_session.gd now (steps 6 to 8)? Yes, split them now (the person, decision card, 2026-11-18).
- [x] Audit 2: one shared co-op test side instead of the hand-built copies (now step 9: review found 12 real copies, so one PR)? Yes (the person, decision card, 2026-11-18).
- [x] Audit 3: Assets CI lists models from the registry (now step 10)? Yes, before more F-77 props (the person, decision card, 2026-11-18).
