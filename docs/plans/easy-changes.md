# Plan: Easy, safe changes (co-op request pattern, short agent docs, audit fixes)

Status: Review
Roadmap: F-79 / no issue
Phase: P7 (co-op foundation) and process; no gameplay change
Size: L
Approved by:

## Goal

Adding or changing a feature should not mean re-inventing co-op plumbing or
digging through 20,000 words of notes. This plan makes the two **shaky**
foundations in `docs/FOUNDATIONS.md` solid (1: co-op authority, 13: rules and
docs agents read), then fixes the audit findings the person picks. It serves
every pillar indirectly: features land faster and with fewer co-op bugs.

## Scope

In:

- **Co-op (foundation 1):** one small server-side helper for client requests
  (`RequestGate`), every existing request handler moved onto it, one way to ask
  "am I the server", the five co-op message patterns written down once, a CI
  rule that enforces the shape, and the two co-op scripts at the 350-line cap
  split by job.
- **Docs (foundation 13):** `docs/DECISIONS.md` cut from a 15,400-word build log
  to short one-line lists; `AGENTS.md` becomes the one entry point with a
  reading map per task, stale lines fixed and the agent gotchas moved into the
  repo; CI keeps both short and in sync.
- **Audit fixes** the person picks (steps 6 to 11, pending the decision cards).

Not in (non-goals, and where each one goes instead):

- Rewriting the state RPCs as `MultiplayerSynchronizer`s: they work and are
  tested; a rewrite is risk with no player gain (never, unless a bug needs it).
- New rate limits: only `InteractionSync` (min gap) and `HitClaims` (per-gun
  window) have them today and keep their own; other requests do not need one.
- Prediction, interpolation or lag compensation (ADR 0003; new ADR first).
- `MapData` and one session scene, and one map-building pipeline: wait for the
  next match map (step 5 writes the trigger into the deferred table).
- Audit items marked "not now" below.

## Audit findings (ranked by payoff)

Checked 2026-11-18 on main `e3c1b65`. Numbers are counted from the code.

| Rank | Finding | Evidence | Fix | Pick |
|---|---|---|---|---|
| 1 | Core scripts sit exactly at the 350-line cap | `weapon.gd`, `zombie.gd`, `game_session.gd`, `hit_claims.gd`, `player_state_sync.gd` all 350; `net.gd` 349, `player.gd` 346. v0.2 grenades, new zombies, skills and legendaries all edit them, so each would be forced into a rushed split mid-feature | Split by job now, one small move-only PR per file; existing tests prove nothing changed. The two co-op files are step 3 (in this plan); the other three are steps 6 to 8 | card |
| 2 | 17 tests hand-build their own co-op session | 17 files each write a `_make_side()` that copies `GameSession` wiring (World, Economy, Progression, Spawner, HitClaims, RemoteShots, PlayerSpawner). `no-triple-copy` skips tests, so CI never flagged it. When the wiring changes, these tests keep passing against a session the game no longer has | One helper in `tests/helpers/` that builds a co-op side from the same wiring; move the 17 files onto it (steps 9 and 10) | card |
| 3 | A new model is listed by hand in four places | `build_models.py` `MODELS`, `JOINTS` in `check_models.py` (`{}` for every static prop), a hand list of ~130 files in `.github/workflows/assets.yml`, and the F-77 catalogue. `assets.yml` changed in 13 of the last 50 commits; F-77 adds about 75 models | Assets CI derives the required files from `MODELS` and checks every committed `.glb` is in it; static props need no `JOINTS` line (step 11) | card |
| 4 | Co-op code is written 3+ ways | 39 RPCs in 15 scripts; 3 ways to find the sender's player; 2 copies of the "one warning a second" refusal log; "am I the server" asked as `Net.is_authority()` (19), `multiplayer.is_server()` (99) and both (5) while AGENTS rule 5 names only the first | Steps 1 to 3 | in plan |
| 5 | The rules agents read are long and partly stale | `DECISIONS.md` 15,400 words (38 lines over 1,000 characters), read "before you start" by every agent; `AGENTS.md` still says "P7 co-op is being built now" and requires a Codex review that has been out of quota; agent gotchas live only in team memory, which Codex never sees | Steps 4 and 5 | in plan |
| 6 | Recipes miss co-op | `HOW_TO_ADD.md` "A buyable or machine" and "A new system" never mention `InteractionSync`, `owner_facts()` / `check_facts()` / `net_state()` or a client test, which is exactly how #138 happened | Step 2 | in plan |
| 7 | Log catalogue drifts | 3 `Log.warn` events in code are missing from `docs/LOGGING.md` (`connection_lost`, `join_failed`, `spawn_points_missing`); nothing checks it | CI rule in step 5 | in plan |
| 8 | A map is a copied session scene | `game_session.tscn` and `hub_session.tscn` differ in 2 lines; the results screen hardcodes "Halcyon Labs"; Halcyon Labs is built from `layout.json` by a GDScript tool, Lantern Post by a Python `.tscn` writer | `MapData` + one session scene, and an ADR picking one map builder, as the first step of the next match map (third use) | not now |
| 9 | Only gun damage is checked against the balance sheet | `test_sheet_damage.gd` checks damage; RPM, mag, reload are not | Wait until the v0.2 balance pass; the design-change skill covers it meanwhile | not now |
| 10 | Changing an RPC without bumping `Build.PROTOCOL_VERSION` | Editor builds all report version "dev", so only the protocol number separates them | The step 2 recipe says "bump the protocol"; a generated RPC list is more upkeep than it saves | not now |

