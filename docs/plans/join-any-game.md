# Plan: Your own world, open to friends, and a server browser

Status: Review
Roadmap: F-66
Phase: P7
Size: L
Approved by:

## Goal

One flow for everyone: the launcher's Play opens the game at the main menu,
the player picks a character and presses **Enter world**, and lands in their
own Lantern Post. That world is a listen server: friends can find it and join
it. Nobody is ever dropped straight into someone else's game: joining a friend
or a dedicated server goes through the **server browser**, which lists servers
you added by address, servers you joined before, and games found on your own
network on their own. Serves the co-op pillar ("better with friends") and the
week goal of co-op that just works.

## Scope

In:

- **Alone means solo.** One rule decides solo or co-op behaviour: "is anyone
  else connected right now?" A world with nobody else in it plays exactly like
  solo today (pause freezes, Second Wind, Play again). When a friend joins it
  follows the co-op rules; when the last friend leaves it is solo again.
- **Enter world.** The main menu gets one big Enter world button (default
  focus) that starts the player's own Lantern Post as a listen server on the
  saved port (default 7777, ADR 0006), deploys from the Deploy board as
  today, and comes back to the hub after a match. If the port is taken, or
  "Let friends join my world" is off, the world runs offline and says so.
  Play solo, Host and play and the Join panel go away (Join moves into the
  browser's Direct connect).
- **Router port and address.** UPnP (Godot's built-in `UPNP` class, on by
  default: the person, 2026-11-17) opens the game and info ports on the
  router once per game run. The pause screen shows "Friends add you at
  <address>:<port>" with a Copy button, or one plain line on why internet
  friends cannot (no router answer, provider NAT).
- **Server info and LAN discovery.** Every server (an open world and a
  dedicated server) answers a small UDP info query on its info port (game
  port + 1) with name, players, max players, what it is playing, version and
  protocol. The browser broadcasts that query on the local network to find
  games there with no typing.
- **Server browser** ("Play online", `docs/design/ui-hud.md` screen 2 and its
  mockup): saved and recent servers plus LAN finds, columns name, players,
  now playing, ping, tags (LAN, Full, Version). Direct connect field (address
  and port) adds and joins. Favourite, rename, remove. Refresh. Errors in
  plain words, reusing `NetErrorDialog`.
- **Settings.** A Network page: "Let friends join my world" (on), "Open
  router port automatically" (on), "World name" (default: the computer name,
  like the mockup's "LAN: DESKTOP-K2"), port.

Not in (non-goals, and where each one goes instead):

- **Picking a character** before Enter world: needs character slots and the
  create screen (`ui-hud.md` screen 3), its own plan F-67. Until it lands,
  Enter world uses today's single `solo` character; F-67 puts its screen
  between the menu and the world.
- **A master server** listing games over the internet: not now (the person,
  2026-11-17). ADR 0006 stands. The browser takes its rows from sources
  (saved list, LAN), so a list server or store lobbies can be one more source
  later without redoing the screen.
- Server password and the lock column, admin commands: P8 (F-44).
- Launcher Play button: F-65 step 5 (it already starts the game at the main
  menu, so nothing changes there).
- NAT punch-through or a relay for players behind carrier-grade NAT: needs a
  central service. Those players join others, or host from the launcher.
- A Windows firewall rule written by an installer: the F-65 launcher can add
  one later. Until then Windows asks once on the first Enter world.
- Keeping a world running after its owner quits: launcher-hosted server
  (F-65 step 6) or Docker.
- Several matches on one server ("2 matches running" in the mockup): later
  with F-45; this plan shows the one match or "Lantern Post".

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 1 Co-op authority (shaky).
  Safe because no shared gameplay state or match message is added: the world uses the
  existing listen-server path, and step 1 pins the solo/co-op switch with tests before
  any port opens. The info query is a separate UDP socket outside the match.
- Decision records that apply (docs/adr/): 0003 trusted client (kept), 0004 one code path
  (changed: solo has an open port) -> ADR 0013 (proposed) added with this plan, 0006
  self-hosted, no master server (kept, person 2026-11-17), 0011 UI router (browser is a
  router screen).
- Co-op:
  - Who decides: the world's owner is the server, same as Host and play today.
  - How a client triggers it: Join from the browser, unchanged ENet handshake.
  - What other players see: nothing new in the match. Browsers see the info reply.
  - Works on a dedicated server with no local player: yes; it answers info queries too.
- Data: settings rows content/settings/network_*.tres; saved servers in
  user://servers.cfg (ConfigFile). No gameplay numbers. Code compares a specific id: no.
- Save: settings.cfg gains keys with defaults; servers.cfg is new. Character saves
  unchanged. Renames or removes a saved id: no.
- Events and UI: no new Events. New router screen `server_browser`; settings Network tab;
  pause screen line. Router: yes.
- Input through InputFrame, gameplay in _physics_process, session RNG: yes (no gameplay change).
- Tests: unit (Net.is_coop switch, open/fallback, PortOpener with a stand-in router,
  ServerInfo reply/parse, ServerList save/load, browser screen), integration (a second
  process finds a world by LAN query and joins it).
- Logging: Log.warn net.port_busy, net.upnp_failed (reason), net.upnp_cgnat,
  net.info_port_busy, net.info_bad_packet (rate-limited); Log.info net.upnp_opened,
  net.coop_started, net.coop_ended.
- Performance: nothing per frame in the match except one non-blocking UDP poll per
  physics tick on the server (a few microseconds, no allocation when idle). UPnP runs
  in a thread.
- Out of scope: character select (F-67), master server, password, relay (see Not in).
```

## Design references

- `docs/design/ui-hud.md` screen 1 (main menu) and screen 2 (server browser,
  "There is no master server ... servers you added or joined before, plus
  servers found on your local network (LAN broadcast on UDP 24600)").
  `docs/design/images/ui_server_browser.jpg`: title "Play online", columns,
  Direct connect panel, detail card, footer keys (Join, Favourite, Refresh,
  Back). This plan follows it except the password field (P8) and the fixed
  broadcast port (see Data: info port = game port + 1, because two servers on
  one PC cannot share one port).
- `docs/design/game-design.md` P8 row (password, name, admin belong to P8)
  and hosting line ("Friends connect by address and port").
- `docs/MULTIPLAYER.md`: one code path, port 7777 UDP, joiners land where the
  server is (hub or running match), squads deploy from the hub (person,
  2026-11-17).
- `docs/DECISIONS.md`: "Second Wind (solo)" (now "alone in the world"),
  "Main menu (co-op step 6)" (replaced by this plan).
- ADR 0003, 0004, 0006, 0011; F-65 plan (`docs/plans/client-server-updates.md`,
  PR #299) for the version handshake and the launcher.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `core/net.gd` | changed | `is_coop()`, `coop_changed(on)`, `open_world(port)` (listen or offline fallback), `open_state` for the pause screen, owns `PortOpener` and `ServerInfo` |
| `systems/net/player_state_sync.gd`, `systems/player/revive.gd`, `systems/player/player.gd` | changed | solo/co-op checks read `Net.is_coop()`; downed rule stored per down |
| `systems/ui/pause_screen.gd`, `.tscn` | changed | freeze only while alone; unfreeze when a friend connects; address line + Copy |
| `systems/ui/results_screen.gd`, `systems/ui/hud.gd` | changed | button and revive text follow `Net.is_coop()` |
| `systems/game/game_session.gd`, `systems/game/deploy_vote.gd` | changed | restart keeps the port; match-end level freeze follows peers |
| `systems/net/remote_shots.gd`, `systems/weapons/effects/chain.gd`, `systems/net/hit_claims.gd` | changed | relay only when peers exist |
| `systems/ui/main_menu.gd`, `.tscn` | changed | Enter world + Play online; host and join panels removed |
| `systems/net/port_opener.gd` | new | UPnP in a `Thread`, once per game run, lease 3600 s |
| `systems/net/server_info.gd` | new | UDP info responder (server) and query/parse helpers (browser) |
| `systems/net/dedicated_server.gd` | changed | starts `ServerInfo` with its name and port |
| `systems/ui/server_browser.gd`, `.tscn` | new | the Play online screen |
| `systems/ui/server_list.gd` | new | saved and recent servers in `user://servers.cfg` |
| `content/screens/server_browser.tres` | new | router entry |
| `core/settings.gd`, `content/settings/network_*.tres`, `systems/ui/settings_screen.tscn` | changed / new | Network page |
| docs | changed | ADR 0013, MULTIPLAYER.md, DECISIONS.md, ui-hud.md, game-design.md Change log, LOGGING.md |

Autoloads, managers or base classes added: none. `PortOpener` and `ServerInfo`
are small scripts owned by `Net` (rule 6: they own the router mapping and the
info socket, which nothing else owns). `ServerList` owns the saved list.

## Data

- Settings (`user://settings.cfg`, section `network`): `open_to_friends` bool
  `true`; `upnp` bool `true`; `world_name` String `""` (empty shows
  `OS.get_environment("COMPUTERNAME")` or `HOSTNAME`, else "Lantern Post");
  `last_port` int 7777 (exists). `last_address` stays for Direct connect.
  Old files load with the defaults.
- `user://servers.cfg` (ConfigFile, new): one section per `address:port`
  with `name` String, `favourite` bool, `last_joined` int (unix time). Recent
  list keeps the newest 20 non-favourites. Unknown keys are kept.
- Info packet (UDP, game port + 1; not an ENet message): query is the 4 bytes
  `EUQ1`. Reply is `EUR1` plus UTF-8 JSON with frozen keys
  `{"name", "players", "max", "playing", "version", "protocol"}`; at most 512
  bytes; unknown keys ignored, so later versions can add fields. `playing` is
  "Lantern Post", "Halcyon Labs, round 12" or "Starting". The server answers
  at most 20 queries per second in total and never more than one reply per
  query, so it cannot be used to flood someone.
- LAN discovery: broadcast `EUQ1` to 255.255.255.255 on info ports 7778 to
  7785 (game ports 7777 to 7784), collect replies for 1 s.
- `Net.open_state` (not saved, not sent): `{"status": open|offline_busy|
  offline_off, "port", "router": pending|opened|no_router|failed|cgnat|off,
  "address"}`.
- Network messages in the match: none new; protocol version unchanged.
- Content checks: the settings rows test covers the new rows; the screens
  test covers `server_browser.tres`.

## Co-op behaviour

- Who owns the state: the world's owner runs the server. Port, router
  mapping, info socket and saved servers are local to each PC.
- What clients send, what the server sends back: unchanged handshake and
  match traffic. Browsers send `EUQ1`; servers reply.
- What a client sees that the host sees too: nothing new in the world. Only
  the owner sees "Friends add you at".
- Late joiner: joins the world wherever it is (hub, or the running match), with
  the existing snapshots.
- Dedicated server: answers info queries with its name; never runs UPnP; it
  is always open.
- Switch points: `Net.is_coop()` is read when a rule is used, never cached,
  except where noted. A player downed under the solo rules keeps the solo rule
  for that down (Second Wind runs out normally) even if a friend joins during
  it. A friend joining a paused solo world unpauses it so the joiner's world
  runs; if the last friend leaves while the pause screen is open, it stays
  unfrozen until closed. If a friend leaves while the owner is downed, the next
  squad check ends the run, as with co-op today.

## Performance

No per-frame cost in the match except `ServerInfo.poll()` once per physics
tick on the server: one `PacketPeerUDP.get_available_packet_count()` call, no
allocation when idle. UPnP discovery blocks up to Godot's default 2 s, so it
runs in a `Thread` and posts its result with `call_deferred`. RemoteShots,
Chain and gravity-well relays skip building packets while no peer is
connected. The browser queries each listed server once per Refresh, not per
frame.

## Steps

### Step 1: Alone means solo

- Build: `Net.is_coop()` is true for a client, or for a server with at least
  one connected peer. Replace the behaviour checks that today mean "not
  offline": `PlayerStateSync.is_coop()` (forwards to Net, so `squad_cards.gd`,
  `coop_hud.gd`, `down_screen.gd` and `player.gd` 220/335 follow on their
  own), `Revive._online()`, `PauseScreen` banner and freeze (track a `_froze`
  bool, not `banner.visible`), `ResultsScreen` button (read the rule again when
  pressed), `Hud` revive text, `GameSession.restart()`, the match-end level
  freeze (`game_session.gd` near line 341, now "peers exist"),
  `DeployVote.back_to_hub`. Delete the duplicate profile-look block in
  `Player.spawn()` (GameSession already applies the look). Pure RPC guards
  (`remote_shots.gd`, `chain.gd`, `hit_claims.gd`) switch to "peers exist".
  `auto_accept_quit` and the close-request check in `GameSession` stay on
  `Net.is_online()`: they are about the open socket, not the rules. A down
  stores which rule it started under (solo Second Wind or co-op bleed-out), so
  a joiner mid-down does not kill the owner. `Net` emits `coop_changed(on)` on
  the first peer in and the last peer out; `PauseScreen` unfreezes on `true`.
  A lone Host and play owner now gets solo behaviour until a friend joins.
