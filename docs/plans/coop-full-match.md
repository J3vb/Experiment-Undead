# Plan: A full co-op match, start to finish

Status: Approved
Roadmap: F-47 / issue #213
Phase: P7
Size: L
Approved by: Codex plan review on PR #214 (2026-11-17); hub flow asked for and late-join decision answered by the person (2026-11-17)

## Goal

Four friends join a dedicated server (or one of them hosts) and land in the
hub. From there they pick a level and deploy together, play Halcyon Labs to
round 20 and past it, see each other's state, and return to the hub when the
match ends, ready to deploy again without restarting anything (flow asked by
the person, 2026-11-17). This is the P7 exit
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
- Hub and deploy flow: joining a server (dedicated or Host and play) lands
  in the hub. A deploy board per level sends the whole server into that
  level. When the match ends, after the results screen, everyone returns to
  the hub. A dedicated server also returns to the hub when the last player
  leaves mid-match.
- Close-out: MULTIPLAYER.md, a 4-player play-test checklist for F-43.

Not in (non-goals, and where each one goes instead):

- Round state and power-ups on clients: `docs/plans/coop-round-state-power-ups.md` (F-40), built first.
- Losing Serums when downed in co-op: a bug fix PR with its own test, before step 1.
- Third-person walk, run and downed animations for teammates: F-41 (art, own plan, own thread).
- The hub scene itself (Lantern Post blockout, deploy board model and
  Interactable): the hub thread. This plan owns the network side: the hub as
  a place a session runs, deploy, and return.
- Town features (stash, Workbench, Quartermaster, chat, squads inside one
  server, two matches at once): P9 (F-45). Until then a server runs one place
  at a time and everyone on it deploys together.
- Play solo keeps going straight into Halcyon Labs; the hub is for servers.
- Server Docker image, Unraid template, server.cfg: F-44.
- Server browser, LAN discovery, town and Deploy Gate: P8 and P9.
- A map list menu on the deploy board: one board per level for now.
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
  - How a client triggers it: deploy uses the existing InteractionSync request on the deploy board.
    Changing place = the server tells clients the new place, then clients rejoin through the existing join
    flow and hello (connection opens after the map exists, so spawns never arrive early).
  - What other players see: names and bleed-out time ride on the existing PlayerStateSync snapshot.
  - Works on a dedicated server with no local player: yes, the soak runs exactly that.
- Data: no new content or numbers; colours from docs/design/look-rules.md. Code compares a specific id: no.
- Save: no change.
- Events and UI: no new Events. Squad cards live in the existing Hud scene; pause stays on the UI router.
  The hub is a new root screen (content/screens/hub.tres) reached only through UI.replace.
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
| systems/game/hub_session.tscn | new | game_session.tscn with the hub level and `is_hub` on |
| content/screens/hub.tres | new | Root screen id for the hub |
| systems/net/dedicated_server.gd | changed | Starts in the hub; swaps its session on deploy, match end and when it empties |
| core/net.gd | changed | Current place id, the "go to place" message, rejoin after a place change |
| systems/ui/results_screen.gd | changed | In co-op the restart button reads "Back to hub" and returns with the squad |
| systems/ui/main_menu.gd | changed | Host and play opens the hub |
| core/build.gd | changed | PROTOCOL_VERSION +1 in step 3 (snapshot fields) |
| docs/MULTIPLAYER.md, docs/DECISIONS.md, docs/ROADMAP.md | changed | Close-out |

Autoloads, managers or base classes added: none. `SquadCards` is a plain
Control script owned by the Hud (one job: draw the cards).

## Data

- No Resource changes.
- `PlayerStateSync._snapshot()` gains `"name": String` and `"bleed": float`
  (seconds left while downed). Clients read them for squad cards and prompts.
- Soak arguments: `--clients N --rounds N --seed N --timescale N`.
- `GameSession.is_hub: bool` (export, default false). True skips the
  WaveDirector start, the Spawner, power-up drops, loot, points and death.
- Network: `Net._go_to_place(place: StringName)` authority to all (reliable);
  the handshake reply carries the server's current place so a client that
  loaded the wrong one switches before its player spawns.
- Content: `content/screens/hub.tres` (ScreenData, scene = hub_session.tscn).
  Deploy boards name the screen id of their level as exported data.
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
  `_request_snapshot`, which now includes names and bleed. A player who joins
  during a match lands in that running match (one place per server until P9;
  decided by the person).
- Place changes: the server owns the current place. Deploy and return go to
  every peer; nobody can be left in a different place than the server.
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
  side: joins `127.0.0.1`, disables local input, gives itself one strong gun
  from Content on its own PC (guns are owner-side, like a wall-buy grant), and
  fights with legal hits only: it moves its own player to within the gun's
  range of one chasing zombie (owners move themselves under ADR 0003) and
  claims one body hit per fire interval through the real `HitClaims` client
  path, so every claim passes the server's damage, range and rate checks and
  kills, points and XP flow through the network code. The gun is a soak
  setting (`--gun <id>`, default the Reforged rifle) so higher rounds stay
  killable without touching the claim limits. Pass when the server
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