Already planned elsewhere (not repeated here): gear visuals by id in
`look_builder.gd` (F-71 step 2 removes them), Co-op soak as a required check
(the person decides after a week of green runs; 20 of 20 recent runs green).

## Ready to build

```
### Ready to build
- Foundations touched: 1 co-op authority (shaky, this plan fixes it), 13 rules and docs
  (shaky, this plan fixes it), 9 tests and CI (solid; new rules), 2 content ids (solid; melee
  added to the id check), 11 asset pipeline (solid; step 11 only).
- Decision records: 0003 trusted client, 0004 one code path, 0007 signals, 0009 CI is the
  gate. Goes against none: who owns what does not change.
- Co-op:
  - Who decides: unchanged (server owns shared state, owners their movement and hits).
  - How a client triggers it: the same RPCs; their first line now asks RequestGate for the
    sender. Step 3 moves the well and loadout RPCs to new nodes (protocol bump).
  - What other players see: unchanged.
  - Works on a dedicated server with no local player: yes, RequestGate needs no local player.
- Data: none. Code compares against a specific id anywhere: no.
- Save: no change.
- Events and UI: no new Events or screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
  (unchanged).
- Tests: tests/unit/test_request_gate.gd (new); every existing two-peer test stays green
  unchanged; tools/ci/test_check_rules.py for each new CI rule; soak and co-op soak.
- Logging: RemoteShots and LookSync start logging refused packets (one warning a second);
  rows added to docs/LOGGING.md.
- Performance: RequestGate allocates nothing per accepted request; it finds the player through
  PlayerSpawner.find_player (a node lookup, no array). Refusal warnings are throttled.
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
| systems/net/request_gate.gd | new (step 1) | `RequestGate`: sender, sender's player, throttled refusal |
| systems/net/interaction_sync.gd, hit_claims.gd, remote_shots.gd, look_sync.gd, player_state_sync.gd | changed (step 1) | request handlers use RequestGate |
| systems/player/revive.gd, economy/economy.gd, game/deploy_vote.gd, waves/wave_director.gd, progression/progression_service.gd | changed (step 2) | request handlers use RequestGate; one server check |
| systems/damage/health_component.gd, weapons/gravity_well.gd, net/hit_claims.gd | changed (step 2) | `Net.is_authority() and multiplayer.is_server()` becomes `multiplayer.is_server()` |
| systems/net/well_claims.gd, systems/net/loadout_sync.gd | new (step 3) | moved out of hit_claims.gd and player_state_sync.gd |
| core/build.gd | changed (step 3) | `PROTOCOL_VERSION` 17 to 18 |
| tools/ci/check_rules.py, test_check_rules.py | changed (steps 2, 4, 5) | rules `rpc-rules`, `decisions-short`, `log-catalogue`; melee in `ID_FOLDERS` |
| docs/MULTIPLAYER.md, HOW_TO_ADD.md, CODE_RULES.md, FOUNDATIONS.md | changed (steps 2, 5) | co-op patterns, recipe, rule docs, rows 1 and 13 |
| docs/DECISIONS.md, docs/design/*.md | changed (step 4) | cut to short lists; design overrides moved into their design doc |
| AGENTS.md, docs/PROCESS.md, docs/KEEP_IT_SIMPLE.md, docs/plans/TEMPLATE.md, .agents/skills/{finish-feature,design-change,write-plan} | changed (steps 4, 5) | reading map, stale lines, gotchas, DECISIONS references |
| systems/enemies/zombie.gd, weapons/weapon.gd, game/game_session.gd | changed (steps 6 to 8, if picked) | split by job into a new file each |
| tests/helpers/coop_side.gd | new (steps 9 and 10, if picked) | shared co-op test side |
| .github/workflows/assets.yml, tools/assets/check_models.py | changed (step 11, if picked) | required models from `MODELS`; `JOINTS` default |

Autoloads, managers or base classes added: none. `RequestGate` is a small
`RefCounted` that owns state (the warning throttle) and replaces code copied in
three or more places (Keep it simple rules 2 and 6).

## Data

- No Resource types, `.tres` files or save fields change.
- Network: no RPC changes its name or arguments. Step 3 moves the gravity-well
  RPCs (`well_at`, `show_well`, `well_orb`, `well_hit`, `show_well_orb`) to a
  `WellClaims` node and `submit_loadout` to a `LoadoutSync` node, which changes
  their node paths on the wire: `Build.PROTOCOL_VERSION` goes 17 to 18, so old
  and new builds refuse each other cleanly.
- Save format change: none.
- Content checks to add in `tests/content/`: none.

## Co-op behaviour

- Who owns the state: unchanged (`docs/MULTIPLAYER.md` "Who owns what").
- What clients send, what the server sends back: unchanged messages. Each
  request handler's first line becomes `_gate.sender_player(players)` or
  `_gate.sender()`; null or 0 means "not the server, or not a remote call", and
  the handler returns.
- What a client sees that the host sees too: unchanged.
- Late joiner: unchanged (the five snapshot requests keep their timing:
  session nodes ask on `connected_to_server`, nodes under a player ask in
  `_ready()` when not the server; step 2 writes both down).
- Dedicated server: nothing skipped; RequestGate needs no local player.

## Performance

No per-frame cost. Per request: one `get_remote_sender_id()` and one
`find_player()` (node lookup), the same as today in `HitClaims`. Hit claims
(the hottest path, up to pellets x fire rate) must not loop the players group;
the test in step 1 checks `sender_player()` uses the spawner when it is given.

## Steps

One step = one PR = one fresh thread. Each step leaves the game playable and CI
green. Steps 1 to 5 need only this plan's approval; steps 6 to 11 wait for the
person's picks.

### Step 1: RequestGate and the systems/net handlers

- Build: `systems/net/request_gate.gd`, `class_name RequestGate extends
  RefCounted`, made with the owning node and its refusal event name:
  `sender() -> int` (the remote sender when this peer is the server and the
  call came from another peer, else 0), `sender_player(players: PlayerSpawner)
  -> Player` (that sender's player through `find_player`, else null),
  `refuse(peer: int, reason: StringName, details: Dictionary = {})` (one
  `Log.warn(&"net", <event>, ...)` a second at most, wall-clock throttle; it is
  logging, not gameplay). Move the request handlers of `InteractionSync`
  (`request_interact`, `_request_snapshot`, `_grant_applied`), `HitClaims`
  (`claim_hit`, `well_at`, `well_orb`), `RemoteShots.shot`, `LookSync._submit_look`
  and `PlayerStateSync` (`_send_snapshot`, `submit_loadout`) onto it, deleting
  their own sender lookups and the two `_next_warning` throttles. Same checks,
  same results; `RemoteShots` and `LookSync` now log refusals.
- Files: request_gate.gd (new), the five scripts above, docs/LOGGING.md (two
  new rows), tests.
- Tests: `tests/unit/test_request_gate.gd` (new, uses `TwoPeers`): sender is 0
  on a client and for a local call, the right peer on the server;
  `sender_player()` returns that peer's player and null for an unknown peer;
  two refusals in a row log once. Existing `test_interaction_sync`,
  `test_hit_claims`, `test_remote_shots`, `test_look_sync`,
  `test_player_state_sync` and the well tests pass unchanged.
- Done when: no script in `systems/net/` reads `get_remote_sender_id()` except
  `RequestGate`; CI green including both soaks.

### Step 2: The rest of the handlers, one server check, the written pattern and CI

- Build: move `Revive._request`, `Economy._request_points` (GameSession sets
  `economy.session` like `director.session`), `DeployVote._request_snapshot`,
  `WaveDirector._request_round_state` and `ProgressionService._acknowledge_run_xp`
  onto RequestGate (the hand-written player loops in Revive and Economy go).
  Gameplay code in a node asks `multiplayer.is_server()`; `Net.is_authority()`
  stays only where there is no node. Remove the five double checks and
  `ProgressionService._is_authority()` if its disconnected-peer case is covered
  by a test, else keep it with a one-line reason. Write the pattern:
  - `docs/MULTIPLAYER.md` new section "Writing co-op code", one short
    paragraph and a reference file each: (1) which server check to use, (2) a
    client request (`InteractionSync`), (3) shared state plus the late-joiner
    snapshot (`WaveDirector`, `DeployVote`), (4) a grant to one owner with an
    ack (`InteractionSync.grant`, run XP), (5) a server-owned node under a
    client-owned Player (`set_multiplayer_authority(1)` in `_init()`, added in
    `Player._ready()`), (6) a cosmetic relay (`RemoteShots`), plus "any
    network change bumps `Build.PROTOCOL_VERSION`".
  - `docs/HOW_TO_ADD.md`: new recipe "A co-op request or synced state";
    co-op lines in "A buyable or machine" (`owner_facts()`, `check_facts()`,
    `net_state()`, a client test) and "A new system".
  - `AGENTS.md` code rule 5: the server check wording.
  - CI rule `rpc-rules` in `tools/ci/check_rules.py`, documented in
    `docs/CODE_RULES.md`: (a) every `@rpc` names its mode and transfer mode
    (Godot's default transfer is unreliable, a silent trap for state); (b) the
    first code line of an `any_peer` RPC calls `.sender(` or
    `.sender_player(`; (c) a `core/` or `systems/` script with an `any_peer`
    RPC is named in a test that uses `TwoPeers`.
  - `docs/FOUNDATIONS.md` row 1: solid.
- Files: the five scripts above, game_session.gd (one line), health_component.gd,
  gravity_well.gd, hit_claims.gd, check_rules.py, test_check_rules.py, the docs above.
- Tests: `tools/ci/test_check_rules.py`: each of (a), (b), (c) fails on a bad
  sample and passes on a good one; existing `test_player_state_sync` (revive),
  `test_solo_coop_switch`, `test_interaction_sync` (points), `test_deploy_vote`,
  `test_coop_round_state` and `test_run_end_grants` pass unchanged.
- Done when: `check_rules.py` passes with the new rule; `rg get_remote_sender_id
  core systems` finds only `request_gate.gd`; foundation 1 is solid.

### Step 3: Split the two co-op scripts at the cap

- Build: move the gravity-well claims out of `hit_claims.gd` into
  `systems/net/well_claims.gd` (`WellClaims`, a sibling node GameSession adds
  next to `HitClaims`) and the loadout submission (`send_loadout`,
  `submit_loadout`, `_loadout_problem`, `_apply_loadout`) out of
  `player_state_sync.gd` into `systems/net/loadout_sync.gd` (`LoadoutSync`,
  server-owned child of the Player like `PlayerStateSync`). Move only; no
  behaviour change. `Build.PROTOCOL_VERSION` 17 to 18. Update the F-71 plan's
  file names (`four-gear-slots.md` step 2 edits `loadout_sync.gd`).
- Files: hit_claims.gd, well_claims.gd (new), player_state_sync.gd,
  loadout_sync.gd (new), player.gd (adds LoadoutSync), game_session.gd,
  core/build.gd, docs/plans/four-gear-slots.md, tests that name the moved functions.
- Tests: the well tests (`test_well_claims`, `test_well_weapon_claims`,
  `test_siphon_orb`) and loadout tests (`test_gear_health_sync`,
  `test_item_effects_coop`, `test_loot_service`) pass after only renaming the
  node they call; `test_handshake` still passes with protocol 18.
- Done when: both old files are under 300 lines; both soaks green.

### Step 4: DECISIONS.md becomes short lists

- Build: rewrite `docs/DECISIONS.md` as three lists, one line per entry
  (at most 300 characters, a link to the plan, ADR or issue for detail):
  **Differs from the design on purpose** (what the design-change skill writes),
  **Simplified on purpose** (each with "fix when"), **Provisional picks** (agent
  picks the person may change). Each of today's 122 entries is either deleted
  (the plan, ADR, recipe or code comment already says it; the PR lists where),
  cut to one line, or moved into the design doc whose number it overrides. The
  "Built" and "Not started" sections go (plans and `docs/ROADMAP.md` hold
  them). Update the references: `AGENTS.md` (read the entries for the systems
  you touch, not the whole file), `docs/PROCESS.md` definition of done ("one
  line per simplification or design difference"), the finish-feature,
  design-change and write-plan skills, `docs/plans/TEMPLATE.md`,
  `docs/HOW_TO_ADD.md`. CI rule `decisions-short`: every list entry in
  `DECISIONS.md` is one line of at most 300 characters.
- Files: docs/DECISIONS.md, the docs and skills above (run
  `python tools/ci/check_skills_mirror.py --fix`), check_rules.py,
  test_check_rules.py, docs/CODE_RULES.md.
- Tests: `test_check_rules.py`: a long entry fails, a short one passes. The PR
  description has a table: every old entry and where it went.
- Done when: DECISIONS.md under 2,500 words; CI green.

### Step 5: AGENTS.md is the one entry point

- Build: `AGENTS.md` opens with a reading map: for every task this file;
  feature: roadmap row, plan, foundations; co-op: MULTIPLAYER.md "Writing
  co-op code"; new content: HOW_TO_ADD.md; visual: design/README.md and
  look-rules.md; bug or crash: LOGGING.md. Fix stale lines ("P7 co-op is being
  built now"; "Merging" says CI green is the gate, Codex review when it runs,
  its findings fixed in the PR or a follow-up). New short "Gotchas" section
  from team memory: `godot -s` scripts skip autoloads (use a temp scene); run
  `--import` after pulling main; never commit an editor-churned
  `project.godot` or editor-local uids; the game pauses on focus loss; kit
  models use light_baking 2, dynamic actors 3. One home per rule:
  `KEEP_IT_SIMPLE.md` keeps examples only, `CODE_RULES.md` the CI details.
  CI rule `log-catalogue`: every `Log.warn(&"<system>", &"<event>"` in `core/`
  and `systems/` appears in `docs/LOGGING.md` (add the three missing rows).
  Add `content/melee/` to `ID_FOLDERS`. `KEEP_IT_SIMPLE.md` deferred table:
  "`MapData` and one session scene: when the second match map starts" and "an
  ADR picking one map builder: before the next map plan".
  `docs/plans/TEMPLATE.md` Systems touched: "Files over 300 lines this plan
  grows: split by job first, as its own step". `docs/FOUNDATIONS.md` row 13:
  solid; "Last full check" date.
- Files: AGENTS.md, docs/KEEP_IT_SIMPLE.md, CODE_RULES.md, LOGGING.md,
  FOUNDATIONS.md, plans/TEMPLATE.md, check_rules.py, test_check_rules.py.
- Tests: `test_check_rules.py`: an uncatalogued warning fails, a catalogued
  one passes; a melee id literal in code fails.
- Done when: `AGENTS.md` under 2,700 words with the map and gotchas;
  foundation 13 solid.

### Step 6: Split zombie.gd (if picked)

- Build: window entry and vault (`_tick_entering`, `_tick_vault`,
  `vault_progress` and their state) move to `systems/enemies/zombie_entry.gd`.
  Move only.
- Files: zombie.gd, zombie_entry.gd (new), tests naming the moved functions.
- Tests: barrier and window-spawn tests pass unchanged; soak green.
- Done when: zombie.gd under 300 lines.

### Step 7: Split weapon.gd (if picked)

- Build: viewmodel pose and visuals (`_update_pose`, `_pose_moving_parts`,
  `_find_moving_parts`, `_set_flash`, `_play_mech`, the `_process` body) move
  to `systems/weapons/weapon_pose.gd`, a child the weapon owns. Move only.
- Files: weapon.gd, weapon_pose.gd (new), tests.
- Tests: viewmodel, recoil and fire tests pass unchanged.
- Done when: weapon.gd under 300 lines.

### Step 8: Split game_session.gd (if picked)

- Build: match end and results (`check_squad`, `_end_match`,
  `_receive_match_end`, `bank_run_xp`, `finish_exfil` and the kill counters)
  move to `systems/game/match_end.gd`, a child node the session wires. Move
  only; the `_receive_match_end` RPC moves node, so protocol bump.
- Files: game_session.gd, match_end.gd (new), core/build.gd, tests.
- Tests: run-end, squad game over and results tests pass after renaming the
  node they call.
- Done when: game_session.gd under 300 lines.

### Step 9: Shared co-op test side (if picked)

- Build: `tests/helpers/coop_side.gd` (`CoopSide`): makes a `TwoPeers` side with
  a `GameSession` and the parts a test asks for, wired the way
  `GameSession._setup_level()` and `_setup_shooting()` wire them. Move the
  hit-claim family onto it (`test_hit_claims`, `test_pierce_claims`,
  `test_double_barrel_coop`, `test_item_effects_coop`, `test_prototype_claims`,
  `test_chain`, `test_remote_shots` and `well_claims_fixture.gd`).
- Files: tests/helpers/coop_side.gd (new), the eight tests.
- Tests: the same assertions pass; each test loses its `_make_side()`.
- Done when: those eight files have no `_make_side()`.

### Step 10: The other co-op tests (if picked)

- Build: move the other nine copies onto `CoopSide` (`test_handshake`,
  `test_look_sync`, `test_loot_service`, `test_player_arm_coop`,
  `test_player_spawner`, `test_player_state_sync`, `test_pose_sync`,
  `test_run_end_grants`, `test_zombie_sync`); a side that needs no session may
  keep its three-line `TwoPeers` call. Move `coop_interaction_fixture.gd` and
  `well_claims_fixture.gd` into `tests/helpers/`.
- Files: the nine tests, the two fixtures.
- Tests: the same assertions pass.
- Done when: `rg "func _make_side" tests` finds nothing outside `tests/helpers/`.

### Step 11: Assets CI lists models from the registry (if picked)

- Build: the "Build every model headless" step checks every `MODELS` entry was
  built and every committed `.glb` under `assets/models/` is a `MODELS` entry
  or a known hand-over (gun intake); the hand list in `assets.yml` goes.
  `check_models.py` treats a model with no `JOINTS` line as a static prop (`{}`)
  instead of failing; the ~90 `{}` lines go. Land before F-77 step 2 if possible.
- Files: .github/workflows/assets.yml, tools/assets/check_models.py, a small
  script or function `tools/assets/check_outputs.py` (new), its pytest.
- Tests: pytest: a missing build output fails, a stray committed `.glb` fails,
  a static prop with no `JOINTS` line passes, a gun missing `Receiver` still fails.
- Done when: adding a static prop touches only its family script and the catalogue.

## Acceptance

- [ ] `docs/FOUNDATIONS.md` rows 1 and 13 say solid, with the reason.
- [ ] Every `any_peer` RPC starts with RequestGate; `rpc-rules` enforces it.
- [ ] `docs/MULTIPLAYER.md` "Writing co-op code" and the HOW_TO_ADD co-op recipe exist.
- [ ] `docs/DECISIONS.md` is short lists only; `decisions-short` enforces it.
- [ ] `AGENTS.md` has the reading map and gotchas; `log-catalogue` enforces the catalogue.
- [ ] Picked audit steps merged; unpicked ones listed under Audit as "not now".
- [ ] Soak and co-op soak green after every step.

## Risks

- **Moving handlers changes behaviour by accident.** Steps 1 to 3 are moves
  with the same checks; the existing two-peer tests and the nightly co-op soak
  are the proof. A step that needs to change a test assertion stops and says why.
- **Step 3 and 8 move RPCs to new nodes.** Wrong node paths fail loudly in the
  two-peer tests; the protocol bump keeps old builds out.
- **DECISIONS cut loses a rule.** The step 4 PR lists every old entry and where
  it went; design overrides move into the design doc, not into the bin.
- **Parallel threads edit the same files.** F-71 step 2 edits loadout code:
  step 3 updates its plan; whichever lands second merges main first.
- **CI rule too strict for a real case.** Each rule has a test for the good
  case; a real exception gets a one-line reason in the rule, not a weaker rule.

## Open decisions

- Approve steps 1 to 5 (foundations 1 and 13)? (decision card)
- Audit 1: split zombie.gd, weapon.gd and game_session.gd now (steps 6 to 8)? (decision card)
- Audit 2: one shared co-op test side for the 17 copies (steps 9 and 10)? (decision card)
- Audit 3: Assets CI lists models from the registry (step 11)? (decision card)
