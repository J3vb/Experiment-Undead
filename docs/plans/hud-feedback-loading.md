# Plan: HUD feedback and loading screen

Status: Approved
Roadmap: F-49 / no issue
Phase: P4 (loading, HUD polish), with the P5 level-up burst and P6 drop feed that were left out
Size: M
Approved by: Codex plan review on PR #243 (2026-11-17), one finding fixed (Siphon scoped out); look picks provisional per the person's working mode

## Goal

The match tells the player what just happened without breaking the
military-shooter feel: a brass ring when they level up, a short drop feed when
loot falls for them, optional damage numbers, and a loading screen instead of
a frozen frame when a map (or the co-op hub) loads. Pillars: tight gunplay
(feedback you can read) and "every run makes you stronger" (level and loot
moments land).

## Scope

In:

- Loading screen for root places that ask for one (the match now, the co-op
  hub when it lands): map name, one tip, a progress bar.
- Damage numbers with the Off / Crits only / All setting, off by default.
- Level-up ring burst behind the XP bar, plus a generated `level_up` sting.
- Item drop feed at the bottom centre: "Rare Talon DMR" in rarity colour,
  fades after 4 s.

Not in (non-goals, and where each one goes instead):

- Squad names appearing on the loading screen as each player finishes
  loading: needs a new network message; goes with the Deploy Gate (P9).
- Map art on the loading screen: no key art exists yet; the field is added
  when the first map picture is made (asset packs after v0.1).
- Loading screen for `UI.reload()` (Restart): the scene is cached, it reloads
  in a frame or two.
- Real crit hits: nothing in the game rolls crits yet. Until it does, "Crits
  only" shows headshots (see Open decisions). Orange crit numbers come with the
  first crit stat (F-31 or a loot affix).
- Damage numbers for Siphon (Gravity Well) damage: the orb's damage is applied on
  the server in `GravityWell._damage()` and the owner only gets `HitClaims.well_hit(killed)`
  with no target or amount, so showing it needs a new network message. Siphon shows no
  numbers for now; it goes with the next change to the Gravity Well claim path (idea
  issue opened with step 2). Every gun that fires through `Weapon._hit()` (including
  pierced extra hits and double barrels) shows numbers.
- Moving the existing "LEVEL N" text toast out of `hud.gd`: `hud.gd` belongs
  to the co-op thread this week; the toast stays, the ring sits behind it.
- The settings menu row for damage numbers: the settings thread adds it once
  `SettingData` lands (F-05). This plan only adds the `Settings.DEFAULTS` key.

## Ready to build

```
### Ready to build
- Foundations touched: 4 Events and signals (solid), 5 UI screens and routing (solid),
  1 Co-op authority (shaky) only as "who sees it"; nothing here changes shared state,
  so the shaky parts do not apply.
- Decision records: 0007 signals and events, 0011 one UI router, 0010 personal loot,
  0003 trusted client. Goes against one: no.
- Co-op:
  - Who decides: nothing new is decided. All four pieces are local presentation of
    facts the owner already has.
  - How a client triggers it: n.a. (no requests).
  - What other players see: nothing; damage numbers, drop feed and level-up are the
    owner's own (like hit markers). Loading is per peer.
  - Works on a dedicated server with no local player: yes (widgets live in the HUD,
    which a dedicated server never builds; the router loads the scene the same way).
- Data: tips and map name live on ScreenData (content/screens/*.tres); loading screen
  id is a ScreenData field, so core never names an id. Code compares against a specific
  id: no.
- Save: no.
- Events and UI: new Events.damage_dealt (owner only) and Events.loot_dropped (owner
  only). Loading screen goes through the UI router: yes.
- Input through InputFrame, gameplay in _physics_process, session RNG: yes; the tip
  pick is visual randomness marked `# cosmetic`.
- Tests: unit tests per widget, router test, content check for screens, weapon/claim
  test for the amount. Co-op: damage numbers checked on the client claim path.
- Logging: Log.warn ui.loading_failed when a threaded load fails (falls back to a
  plain scene change).
- Performance: damage number labels pooled (12, made once); no per-hit allocation
  except the merge dictionary entry reuse; loading polls only while loading.