- Files: `core/net.gd`, `systems/net/player_state_sync.gd`,
  `systems/player/revive.gd`, `systems/player/player.gd`,
  `systems/ui/pause_screen.gd`, `systems/ui/results_screen.gd`,
  `systems/ui/hud.gd`, `systems/game/game_session.gd`,
  `systems/game/deploy_vote.gd`, `systems/net/remote_shots.gd`,
  `systems/weapons/effects/chain.gd`, `systems/net/hit_claims.gd`,
  `tests/unit/test_net.gd`, `tests/unit/test_pause_screen.gd`,
  `tests/unit/test_results_screen.gd`, `tests/unit/test_solo_coop_switch.gd`
  (new, two peers in one process like `coop_interaction_fixture.gd`).
- Tests: listen server with no peers: `is_coop()` false, pause freezes,
  results say Play again, a downed owner follows the solo rule, the level is
  not frozen at match end (all fail today). A peer joins: `is_coop()` true,
  `coop_changed(true)` once, an open pause screen unfreezes, squad cards show.
  A peer joins during solo Second Wind: the owner gets up, not dead. The peer
  leaves: back to false. Offline solo unchanged; existing co-op tests green.
- Done when: a Host and play game with nobody in it plays exactly like Play
  solo, and turns into co-op the moment a friend joins.

