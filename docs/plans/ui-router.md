# Plan: Minimal UI router (foundation fix 5)

Status: Done
Roadmap: F-00 foundation fix 5 / ADR 0011, docs/design/ui-hud.md
Phase: P7
Size: M
Approved by: Codex plan review on PR #178 (2026-11-16); the person approved the UI autoload (2026-11-17)

## Goal

One place decides which screen is open and whether the mouse is free, so
the skill tree (#112), the town hub (#131) and more pause pages can be added
as a screen file plus one data file, with no new scene-change or mouse code.
Players see no change: menus look and behave as today. Serves "Easy to add
content" and readable, controller-friendly menus (docs/PROCESS.md).

## Scope

In:

- A `UI` autoload with `replace(id)`, `push(id)`, `pop()`, `top()` and
  `hold_mouse(node, held)`, and the only code that sets `Input.mouse_mode`
  or changes the scene.
- `ScreenData` resource (scene, layer, captures mouse) in `content/screens/`.
- Current flows moved onto it: main menu to match and back, net error
  dialog, settings and character screens from the main menu, pause,
  settings in pause, results.
- The Pack overlay and debug console keep their own panels but ask the
  router for the mouse through `hold_mouse`.
- A CI rule so scene changes and mouse mode stay in the router.

Not in (non-goals, and where each one goes instead):

- Transitions, toasts, loading screen, modal layer 40, layer 50: when a
  screen needs one (ui-hud.md, ADR 0011 "layers, transitions and toasts come
  when a screen needs them").
- `main_theme.tres` / `ui_tokens.tres` split, `key_prompt`, text size
  scaling: Rebind controls (F-05) and later UI work.
- `SettingData`, `StationData`, `HudLayout`: Rebind controls (F-05), town hub
  (F-45), later.
- Moving the Pack overlay into its own pushed screen: foundation fix 6 (#146)
  already reworks its input; it can move then.
- Co-op pause behaviour (pause stops the local tree, also in co-op): kept as
  it is; not a router question.
- Moving screen files into `systems/ui/screens/<name>/` folders: no file
  moves now, to keep the diff small. Later, when a screen is next changed.
- Main menu sub-panels (host, join, credits): stay inside the main menu
  scene; they are panels of one screen, not screens.

## Ready to build

```
### Ready to build
- Foundations touched: 5 UI screens and routing (missing: this builds it), 6 Input (Back and pause keys),
  10 Exported builds (the autoload loads on the dedicated server too).
  Any of them shaky or missing? 5 is what this fixes. 6: no new raw key reads outside UI. 10: UI does
  nothing headless (no mouse, no screens pushed by the server).
- Decision records: 0011 one UI router (proposed; this makes it accepted), 0004 one code path,
  0007 signals and events. Goes against one: no. New autoload `UI`: approved by the person on 2026-11-17 (AGENTS.md
  Keep it simple rule 5); see Open decisions.
- Co-op:
  - Who decides: each client, for its own screens. Nothing is networked.
  - How a client triggers it: n.a. (local UI only).
  - What other players see: nothing new.
  - Dedicated server with no local player: yes. The server's main scene is dedicated_server.tscn and
    never calls the router; UI skips mouse calls when the display is headless.
- Data: new ScreenData type, content/screens/*.tres (id = file name). No numbers.
  Code compares against a specific id anywhere: only screen ids passed to UI.push/replace, which is
  the router's API (screen flow is code, ui-hud.md). Screen ids are left out of the content id rule
  (ids-into-data plan step 5).
- Save: no change.
- Events and UI: no new Events. New screens go through the UI router: yes, this is the router.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes; the
  router is UI input (allowed by input-only-in-input), gameplay untouched.
- Tests: unit test for the router; content check for every ScreenData; main menu, HUD, pause, results,
  net error and Pack overlay tests updated; CI rule tests in Python.
- Logging: Log.warn ui_unknown_screen (id) and ui_pop_empty when pop() is called on an empty stack.
- Performance: screens are instanced on push and freed on pop, as today; nothing per frame.
- Out of scope: see Not in above.
```

## Design references

- docs/design/ui-hud.md#godot-structure: "Screen router. `UI.push(&"stash")`,
  `UI.pop()`, `UI.replace(&"town_hud")`... Screens never load other screens
  directly"; layers "HUD 10, screens 20, overlays (pack, pause) 30";
  "Mouse capture is handled only by the router: it frees the mouse when any
  screen above the HUD is open"; "A GUT test pushes every `ScreenData` once".
- docs/design/ui-hud.md#11-pack-overlay: mouse look pauses while the Pack is
  open, the game keeps running.
- docs/adr/0011-one-ui-router.md: minimal version first (push, pop, replace,
  mouse); add `UI` to the allowed autoloads when built.
- docs/FOUNDATIONS.md#5-ui-screens-and-routing: the four `change_scene` call
  sites and the main menu adding the character screen itself.
- docs/DECISIONS.md "Character screen and shared item tooltip" and
  "Settings autoload": the current screens and that "the full UI router"
  was deferred.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| core/ui.gd | new | `UI` autoload: screen stack, scene replace, mouse rule |
| systems/ui/screen_data.gd | new | `ScreenData` resource |
| content/screens/*.tres | new | `main_menu`, `match`, `settings`, `character`, `pause`, `results` |
| project.godot | changed | One line at the end of `[autoload]`: `UI="*res://core/ui.gd"` |
| tools/ci/check_rules.py | changed | `UI` in `ALLOWED_AUTOLOADS`; later the `ui-router-only` rule |
| systems/ui/main_menu.gd, main_menu.tscn | changed | Play, host, join use `UI.replace`; settings and character through `UI.push`; embedded settings node removed |
| systems/game/game_session.gd | changed | No mouse code; pause pushes the pause screen; results pushed on game over; menu via `UI.replace` |
| systems/ui/hud.gd, hud.tscn | changed | Pause panel, settings and results nodes removed; no scene change |
| systems/ui/pause_screen.gd, pause_screen.tscn | new | The pause menu, moved out of the HUD as it looks today |
| systems/ui/net_error_dialog.gd | changed | `UI.replace(&"main_menu")`; mouse through the router |
| systems/ui/pack_overlay.gd, systems/debug/debug_console.gd | changed | `UI.hold_mouse(self, open)` instead of setting the mouse |
| systems/ui/settings_screen.gd, character_screen.gd, results_screen.gd | changed | Small: emit `closed` when done; results asks `GameSession` through its signals as today |
| docs/FOUNDATIONS.md, docs/adr/0011-one-ui-router.md, docs/DECISIONS.md, docs/CODE_RULES.md, docs/LOGGING.md, docs/HOW_TO_ADD.md, AGENTS.md | changed | Foundation 5 solid, ADR accepted, rule documented, "add a screen" recipe |

Autoloads, managers or base classes added: `UI` autoload. ui-hud.md and ADR
0011 name it; it is not in AGENTS.md's autoload list, so the person approved
it on 2026-11-17 (Open decisions). No base class: screens are plain scenes that
emit `closed`.

## Data

- `ScreenData` (new, `systems/ui/screen_data.gd`), files in
  `content/screens/<id>.tres`, id = file name:
  - `scene: PackedScene` (as built: a `String` path)
  - `layer: int = 20` (ui-hud.md layers: screens 20, overlays 30)
  - `root: bool = false`: true for a place the game goes to with
    `replace()` (`main_menu`, `match`); false for a screen pushed on top
  - `captures_mouse: bool = false`: only `match` sets true
- Folder is `content/screens/`, not ui-hud.md's `content/ui/screens/`:
  `Content` treats each top folder as one type and merges subfolders, so
  `content/ui/` would later mix screens with HUD layouts. One line in
  DECISIONS.md says so.
- `UI` API (core/ui.gd):
  - `replace(id)`: frees every pushed screen, changes the scene to that
    root's scene, applies the mouse rule.
  - `push(id) -> Node`: instances the scene on a CanvasLayer at
    `max(its layer, the covered screen's layer)`, so a screen opened from an
    overlay (settings from pause) draws above it. The covered screen is
    hidden and set to `PROCESS_MODE_DISABLED` until it is on top again, so it
    neither shows nor reads keys. Remembers the focused control, connects
    the screen's `closed` signal to `pop()`, applies the mouse rule, returns
    the screen so the caller can pass it data (`character.open(profile)`).
    Router layers use `PROCESS_MODE_ALWAYS`, so screens work while the tree
    is paused.
  - `pop()`: frees the top screen, shows and re-enables the one below,
    gives focus back to the control that had it before the push, applies the
    mouse rule.
  - `reload()`: frees every pushed screen, then `reload_current_scene()`
    (as built, restart goes through `Net.world.reload()`, which calls it)
    (used by `GameSession.restart()`, so a restart from results never keeps
    a stale stack).
  - `top() -> StringName`: id of the top screen, `&""` when none.
  - `hold_mouse(node, held)`: for panels that are not pushed screens (Pack
    overlay, debug console). A freed node lets go automatically.
  - Mouse rule: the mouse is captured only when the current root has
    `captures_mouse`, no screen is pushed and no node holds the mouse (as
    built there is no window focus check); a mouse click in the match recaptures it (moved from
    `GameSession._unhandled_input`). Headless: never touch the mouse.
  - `mouse_should_be_free() -> bool` so tests can check the rule headless.
- Screen convention: every pushed screen's root has `signal closed` and
  handles its own Back key (settings and character already do). The router
  pops it when it emits `closed`.
- Save format change: none. Network messages: none.
- Content checks to add in `tests/content/`: every `ScreenData` has a scene
  that instances; layer is 20 or 30; exactly two roots (now five: launcher,
  main_menu, hub, match, dedicated_server); every non-root
  scene root has a `closed` signal.

## Co-op behaviour

- Who owns the state: each client owns its own screen stack. Not networked.
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: nothing new; screens are local.
- Late joiner: nothing to receive.
- Dedicated server: the `UI` autoload exists but stays idle: the server never
  calls `replace` or `push` (it adds `GameSession` itself), and mouse calls
  are skipped headless. The match's pause and results pushes only run where
  there is a local player (`GameSession.has_local_player`).

## Performance

Push instances one scene and pop frees it, as the code does today with
`add_child` and `queue_free`. The mouse rule runs on push, pop, hold and
focus change only, never per frame. Budget: no per-frame cost.

## Steps

### Step 1: Router, roots and the mouse

- Build: add the `UI` autoload (one line at the end of `[autoload]`), allow
  it in `check_rules.py`, add `ScreenData` and `content/screens/main_menu.tres`
  and `match.tres`. Replace the four `change_scene_to_file` calls
  (`main_menu.gd`, `hud.gd`, `game_session.gd`, `net_error_dialog.gd`) with
  `UI.replace(&"match")` or `UI.replace(&"main_menu")`. Remove every
  `Input.mouse_mode` write outside `core/ui.gd`: the main menu and match
  roots get it from `captures_mouse`; the pause panel, Pack overlay, debug
  console and net error dialog call `UI.hold_mouse(self, open)`.
  `GameSession._capture_mouse` and the click-to-recapture branch move into
  the router. `GameSession.restart()` calls `UI.reload()` instead of
  `reload_current_scene()`. Until step 3 moves results onto the stack, the
  HUD's results panel calls `UI.hold_mouse(results_screen, true)` when it
  shows, so the cursor is free over the results buttons after game over, as
  `GameSession._capture_mouse(false)` does today.
- Files: core/ui.gd (new), systems/ui/screen_data.gd (new),
  content/screens/main_menu.tres, content/screens/match.tres (new),
  project.godot, tools/ci/check_rules.py, systems/ui/main_menu.gd,
  systems/ui/hud.gd, systems/game/game_session.gd,
  systems/ui/net_error_dialog.gd, systems/ui/pack_overlay.gd,
  systems/debug/debug_console.gd, tests/unit/test_ui_router.gd (new),
  tests/content/test_screens.gd (new), tests/unit/test_main_menu.gd,
  tests/unit/test_net_errors.gd, tests/unit/test_pack_overlay.gd,
  tests/unit/test_debug_console.gd, docs/LOGGING.md.
- Tests: `test_ui_router.gd`: `replace` to a test root clears pushed
  screens; `mouse_should_be_free()` is false on a captures-mouse root with
  nothing open, true while a node holds the mouse, false again after that
  node is freed (fails today: there is no single rule, the overlay and the
  pause menu each set the mouse); unknown id warns and returns null;
  `reload()` empties the stack. In a headless `GameSession`, game over makes
  `mouse_should_be_free()` true (results panel holds the mouse).
  `test_screens.gd` content checks for the two roots. Updated tests: opening
  the Pack overlay and the debug console makes `mouse_should_be_free()` true.
- Done when: no `change_scene_to_` and no `Input.mouse_mode =` left outside
  `core/ui.gd`; boot test and all GUT tests green; the dedicated server
  smoke test still passes.

### Step 2: Main menu screens on the stack

- Build: `content/screens/settings.tres` and `character.tres` (layer 20).
  The main menu opens settings with `UI.push(&"settings")` and the
  character screen with `UI.push(&"character").open(profile)`. Delete the
  embedded `SettingsScreen` node from `main_menu.tscn`, `_open_character`'s
  manual `add_child`, and the menu's own focus-restore code: the router gives
  focus back. The settings screen keeps its fade-in (0.12 s, from x 12) in
  its own `_ready`, so it looks the same. The character screen keeps its
  save-before-close and second-Back behaviour, then emits `closed`.
- Files: content/screens/settings.tres, content/screens/character.tres (new),
  systems/ui/main_menu.gd, systems/ui/main_menu.tscn,
  systems/ui/settings_screen.gd, systems/ui/character_screen.gd,
  tests/unit/test_main_menu.gd, tests/unit/test_settings_screen.gd,
  tests/unit/test_character_screen.gd, tests/unit/test_ui_router.gd.
- Tests: router: `push` puts a screen on layer 20 and `top()` returns its
  id; the screen emitting `closed` pops it and focus returns to the button
  that opened it (fails today: there is no push). Main menu: Settings opens
  the settings screen through the router (`UI.top() == &"settings"`) with
  the same fade; Back closes it and focuses the Settings button; Character
  opens and closes the same way, and a failed save still needs a second
  Back.
- Done when: the main menu adds no screen nodes itself; tests green.

### Step 3: Pause, settings in pause, results

- Build: `content/screens/pause.tres` (layer 30), `results.tres`
  (layer 20). Move the pause menu out of `hud.tscn` into
  `systems/ui/pause_screen.tscn` with the same nodes, theme and focus; it
  emits `closed` on Resume and on Esc. Pause and Back are both Esc: when
  nothing is pushed, `GameSession` handles `pause` by pausing the tree and
  pushing the pause screen, and connects the screen's `tree_exiting` to
  unpause; while a screen is open the screen handles Esc. The pause
  screen's Settings button calls `UI.push(&"settings")`; the router draws
  it above the pause screen and hides pause until settings pops (the push
  rules above), replacing `Hud._open_settings()`. Delete step 1's temporary
  results `hold_mouse`. On game over,
  `GameSession` pushes `results` and passes the stats (what `Hud._on_game_over`
  does today); results' `main_menu_requested` goes to `UI.replace(&"main_menu")`,
  `restart_requested` to `GameSession.restart()`. Delete the HUD's pause,
  settings and results nodes and code. Pushes only happen when
  `has_local_player` is true.
- Files: content/screens/pause.tres, content/screens/results.tres (new),
  systems/ui/pause_screen.gd, systems/ui/pause_screen.tscn (new),
  systems/ui/hud.gd, systems/ui/hud.tscn, systems/game/game_session.gd,
  systems/ui/results_screen.gd, tests/unit/test_hud.gd,
  tests/unit/test_results_screen.gd, tests/unit/test_ui_router.gd,
  tests/unit/test_pause_screen.gd (new), tests/content/test_screens.gd.
- Tests: in a headless `GameSession`, the pause action pushes `pause`
  (`UI.top() == &"pause"`, tree paused); Esc pops it and unpauses; Settings
  from pause stacks `settings` on a layer above pause, pause is hidden and
  disabled (an Esc goes to settings only), and Back returns to a visible
  `pause`; game over pushes `results`, its Main menu button replaces to
  `main_menu`, and its Restart button leaves an empty stack in the new match
  (pause opens again there). These
  fail today because the HUD shows and hides its own panels. The existing
  results and HUD tests keep their checks, aimed at the new screens.
- Done when: `hud.gd` has no pause, settings or results code; tests green;
  a solo play-test (by the person or the local agent) confirms pause,
  settings and results look and work as before.

### Step 4: CI rule and close out

- Build: rule `ui-router-only` in `tools/ci/check_rules.py`: in `core/`,
  `systems/` and `levels/`, `change_scene_to_` and assignments to
  `Input.mouse_mode` are allowed only in `core/ui.gd`. Document it in
  `docs/CODE_RULES.md` and the AGENTS.md rule list. Mark foundation 5 solid
  in `docs/FOUNDATIONS.md`, set ADR 0011 to accepted, add a
  `docs/DECISIONS.md` line (router built; the content/screens folder), and
  an "Add a screen" recipe to `docs/HOW_TO_ADD.md` (scene with `signal
  closed`, one `ScreenData`, open it with `UI.push`).
- Files: tools/ci/check_rules.py, tools/ci/test_check_rules.py,
  docs/CODE_RULES.md, AGENTS.md, docs/FOUNDATIONS.md,
  docs/adr/0011-one-ui-router.md, docs/DECISIONS.md, docs/HOW_TO_ADD.md,
  docs/ROADMAP.md, this plan (Status: Done).
- Tests: `test_check_rules.py`: `change_scene_to_file` in a systems script
  fails; in `core/ui.gd` passes; `Input.mouse_mode = ...` in a systems
  script fails; reading `Input.mouse_mode` passes; a match in `tests/` or
  `tools/` passes.
- Done when: `python tools/ci/check_rules.py` green; Acceptance ticked.

## Acceptance

- [x] Every screen opens through `UI.push` or `UI.replace`; no scene change or mouse write outside `core/ui.gd` (CI rule, test_check_rules.py).
- [x] The mouse is free whenever a screen, the Pack overlay or the debug console is open, and captured in the match otherwise (test_ui_router.gd).
- [x] Back closes the top screen and focus returns to the button that opened it (test_ui_router.gd, test_main_menu.gd).
- [x] Every `ScreenData` loads and instances (tests/content/test_screens.gd).
- [ ] Pause, settings and results look and work as before in a solo play-test (waiting on the person's play-test).
- [x] The dedicated server boots and the smoke test passes with the `UI` autoload present.

## Risks

- **Esc does two things.** `pause` and `ui_cancel` are both Esc. If both
  fire, pause reopens right after closing. Step 3's rule (GameSession only
  pauses when nothing is pushed; screens mark Esc handled) is tested by the
  open, close, reopen test.
- **Focus loss in a match.** Today a click recaptures the mouse after
  alt-tab (the game pauses on focus loss). Step 1 moves that branch into the
  router and keeps its test.
- **Tests that poke HUD nodes.** `test_main_menu.gd` and `test_hud.gd` reach
  into `settings_screen`, `pause_panel` and `results_screen`. Each step
  updates those tests in the same PR; none are skipped or deleted.
- **Clash with other plans.** The item-effects plan step 3 and foundation
  fix 6 edit `pack_overlay.gd`; step 1 here only changes its mouse lines.
  Rebase on main before building step 1.
- **The server loads `UI`.** A bug in its `_ready` could break the
  dedicated server. Step 1 keeps `_ready` empty of scene work and runs the
  server smoke test.

## Open decisions

- [x] New autoload `UI` (AGENTS.md lists Events, Content, Settings, Audio,
  Pool, Game, Net; ui-hud.md and ADR 0011 name `UI`): yes, the person
  approved it on 2026-11-17 (decision card in the project thread).