- Out of scope: see Not in.
```

## Design references

- docs/design/ui-hud.md#9-loading: "Map art, the map name, and one rotating tip. A
  progress bar ... no 'press any key'."
- docs/design/ui-hud.md#10-match-hud: "Bottom centre: ... a small item drop feed
  ('Rare Talon DMR' in rarity colour) that fades after 4 s."
- docs/design/ui-hud.md#godot-structure: layers, toasts and loading on 50.
- docs/design/game-feel.md#hit-markers: "Damage numbers: off by default ... Off /
  Crits only / All. When on: numbers in the world above the hit point, 14 px, white
  (gold for headshot, orange for crit), merged per target every 120 ms, max 12 on
  screen."
- docs/design/game-feel.md "Other big moments": "Level up: gold ring burst behind the
  XP bar, `level_up` sting, no screen effect".
- docs/design/game-feel.md#player-settings-settings-autoload: Damage numbers Off /
  Crits only / All, default Off.
- docs/design/look-rules.md: Brass #E3CF9A (XP bar, level-up), Headshot gold #FFC845.
- docs/design/sound.md: level-up "a warm rising chord plus a soft bell", UI bus.
- docs/DECISIONS.md "UI router": "Transitions, toasts and layers 40/50 wait until a
  screen needs them." The loading screen is that screen.
- docs/plans/coop-full-match.md steps 4-5: the hub and match swap with
  `UI.replace(place)`; this plan's loading screen rides on that call.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| core/ui.gd | changed | `replace()` loads threaded and shows the root's loading screen when it names one |
| systems/ui/screen_data.gd | changed | `loading_screen: StringName`, `title: String`, `tips: PackedStringArray` |
| systems/ui/loading_screen.tscn/.gd | new | Title, tip, progress bar |
| content/screens/loading.tres | new | ScreenData for the loading screen, layer 50 |
| content/screens/match.tres | changed | `loading_screen = &"loading"`, title, tips |
| core/settings.gd | changed | `accessibility/damage_numbers` default `"off"` |
| core/events.gd | changed | `damage_dealt`, `loot_dropped` |
| systems/weapons/weapon.gd, weapon_holder.gd, systems/net/hit_claims.gd | changed | `hit_landed` carries the DamageInfo and zone; holder relays `damage_dealt` |
| systems/ui/damage_numbers.gd/.tscn | new | Pooled Label3D numbers |
| systems/ui/level_up_burst.gd/.tscn | new | Brass ring behind the XP bar + sting |
| systems/ui/loot_feed.gd/.tscn | new | Bottom-centre drop rows |
| systems/loot/loot_service.gd | changed | `_receive_drop` emits `Events.loot_dropped` |
| systems/ui/hud.tscn | changed | Three instanced widget nodes (mount points, no hud.gd change) |
| tools/generate_sfx.py, assets/audio/level_up.wav | new sound | Generated sting |

Autoloads, managers or base classes added: none. Each widget is one plain
scene with one job that listens to Events itself, so `hud.gd` does not grow.

## Data

- `ScreenData.loading_screen: StringName = &""`: id of the screen shown while this
  root loads. Empty = plain scene change (main menu keeps that).
- `ScreenData.title: String = ""`: place name shown on the loading screen.
- `ScreenData.tips: PackedStringArray = []`: one is shown per load.
- `content/screens/loading.tres`: scene `systems/ui/loading_screen.tscn`, layer 50,
  not a root.
- `Settings.DEFAULTS[&"accessibility"][&"damage_numbers"] = "off"`; values `"off"`,
  `"crits"`, `"all"`. Unknown strings read as off. Strings, not ints, to match the
  readable settings file in controls.md and to keep `_normalize` unchanged.
- `Events.damage_dealt(player: Player, target: Node3D, info: DamageInfo)`. Peers: the
  shooter's owner, on its own shot (on clients from the hit prediction, like hit
  markers). `info.amount` is the zone-scaled damage on both host and client paths.
- `Events.loot_dropped(player: Player, item: Dictionary)`. Peers: the drop's owner only.
- Save format change: none.
- Content checks in `tests/content/test_screens.gd`: every `loading_screen` id exists
  and is not a root; a root with a loading screen has a title and at least one tip.

## Co-op behaviour

- Who owns the state: no shared state. Damage numbers, drop feed, level-up burst:
  the owning client draws its own. Loading: each peer loads its own scene.
- What clients send, what the server sends back: nothing new. Drops already arrive
  by `_receive_drop` RPC; level-ups already arrive with server XP; damage numbers use
  the client's own hit prediction.
- What a client sees that the host sees too: nothing new; teammates' numbers, drops
  and level-ups are never shown (personal loot, ADR 0010; markers are own-only).
- Late joiner: nothing to receive (all transient).
- Place change (hub to match and back, coop-full-match steps 4-5): the client calls
  `UI.replace(place)`; if that place's ScreenData names `loading`, the screen shows
  until the new scene is in the tree. The co-op thread adds `loading_screen`, title
  and tips to `hub.tres` when it creates it (agreed through the coordinator).
- Dedicated server: no HUD, so no widgets. The router still uses the threaded load;
  the loading Control is built but never drawn.

## Performance

- Damage numbers: 12 Label3D nodes created in `_ready`, reused oldest-first; a hit
  only updates text, position and a tween. One Dictionary keyed by target instance id,
  cleared entries reused. At most 12 visible, as the design says.
- Feed and burst: work only on their event; nothing per frame while idle.
- Loading: `_process` polls `ResourceLoader.load_threaded_get_status` only while a
  load is running.
- Budget: under 0.1 ms per frame with 24 zombies and an LMG firing (checked with the
  existing benchmark test in step 2).

## Steps

### Step 1: Loading screen in the router

- Build: `ScreenData` gains `loading_screen`, `title`, `tips`. `UI.replace(id)`: when
  `data.loading_screen` is set, instance that screen on its own CanvasLayer (layer from
  its ScreenData, 50) under UI so it survives the scene change, call
  `setup(title, tip)` on it, `ResourceLoader.load_threaded_request(data.scene)`, poll in
  `_process` and call `set_progress(value)`, then `change_scene_to_packed`. The layer is
  freed on `scene_changed`. A failed load logs `ui.loading_failed` and falls back to
  `change_scene_to_file`. Roots without a loading screen keep the current path. A second
  `replace()` during a load cancels the first screen (last call wins).
  `LoadingScreen` shows title, tip (picked with `randi()` `# cosmetic`) and a
  ProgressBar, using `theme.tres`. `match.tres` gets the loading id, "Halcyon Labs" and
  six tips from current rules (points, headshots, personal loot, Vault, exfil, Serums).
