# Foundations

The core systems every feature stands on. If one of these is wrong, every
feature built on it has to be redone. So:

1. Check this map before you plan a feature.
2. Fill in the **Ready to build** checklist below before you write code.
3. If your feature needs a foundation that is **shaky** or **missing**, fix the
   foundation first (or say in the plan why your feature is safe without it).

Big technical choices behind these foundations are written down as decision
records in [docs/adr/](adr/README.md). Do not go against one without writing a
new record first. Feature plans and their order live in `docs/ROADMAP.md` and
`docs/plans/`; this file only covers the foundations.

**Keep it current.** A PR that fixes or changes a foundation updates its row
here in the same PR. Re-check every row at the end of each milestone.

Last full check: 2026-11-16, main at `3a2fb7f`.

## Foundation map

Status: **solid** = rule decided, built, followed and tested. **Shaky** = rule
decided but the code breaks it in places, so new features copy the wrong
pattern. **Missing** = needed soon, not built.

| # | Foundation | Status | Rule lives in |
|---|---|---|---|
| 1 | [Co-op authority: who decides what](#1-co-op-authority) | solid | [ADR 0003](adr/0003-trusted-client-co-op.md), `docs/MULTIPLAYER.md` |
| 2 | [Content and ids in data](#2-content-and-ids-in-data) | solid | [ADR 0002](adr/0002-content-as-resources.md), `docs/HOW_TO_ADD.md` |
| 3 | [Save format](#3-save-format) | solid | [ADR 0005](adr/0005-local-versioned-saves.md) |
| 4 | [Events and signals](#4-events-and-signals) | solid | [ADR 0007](adr/0007-signals-and-events.md) |
| 5 | [UI screens and routing](#5-ui-screens-and-routing) | solid | [ADR 0011](adr/0011-one-ui-router.md), `docs/design/ui-hud.md` |
| 6 | [Input](#6-input) | solid | AGENTS.md code rule 5 |
| 7 | [Game tick and randomness](#7-game-tick-and-randomness) | solid | AGENTS.md code rule 5 |
| 8 | [Logging and diagnostics](#8-logging-and-diagnostics) | solid | `docs/LOGGING.md` |
| 9 | [Tests and CI](#9-tests-and-ci) | solid | AGENTS.md, [ADR 0009](adr/0009-ci-is-the-gate.md) |
| 10 | [Exported builds and dedicated server](#10-exported-builds-and-dedicated-server) | solid | `docs/RELEASING.md`, [ADR 0006](adr/0006-self-hosted-servers.md) |
| 11 | [Asset pipeline](#11-asset-pipeline) | solid | [ADR 0008](adr/0008-code-built-assets-first.md), skills |
| 12 | [Performance: pooling and hot paths](#12-performance-pooling-and-hot-paths) | solid | AGENTS.md code rule 6 |
| 13 | [Rules and docs agents read](#13-rules-and-docs-agents-read) | shaky | AGENTS.md, this file, `docs/adr/` |

### 1. Co-op authority

**Rule:** trusted client. Each PC moves its own player and claims its own hits.
The server owns everything shared: zombies, waves, health, points, XP, loot,
doors and machines. A client never changes shared state itself; it sends a
request and the server runs the same code it runs in solo.

**What works:** movement sync, hit claims (`HitClaims`), health/downed/revive
(`PlayerStateSync`), XP grants, loot drops and every interactable
(`InteractionSync`: doors, power, barriers, wall-buys, Reforger, Med
Dispenser, Specimen Vault, exfil) follow the rule, with two-peer ENet tests
(`test_interaction_sync`, `test_coop_machines`, `test_coop_world_state`).
Gear and item guns do too: each owner sends its loadout
(`PlayerStateSync.submit_loadout`), the server applies gear and loot luck from
its own copy, and leech / points per hit run where the server applies the hit
(`ItemLoadout.apply_hit`). Pack equips run in `LootService`'s physics tick
(plans/item-effects-server.md).

**Why solid now:** the six co-op message patterns are written down with a
reference file each (`docs/MULTIPLAYER.md` "Writing co-op code"), new node
code has one server check (`multiplayer.is_server()`), `docs/HOW_TO_ADD.md`
has a co-op recipe, and CI rule `rpc-rules` checks every `@rpc` names its
transfer mode and every `any_peer` handler starts with the server check
(F-79 step 1, [plans/easy-changes.md](plans/easy-changes.md)). Steps 2 and 3
split the two co-op scripts at the 350-line cap by job.

**Fixed when:** ~~one request path for interactions (client sends the request,
server checks sender, range and state, then calls the same `interact()`)~~
(done, F-02), ~~a test runs each interactable from a client~~ (done), and
~~item effects run where the server applies the hit~~ (done, #145).

### 2. Content and ids in data

**Rule:** a new gun, zombie, serum or power-up is a new `.tres` file, not new
code. The file name is the id. Code never compares against a specific id: the
behaviour is a field on the data type (`WeaponData.effect` and `grip`,
`EnemyData.loot_drop_chance` and `loot_min_rarity`, `SerumData.badge`). CI
checks it (`no-content-id-literals`). `Content` keeps each loaded resource.
Built in [plans/ids-into-data.md](plans/ids-into-data.md).

**Known leftovers** (in `tools/ci/content_id_baseline.txt`, which may only
shrink): serum and power-up effects that are code anyway (`second_wind`,
`scavenger`, `resupply`, `ammo_pack`), gear visual fallbacks and the starting
sidearm. They move when More power-ups (F-26), Gear in first person (F-42) or
Dyes (F-46) touch them.

### 3. Save format

**Rule:** characters and stash are versioned JSON on the player's PC
(`SaveFile`): temp-file writes, backups before upgrade, one migration step per
version, newer saves refused.

**What works:** all of the above, with tests that load old samples.

**Watch out:** saves store content ids (guns, gear bases, affixes). Renaming or
deleting a `.tres` that can be saved breaks old items. Treat saved ids as
permanent; a rename needs a migration step and a test.

### 4. Events and signals

**Rule:** a node signals up to its parent; game-wide facts go through `Events`
in the past tense; requests are direct calls.

**What works:** 24 past-tense signals, used consistently.

**Which peers hear it:** every signal in `core/events.gd` has a `## Peers:`
line (server only, owner, every peer); `tests/unit/test_events.gd` fails if one
is missing. Read it before co-op code listens to an event. Round events
(`round_started`, `round_ended`, `intermission_started`) fire on every peer:
`WaveDirector` relays them and sends late joiners a snapshot (F-40).

### 5. UI screens and routing

**Rule:** the `UI` autoload (`core/ui.gd`) owns screen flow: `UI.replace()` for
a root place (main menu, match), `UI.push()` / `UI.pop()` for screens on top,
`UI.hold_mouse()` for panels that are not screens. Screens are listed in
`content/screens/` and emit `closed`; only the router changes the scene or the
mouse mode. CI checks it (`ui-router-only`). Built in
[plans/ui-router.md](plans/ui-router.md); recipe in `docs/HOW_TO_ADD.md`.

### 6. Input

**Rule:** gameplay reads `InputFrame`s, never the keyboard. CI checks it
(`input-only-in-input`).

**Fixed leak:** the Pack overlay (now `systems/ui/pack_overlay.gd`) uses the
`pack_toggle`, `pack_drop` and `pack_equip` input actions, so its keys can be
rebound (#146, foundation fix 6). Its equip key only queues a request;
`LootService` equips in its physics tick (#147).

### 7. Game tick and randomness

**Rule:** gameplay runs in `_physics_process`, gameplay randomness uses the
session RNG (CI checked).

**Fixed leak:** health regen now runs in `HealthComponent._physics_process`,
only on the server (#144, foundation fix 6).

### 8. Logging and diagnostics

**Rule:** JSON-lines logs, `Log.warn` for early warning signs, catalogue in
`docs/LOGGING.md`. Solid; keep adding warnings for new systems.

### 9. Tests and CI

**Rule:** `quality` and `test` must be green; behaviour changes add tests;
structure rules in `tools/ci/check_rules.py`.

**What works:** 100+ GUT tests, headless match and two-peer ENet tests,
lint and complexity limits, no-weakening guard.

**Gaps:** test helpers are copied between files (#161, #164, #170). A test that
only runs as host cannot catch "works for host, broken for clients" (that is
how #138 and #145 slipped through): co-op features need a test that runs the
action from a client.

### 10. Exported builds and dedicated server

**Rule:** the same project exports a game client and a headless dedicated
server; the Build workflow smoke-tests both.

**Why solid:** Build has been green on main since the exported-server crash
fix (#174). The smoke test checks exit codes, a clean stop and a real join of
the exported server by the exported client. Build also runs on every pull
request, so a PR that breaks an export shows a red check before it merges.
Visual scripts that can run on the server must null-check materials (the
server export strips them).

### 11. Asset pipeline

**Rule:** models are built by Blender Python scripts in `tools/assets/`, checked
by the Assets CI (glTF validator, budgets, joints, facing) and turnarounds.
Import settings and committed files follow the `godot-asset-import` skill.
Solid. The only gap is per-gun rig data kept in code (see foundation 2, #149).

### 12. Performance: pooling and hot paths

**Rule:** no per-frame allocations in hot paths; 120 fps target with 8 players.

**What works:** ([plan](plans/hot-path-allocations.md)) zombie separation
loops the `Spawner.zombies` live list (no array per tick); impacts reuse a
ring of at most 48 nodes with shared meshes and materials; remote tracers
redraw one node per player; chain arcs share one mesh; the gravity well scene
is loaded once.

**Watch:** new per-shot or per-hit visuals follow the same pattern: shared
static meshes and materials, reused nodes where they appear every shot. A
`Pool` autoload and zombie pooling wait for a measured stutter
(`docs/KEEP_IT_SIMPLE.md`). Separation is still O(n²) (2304 checks at 48
zombies), cheap without allocation.

### 13. Rules and docs agents read

**Why shaky:** `docs/DECISIONS.md` had grown into long build notes, so the
actual rules were hard to find. Step 4 cut it to one-line lists (design
differences, simplifications, provisional picks); the decision records in
`docs/adr/` hold the big choices. AGENTS.md said "no
RPCs before P7" while P7 co-op was half built; that line now points to the
co-op rules instead.

**Being fixed:** F-79, [plans/easy-changes.md](plans/easy-changes.md) step 5
(AGENTS.md reading map and gotchas). Step 4 (DECISIONS.md as short lists) is done.

## Ready to build

Copy this block into the feature plan (or the Codex prompt, or the PR
description for small changes) and answer every line **before** writing code.
"Don't know" is not an answer: find out, or ask.

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): …
  Any of them shaky or missing? → fix first, or explain why this feature is safe: …
- Decision records that apply (docs/adr/): … Does this go against one? no / yes → new ADR first
- Co-op:
  - Who decides: owning client / server: …
  - How a client triggers it (request to server, what the server checks): …
  - What other players see, and how it reaches them: …
  - Works on a dedicated server with no local player: yes / n.a.
- Data: where new ids and numbers live (content/<type>/*.tres, balance sheet): …
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no / yes → new fields have defaults, version bump + migration + old-sample test
  Renames or removes a saved id: no / yes → migration step
- Events and UI: new Events (past tense, which peers emit them): … New screens go through the UI router: yes / n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
- Tests: which unit / content / integration tests; co-op features run the action from a client: …
- Logging: Log.warn lines for early warning signs: …
- Performance: anything created per frame, per shot or per hit? → preload or pool: …
- Lore link: the story reason for what the player sees (docs/design/lore.md#story-links-for-game-content), or none for pure tech: …
- Out of scope (later phases, not built now): …
```

**Stop signs.** Do not start coding when:
- a foundation it needs is shaky or missing and the plan does not fix it,
- the co-op lines are blank or say "later",
- new behaviour depends on a specific id in code,
- the save impact is unknown.

## Foundation fixes, in order

Do these before new content that depends on them. Each is one small PR with
tests, as usual. The issue numbers have the details.

| Order | Fix | Issues | Must land before |
|---|---|---|---|
| 1 | Done: green Build. Exported server boots, smoke test checks exit codes and a real join (#174); Build also runs on pull requests | #156 | any server or export work |
| 2 | **Done (F-02).** One interaction request path for co-op (client asks, server checks sender, range, state, then runs `interact()`), with a client-side test for every interactable | #138, #126 | new machines, doors, power-ups, the 4-player play-test (#127) |
| 3 | Done: item effects run where the server applies the hit; one public equip function in `ItemLoadout`, called from a physics tick ([plan](plans/item-effects-server.md)) | #145, #147 | Legendaries (#116), sets (#117), skill effects (#113) |
| 4 | Done: ids into data ([plan](plans/ids-into-data.md)): on-hit effect field on `WeaponData`, grip profile data, shot-peak flag, drop chance and rarity floor on `EnemyData`, badge on `SerumData`; cache loaded content; CI rule against content id literals in code | #143, #149, #163, #148, #154, #140 | new guns or zombies (Crawler #121, Stalker #123, Brute #124) |
| 5 | Done: minimal UI router (push, pop, replace, mouse capture), current screens moved onto it ([plan](plans/ui-router.md)) | ui-hud.md | skill tree screen (#112), town hub (#131) |
| 6 | Done: small leaks: regen in the physics tick (#144), Pack overlay input through the input layer (#146) | #144, #146 | anything touching health or the Pack |
| 7 | Done: hot-path allocations ([plan](plans/hot-path-allocations.md)): impacts, remote tracers, chain arcs and the gravity well reuse resources; zombie separation without per-tick arrays | #139, #141, #142, #150, #151 | 4-player play-test (#127), more VFX |
| 8 | Done: shared test helpers: `TwoPeers` for two-peer ENet tests, `MeshChecks` for model sight-line checks, `grip_checks.py` for grip tests | #161, #164, #170 | more co-op tests |
| 9 | Done: every Events signal says which peers emit it (`## Peers:` in `core/events.gd`, checked by a test) | - | next co-op feature that uses Events |
| 10 | F-79 ([plan](plans/easy-changes.md)): written co-op patterns with a CI rule for every RPC, then short agent docs (foundations 1 and 13) | - | next co-op feature (skills, abilities, grenades) |