### Step 2: Enter world

- Build: `Net.open_world(port)`: when `network/open_to_friends` is on, calls
  `host(port)`; on failure logs `net.port_busy` and stays offline; sets
  `open_state`. Main menu: one big **Enter world** button (default focus)
  that calls it with `network/last_port` and goes to the hub
  (`UI.replace(&"hub")`); **Play online** opens the browser (until step 5 it
  opens the existing Join panel, so joining keeps working). Play solo, Host
  and play and the Host panel go. Restart while alone sets
  `Net.changing_place` before `UI.reload` so the port stays open
  (`start_pending_join` clears it); Main menu closes the port. `--host` and
  `--join=` launch flags stay for tests and the soak. Settings: Network page
  with "Let friends join my world" and the port. Pause screen: "Friends can
  join on port 7777" or "Port 7777 is in use, friends can't join", or nothing
  when off.
- Files: `core/net.gd`, `core/settings.gd`, `systems/ui/main_menu.gd`,
  `.tscn`, `systems/game/game_session.gd`, `systems/ui/pause_screen.gd`,
  `.tscn`, `systems/ui/settings_screen.tscn`,
  `content/settings/network_open_to_friends.tres`,
  `content/settings/network_port.tres` (new), `tests/unit/test_net.gd`,
  `tests/unit/test_main_menu.gd`, `tests/unit/test_main_menu_screens.gd`,
  `tests/unit/test_settings.gd`, `tests/integration/test_net_match.gd`.