- Files: core/ui.gd, systems/ui/screen_data.gd, systems/ui/loading_screen.gd/.tscn (new),
  content/screens/loading.tres (new), content/screens/match.tres,
  tests/unit/test_ui_router.gd, tests/content/test_screens.gd, docs/LOGGING.md.
- Tests: router: replace to a test root with a loading screen shows a layer at 50 with
  the title, progress reaches 1, the scene changes and the layer is gone after; replace
  to the main menu shows no loading layer; a bad scene path falls back and logs the
  warning; the stack is still cleared and the tree unpaused. Content check above.
- Done when: Play solo shows the loading screen, then the match; existing router,
  menu and pause tests stay green; soak green.

### Step 2: Damage numbers

- Build: `Settings.DEFAULTS` key. `Weapon.hit_landed(is_kill, info, zone)` replaces the
  `is_headshot` argument (same line count in weapon.gd, which is at its size limit);
  `hit_claims.submit_hit` passes the same. `WeaponHolder._on_hit_landed` emits
  `hit_confirmed` as before plus `Events.damage_dealt(player, zombie, info)`, scaling a
  client-claim amount by `zone.damage_multiplier` so host and client show the same
  number (the host's `info` already has it from `receive_hit`). If the knife (PR #239)
  has merged, its hit emits the same event. `DamageNumbers` (Node3D in hud.tscn): reads
  the setting live, ignores non-local players, shows `info.amount` rounded at
  `info.position` + 0.3 m up, Label3D billboard, fixed size, 14 px, no depth test,
  white or headshot gold; "crits" shows headshots only; same target within 120 ms adds
  to the same label; 12 labels max, oldest reused; each drifts up and fades.
- Files: core/settings.gd, core/events.gd, systems/weapons/weapon.gd, weapon_holder.gd,
  systems/net/hit_claims.gd, systems/ui/damage_numbers.gd/.tscn (new),
  systems/ui/hud.tscn (one instanced node), tests/unit/test_damage_numbers.gd (new),
  tests/unit/test_settings.gd, tests/unit/test_hit_claims.gd, tests/unit/test_events.gd,
  docs/DECISIONS.md.
- Not in this step: Siphon (see Scope).
- Tests: off shows nothing; all shows one label with the amount; crits shows a
  headshot and skips a body hit; two hits on one target 50 ms apart give one label with
  the sum, 200 ms apart give two; the 13th target reuses the oldest label; a remote
  player's hit shows nothing; a client claim and a host hit with the same shot give the
  same amount; default setting is "off".
- Done when: with the setting on (set in settings.cfg until the menu row exists),
  numbers show in a match; tests green.

### Step 3: Level-up burst and drop feed

- Build: `level_up.wav` from `tools/generate_sfx.py` (warm rising chord plus soft
  bell). `LevelUpBurst` (Control mounted behind `XpBar` in hud.tscn): on
  `Events.player_leveled_up` for the local player (`is_multiplayer_authority()`), draws
  a brass #E3CF9A ring that grows and fades and plays the sting on the UI bus. No
  screen effect. `LootService._receive_drop` emits `Events.loot_dropped(player, item)`
  after the drop is added. `LootFeed` (VBoxContainer bottom centre in hud.tscn): one
  row per drop, "<Rarity> <item name>" (`RarityData` display name + `LootDrop.item_name`)
  in `RarityData.colour`, newest on top, 3 rows max, each fades after 4 s.
- Files: tools/generate_sfx.py, assets/audio/level_up.wav(+.import), core/events.gd,
  systems/loot/loot_service.gd, systems/ui/level_up_burst.gd/.tscn (new),
  systems/ui/loot_feed.gd/.tscn (new), systems/ui/hud.tscn (two instanced nodes),
  tests/unit/test_level_up_burst.gd (new), tests/unit/test_loot_feed.gd (new),
  tests/unit/test_loot_service.gd, tests/content/test_generated_sounds.gd,
  docs/DECISIONS.md, docs/ROADMAP.md, this plan (Done).
- Tests: burst plays (visible, sound playing) on a local level-up and not on another
  player's; a drop received makes one row with the rarity colour and name, gone after
  4 s; a fourth drop drops the oldest row; `_receive_drop` emits once and not after
  banking; the generated sound exists and is not silent.
- Done when: a level-up and a loot drop in a solo match show the ring and the feed row;
  `look-check` screenshot against match_hud.jpg; plan Done, roadmap F-48 Done.

## Acceptance

- [ ] Play solo shows the loading screen with the map name, a tip and progress (test + screenshot)
- [ ] Damage numbers follow the Off / Crits only / All setting, off by default (tests)
- [ ] A level-up shows the brass ring and plays the sting, only for the local player (tests)
- [ ] A loot drop shows "<Rarity> <name>" in rarity colour for 4 s, only for its owner (tests)
- [ ] Soak green, no SCRIPT ERROR

## Risks

- Threaded loading changes when the scene appears (a few frames later). Tests that
  call `UI.replace()` and check the scene next frame could break; step 1 runs the
  router, menu and pause tests and awaits `scene_changed` where needed.
- `hud.tscn` is also edited by the co-op thread (squad cards). Mount points are
  three new nodes at the end of the file; whoever merges second rebases. Agreed through
  the coordinator.
- Label3D under a CanvasLayer parent: Node3D works anywhere in the tree, but step 2's
  first test checks the labels land in the world at the hit point.
- weapon.gd is at 350 lines: the signal change keeps its line count the same.

## Open decisions

Reversible look and feel picks taken as provisional (working mode set by the
person on 2026-11-14), tuned at the play-test:

- [x] "Crits only" before crits exist: shows headshots (provisional).
- [x] Ring burst timing: grows over 0.6 s while fading (provisional).
- [x] Drop feed length: 3 rows max (provisional; design says "small").
- [x] Loading tips text: six tips written from current rules (provisional, editable in match.tres).
