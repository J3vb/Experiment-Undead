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
| 1 | [Co-op authority: who decides what](#1-co-op-authority) | shaky | [ADR 0003](adr/0003-trusted-client-co-op.md), `docs/MULTIPLAYER.md` |
| 2 | [Content and ids in data](#2-content-and-ids-in-data) | shaky | [ADR 0002](adr/0002-content-as-resources.md), `docs/HOW_TO_ADD.md` |
| 3 | [Save format](#3-save-format) | solid | [ADR 0005](adr/0005-local-versioned-saves.md) |
| 4 | [Events and signals](#4-events-and-signals) | solid | [ADR 0007](adr/0007-signals-and-events.md) |
| 5 | [UI screens and routing](#5-ui-screens-and-routing) | missing | [ADR 0011](adr/0011-one-ui-router.md), `docs/design/ui-hud.md` |
| 6 | [Input](#6-input) | solid (2 leaks) | AGENTS.md code rule 5 |
| 7 | [Game tick and randomness](#7-game-tick-and-randomness) | solid (1 leak) | AGENTS.md code rule 5 |
| 8 | [Logging and diagnostics](#8-logging-and-diagnostics) | solid | `docs/LOGGING.md` |
| 9 | [Tests and CI](#9-tests-and-ci) | solid | AGENTS.md, [ADR 0009](adr/0009-ci-is-the-gate.md) |
| 10 | [Exported builds and dedicated server](#10-exported-builds-and-dedicated-server) | shaky | `docs/RELEASING.md`, [ADR 0006](adr/0006-self-hosted-servers.md) |
| 11 | [Asset pipeline](#11-asset-pipeline) | solid | [ADR 0008](adr/0008-code-built-assets-first.md), skills |
| 12 | [Performance: pooling and hot paths](#12-performance-pooling-and-hot-paths) | shaky | AGENTS.md code rule 6 |
| 13 | [Rules and docs agents read](#13-rules-and-docs-agents-read) | shaky | AGENTS.md, this file, `docs/adr/` |

### 1. Co-op authority

**Rule:** trusted client. Each PC moves its own player and claims its own hits.
The server owns everything shared: zombies, waves, health, points, XP, loot,
doors and machines. A client never changes shared state itself; it sends a
request and the server runs the same code it runs in solo.

**What works:** movement sync, hit claims (`HitClaims`), health/downed/revive
(`PlayerStateSync`), XP grants and loot drops all follow the rule, with
two-peer ENet tests.

**Why shaky:**
- Interactables only run where `Net.is_authority()` is true, and there is no
  client request path. Co-op clients cannot use doors, wall-buys or machines,
  and on a dedicated server nobody can (#138, also #126).
- Equipped item effects (leech, points per hit) are wired on the owning
  client only, so they never apply for clients (#145). Equipping from the Pack
  runs inside a UI key handler (#147).
- There is no standard "client asks the server" pattern. Eleven scripts each
  write their own `@rpc` with their own checks, so every new feature
  re-invents it.

**Fixed when:** one request path for interactions (client sends the request,
server checks sender, range and state, then calls the same `interact()`), item
effects run where the server applies the hit, and a test runs each
interactable from a client.

### 2. Content and ids in data

**Rule:** a new gun, zombie, serum or power-up is a new `.tres` file, not new
code. The file name is the id. Code never compares against a specific id.

**What works:** the `Content` autoload, id = file name, duplicate-id check,
content tests per type, `docs/HOW_TO_ADD.md` recipes.

**Why shaky:** code picks behaviour by comparing ids, so a new `.tres` silently
does nothing until someone edits code:
- weapon on-hit effects by id: `synapse`, `cryo_lance`, `siphon` (#143)
- arm grip profiles for every gun in `player_arm_profiles.gd` (#149)
- which guns get a shot-peak export (#163)
- drop chance and rarity floor per enemy id in `LootService` (#148)
- serum badge text and colour per serum id in the HUD (#154)
- `Content.get_item()` reloads from disk on every call (#140)

**Fixed when:** each of these is a field on the matching data type, and CI
fails when a content id literal appears in `core/` or `systems/` (with a
shrinking baseline, like `tested-scripts`).

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

**Gap to keep in mind:** nothing says which peer emits each event in co-op
(for example `enemy_killed` fires where the zombie dies, the server). When you
add or use an event in co-op code, say in the plan which peers see it.

### 5. UI screens and routing

**Rule (designed, not built):** `docs/design/ui-hud.md` specifies one router:
`UI.push()`, `UI.pop()`, `UI.replace()`. Screens never load other screens, and
only the router captures or frees the mouse.

**Why missing:** screens change scenes by hand in four places
(`main_menu.gd`, `hud.gd`, `game_session.gd`, `net_error_dialog.gd`) and the
main menu adds the character screen itself. That works for today's few
screens, but the skill tree (#112), town hub (#131) and more pause pages would
each add their own flow and mouse handling.

**Fixed when:** a minimal router (push, pop, replace, mouse capture) exists and
the current screens use it. Build it before the next new screen.

### 6. Input

**Rule:** gameplay reads `InputFrame`s, never the keyboard. CI checks it
(`input-only-in-input`).

**Leaks:** the Pack overlay reads raw keys (#146) and equips guns from a key
handler instead of the player's tick (#147).

### 7. Game tick and randomness

**Rule:** gameplay runs in `_physics_process`, gameplay randomness uses the
session RNG (CI checked).

**Leak:** health regen runs in `_process` with no authority check and is
patched by a manual call in `PlayerStateSync` (#144).

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

**Why shaky:** the Build workflow on main has failed at "Smoke test exported
builds" since the co-op work started, so nobody can tell whether the exported
server works. A fix is in progress (exported-server crash and smoke test,
#156). Until Build is green on main, treat any server or export change as
unverified.

### 11. Asset pipeline

**Rule:** models are built by Blender Python scripts in `tools/assets/`, checked
by the Assets CI (glTF validator, budgets, joints, facing) and turnarounds.
Import settings and committed files follow the `godot-asset-import` skill.
Solid. The only gap is per-gun rig data kept in code (see foundation 2, #149).

### 12. Performance: pooling and hot paths

**Rule:** no per-frame allocations in hot paths; 120 fps target with 8 players.

**Why shaky:** there is no pooling yet, and several hot paths build new nodes,
meshes and materials per shot or hit (#141, #142, #150, #151); zombie
separation is O(n²) and allocates each tick (#139). Fine at today's numbers
(430+ fps solo), but it multiplies with 8 players and more effects.

**Fixed when:** shot, impact and effect visuals reuse resources (preloaded
meshes and materials, a small pool where nodes are created often), before the
4-player play-test (#127).

### 13. Rules and docs agents read

**Why shaky:** `docs/DECISIONS.md` has grown into long build notes, so the
actual rules are hard to find. The decision records in `docs/adr/` now hold the
big choices in short form; DECISIONS.md stays the build log. AGENTS.md said "no
RPCs before P7" while P7 co-op was half built; that line now points to the
co-op rules instead.

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
| 1 | Green Build: exported server boots, smoke test checks exit codes and a real join | #156 | any server or export work |
| 2 | One interaction request path for co-op (client asks, server checks sender, range, state, then runs `interact()`), with a client-side test for every interactable | #138, #126 | new machines, doors, power-ups, the 4-player play-test (#127) |
| 3 | Item effects run where the server applies the hit; one public equip function in `ItemLoadout`, called from the player's tick | #145, #147 | Legendaries (#116), sets (#117), skill effects (#113) |
| 4 | Ids into data: on-hit effect field on `WeaponData`, grip profile data, shot-peak flag, drop chance and rarity floor on `EnemyData`, badge on `SerumData`; cache loaded content; CI rule against content id literals in code | #143, #149, #163, #148, #154, #140 | new guns or zombies (Crawler #121, Stalker #123, Brute #124) |
| 5 | Minimal UI router (push, pop, replace, mouse capture), current screens moved onto it | ui-hud.md | skill tree screen (#112), town hub (#131) |
| 6 | Small leaks: regen in the physics tick (#144), Pack overlay input through the input layer (#146) | #144, #146 | anything touching health or the Pack |
| 7 | Hot-path allocations: preload or pool shot, impact and effect visuals; zombie separation without per-tick arrays | #139, #141, #142, #150, #151 | 4-player play-test (#127), more VFX |
| 8 | Shared test helpers for two-peer ENet and mesh checks | #161, #164, #170 | more co-op tests |
| 9 | Write down which peer emits each Events signal (foundation 4) | - | next co-op feature that uses Events |
