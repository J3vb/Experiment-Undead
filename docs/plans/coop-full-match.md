# Plan: A full co-op match, start to finish

Status: Review
Roadmap: F-47 / issue #213
Phase: P7
Size: L
Approved by:

## Goal

Four friends can join a dedicated server (or one of them hosts), play
Halcyon Labs together to round 20 and past it, see each other's state, finish
the match and play again without restarting anything. This is the P7 exit
test in `docs/design/game-design.md` ("Four players finish a run to round 20
with no desync"), minus the art work in F-41. Serves "The pressure always
builds" and "Better together".

## Scope

In:

- A co-op soak: a headless dedicated server and bot clients play real rounds
  through the real join, hit-claim and sync paths, and fail on desync, errors
  or stalls. Short version on pull requests, full 4 bots to round 20 nightly.
- Pause in co-op opens the menu but does not stop the match, with a banner
  (`docs/design/ui-hud.md#12-pause`).
- Results show your own points, not the first player's.
- Squad cards in the match HUD: name, health bar, down state with bleed-out
  timer (`docs/design/ui-hud.md#10-match-hud`). Revive prompt says the
  teammate's name instead of a peer number.
- Match end and play again: after a co-op match ends, the server starts a
  fresh match; a dedicated server also resets when the last player leaves.
  Clients and the host can play again from the results screen.
- Close-out: MULTIPLAYER.md, a 4-player play-test checklist for F-43.

Not in (non-goals, and where each one goes instead):

- Round state and power-ups on clients: `docs/plans/coop-round-state-power-ups.md` (F-40), built first.
- Losing Serums when downed in co-op: a bug fix PR with its own test, before step 1.
- Third-person walk, run and downed animations for teammates: F-41 (art, own plan).
- Server Docker image, Unraid template, server.cfg: F-44.
- Server browser, LAN discovery, town and Deploy Gate: P8 and P9.
- "View squad" on the results screen and the Tab scoreboard: after F-43, if
  the play-test asks for them (new roadmap row then).
- Voice or text chat: P9 (town).

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky only for "no standard request pattern"; no new client
  request is added except one "play again" that is just a normal rejoin), 5 UI screens and routing
  (solid), 9 Tests and CI (solid; adds a non-required workflow, weakens nothing), 10 Exported builds and
  dedicated server (solid).
  Any of them shaky or missing? 1: safe, see above.
- Decision records: 0003 trusted client, 0004 one code path, 0006 self-hosted servers, 0009 CI is the gate,
  0011 one UI router. Goes against one: no.
- Co-op:
  - Who decides: server for player state, names, match end and reset; each client for its own pause menu
    and HUD.
  - How a client triggers it: no new requests. Play again = leave and join the same address again through
    the existing join flow and hello.
  - What other players see: names and bleed-out time ride on the existing PlayerStateSync snapshot.
  - Works on a dedicated server with no local player: yes, the soak runs exactly that.
- Data: no new content or numbers; colours from docs/design/look-rules.md. Code compares a specific id: no.
- Save: no change.
- Events and UI: no new Events. Squad cards live in the existing Hud scene; pause stays on the UI router.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes.
- Tests: two-peer ENet unit tests per step, the co-op soak, solo tests and the solo soak stay green.
- Logging: Log.warn net.match_reset with the reason; the soak reads existing net.* warnings.
- Performance: squad cards update on state change, not per frame (bleed timer text only while downed).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md, Build roadmap, P7 row: "Squads of 2 to 4
  players ... Four players finish a run to round 20 with no desync".
- docs/design/ui-hud.md#10-match-hud: squad cards top right.
- docs/design/ui-hud.md#12-pause: "In solo the game pauses; in a squad it
  does not, and a banner says so."
