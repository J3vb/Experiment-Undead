# Plan: Rebind controls in Settings

Status: Review
Roadmap: F-05 / issue #105
Phase: P4
Size: M
Approved by:

## Goal

Players can move any keyboard or mouse action to the key they want from the
Controls tab, and the change survives a restart. AZERTY players get Z Q S D
movement and see their own letters. Serves "readable, comfortable controls"
(docs/design/controls.md) and keeps the slice playable on any keyboard.

## Scope

In:

- Keyboard and mouse bindings for every action in the `project.godot` input
  map except `pause` (locked so nobody can lock themselves out of menus).
- Two slots per action, main and backup (docs/design/controls.md#rebinding).
- Bindings saved in `user://settings.cfg` as plain values, physical keys only.
- One key, one action: a taken key shows which action uses it, with Swap or
  Cancel. Nothing is silently unbound.
- Reset per action, and the existing Reset button resets bindings too.
- Key labels show the local letter (`DisplayServer.keyboard_get_label_from_physical()`),
  in Settings and in the Pack overlay buttons.

Not in (non-goals, and where each one goes instead):

- Controller rebinding and the controller column (issue #105 leaves it out; with controller support).
- Controller presets (Tactical, Southpaw) (with controller support).
- Action contexts (on foot / menus / always): no current actions need to share
  a key, so one global "one key, one action" rule is enough. Add contexts when
  a real pair needs the same key (later idea issue).
- Hold-Esc-for-1-s to cancel: Esc can never be bound, so a plain Esc press
  cancels. Same safety, less code.
- Per-page reset and settings search (with the SettingData screen rework, later).
- New actions from the controls table that the game does not have yet
  (melee, lethal, tactical, ping, ...): they arrive with their features.
- Changing defaults (for example interact F vs the doc's E): balance/feel
  change, separate issue if wanted.
- A save version for bindings: only actions that differ from the default are
  saved, so new actions in a later update just use their defaults. Nothing
  to migrate.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): Settings autoload, UI router (fix 5, done), input actions (fix 6, done).
  Any of them shaky or missing? → no
- Decision records that apply (docs/adr/): 0011 one UI router (settings stays a pushed screen, no new screen), 0003 trusted-client co-op (not touched). Does this go against one? no
- Co-op:
  - Who decides: owning client. Bindings are local to each PC.
  - How a client triggers it (request to server, what the server checks): n.a., nothing is sent.
  - What other players see, and how it reaches them: nothing; the server only gets InputFrames.
  - Works on a dedicated server with no local player: yes (bindings load into InputMap, unused).
- Data: action list and defaults come from project.godot (ProjectSettings `input/<action>`); display names are a constant in the bindings UI script. No new content ids.
  Code compares against a specific id anywhere: no (action names are input actions, not content ids)
- Save: changes what is saved? yes, settings.cfg only (not the character save of ADR 0005). New `[bindings]` section, only changed actions; missing section = defaults, bad entries = default for that action.
  Renames or removes a saved id: no
- Events and UI: new Events: none (Settings.changed with section `bindings` is a local node signal). New screens go through the UI router: n.a. (rows inside the existing settings screen)
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (LocalInput keeps reading actions; nothing in gameplay changes)
- Tests: unit tests for Settings bindings (step 1) and the bindings UI (step 2); no co-op test needed (nothing networked).
- Logging: Log.warn when a saved binding is malformed or names an unknown action.
- Performance: nothing per frame; rows are built once when the screen opens.
- Out of scope (later phases, not built now): controller rebinding, contexts, presets, per-page reset.
```

## Design references

- docs/design/controls.md#rebinding: action names only in game code, main and
  backup slots, save `physical_keycode`, show local letter, saved as plain
  values like `{"type": "key", "physical": 87}`, clear with
  `InputMap.action_erase_events()` and add saved events back, Esc locked,
  conflicts say which action and offer Swap or Cancel, reset per action.
- docs/design/controls.md#keyboard-and-mouse: default keys (already in
  project.godot, not changed here).
- docs/design/ui-hud.md#14-settings: Controls tab lists every action with a
  "press a key" rebind; rows are label, control, hint, Cold Containment theme.
- docs/DECISIONS.md "Settings autoload": three tabs, immediate saving, Reset.
- No balance numbers involved.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| core/settings.gd | changed | load, save, apply and reset bindings; conflict lookup; `event_label()` |
| systems/ui/key_bindings.gd + .tscn | new | the list of binding rows on the Controls tab, listen mode, Swap/Cancel |
| systems/ui/settings_screen.tscn | changed | Controls tab wrapped in a ScrollContainer, key bindings scene added |
| systems/ui/settings_screen.gd | changed | only if the scroll wrap moves node paths |
| systems/ui/pack_overlay.gd | changed | `key_name()` uses `Settings.event_label()` (local letter) |
| docs/design/controls.md, docs/DECISIONS.md | changed | note the simplifications above |

Autoloads, managers or base classes added: none.

## Data

- `settings.cfg` new section `[bindings]`: key = action name, value = Array of
  up to 2 Dictionaries, `{"type": "key", "physical": int}` or
  `{"type": "mouse", "button": int}`. Written only for actions whose
  keyboard/mouse events differ from the project default. Controller events in
  the input map are never touched or saved.
- Defaults are read from `ProjectSettings.get_setting("input/<action>")`, so
  project.godot stays the one place defaults live.
- Save format change: additive. Old files have no `[bindings]` section and
  load as defaults. Unknown actions and malformed entries are skipped
  (Log.warn) and that action keeps its default.
- Content checks to add in `tests/content/`: none (no content type).

## Co-op behaviour

- Who owns the state: each client, on its own PC.
- What clients send, what the server sends back: nothing new; InputFrames as today.
- What a client sees that the host sees too: nothing; bindings are private.
- Late joiner: nothing to receive.
- Dedicated server: loads bindings like any client; they are never read. No screen work.

## Performance

Zero per-frame cost. Bindings apply to InputMap once at load and on each
change. The rows (about 18) are built once in `_ready` of the bindings scene.

## Steps

### Step 1: Settings saves and applies bindings

- Build: in `core/settings.gd`: `get_binding(action) -> Array[InputEvent]`
  (keyboard/mouse events, max 2), `set_binding(action, slot, event)`,
  `binding_owner(event, except_action) -> StringName` (who already uses this
  key, `&""` if free), `swap_binding(action, slot, event)` (the other action
  gets this slot's old key), `reset_binding(action)`, and `event_label(event)`
  (local letter for keys, "Mouse 1" style names for buttons and wheel).
  Load applies saved bindings on start (keep controller events, replace
  keyboard/mouse events). `reset_to_defaults()` also resets bindings.
  Each change saves and emits `changed(&"bindings", action, null)`.
  `pause` and `ui_*` actions are refused. Keys are stored as
  `physical_keycode` with `keycode` 0. Pack overlay `key_name()` uses
  `event_label()`.
- Files: core/settings.gd, systems/ui/pack_overlay.gd, tests/unit/test_settings_bindings.gd (new), tests/unit/test_pack_overlay.gd, docs/LOGGING.md (new warn line).
- Tests: `test_settings_bindings.gd`: round trip survives reload; saved key
  uses physical_keycode; only changed actions are written; a key bound to two
  actions is caught by `binding_owner`; swap moves the old key; reset per
  action and global reset restore project defaults; pause is refused;
  malformed entries and unknown actions fall back to defaults; controller
  events survive a rebind; default movement keys are physical W A S D. Tests
  restore the global InputMap from ProjectSettings after each run.
- Done when: bindings set from code survive a restart, CI green.

### Step 2: Controls tab rebinding rows

- Build: `systems/ui/key_bindings.tscn/.gd`: one row per action (display
  name, Main button, Backup button, Reset button), built from InputMap in
  `_ready` with a display-name constant. Clicking a slot shows "Press a key"
  and listens in `_input` (child before the screen, so Esc cancels the rebind
  instead of closing Settings). The mouse click that started listening is
  ignored (listen starts on the next press). A free key binds at once; a taken
  key shows "<key> is used by <action>" with Swap and Cancel. Esc cancels.
  The Controls tab gets a ScrollContainer so all rows fit at 1080p. Labels use
  `Settings.event_label()`; rows refresh on `Settings.changed`. Keyboard and
  controller focus moves through the rows. Then the finish-feature checks:
  roadmap F-05 Done, issue #105 ticked, DECISIONS.md entry, plan Done.
- Files: systems/ui/key_bindings.gd, systems/ui/key_bindings.tscn (new), systems/ui/settings_screen.tscn, systems/ui/settings_screen.gd (if paths move), tests/unit/test_key_bindings.gd (new), tests/unit/test_settings_screen.gd (if paths move), docs/ROADMAP.md, docs/DECISIONS.md, docs/design/controls.md, docs/plans/control-rebinding.md.
- Tests: `test_key_bindings.gd`: every rebindable action has a row and pause
  has none; pressing a free key in listen mode rebinds and saves; Esc in
  listen mode cancels and does not close Settings; a taken key shows the
  conflict and Swap swaps, Cancel changes nothing; Reset restores the
  default; labels follow external changes.
- Done when: the Controls tab rebinds every action, look-check render matches
  the settings style, CI green.

## Acceptance

- [ ] Controls tab lists every action with rebind and reset to default (test_key_bindings)
- [ ] Rebinds save in settings and survive a restart (test_settings_bindings round trip)
- [ ] Movement uses physical keys so AZERTY gets ZQSD by default (test_settings_bindings default check)
- [ ] Unit test catches a key bound to two actions (test_settings_bindings conflict test)
- [ ] Esc cancels a rebind and can never be bound (test_key_bindings)

## Risks

- Tests changing the global InputMap leak into other tests: every binding test
  reloads defaults from ProjectSettings in `after_each`. Step 1 proves this
  before any UI exists.
- The click that opens listen mode is caught as the new binding: step 2
  starts listening on the next press and tests it.
- `keyboard_get_label_from_physical()` returns QWERTY names headless: tests
  check stored physical codes, not label text, for AZERTY.

## Open decisions

- none