- Tests (ports 24645+, never 7777): Enter world leaves Net listening and
  routes to the hub (fails today: no such button); setting off stays offline;
  port held by another `ENetMultiplayerPeer` falls back to offline with
  `offline_busy`; restart alone keeps the port. Integration: a world started
  through Enter world accepts a second process's `--join`, both see two
  players in the hub.
- Done when: a friend on the same network can join a world started with
  Enter world.

### Step 3: Router port and address

- Build: `PortOpener` (`RefCounted`, owned by `Net`): when `network/upnp` is
  on, the first `open_world` of a game run starts a `Thread` that runs
  `UPNP.discover()`, takes the valid gateway, maps the game port and the info
  port (UDP, lease 3600 s, falling back to 0 if the router refuses a lease),
  and reads the external address. Results: `opened`, `cgnat` (external
  address private or in 100.64.0.0/10), `no_router`, `failed`. The mapping
  stays for the whole game run while the port is unchanged (no churn per
  match) and is renewed every 50 minutes; it is removed only when the game
  quits (`Net._exit_tree` / close request), with `wait_to_finish` on the
  thread. A `leave()` during discovery just drops the result. Without a public
  address the line uses the first private IPv4 from `IP.get_local_addresses()`.
  If `ClassDB.class_exists("UPNP")` is false, the result is `no_router`.
  Pause screen: "Friends add you at 81.2.3.4:7777" + Copy
  (`DisplayServer.clipboard_set`) + the reason line. Settings toggle
  `network/upnp`.