- docs/design/ui-hud.md#13-death-and-run-results: results content.
- docs/design/look-rules.md: HUD colours and type.
- docs/MULTIPLAYER.md: bleed-out 30 s, revive 3 s, respawn next round.
- docs/adr/0004 (one code path), 0006 (self-hosted dedicated servers).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/soak/coop_soak.gd | new | Launches a server and N bot clients, collects logs, prints the PASS/FAIL table |
| tools/soak/coop_soak_server.gd, coop_soak_bot.gd | new | Server side: immortal players, open map. Bot side: joins, claims hits through HitClaims |
| .github/workflows/coop-soak.yml | new | PR (short, non-required) and nightly + manual (4 bots, round 20) |
| systems/game/game_session.gd | changed | Pause without pausing in co-op; own points in results; play again |
| systems/ui/pause_screen.gd / .tscn | changed | "Match continues" banner in co-op |
| systems/net/player_state_sync.gd | changed | Snapshot carries display name and bleed time left |
| systems/net/handshake.gd | changed | Exposes the accepted display name per peer (it already receives it) |
| systems/net/coop_hud.gd | changed | Revive prompt uses the display name |
| systems/ui/hud.gd / hud.tscn, systems/ui/squad_cards.gd (new) | new + changed | Squad cards |
| systems/net/dedicated_server.gd | changed | Builds a fresh GameSession after a match ends or the server empties |
| core/net.gd | changed | Remembers the last join target / host port for play again |
| systems/ui/results_screen.gd | changed | "Play again" label and behaviour in co-op |
| core/build.gd | changed | PROTOCOL_VERSION +1 in step 3 (snapshot fields) |
| docs/MULTIPLAYER.md, docs/DECISIONS.md, docs/ROADMAP.md | changed | Close-out |

Autoloads, managers or base classes added: none. `SquadCards` is a plain
Control script owned by the Hud (one job: draw the cards).

## Data

- No Resource changes.
- `PlayerStateSync._snapshot()` gains `"name": String` and `"bleed": float`
  (seconds left while downed). Clients read them for squad cards and prompts.
- Soak arguments: `--clients N --rounds N --seed N --timescale N`.
- Save format change: none.
- Content checks to add in `tests/content/`: none.

## Co-op behaviour

- Who owns the state: server (names as accepted in the hello, health, downed,
  bleed, match over, match reset). Each client: its own pause menu and HUD.
- What clients send, what the server sends back: nothing new. Names and bleed
  ride on the existing snapshot. Play again uses the normal join.
- What a client sees that the host sees too: every teammate's card. Only the
  owner: its own results points and pause menu.
- Late joiner: gets every player's snapshot through the existing
  `_request_snapshot`, which now includes names and bleed.
- Dedicated server: no HUD; it runs the reset loop and the soak's server side.

## Performance

Squad cards rebuild only on `health_changed` or a snapshot, at most 3 cards.
The bleed label updates in `_process` only while someone is downed. The soak
is a test tool and never ships. No per-frame allocations.

## Steps

### Step 1: Co-op soak

- Build: `coop_soak.gd` (a SceneTree script like `tools/soak/soak.gd`)
  starts one headless dedicated server process running
  `coop_soak_server.gd` and N bot client processes running
  `coop_soak_bot.gd`, each with its own `XDG_DATA_HOME` so their
  `user://logs/` stay apart. Server side: every joined player's health is
  `INF` on the server, power on, doors open (same as `soak_run.gd`). Bot
  side: joins `127.0.0.1`, disables local input, and every 30 ticks claims a
  killing hit on one chasing zombie through the real `HitClaims` client path,
  so kills, points and XP flow through the network code. Pass when the server
  log finishes round N, every bot's log reached round N (needs F-40 step 1),
  no SCRIPT ERROR or `level: error` line in any log, and the fail list from
  `soak.gd` plus `net.hit_claim_rejected` above 1% of claims is empty.
  Reuse `soak.gd`'s `check_log` per log. Workflow `coop-soak.yml`: on pull
  requests 1 server + 2 bots, rounds 1-5; nightly and manual 4 bots, rounds
  1-20. Not a required check (the person decides that after a week of green
  runs).
- Files: tools/soak/coop_soak.gd, coop_soak_server.gd, coop_soak_bot.gd (new),
  .github/workflows/coop-soak.yml (new), tools/ci/test_workflows.py,
  docs/LOGGING.md (how to read a co-op soak).
- Tests: `tools/ci/test_workflows.py` checks the workflow; a GUT unit test
  for the pass/fail summary over sample logs (one passing, one with a
  desync warning); the PR run itself.
- Done when: the short soak passes on CI and the manual 4-bot run reaches
  round 20 (or every failure it finds has a fix PR or an issue).

### Step 2: Pause and results in co-op

- Build: in `GameSession._unhandled_input`, set `get_tree().paused` only when
  not `Net.is_online()`; in co-op the pause screen opens, the local player's
  input stops (`input_enabled` false while the screen is up) and a banner
  "Match continues. Your squad is still fighting." shows on the pause screen.
  In `_receive_match_end`, each peer replaces `stats.points` with its own
  player's wallet points.
- Files: systems/game/game_session.gd, systems/ui/pause_screen.gd/.tscn,
  tests/unit/test_game_session.gd (or the existing pause test),
  tests/unit/test_coop_pause.gd (new).
