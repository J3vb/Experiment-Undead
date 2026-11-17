# Plan: Full settings screen (graphics first)

Status: Review
Roadmap: F-48
Phase: P4
Size: L
Approved by:

## Goal

Players get a real Settings screen: a Graphics page with display mode,
resolution, render scale, quality presets and every big render option, then
Accessibility and Comfort pages, all found with one search box. Serves the
v0.1 slice (runs well on any PC, readable and comfortable controls,
docs/design/controls.md) and keeps the 120 fps target at 1440p High.

## Scope

In:

- **Graphics page** (named "Video" in docs/design/ui-hud.md; the tab is
  called Graphics because that is the word players look for):
  display mode (Windowed, Borderless, Fullscreen), window resolution,
  render scale 50 to 100% with upscaler (Off, FSR 1, FSR 2), quality preset
  (Low, Medium, High, Ultra, Custom), shadows, anti-aliasing (Off, FXAA,
  MSAA 2x + FXAA, MSAA 4x + FXAA, TAA), ambient occlusion (SSAO), indirect light (SSIL),
  screen-space reflections, glow, volumetric fog, baked lighting filter
  (bicubic on or off), texture filtering (anisotropic 2x to 16x), brightness,
  plus today's VSync, max FPS and show FPS.
- "Keep these settings?" with a 15 second countdown after display mode or
  resolution changes (docs/design/controls.md#settings-menu-and-file).
- `SettingData` resources that generate every row: tab, label, hint, control
  type, range or options, Settings key (docs/design/ui-hud.md#godot-structure).
- Pages Controls, Aim, Graphics, Audio, Accessibility, Comfort, a search box,
  a one-line hint under each row, Revert and Defaults at the bottom.
- The F-05 `KeyBindings` node stays one node, placed at the end of the
  generated Controls page.
- **Accessibility:** text size 80 to 150% (scales all UI), hold or toggle
  for aim, sprint and crouch, reduce motion (UI slides become fades).
- **Comfort:** head bob, weapon bob and sway, FOV change while sprinting,
  damage screen effects, centre dot always on, rows for the game feel
  thread's shake and flash reduction keys, and a "Comfort preset" button that sets the doc's Comfort
  column.
- Settings split by job so `core/settings.gd` stays under the 350-line limit.
- A paste-ready prompt for the person's local GPU agent to measure each
  preset at 1440p with 24 zombies.

Not in (non-goals, and where each one goes instead):

- SDFGI and "lightmap quality" as a run-time option: Halcyon Labs is lit by
  a baked LightmapGI (docs/DECISIONS.md, Halcyon Labs lightmaps). SDFGI on
  top would light rooms twice, cost a lot of frame time and change the
  Cold Containment look; bake quality is fixed at bake time. The run-time
  part that can change is the bicubic lightmap filter, which is in.
- A separate gamma slider: Godot has no gamma control in the Environment;
  one Brightness slider (Environment `adjustment_brightness`) with a
  calibration hint covers it.
- Screen shake and flash reduction effects: owned by the game feel thread,
  which adds `comfort/shake_own_gun`, `comfort/shake_hits` and
  `comfort/flash_reduction` (names from docs/design/controls.md). This plan
  only adds their SettingData rows and puts them in the Comfort preset.
- Damage numbers setting (Off, Crits only, All): owned by the damage numbers
  thread, same way.
- Subtitles, captions, sound visualizer: no subtitle system exists yet (with
  the first spoken lines, later row).
- Font choice (Lexend, OpenDyslexic): only Atkinson ships today; adding
  fonts is an asset task with credits (later idea issue).
- Colour vision modes: need `ui_tokens.tres` and a palette swap that do not
  exist yet (with F-31 rarity work or a later row).
- Controller sensitivity, dead zones, aim assist: no controller support yet.
- Motion blur, depth of field, chromatic aberration options: those effects do
  not exist; each effect adds its own toggle when it is built.
- HUD size, HUD opacity, safe zone: with the final HUD polish (P4 later).
- First-launch quick setup screen: needs fonts and colour modes first (later
  row, after this plan).
- Moving the FOV default from 110 to the doc's 95: a feel change, separate
  issue if wanted.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): Settings autoload, UI router (fix 5, done), input actions (fix 6, done).
  Any of them shaky or missing? → Settings is at the file size limit after F-05; step 1 splits it by job before adding keys.
- Decision records that apply (docs/adr/): 0011 one UI router (settings stays one pushed screen, the keep-settings prompt is a child dialog, not a screen), 0002 content as resources (SettingData .tres), 0003 trusted-client co-op (nothing networked). Does this go against one? no
- Co-op:
  - Who decides: owning client. Every option here is local to one PC.
  - How a client triggers it (request to server, what the server checks): n.a., nothing is sent.
  - What other players see, and how it reaches them: nothing. Hold or toggle aim is turned into held actions before the InputFrame, so the server sees the same frames.
  - Works on a dedicated server with no local player: yes. Window, viewport and render calls are skipped when DisplayServer is headless, as today.
- Data: rows are content/settings/<id>.tres (SettingData); defaults stay in Settings.DEFAULTS; preset tables are constants in core/graphics.gd (fixed rules, nobody tunes them per map).
  Code compares against a specific id anywhere: no (SettingData names Settings keys, which are not content ids)
- Save: changes what is saved? yes, user://settings.cfg only. New sections [graphics], [accessibility], [comfort]; missing keys load defaults, bad values clamp (same as today). No character save change.
  Renames or removes a saved id: video/fov moves to aim/fov in step 3; old files keep working because load reads video/fov when aim/fov is missing (tested).
- Events and UI: new Events: none (Settings.changed is a local signal). New screens go through the UI router: n.a. (rows inside the existing settings screen).
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (toggle aim lives in LocalInput, which builds the InputFrame)
- Tests: unit tests per step (below); a content test checks every SettingData; no co-op test needed (nothing networked).
- Logging: Log.warn `settings.row_unknown_key` when a SettingData names a key Settings does not have; `settings.display_mode_failed` when the window refuses a mode.
- Performance: rows are built once when the screen opens; nothing per frame. Presets change render cost only (measured by the GPU prompt).
- Out of scope (later phases, not built now): fonts, colour vision, subtitles, controller options, quick setup.
```

## Design references

- docs/design/ui-hud.md#14-settings: pages, search, hints, live apply,
  Revert and Defaults, "Video changes that need a restart say so".
- docs/design/ui-hud.md#godot-structure: `content/ui/settings/` SettingData
  "one per settings row", screen generated from them, validator test. This
  plan uses `content/settings/` because content folders are one level deep
  (`content/screens/`), same idea.
- docs/design/ui-hud.md#ui-style: text size setting scales all sizes 80% to
  150%; reduce motion turns slides into plain fades.
- docs/design/controls.md#settings-menu-and-file: live apply also from pause,
  only display mode and resolution ask "Keep these settings?" with a 15 s
  countdown, search box, one-line description per row.
- docs/design/controls.md#comfort-and-motion-sickness: the Comfort table and
  its preset column (head bob 60% default, 0% Comfort; weapon bob and sway
  100% / 50%; sprint FOV on / off; screen blood 100% / 50%; flash reduction
  off / on; centre dot off / on).
- docs/design/controls.md#toggle-or-hold: own setting for aim, sprint, crouch.
- AGENTS.md code rule 6: 60 fps with 24 zombies at v0.1, 120 fps at 1440p
  High on an RTX 4080 Super long term. Memory 2026-11-14: Halcyon Labs ran
  434 to 530 fps at 1440p with today's settings, so High = today's look.
- docs/DECISIONS.md: Look reference and Halcyon Labs lightmaps (baked GI,
  shared `levels/looks/halcyon_interior.tres` that scenes must not copy).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| core/settings.gd | changed | New sections and keys; video apply moves out; preset sets its keys |
| core/graphics.gd | new | Static helper (like core/layers.gd, not an autoload): applies window, viewport and RenderingServer options; preset tables |
| systems/effects/environment_quality.gd | new | Script on each `WorldEnvironment`: works on a duplicate of its look, turns SSAO, SSIL, SSR, glow, fog and brightness on or off from Settings |
| levels/halcyon_labs/map.tscn, levels/look_reference/halcyon_corridor.tscn, systems/ui/character_screen.tscn | changed | `WorldEnvironment` gets the script (one line each) |
| systems/ui/setting_data.gd | new | `SettingData` Resource |
| systems/ui/settings_page.gd | new | Builds one page's rows from SettingData; search filter |
| systems/ui/settings_screen.gd, .tscn | changed | Tabs from data, search box, Revert, Defaults, keep-settings dialog; KeyBindings placed on Controls |
| content/settings/*.tres | new | One per row |
| systems/input/local_input.gd | changed | Hold or toggle for aim, sprint, crouch |
| systems/player/player_camera.gd, systems/weapons/weapon_holder.gd, systems/ui/hud.gd, systems/ui/crosshair.gd | changed | Comfort scales (bob, sway, sprint FOV, damage effect, centre dot) |
| core/ui.gd | changed | Text size sets the root window `content_scale_factor` (stretch mode is canvas_items, so all UI scales and 3D does not) |

Autoloads, managers or base classes added: none. `core/graphics.gd` is a
plain static helper, the same kind as `core/layers.gd`; it exists because
Settings is at its size limit and applying render options is its own job.

## Data

- `SettingData` (new Resource, `systems/ui/setting_data.gd`):
  `page: StringName` (controls, aim, graphics, audio, accessibility,
  comfort), `section: StringName`, `key: StringName`, `label: String`,
  `hint: String`, `kind: StringName` (toggle, slider, choice),
  `min_value: float`, `max_value: float`, `step: float`,
  `display_scale: float = 1.0` (100 for percent), `options: PackedStringArray`
  (choice labels; the saved value is the index),
  `option_values: PackedStringArray` (optional; when set, the saved value is
  the matching string, for keys like `accessibility/damage_numbers`), `order: int`,
  `needs_confirm: bool` (display mode, resolution).
  Read by `SettingsPage` only.
- New Settings keys (section / key / default):
  - graphics / display_mode / 1 (Borderless) ; window_size / 0 (index into a
    resolution list built from the screen, 0 = screen size) ; render_scale /
    1.0 ; upscaler / 0 (Off) ; preset / 2 (High) ; shadows / 2 ; aa / 2
    (MSAA 2x + FXAA, today's project setting) ; ssao / 2 ; ssil / 0 ; ssr /
    true ; glow / true ; fog / 2 ; lightmap_bicubic / true ;
    anisotropic / 2 (4x) ; brightness / 1.0.
  - The existing video keys (vsync, max_fps, show_fps) move to graphics in
    step 1, with the same old-key fallback on load as fov.
  - accessibility / text_scale / 1.0 ; toggle_ads / false ;
    toggle_sprint / false ; toggle_crouch / false ; reduce_motion / false.
  - comfort / head_bob / 0.6 ; weapon_bob / 1.0 ; sprint_fov / true ;
    damage_effects / 1.0 ; centre_dot / false. (shake_own_gun, shake_hits,
    flash_reduction come from the game feel thread.)
  - aim / fov (moved from video), mouse_sensitivity, ads_sensitivity_multiplier,
    invert_y (moved from controls in step 3).
- High preset = today's look exactly: shadows High (directional atlas 4096,
  soft shadow quality Medium), MSAA 2x + FXAA, SSAO Medium, SSIL off, SSR on,
  glow on, fog Medium, bicubic lightmaps on. Ultra raises shadows (8192, soft
  High), MSAA 4x + FXAA, SSAO High, SSIL Medium, fog High. Medium and Low step
  down (Low: shadows 1024 hard, FXAA only, SSAO off, SSR off, fog off, glow
  on). These are render costs, not look-defining picks: High, the default,
  keeps the approved look.
- Save format change: new sections only; old files load. Moved keys read
  their old place when the new one is missing (tested per step).
- Content checks to add in `tests/content/`: `test_setting_data.gd`: every
  SettingData has a page, label, hint, a kind it can draw, a Settings key
  that exists, min < max for sliders, options for choices, and no two rows
  share a key.

## Co-op behaviour

- Who owns the state (server / owning client / each client): each client,
  for itself. Settings never leave the PC.
- What clients send, what the server sends back: nothing new. Toggle aim,
  sprint and crouch become held flags in the InputFrame, as today.
- What a client sees that the host sees too (and what only the owner sees):
  only the owner sees their own render options; the world is the same.
- Late joiner: nothing to receive.
- Dedicated server (no screen, no local player): Graphics.apply returns at
  once when DisplayServer is headless; EnvironmentQuality is in level scenes
  but a headless server never renders, so its toggles cost nothing.

## Performance

Nothing runs per frame: rows are built when the screen opens, settings apply
once on change. EnvironmentQuality duplicates one Environment per level load.
Budget: the High preset must hold 120 fps at 1440p with 24 zombies on an RTX
4080 Super (today 434 to 530 fps); Low must not be slower than High. The GPU
prompt (after step 2) measures all four presets at the four test spots.

## Steps

### Step 1: Graphics settings that apply

- Build: split Settings by job: new `core/graphics.gd` takes the window,
  viewport and RenderingServer work (today's vsync and max FPS move there).
  Add the `graphics` keys above, move vsync, max_fps and show_fps from video
  to graphics with old-key fallback. Picking a preset writes its keys;
  changing one of them sets preset to Custom (4). Display mode and window
  size use DisplayServer; resolution applies only in Windowed (Borderless
  and Fullscreen use the screen's size, render scale sets the 3D resolution).
  FSR 2 forces TAA on (Godot rule) and the AA value shows that.
  `EnvironmentQuality` on each WorldEnvironment duplicates its look once and
  turns effects on or off live. The current Video tab gets one Preset
  dropdown so the step is playable; step 2 replaces the tab.
- Files: core/settings.gd, core/graphics.gd (new),
  systems/effects/environment_quality.gd (new), levels/halcyon_labs/map.tscn,
  levels/look_reference/halcyon_corridor.tscn, systems/ui/character_screen.tscn,
  systems/ui/settings_screen.gd/.tscn (preset row), systems/ui/hud.gd (show_fps
  key), tests/unit/test_graphics.gd (new), tests/unit/test_environment_quality.gd
  (new), tests/unit/test_settings.gd, docs/LOGGING.md.
- Tests: presets write the expected keys and a single change flips to Custom;
  old `video/vsync` in a config loads into `graphics/vsync`; FSR 2 reports
  TAA; EnvironmentQuality never changes the shared `halcyon_interior.tres`
  and toggles its duplicate; Graphics.apply on headless does nothing and
  does not error. Each fails without the step.
- Done when: choosing Low, Medium, High, Ultra changes the scene live in a
  windowed run; the High preset renders the same as main (look-check
  corridor shot matches); CI green; settings.gd under 350 lines.

### Step 2: Generated Graphics page

- Build: `SettingData` and `SettingsPage` (builds toggle, slider and choice
  rows with label, control and hint, from `content/settings/*.tres` for one
  page, ordered by `order`). The Graphics tab becomes a generated page with
  all graphics rows. Display mode and resolution changes open a "Keep these
  settings?" dialog with a 15 s countdown that reverts on timeout or Esc.
  Other tabs stay hand-built until step 3.
- Files: systems/ui/setting_data.gd (new), systems/ui/settings_page.gd (new),
  systems/ui/settings_screen.gd/.tscn, content/settings/*.tres (graphics rows,
  new), tests/unit/test_settings_page.gd (new),
  tests/content/test_setting_data.gd (new), docs/DECISIONS.md.
- Tests: a page built from three test SettingData has three rows with the
  right control types and hints; moving a slider calls Settings.set_value
  with the scaled value; the keep dialog reverts after the countdown and
  keeps on confirm; content checks above.
- Done when: every graphics option is on the page with a hint, changes apply
  live, the keep prompt works; CI green. Then write the GPU fps prompt.

### Step 3: All pages from data, search, Revert and Defaults

- Build only after F-05 step 2 has merged. Controls, Aim and Audio rows
  become SettingData; mouse settings and FOV move to the Aim page (keys move
  to `aim` with old-key fallback). The KeyBindings node is placed once at the
  end of the generated Controls page. Search box filters rows on every page
  by label and hint and jumps to the first page with a match. Revert puts
  back the values from when the screen opened; Defaults resets the current
  page only.
- Files: systems/ui/settings_screen.gd/.tscn, systems/ui/settings_page.gd,
  core/settings.gd (moved keys, `reset_section`), systems/input/local_input.gd
  and systems/player/player_camera.gd (read `aim` keys),
  content/settings/*.tres, tests/unit/test_settings_screen.gd,
  tests/unit/test_settings_page.gd, tests/unit/test_settings.gd.
- Tests: searching "shadow" shows only the shadow row and opens Graphics;
  Revert restores the opening values; Defaults on Audio leaves Graphics
  alone; old `controls/mouse_sensitivity` loads into `aim`; KeyBindings is on
  the Controls page exactly once.
- Done when: no hand-built rows left; CI green.

### Step 4: Accessibility page

- Build: text size (root `content_scale_factor`, 0.8 to 1.5, applied by the
  UI autoload); hold or toggle for aim, sprint and crouch in LocalInput
  (toggle flips on press, clears on death and when the match ends); reduce
  motion (settings and pause fades skip the 12 px slide). Row for the HUD
  thread's `accessibility/damage_numbers` ("off", "crits", "all"; labels
  Off, Crits only, All; that thread adds the DEFAULTS key).
- Files: core/ui.gd, systems/input/local_input.gd, systems/ui/settings_screen.gd,
  systems/ui/pause_screen.gd, content/settings/*.tres,
  tests/unit/test_local_input.gd, tests/unit/test_ui.gd (or the router test file).
- Tests: toggle aim stays aimed after release and drops on second press;
  hold mode unchanged; text size 1.5 sets the scale factor; reduce motion
  leaves position unchanged during the fade.
- Done when: all three work live from the pause menu; CI green.

### Step 5: Comfort page

- Build: head bob and weapon bob and sway scale the camera and viewmodel
  bob; sprint FOV toggle; damage effects scale the damage vignette; centre
  dot shows a dot in the crosshair; rows for the game feel thread's shake
  and flash reduction keys; "Comfort preset" button writes the doc's Comfort
  column (shake 25%, head bob 0, weapon bob 50%, sprint FOV off, damage 50%,
  flash reduction on, centre dot on). Visual only: bullet direction never changes (test).
- Files: systems/player/player_camera.gd, systems/weapons/weapon_holder.gd,
  systems/ui/hud.gd, systems/ui/crosshair.gd,
  core/settings.gd (comfort preset values), content/settings/*.tres,
  tests for each touched script, docs/DECISIONS.md, docs/ROADMAP.md (Done).
- Tests: head bob 0 keeps the camera still while walking; sprint FOV off
  keeps FOV; bullet direction equal at all comfort values; preset writes the
  Comfort column.
- Done when: every Comfort row works live; finish-feature checklist; CI green.

## Acceptance

- [ ] Every graphics option in Scope is on the Graphics page and applies live (step 1-2 tests).
- [ ] Display mode and resolution changes ask to keep, and revert after 15 s (step 2 test).
- [ ] High preset looks like today's build (look-check corridor shot).
- [ ] GPU prompt result: High at least 120 fps at 1440p with 24 zombies; each lower preset at least as fast (recorded in the PR or issue).
- [ ] Every row comes from a SettingData file; content checks pass (step 2-3).
- [ ] Search, Revert and Defaults work (step 3 tests).
- [ ] Accessibility and Comfort rows work live, also from the pause menu (step 4-5 tests).
- [ ] Old settings.cfg files load without losing values (tests in steps 1 and 3).

## Risks

- Display mode and resolution are hard to test headless: Graphics keeps the
  pure part (picking the size list, preset tables, AA mapping) in functions
  tests can call, and only the last DisplayServer call is skipped headless.
  The person checks the window change once in the step 1-2 play-test.
- Changing the shared Environment would change every scene: EnvironmentQuality
  duplicates it, and a test checks the shared file stays untouched.
- F-05 is editing the same files: code steps start from main after F-05's
  PR 237 (step 1) and its step 2 (step 3); step 2 here only touches the
  Graphics tab.
- A preset that changes the look: High is pinned to today's values, so the
  default look cannot move; look-check runs in step 1.

## Open decisions

- none
