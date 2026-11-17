# Plan: First Lantern Post hub (blockout and deploy board)

Status: Done
Roadmap: F-50 / issue #131 (first slice of F-45)
Phase: P9 (pulled forward for the co-op week goal)
Size: M
Approved by: Codex plan review on PR #222 (no findings, 2026-11-17); the person approved the town look and asked for a ready-up vote (2026-11-17); vote section re-reviewed by a Claude plan review (2026-11-17), its findings fixed. Step 2 also needs the same interface text in `coop-full-match.md` (co-op thread adds it with its vote step).

## Goal

Players who join a server land in a small Lantern Post town instead of the
match, walk to the Deploy board and press Ready for Halcyon Labs, and when
everyone is ready the whole server deploys. They come back to the town when
the match ends. Serves the co-op pillar ("friends meet, squad up,
deploy, return with loot", game-design.md P9) and gives the week goal its
join, hub, play, return loop.

This plan covers the town scene and the board. The co-op thread's plan
`docs/plans/coop-full-match.md` (F-47, steps 4-5) covers the session that
runs the hub, `deploy()`, switching places and the return. The interface
between the two is in "Systems touched" and is the same in both plans.

## Scope

In:

- `levels/lantern_post/lantern_post.tscn`: a walled street with houses, lit
  windows, orange sodium lamps, fire barrels, pines outside the walls and the
  green Deploy Gate at the north end. Grey-box `Block` nodes and the existing
  materials, Cold Containment town look (look-rules.md "Lantern Post").
- Room for 8 players at the spawn (PlayerSpawner already lines them up 1.2 m
  apart from one marker).
- One Deploy board in front of the gate: pressing interact readies you for
  Halcyon Labs (or cancels your ready), through the normal F-02 interaction
  request path and the co-op thread's `DeployVote`.
- A deploy vote panel in the town: map name, every player with a ready tick,
  and the 5-second countdown (ui-hud.md screen 8 numbers).
- A render tool for the look check (`tools/hub_shot.gd`).

Not in (and where it goes):

- Hub session, `deploy()`, place switching, return to hub, main menu and
  dedicated server landing in the hub (co-op thread, `coop-full-match.md`).
- Map list screen with map cards, squads (1-4 of the 8), squad leader, "matches
  running 1 of 2" (F-45 later step; ui-hud.md screen 8). A screen arrives
  with the second map; until then one board per map is the pick and the whole
  server is one squad.
- Vote state, its network sync and the countdown (co-op thread, `DeployVote`).
- `MapData` resource: added when the second map arrives (third-use rule,
  agreed with the co-op thread). The board points at a screens id for now.
- Stash, Workbench, Quartermaster, Trainer, Contract Board, Firing Range,
  Hall of Records, NPCs, town HUD, chat, emotes, infirmary wake-up (F-45).
- Baked lightmap and the sweeping watchtower spotlight (local GPU bake after
  the layout is approved; look-rules.md asks for fully baked light).
- Town ambience and music (later audio row).

## Ready to build

### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 2 interactions
  (F-02 request path, done), 5 UI router (not used by this plan's steps).
  Any of them shaky or missing? No, both done.
- Decision records that apply (docs/adr/): 0003 trusted client, 0004 one code
  path, 0008 code-built assets first, 0011 one UI router. Does this go against
  one? no
- Co-op:
  - Who decides: server. The board's `interact()` runs only where
    `Net.is_authority()` (InteractionSync); `DeployVote.toggle_ready()` is
    server only and calls `deploy()` when everyone is ready.
  - How a client triggers it: presses interact on the board; InteractionSync
    sends the request, the server checks sender, range and rate (F-02) and
    runs `interact()`. `deploy()` refuses when the session is not the hub, a
    place change is running or the place id is unknown.
  - What other players see: every peer changes place together (co-op thread).
    The town itself is static geometry on every peer.
  - Works on a dedicated server with no local player: yes (the server runs
    `interact()` for the client's request).
- Data: the board's place is an exported `StringName` that names a
  `content/screens/*.tres` id; its label is an exported string. Code compares
  against a specific id anywhere: no (the id lives in the scene, not in code).
- Save: changes what is saved? no
- Events and UI: listens to `Events.deploy_vote_changed` (added by the co-op
  thread, fired on every peer). The vote panel is a small CanvasLayer in the
  town, not a pushed screen, and never takes the mouse: n.a. for the router.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (no new input, no randomness).
- Tests: `tests/unit/test_lantern_post.gd` (scene), `tests/unit/test_deploy_board.gd`
  (board, run from a client in the two-peer fixture).
- Logging: none new. `deploy()` already logs `net.deploy_refused`.
- Performance: nothing created per frame. Static scene: about 800 nodes
  (detail meshes share one BoxMesh per material), about 25 OmniLights (6 with shadows). Check fps on the GPU agent with 8
  players before F-45 adds more.
- Out of scope: see "Not in".

## Design references

- docs/design/look-rules.md#lantern-post-town: warm village at night,
  lanterns, fire barrels, lit windows, cold blue fog, pines outside the walls,
  the only green is the Deploy Gate. Reference: docs/design/images/style_hub.jpg.
- docs/design/lore.md#lantern-post-and-its-people: orange sodium lamps on every
  roof mean safe.
- docs/design/game-design.md#town-hub-lantern-post: Deploy Gate picks the map;
  up to 8 players per server.
- docs/design/ui-hud.md: "from the town, the Deploy Gate is the only way into a
  match"; screen 8 (deploy gate) is later.
- docs/MULTIPLAYER.md and docs/adr/0003-trusted-client-co-op.md: client asks,
  server decides.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| levels/lantern_post/lantern_post.tscn | new | Town scene. Root uses `systems/level/level.gd` (`Level`), `player_spawn` set, no `navigation_region` (so `Level._ready()` calls `_finish()` and `is_navigation_ready` is true on load), no zombie spawn points |
| levels/looks/lantern_post_night.tres | new | Night Environment: dark blue sky, blue volumetric fog, glow |
| levels/materials/town_surface.gdshader + town_stone/plaster/planks/dark_wood/slate/cobbles/snow.tres | new | One world-space shader for stone courses, timber-framed plaster, planks, slate with snow, wet cobbles and snow; no UVs or texture files (code-built assets first, ADR 0008) |
| levels/materials/sodium_lamp.tres, lit_window.tres, pine.tres, iron.tres | new | Emissive sodium lamp, warm window, pine, dark iron |
| tools/assets/town_props.py, assets/models/town/*.glb (+ .import), docs/design/turnarounds/town/*.png | new | Blender-built street lamp, wall lantern, lit and dark windows with shutters, fence, signpost; new `town` folder in check_models.py BUDGETS (2,500 triangles, 4 materials) and turnarounds REFERENCES (style_hub.jpg); tests/content/test_town_models.gd |
| tools/hub_shot.gd | new | Renders the street and an overview to `screenshots/` |
| systems/hub/deploy_board.gd, deploy_board.tscn | new (step 2) | `DeployBoard extends Interactable`: `@export var place: StringName`, `@export var label: String`; `get_prompt()` shows "Ready: <label>" or "Cancel ready" from the last `Events.deploy_vote_changed` payload (local peer id in `ready_ids`), so it is right on clients too; `interact(player)` calls `player.session.deploy_vote.toggle_ready(player, place)` |
| systems/hub/deploy_vote_panel.gd, deploy_vote_panel.tscn | new (step 2) | CanvasLayer in the town scene: hidden while no vote; shows the place label, each player's `display_name` with a ready tick and the countdown; updates only on `Events.deploy_vote_changed` |
| tests/unit/test_lantern_post.gd, test_deploy_board.gd | new | See steps |

Interface with the co-op thread (same text in `coop-full-match.md`):

1. This plan delivers `levels/lantern_post/lantern_post.tscn` as above. The
   return to the hub lands on the same `PlayerSpawn` marker.
2. This plan delivers `systems/hub/deploy_board.gd/.tscn`, a normal (not
   `is_local()`) Interactable whose `interact(player)` only calls
   `player.session.deploy_vote.toggle_ready(player, place)`, and the vote
   panel `systems/hub/deploy_vote_panel.gd/.tscn`.
3. The co-op thread owns `DeployVote` (`systems/game/deploy_vote.gd`, a child of
   GameSession reached as `session.deploy_vote`): `toggle_ready(player, place)`
   is server only; the first press proposes the place and readies that player,
   any ready player who presses again un-readies and cancels the countdown (ui-hud.md screen 8: any player can cancel), a press
   for another place while a vote runs is ignored; when every connected player
   is ready a 5 s countdown runs, then `deploy_vote.deploy(place)`. Leaving or
   joining re-checks (a joiner starts not ready). Read-only: `deploy_vote.place`,
   `deploy_vote.is_ready(peer_id)`. It fires
   `Events.deploy_vote_changed(place: StringName, ready_ids: Array[int], countdown_left: float)`
   on every peer (empty place = no vote; once for a late joiner from a snapshot).
   Player names come from `player.display_name`. It also owns
   `deploy_vote.deploy(place: StringName)` (on the vote, game_session.gd is at its size limit),
   `hub_session.tscn`, `content/screens/hub.tres`, switching places, the return
   to the hub and landing in the hub from the menu, join and dedicated server.
4. This plan stays out of `systems/game/`, `systems/net/` and `core/`; the
   co-op thread stays out of `levels/lantern_post/` and `systems/hub/`.

Autoloads, managers or base classes added: none. `DeployBoard` extends the
existing `Interactable` base named in the architecture doc.

## Data

- No new Resource types. The board's `place` names an existing screens id
  (`&"match"` for Halcyon Labs). A second map adds a screens `.tres`, its
  session scene and one more board node in the town scene.
- Save format change: none.
- Network messages: none new in this plan. The board uses InteractionSync's
  request; vote sync and place switching belong to the co-op plan.
- Content checks to add in `tests/content/`: none (no new content type). The
  board test checks the place id exists in `content/screens/`.

## Co-op behaviour

- Who owns the state: the town has no changing state. The vote and the deploy
  decision are the server's (`DeployVote`).
- What clients send, what the server sends back: the F-02 interact request for
  the board; the server runs `toggle_ready()`; the vote reaches every peer as
  `Events.deploy_vote_changed`, which the panel and the board prompt read.
- What a client sees that the host sees too: the same static town and the
  other players (PlayerSpawner, LookSync, owned by the co-op thread).
- Late joiner: the co-op thread's snapshot fires `deploy_vote_changed` once, so the panel shows the running vote.
- Dedicated server: loads the same scene (collision for player checks); no
  screen. Lights and meshes cost nothing without a renderer.

## Performance

Static scene, no scripts with `_process` except `Level` (which stops its
physics tick after `_finish()`). Draw calls in the software render: 444 for
the whole town in view. Pines share one mesh. Budget: the town must hold 120
fps at 1440p High with 8 players on the RTX 4080 Super; check on the GPU agent
after step 1 merges.

## Steps

### Step 1: Town scene

- Build: `lantern_post.tscn` with the street, plaza, houses on both sides
  (stone ground floor, timber-framed or plank upper floor, slate roofs, chimneys,
  framed and shuttered windows, doors with steps and awnings), sodium street
  lamps, wall lanterns, string lights, a well, log stacks, fire barrels, palisade walls, the gate with the green "LANTERN POST" sign
  and a `DeployBoardSpot` marker, pines, moon light and the night look. Render
  tool. Look check against style_hub.jpg.
- Files: `levels/lantern_post/lantern_post.tscn`,
  `levels/looks/lantern_post_night.tres`, `levels/materials/town_surface.gdshader`,
  `levels/materials/town_*.tres`, `levels/materials/sodium_lamp.tres`,
  `levels/materials/lit_window.tres`, `levels/materials/pine.tres`, `levels/materials/iron.tres`,
  `tools/hub_shot.gd`, `tests/unit/test_lantern_post.gd`, `tools/assets/town_props.py`,
  `assets/models/town/*.glb` (+ `.import`), `docs/design/turnarounds/town/*.png`,
  the hub scene line in `systems/game/hub_session.tscn` (placeholder -> this town, and
  delete `levels/hub_placeholder/`, agreed with the co-op thread; done in step 2 if
  their PR lands after step 1),
  `tests/content/test_town_models.gd`, and the `town` lines in `tools/assets/build_models.py`,
  `tools/assets/check_models.py`, `tools/turnarounds.py` and `.github/workflows/assets.yml`.
- Tests also: `test_town_models.gd` checks the props stand on the origin, the lamp
  glows and reaches forward, and window shutters sit in front of the glass.
- Tests: `test_lantern_post.gd` loads the scene, checks the root is a `Level`
  with `is_navigation_ready` true right after `_ready`, has a player spawn,
  has no zombie spawn points, and that all 8 lined-up spawn spots
  (`PlayerSpawner.SPAWN_SPACING`) have floor under them and no wall or prop
  overlapping a player capsule. Fails without the scene, or if a house or
  prop is moved onto the spawn line.
- Done when: CI green, render in the PR, the person approved the look (decision
  card).

### Step 2: Deploy board and vote panel

- Build: `DeployBoard` interactable and scene (a sign board on posts with a
  green screen and a label), placed at `DeployBoardSpot` in the town with
  `place = &"match"`, label "Halcyon Labs". The vote panel in the town scene.
  Starts after the co-op squad cards PR (`player.display_name`), F-47 step 4 (`deploy()`) and the
  co-op vote step (`DeployVote`, `Events.deploy_vote_changed`, vote sync and
  late-join replay) are on main.
- Files: `systems/hub/deploy_board.gd`, `systems/hub/deploy_board.tscn`,
  `systems/hub/deploy_vote_panel.gd`, `systems/hub/deploy_vote_panel.tscn`,
  `levels/lantern_post/lantern_post.tscn`, `tests/unit/test_deploy_board.gd`,
  docs (DECISIONS.md entry, this plan to Done, roadmap row Done).
- Tests: `test_deploy_board.gd`: the board's place is a known screens id; the
  prompt reads "Ready: Halcyon Labs", then "Cancel ready" once that player is
  ready; in the two-peer fixture (`tests/unit/coop_interaction_fixture.gd`) a
  client's interact request on the board readies that client on the server and
  a second press un-readies it; the panel shows names, ticks and the countdown
  from a `deploy_vote_changed` emit and hides on an empty place; with a second
  player ready, the first player's second press cancels the countdown. Fails without
  the board or panel. Vote rules themselves (a press for another place is ignored,
  leave and join re-checks, late-join replay) are tested in the co-op plan's vote step.
- Done when: CI green; from a client, pressing the board readies you, and when
  everyone is ready the whole server goes into Halcyon Labs after 5 s
  (two-instance play-test goes on issue #191's checklist).

## Acceptance

- [x] A player who joins a server lands in Lantern Post next to up to 7 others
      (co-op plan + step 1 test).
- [x] Pressing interact on the Deploy board readies a player; when everyone
      is ready, Halcyon Labs starts for everyone after 5 s (step 2 test + co-op plan test).
- [x] After the match, players are back at the town spawn (co-op plan test).
- [x] The town look is approved by the person (decision card, step 1).

## Risks

- Look not what the person wants: the layout is cheap grey-box; step 1 gets
  the card before step 2 builds on it.
- Software renders are darker than the GPU (no SSR, weak ambient); judge
  colour and layout, then check on the GPU agent.
- `DeployVote` and `deploy()` land later than step 1: step 2 waits; step 1 has no dependency.
- Many OmniLights: only 6 cast shadows; the lightmap bake later replaces most
  real-time light.

## Open decisions

- [x] Town layout and look (one walled street from the spawn plaza to the
      Deploy Gate, houses both sides, sodium lamps): decision card to the
      person with the render. First render: the person asked for better
      textures, more detail and a bit brighter (2026-11-17); second render: they asked for more detail first (Blender props, fences, signs); third render sent, roof tilt fixed after their note. Answer: approved "for now" (2026-11-17), and add a ready-up vote so the server moves everyone when all are ready (added to step 2).