- Tests: two-peer: the host opens pause, the tree is not paused, zombies keep
  moving on the server and the client; solo pause still pauses; client
  results show the client's own points.
- Done when: pausing never freezes teammates; tests pass.

### Step 3: Squad cards and names

- Build: `Handshake` keeps each accepted peer's display name (it already
  parses it from the hello). `PlayerStateSync._snapshot()` adds `name` and
  `bleed`; clients store them on the player (`display_name`, `bleed_left`).
  New `SquadCards` Control in `Hud` top right: one card per other player in
  `session.get_players()` with name, health bar and a red "DOWN 0:24"
  bleed-out timer, greyed with "Respawn next round" when dead. Hidden in solo.
  `CoopHud` revive prompt uses the name. PROTOCOL_VERSION +1.
- Files: systems/net/handshake.gd, player_state_sync.gd, coop_hud.gd,
  systems/ui/squad_cards.gd (new), systems/ui/hud.gd, hud.tscn,
  core/build.gd, tests/unit/test_squad_cards.gd (new),
  tests/unit/test_player_state_sync.gd.
- Tests: two-peer: a client sees the other player's name and health; a downed
  teammate's card shows the bleed timer counting down; the prompt says
  "Hold F to revive <name>"; a late joiner gets names. Look-check render of
  the HUD with two cards against the mockup (`look-check` skill).
- Done when: teammates' names and states are on screen; tests pass.

### Step 4: Match end and play again

- Build: Dedicated server: when its `GameSession` emits `Events.game_over`
  (after the results delay) or the last peer disconnects mid-match, it frees
  the session and adds a fresh one at `/root/GameSession` (same port stays
  open, `Log.info net.match_reset` with the reason). Peers still connected
  after game over are disconnected with the existing "host ended the match"
  message so their results screen stays up instead of a lost-connection
  dialog. `Net` remembers the last join address and the last host port.
  Results screen in co-op: the restart button reads "Play again": a client
  sets `Net.pending_join` to the last address and reloads (normal join,
  retried for up to 6 s if the server is still resetting); the host re-hosts
  on the same port and reloads. Solo restart is unchanged.
- Files: systems/net/dedicated_server.gd, core/net.gd,
  systems/game/game_session.gd, systems/ui/results_screen.gd,
  tests/unit/test_dedicated_server.gd, tests/integration/test_net_match.gd,
  tests/unit/test_net.gd.
- Tests: in-process: a dedicated server with no players left mid-match
  resets to round 0 with a fresh map; after game over it resets and a client
  joining gets round 1 state. Integration (real processes): a client plays,
  the squad goes down, the client presses play again and joins the fresh
  match. Solo restart test unchanged.
- Done when: a dedicated server runs match after match unattended; tests pass.

### Step 5: Close-out and play-test checklist

- Build: MULTIPLAYER.md build order step 9 (done) and "Running it locally"
  with the soak command; DECISIONS.md entry; ROADMAP F-47 Done; open the
  4-player play-test checklist on issue #127 (F-43) with exact steps; run the
  `finish-feature` skill.
- Files: docs only.
- Tests: none (docs only); the nightly co-op soak is green.
- Done when: plan Status Done.

## Acceptance

- [ ] The nightly co-op soak (4 bots, dedicated server) reaches round 20 with no desync warnings or errors.
- [ ] Pausing in co-op never stops the match (step 2 test).
- [ ] Every player sees teammates' names, health and bleed-out (step 3 test).
- [ ] A dedicated server runs a second match after the first ends, with no restart (step 4 tests).
- [ ] Solo play, the solo soak and every existing co-op test stay green.

## Risks

- Unknown co-op bugs at 4 players and round 20 (bandwidth, claim rate limits
  with more zombies, spawn positions). Step 1 is first so they show up before
  the polish steps; each one gets a fix PR with a test.
- CI time: 3 Godot processes on a 2-core runner. The PR run is kept to 5
  rounds at time scale 4; the long run is nightly.
- Resetting a match on a live server could leak nodes or keep stale
  references in autoloads (`Net` ids, `Log`). Step 4 tests check orphan
  nodes after a reset and that `Net.reset_ids()` runs.
- Reloading the client scene while connected. Play again always leaves and
  rejoins, which reuses the tested join path instead of a new one.

## Open decisions

- [ ] What should Play again do in co-op? Recommended: everyone stays on the
  same server and rejoins a fresh match. Other option: always back to the
  main menu, and players join again by hand.