### Step 4: Hub as a place, and changing places

- Build: `GameSession.is_hub` and `hub_session.tscn` (uses the hub thread's
  `levels/lantern_post/lantern_post.tscn`; until it lands, the test uses a
  small test level). `Net` holds `place` (screen id). Server side
  `GameSession.deploy(place)` (called by the hub thread's deploy board through
  `interact()`): refuses unless `is_hub`, then sends `_go_to_place` to all and
  swaps the server's own session. Clients receive it, set `Net.pending_join`
  to the same server and `UI.replace(place)`; the new session joins again in
  `_ready()` (retrying for up to 6 s while the server swaps). The handshake
  reply carries the server's place; a client in the wrong place switches
  first. Dedicated server and Host and play start in the hub; a listen host
  re-hosts on the same port after the swap. `GameSession._exit_tree` does not
  show the lost-connection dialog for a planned place change.
- Files: systems/game/game_session.gd, hub_session.tscn (new),
  content/screens/hub.tres (new), core/net.gd, systems/net/handshake.gd,
  systems/net/dedicated_server.gd, systems/ui/main_menu.gd, core/build.gd,
  tests/unit/test_places.gd (new), tests/integration/test_net_match.gd,
  tests/content/ screen check.
- Tests: in-process: a hub session starts no waves and spawns no zombies;
  `deploy()` from a client request moves the server and the client to the
  match place, both players spawn there, round 1 starts; `deploy()` outside
  the hub is refused. Integration (real processes): a client joins a
  dedicated server, lands in the hub, deploys, and reaches round 1. Solo play
  from the menu still goes straight into Halcyon Labs.
- Done when: a squad on a dedicated server can go from the hub into a match.

### Step 5: Back to the hub after a match

- Build: after a co-op match ends and the results delay passes, the server
  sends everyone to the hub with the same place change. The client's results
  screen stays up until the player presses "Back to hub" (it reads "Back to
  hub" in co-op; solo keeps Restart and Main menu); a client that takes longer
  than the swap simply rejoins into the hub. Run XP and the Pack bank before
  the change (the existing `bank_run_xp` guard). A dedicated server whose last
  player leaves mid-match also returns to the hub (`Log.info net.match_reset`).
  Each new session starts clean: `Net.reset_ids()`, fresh wallets, no
  leftover zombies or pickups.
  A planned place change is not a lost connection: `_go_to_place` sets
  `Net.changing_place` and the target place before the client leaves, and
  `GameSession._on_connection_lost` and `Net._on_server_disconnected` skip
  the main-menu replace and the error dialog while it is set. A client
  whose results screen is up when the order arrives keeps the screen (the
  session stays until the player leaves it, the connection closes quietly),
  and "Back to hub" then joins the remembered address into the remembered
  place.
- Files: systems/game/game_session.gd, systems/net/dedicated_server.gd,
  systems/ui/results_screen.gd, tests/unit/test_places.gd,
  tests/integration/test_net_match.gd.
- Tests: in-process: after game over the server and client are back in the
  hub with run XP banked once; a client on the results screen when the
  server changes place still shows the results with no error dialog and
  "Back to hub" joins the hub; an empty dedicated server mid-match returns to
  the hub with no orphan nodes; a second deploy starts a fresh round 1.
  Integration: client plays, squad goes down, client lands back in the hub.
- Done when: a dedicated server runs hub, match, hub, match unattended.

### Step 6: Close-out and play-test checklist

- Build: MULTIPLAYER.md build order step 9 (done), the hub flow and "Running
  it locally" with the soak command; DECISIONS.md entry; ROADMAP F-47 Done;
  open the 4-player play-test checklist on issue #127 (F-43) with exact
  steps; run the `finish-feature` skill.
- Files: docs only.
- Tests: none (docs only); the nightly co-op soak is green.
- Done when: plan Status Done.

## Acceptance

- [ ] The nightly co-op soak (4 bots, dedicated server) reaches round 20 with no desync warnings or errors.
- [ ] Pausing in co-op never stops the match (step 2 test).
- [ ] Every player sees teammates' names, health and bleed-out (step 3 test).
- [ ] Joining a server lands in the hub; a deploy board takes the squad into Halcyon Labs (step 4 tests).
- [ ] After a match everyone is back in the hub and can deploy again, unattended on a dedicated server (step 5 tests).
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
- Reloading the client scene while connected. A place change always leaves
  and rejoins, which reuses the tested join path instead of a new one. Cost:
  about a second of loading per change; fine behind the loading screen.
- The hub scene comes from another thread. Step 4 tests use a small test
  level, so the network side does not wait for the art.

## Open decisions

- [x] Where does a player land who joins while the squad is in a match? In
  that running match, as a late joiner (the person, 2026-11-17).