- Files: `systems/net/port_opener.gd` (new), `core/net.gd`,
  `core/settings.gd`, `systems/ui/pause_screen.gd`, `.tscn`,
  `content/settings/network_upnp.tres` (new),
  `tests/unit/test_port_opener.gd` (new), `tests/unit/test_pause_screen.gd`,
  `docs/LOGGING.md`.
- Tests: only a stand-in router object (tests set `network/upnp` off for
  everything else, so CI never runs a real discovery): success gives `opened`
  and the address; 100.64.x.x gives `cgnat`; no gateway gives `no_router`
  with the LAN address; a refused lease retries with 0; a refused mapping
  gives `failed`; a second `open_world` in the same run does not map again;
  quitting removes both mappings once. Pause screen shows the line and Copy
  puts `address:port` on the clipboard.
- Done when: on a home router with UPnP, the pause screen shows the internet
  address; without it, the screen says why.

### Step 4: Server info and LAN discovery

- Build: `ServerInfo` (new, owned by `Net`): on the server, binds a
  `PacketPeerUDP` to game port + 1 when the world opens (and in
  `DedicatedServer`), polls it in `Net._physics_process`, and answers `EUQ1`
  with the `EUR1` JSON reply (name, players, max, playing, version,
  protocol), capped at 20 replies per second. A busy info port only logs
  `net.info_port_busy`; joining still works. Browser side: static
  `ServerInfo.query(address, port)` and `ServerInfo.discover()` (broadcast to
  info ports 7778 to 7785) send and collect replies for 1 s on a client
  socket, with ping from send to reply. Settings: "World name".
- Files: `systems/net/server_info.gd` (new), `core/net.gd`,
  `systems/net/dedicated_server.gd`, `core/settings.gd`,
  `content/settings/network_world_name.tres` (new),
  `tests/unit/test_server_info.gd` (new),
  `tests/integration/test_net_match.gd`.
- Tests: reply builder gives the frozen keys and stays under 512 bytes with a
  long name; parser ignores unknown keys and rejects bad packets; the rate cap
  answers 20 and drops the rest; a world on port 24645 answers a query on
  24646 with its name and player count (fails without the step). Integration:
  a second process queries a dedicated server on loopback and then joins it.
- Done when: a query to any running world or dedicated server returns its
  name, players and what it is playing.

### Step 5: The server browser

- Build: `server_browser` router screen ("Play online", the mockup): list from
  `ServerList` (favourites first, then recent) plus `ServerInfo.discover()`
  finds tagged LAN; each row queried on open and on Refresh (R); columns name,
  players, now playing, ping (colours from `look-rules.md`), tags LAN / Full /
  Version mismatch / Not responding. Detail card for the selected row. Direct
  connect (address and port) adds the server to recent and joins through the
  existing `Net.pending_join` path and `NetErrorDialog`. Favourite (F),
  rename, remove, Join (Enter), Back (Esc), with gamepad focus. A version
  mismatch row says "Version mismatch: server X, you Y" before joining.
  `ServerList` saves `user://servers.cfg` and records every successful join.
  The old Join panel goes.
