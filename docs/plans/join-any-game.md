# Plan: Friends can join any game by IP

Status: Review
Roadmap: F-66
Phase: P7
Size: M
Approved by:

## Goal

Every game a player starts is open to friends: they type the player's address
and port in Join and land in that game, with no separate "host" step. The game
shows the address to give out and opens the router port on its own where it
can. Serves the co-op pillar ("better with friends") and the week goal of
co-op that just works.

## Scope

In:

- **Alone means solo.** One rule decides solo or co-op behaviour: "is anyone
  else connected right now?" A game with an open port and nobody else in it
  plays exactly like solo today (pause freezes, Second Wind, Play again). When
  a friend joins it plays by the co-op rules; when the last friend leaves it is
  solo again.
- **Every game opens its port.** Play solo and Host and play both start a
  listen server on the saved port (default 7777, ADR 0006). If the port is
  taken, or the player turned the setting off, the game runs offline like
  today and says so on the pause screen.
- **Router port and address.** UPnP (Godot's built-in `UPNP` class) opens the
  UDP port on the router, in a background thread, and closes it when the game
  closes its port. The pause screen shows "Friends join at <address>:<port>"
  with a Copy button: the internet address when UPnP worked, the local network
  address when it did not, plus one plain line on why (no router answer,
  provider blocks it).
- **Settings.** A new Network page: "Let friends join my game" (default on)
  and "Open router port automatically" (default on). Port stays the field in
  the Host panel (`network/last_port`, shared by both).
- **Menu wording.** "Play solo" and "Host and play" stay as two buttons
  (straight to a match, or start in Lantern Post); see Open decisions.
- Docs: ADR 0013 (added with this plan, replaces the "no open port" line of ADR 0004),
  `docs/MULTIPLAYER.md`, `docs/DECISIONS.md`, `docs/design/ui-hud.md` and a
  Change log row in `docs/design/game-design.md`.

Not in (non-goals, and where each one goes instead):

- Server password, server name, kicking a player: P8 server package
  (`docs/design/game-design.md` P8 row). Until then anyone with the address
  can join; the setting can turn it off.
- Server browser, LAN discovery, favourites: P8 (`ui-hud.md` screen 2).
- NAT punch-through or a relay for players behind carrier-grade NAT: needs a
  central service, which ADR 0006 rules out. Those players host from the
  launcher or a rented box instead.
- A Windows firewall rule written by an installer: the F-65 launcher can add
  one later. Until then Windows asks once on the first game.
- Keeping the game running after its owner quits: that is what hosting from
  the launcher (F-65 step 6) or Docker is for.
- Changing the handshake or version check: F-65 owns it; this plan sends no
  new network message.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 1 Co-op authority (shaky).
  Safe because this plan adds no shared state and no new message: it only changes
  when the existing listen-server path is used, and step 1 pins the solo/co-op
  switch with tests before any port opens.
- Decision records that apply (docs/adr/): 0003 trusted client (kept), 0004 one code path
  (changed: solo now has an open port) -> new ADR 0013 in step 1, 0006 self-hosted (kept,
  port 7777, no central service), 0011 UI router (pause screen and settings go through it).
- Co-op:
  - Who decides: the game's owner is the server, same as Host and play today.
  - How a client triggers it: Join with address and port, unchanged handshake.
  - What other players see: nothing new; the owner sees the join address.
  - Works on a dedicated server with no local player: yes, unchanged (it never runs
    the menu path; UPnP is not used there).
- Data: two new settings rows content/settings/network_open_to_friends.tres and
  network_upnp.tres. No gameplay numbers. Code compares against a specific id: no.
- Save: settings.cfg gains two keys with defaults (old files load, missing keys use
  DEFAULTS). Character saves unchanged. Renames or removes a saved id: no.
- Events and UI: no new Events. New Network tab inside the existing settings screen;
  pause screen gains one line and a button. Router: yes.
- Input through InputFrame, gameplay in _physics_process, session RNG: yes (no gameplay change).
- Tests: unit (Net.is_coop, open/fallback, PortOpener with a stand-in router, pause and
  results switch), integration (a second process joins a game started with Play solo).
- Logging: Log.warn net.port_busy, net.upnp_failed (reason), net.upnp_cgnat; Log.info
  net.upnp_opened, net.coop_started, net.coop_ended.
- Performance: nothing per frame. UPnP runs once in a thread. RemoteShots stops building
  relay packets while nobody else is connected.
- Out of scope: password, browser, relay, firewall rule (see Not in).
```

## Design references

- `docs/design/ui-hud.md#1-main-menu`: "Play solo starts a private local server
  in the background"; "Host and play: same as solo, but opens the port". This
  plan makes both open (the design doc gets updated in step 4).
- `docs/design/game-design.md` P8 row: password and server name belong to P8.
  Hosting line: "Friends connect by address and port (UDP port forwarding
  needed on the host's router)"; UPnP removes the manual forward where the
  router allows it.
- `docs/MULTIPLAYER.md` provisional picks: one code path, port 7777 UDP,
  mid-match joiners land in the running match (person, 2026-11-17).
- `docs/DECISIONS.md`: "Second Wind (solo)" stays solo-only, which now means
  "alone in the game"; "Main menu (co-op step 6)".
- ADR 0003, 0004, 0006, 0011. F-65 plan (`docs/plans/client-server-updates.md`,
  PR #299) for the handshake and the launcher-hosted server.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `core/net.gd` | changed | `is_coop()` (anyone else connected, or this peer is a client), `open_for_friends(port)` (listen or offline fallback, remembers why), `open_state` for the pause screen, `coop_changed` signal on first peer in / last peer out |
| `systems/net/player_state_sync.gd` | changed | `is_coop()` forwards to `Net.is_coop()` |
| `systems/player/revive.gd`, `systems/player/player.gd` | changed | read `Net.is_coop()` instead of "not offline" |
| `systems/ui/pause_screen.gd`, `.tscn` | changed | freeze only while alone; unfreeze and show the banner when a friend connects; "Friends join at" line + Copy (step 3) |
| `systems/ui/results_screen.gd`, `systems/ui/hud.gd` | changed | "Back to hub" and "REVIVED" follow `Net.is_coop()` |
| `systems/game/game_session.gd`, `systems/game/deploy_vote.gd` | changed | restart and quit rules follow `Net.is_coop()`; a lone owner's Play again reloads the match and keeps the port open |
| `systems/net/remote_shots.gd`, `systems/weapons/effects/chain.gd`, `systems/net/hit_claims.gd` | changed | relay only when peers exist (no packets built for nobody) |
| `systems/ui/main_menu.gd` | changed | Play solo calls `Net.open_for_friends()` before the match; Host and play uses the same call |
| `systems/net/port_opener.gd` | new | UPnP in a `Thread`: discover, add UDP mapping, read the external address, sort the result (opened, no router, failed, provider NAT); removes the mapping on close |
| `core/settings.gd` | changed | `network/open_to_friends: true`, `network/upnp: true` defaults |
| `content/settings/network_*.tres`, `systems/ui/settings_screen.tscn` | new / changed | Network tab with two toggles |
| docs | changed | ADR 0013, ADR README, MULTIPLAYER.md, DECISIONS.md, ui-hud.md, game-design.md Change log, LOGGING.md catalogue |

Autoloads, managers or base classes added: none. `PortOpener` is one small
script owned by `Net` (rule 6: it owns the router mapping, which nothing else
owns).

## Data

- Settings keys (in `user://settings.cfg`): `network/open_to_friends` bool,
  default `true`; `network/upnp` bool, default `true`. Read by
  `Net.open_for_friends()` and `PortOpener`. Old files without the keys use the
  defaults.
- Two `SettingData` rows, `page = &"network"`, `kind = &"toggle"`.
- `Net.open_state`: Dictionary for the pause screen, not saved, not sent:
  `{"status": &"open"|&"offline_busy"|&"offline_off", "port": int,
  "router": &"pending"|&"opened"|&"no_router"|&"failed"|&"cgnat"|&"off",
  "address": String}`.
- Save format change: none (settings keys only, with defaults).
- Network messages: none new. Protocol version unchanged.
- Content checks: the existing settings rows test covers the new rows (page id
  must be a real tab).

## Co-op behaviour

- Who owns the state: the game's owner runs the server, exactly as Host and
  play does today. Port and router mapping are local to the owner's PC.
- What clients send, what the server sends back: unchanged handshake and
  match traffic.
- What a client sees that the host sees too: nothing new. Only the owner sees
  "Friends join at".
- Late joiner: same as a mid-match joiner today (lands in the running match,
  or in the hub if the owner is there, with the existing snapshots).
- Dedicated server: unchanged. It never runs `open_for_friends()` and never
  uses UPnP. A launcher-hosted server on the same PC holds 7777, so the
  player's own game falls back to offline and says "Port 7777 is in use";
  the player joins their server with Join or the launcher's "Play on my
  server".
- Switch points: `Net.is_coop()` is read when a rule is used, never cached.
  A friend joining a paused solo game unpauses it (the game cannot finish a
  handshake while frozen). The owner downed alone follows solo rules; if a
  friend leaves while the owner is downed, the next squad check ends the run
  like today's co-op with one player left.

## Performance

No per-frame cost. UPnP discovery blocks for up to Godot's default 2 s, so it
runs in a `Thread` and posts its result with `call_deferred`. A listen server
with no peers costs what offline costs plus ENet polling (microseconds).
RemoteShots, Chain and gravity-well relays skip building packets while no
peer is connected, so solo shooting allocates no more than today.

## Steps

### Step 1: Alone means solo

- Build: `Net.is_coop()` returns true for a client, or for a server with at
  least one connected peer; false offline or alone. Replace every behaviour
  check that today means "not offline" (`PlayerStateSync.is_coop()`,
  `Revive._online()`, `Player.spawn()` profile look, `PauseScreen` banner and
  freeze, `ResultsScreen` button, `Hud` revive text, `GameSession` restart and
  quit, `DeployVote.back_to_hub`) with it. Pure RPC guards
  (`remote_shots.gd`, `chain.gd`, `hit_claims.gd`) switch to "peers exist".
  `Net` emits `coop_changed(on)` on the first peer in and last peer out;
  `PauseScreen` listens and unfreezes when it turns on. A lone Host and play
  owner now gets solo behaviour (pause freezes, Play again) until a friend
  joins. ADR 0013 (proposed, added with this plan) describes the rule.
- Files: `core/net.gd`, `systems/net/player_state_sync.gd`,
  `systems/player/revive.gd`, `systems/player/player.gd`,
  `systems/ui/pause_screen.gd`, `systems/ui/results_screen.gd`,
  `systems/ui/hud.gd`, `systems/game/game_session.gd`,
  `systems/game/deploy_vote.gd`, `systems/net/remote_shots.gd`,
  `systems/weapons/effects/chain.gd`, `systems/net/hit_claims.gd`,
  `tests/unit/test_net.gd`,
  `tests/unit/test_pause_screen.gd`, `tests/unit/test_results_screen.gd`,
  `tests/unit/test_solo_coop_switch.gd` (new, uses
  `tests/unit/coop_interaction_fixture.gd`).
- Tests: a listen server with no peers: `Net.is_coop()` false, pause freezes
  the tree, results say Play again, a downed owner follows the solo down rules
  with no bleed-out (fails today: a listen server counts as co-op). A peer joins: `is_coop()`
  true, an open pause screen unfreezes, `coop_changed(true)` fires once. The
  peer leaves: back to false. Offline solo unchanged. Existing co-op and
  revive tests stay green.
- Done when: a Host and play game with nobody joined plays exactly like Play
  solo, and turns into co-op the moment a friend joins.

### Step 2: Every game opens its port

- Build: `Net.open_for_friends(port)`: when `network/open_to_friends` is on,
  calls `host(port)`; on failure logs `net.port_busy` and stays offline. Sets
  `open_state`. Play solo calls it with `network/last_port` before
  `UI.replace(&"match")`; Host and play calls it with the panel's port (and
  still shows the busy-port error, since there the player asked for that
  port). Play again (alone) reloads the match without closing the port; Main
  menu closes it. Settings: `network/open_to_friends` default, Network tab in
  the settings screen with the first toggle. Pause screen: one line "Friends
  can join on port 7777" or "Port 7777 is in use, friends can't join" or
  nothing when the setting is off (the full address comes in step 3).
  `parse_launch` gains nothing: `--host` stays the test entry.
- Files: `core/net.gd`, `core/settings.gd`, `systems/ui/main_menu.gd`,
  `systems/game/game_session.gd`, `systems/ui/pause_screen.gd`, `.tscn`,
  `systems/ui/settings_screen.tscn`,
  `content/settings/network_open_to_friends.tres` (new),
  `tests/unit/test_net.gd`, `tests/unit/test_main_menu.gd`,
  `tests/unit/test_settings.gd`, `tests/integration/test_net_match.gd`.
- Tests: Play solo with the setting on leaves Net listening on the saved
  port (fails today: offline); with the setting off stays offline; with the
  port held by another `ENetMultiplayerPeer` falls back to offline with
  `status = offline_busy` and starts the match. Play again keeps the port.
  Integration: a game process started through the solo path accepts a second
  process's join and both see two players.
- Done when: a friend can type the owner's LAN address in Join and land in a
  game the owner started with Play solo.

### Step 3: Router port and join address

- Build: `PortOpener` (new, `RefCounted`, owned by `Net`): when
  `network/upnp` is on and the port is open, runs `UPNP.discover()`, picks
  the valid gateway, `add_port_mapping(port, port, "Experiment Undead",
  "UDP", 0)` and `query_external_address()` in a `Thread`. Sorts the result:
  `opened` (address = external), `cgnat` (external address is private or in
  100.64.0.0/10: "Your internet provider blocks direct joins; friends on your
  network can still join"), `no_router` (no UPnP answer: "Open UDP <port> on
  your router to let friends join over the internet"), `failed` (router said
  no). Without a public address the line shows the first private IPv4 from
  `IP.get_local_addresses()`. `Net.leave()` removes the mapping (in the
  thread, with a 2 s cap, so quitting never hangs). The router object is
  injected so tests use a stand-in. Pause screen: "Friends join at
  81.2.3.4:7777" + Copy (`DisplayServer.clipboard_set`) + the reason line.
  Second Network toggle `network/upnp`. Log lines as in Ready to build.
- Files: `systems/net/port_opener.gd` (new), `core/net.gd`,
  `core/settings.gd`, `systems/ui/pause_screen.gd`, `.tscn`,
  `content/settings/network_upnp.tres` (new),
  `tests/unit/test_port_opener.gd` (new), `tests/unit/test_pause_screen.gd`,
  `docs/LOGGING.md`.
- Tests: with a stand-in router: success gives `opened` and the external
  address; a 100.64.x.x answer gives `cgnat`; no gateway gives `no_router`
  with the LAN address; a refused mapping gives `failed`; leave removes the
  mapping once; upnp off never calls discover. On the real headless CI box
  discover finds nothing, so the real path ends in `no_router` without
  hanging the test (timeout guard). Pause screen shows the address line and
  Copy puts `address:port` on the clipboard.
- Done when: on a home router with UPnP, a friend over the internet joins
  with the address the pause screen shows; without UPnP the screen says why.

### Step 4: Menu wording and close-out

- Build: menu wording from the decision below. Update `docs/MULTIPLAYER.md`
  (one code path line, a "Joining any game" section), `docs/DECISIONS.md`,
  `docs/design/ui-hud.md` main menu, a dated Change log row in
  `docs/design/game-design.md`, ADR 0013 accepted, roadmap row Done, and add a
  two-PC line to play-test issue #191. Use the `finish-feature` skill.
- Files: `systems/ui/main_menu.tscn`, `systems/ui/main_menu.gd`,
  `tests/unit/test_main_menu.gd`, the docs above.
- Tests: menu buttons have the decided labels and still route to match and
  hub (fails before the rename).
- Done when: all Acceptance lines are ticked or listed on #191 for the
  person's play-test.

## Acceptance

- [ ] A game started with Play solo accepts a join from a second process (integration test).
- [ ] Alone, a joinable game plays like solo: pause freezes, Second Wind, Play again (unit tests).
- [ ] When a friend joins, the game switches to co-op rules, and back when they leave (unit tests).
- [ ] Busy port or setting off: the game starts offline and the pause screen says why (unit tests).
- [ ] UPnP results are sorted into opened, no router, failed and provider NAT (unit tests with a stand-in router).
- [ ] Two PCs on different home networks: one plays solo, the other joins with the shown address (play-test, #191).

## Risks

- **Solo behaviour drifts.** About fifteen checks mean "solo" today. Step 1
  changes only those, with tests on both sides of the switch, before any port
  opens, so a miss shows up as a red test and not as a broken solo game.
- **Joining a paused game.** A frozen tree cannot finish the handshake.
  Step 1 unpauses on the first peer; the step 1 test covers it.
- **UPnP hangs or crashes.** It runs in a thread with Godot's own timeout,
  and the real-router path is exercised headless in CI (it ends in
  `no_router`). If Godot's UPnP module is missing from an export template,
  `PortOpener` sees `ClassDB.class_exists("UPNP")` false and reports
  `no_router`.
- **Strangers join.** No password until P8. UPnP opens the port only while
  the game is open; the setting turns it off. A crash can leave a router
  mapping behind; it points at a closed port and is replaced on the next game.
- **Windows firewall prompt** now appears on the first Play solo instead of
  the first Host. The F-65 launcher can add the rule later.
- **Merge order with F-65 (PR #299).** Both add a roadmap row and an ADR; the
  second to merge renumbers. Neither changes the other's code.

## Open decisions

- [ ] Open the router port automatically (UPnP) by default? Recommended: yes, on by default, with the setting to turn it off.
- [ ] Main menu: keep two buttons, renamed "Play" (straight to a match) and "Play in hub" (start in Lantern Post)? Recommended: yes; the alternatives are one Play button into the hub, or leaving the labels as they are.