- Files: `systems/ui/server_browser.gd`, `.tscn` (new),
  `systems/ui/server_list.gd` (new), `content/screens/server_browser.tres`
  (new), `systems/ui/main_menu.gd`, `.tscn`,
  `tests/unit/test_server_list.gd` (new),
  `tests/unit/test_server_browser.gd` (new),
  `tests/unit/test_main_menu_screens.gd`.
- Tests: `ServerList` add, favourite, rename, remove, recent cap of 20,
  unknown keys kept, missing file is empty; the browser fills rows from a
  stand-in list and stand-in replies, sorts by ping, tags Full and Version
  mismatch, Direct connect with a bad address shows the error and joins
  nothing; Play online opens the screen (fails without the step).
- Done when: a player can add a friend's world by address once, see it in
  the list with players and ping next time, and join it from there; worlds on
  the same network show up without typing.

### Step 6: Close-out

- Build: update `docs/MULTIPLAYER.md` (one code path, a "Worlds and the
  browser" section), `docs/DECISIONS.md` (replace "Main menu (co-op step 6)"),
  `docs/design/ui-hud.md` screens 1 and 2 (Enter world, info port), a dated
  Change log row in `docs/design/game-design.md`, ADR 0013 accepted, roadmap
  row Done, and a two-PC line on play-test issue #191. Use `finish-feature`.
- Files: the docs above.
- Tests: none new (docs only); all earlier tests green.
- Done when: all Acceptance lines are ticked or listed on #191.

## Acceptance

- [ ] Alone, a world plays like solo; a joining friend switches it to co-op and back (unit tests).
- [ ] Enter world opens the port and lands in Lantern Post; busy port or setting off starts offline and says why (unit tests).
- [ ] A second process joins a world started with Enter world (integration test).
- [ ] UPnP results are sorted into opened, no router, failed and provider NAT, mapped once per run (unit tests, stand-in router).
- [ ] A query returns name, players and what a world or dedicated server is playing; LAN discovery finds it (unit and integration tests).
- [ ] The browser lists saved, recent and LAN servers with ping and tags, and joins from a row or Direct connect (unit tests).
- [ ] Two PCs on different home networks: one enters their world, the other adds it by address in the browser and joins (play-test, #191).

## Risks

- **Solo behaviour drifts.** About fifteen checks mean "solo" today. Step 1
  changes only those, with tests on both sides of the switch, before any port
  opens.
- **Joining a paused world.** The handshake runs in the multiplayer poll,
  which Godot runs while paused, so the join completes; the level would stay
  frozen for the joiner. Step 1 unpauses on the first peer.
- **UPnP blocks or fails.** It runs in a thread, once per game run; removal
  happens only on quit with `wait_to_finish`, so a slow router can delay
  quitting by its timeout, never a match. CI never runs real discovery.
- **Strangers join.** No password until P8. LAN finds only reach your own
  network; over the internet a stranger needs your address. The setting
  turns the world private. A crash leaves at most a 1-hour lease.
- **Info port busy** (two worlds on one PC): joining still works; only the
  browser cannot see that world. Logged.
- **Losing the quick solo start.** Every game now goes through the hub and
  the Deploy board; the soak and tests keep using `--host` / scene flags.
- **Merge order with F-65 (PR #299).** Both add a roadmap row and an ADR; the
  second to merge renumbers. The info reply carries `version` and `protocol`
  so the browser can warn before F-65's handshake refuses.

## Open decisions

- [x] Open the router port automatically (UPnP) by default? Yes, on by default, with the setting to turn it off (the person, 2026-11-17).
- [x] Main menu shape? One big Enter world button into your own Lantern Post after picking a character; nothing joins you straight into a friend's game; joining goes through a server browser (the person, 2026-11-17).
- [x] Master server for finding games over the internet? None for now: saved list, add by address, LAN discovery (the person, 2026-11-17).
