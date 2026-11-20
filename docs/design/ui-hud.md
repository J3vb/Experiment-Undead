# Menus, HUD and Screen Flow

Source: copy of the design doc (UI/UX spec) as of Nov 14, 2026, with screens 1, 2, 3 and 10 updated on Nov 17, 2026 to the person's concept art ([concepts/screens/screens_concept.jpg](concepts/screens/screens_concept.jpg)). Where this file and the code differ, the code and `docs/DECISIONS.md` win.

## Summary

The game has 15 screens in 3 places: the front end (before you join a server), the town (Lantern Post) and the match. Every screen is a Godot scene loaded by one router, styled by one theme, and filled from data files, so a new screen, tab or item type is a data change plus one small scene.

**Rules every screen follows**

1. **Two clicks to play.** From the main menu, Enter World puts you in your own town with your last character; from the town, the Deploy Gate is the only way into a match.
2. **Easy to read.** Atkinson Hyperlegible by default (Lexend and OpenDyslexic as options), body text never below 24 px at 1080p, left-aligned, no italics, no long all-caps text, short labels. A text size slider scales every screen, not only the HUD.
3. **The middle of the HUD stays empty.** Only the crosshair, hitmarkers and the interaction prompt live in the centre.
4. **Colour always has a second signal.** Rarity has a colour, a shape, a name and pips (Common circle with 1 pip up to Prototype hazard triangle with 6). Low ammo turns orange and shows LOW. This keeps colour-blind players covered.
5. **Keyboard, mouse and controller all work everywhere.** Every screen has a default focus, and the bottom bar shows the right button prompts for the device you last touched.
6. **The town is a place, not a menu.** Stash, Workbench, Trainer and the rest open when you walk up to them and press F. Esc or B always goes back one step.
7. **Nothing blocks a live match.** In a match the pause menu does not pause the game unless you play solo, and inventory is a quick overlay, not a full screen.

## Screen flow

The town is the hub: the front end leads into it, and every match leaves through the Deploy Gate and comes back to it.

_(Diagram not copied: screen flow · 3 areas, 14 screens.)_

Two-way arrows are screens that open on top and close with Esc or B. The first-launch quick setup (shown once, before the main menu) and Settings are not drawn. Settings opens from the main menu, the pause menu and the town Esc menu, and always returns to where you were.

## UI style

Menus look like containment-facility terminals: dark blue-black glass panels, thin teal-grey borders, and one bright accent per screen. Bio-green is for the experiment (Prototype loot, power-ups, the Vault) and for **one main action button per screen** (Enter World, Join Server, Select Character, the launcher's PLAY), as in the concept art (the person, 2026-11-17). Every other button, focus ring and selected row stays teal.

**Front-end layout (from the concept art).** Front-end screens use a left column of menu rows or tabs, each with a small line icon, and the selected row gets a teal bar on its left edge. Content sits in large glass panels. The one main action is a wide green button with dark text and a soft green glow, at the bottom right of the screen's content or at the top of the menu column.

| Token | Hex | Used for |
| --- | --- | --- |
| bg\_deep | #0B1014 | Full-screen backgrounds, behind panels |
| panel | #121A20 at 88% | Every panel and card |
| panel\_raised | #1A252D | Hovered rows, selected tabs |
| line | #2C3B44 | Borders, dividers |
| text | #E6ECEC | Main text |
| text\_dim | #8FA3A8 | Labels, hints, disabled |
| accent | #7FD6E0 | Focus ring, selected item, secondary buttons (cold fluorescent teal) |
| warn | #FF9F1C | Low ammo, warnings |
| danger | #C3201B | Round number, damage, death, delete |
| headshot | #FFC845 | Headshot hitmarker and kill numbers |
| xp | #E3CF9A | XP bar and level-up (brass) |
| experiment | #8DFF3A | Prototype, power-ups, Vault, and the one main action button per screen (gradient #A6FF66 to #6FD626, text bg\_deep) |

Rarity colours come from the style guide: Common #D9D9D2, Uncommon #3FE0C8, Rare #3D7DFF, Epic #A64DFF, Legendary #FF8A1C, Prototype #8DFF3A. Each item shows rarity four ways: border colour, rarity shape (circle for Common up to hazard triangle for Prototype), rarity name in the tooltip, and 1 to 6 pips.

**Type.** Atkinson Hyperlegible by default, with Lexend and OpenDyslexic as font options, and Atkinson Hyperlegible Mono for numbers that change (ammo, points, timers) so digits do not jump. Sizes at 1080p: 24 body, 28 headings, 36 screen titles, 56 HUD ammo, 72 round number. All sizes scale with the text size setting (80% to 150%).

**Motion.** Panels fade and slide 12 px in 120 ms. No bounce. Hover is instant. A "reduce motion" setting turns slides into plain fades.

**Sound.** Three UI sounds only: move (soft tick), confirm (relay click) and back (low thunk). Buying and equipping reuse the game's own sounds.

## Screens

Each screen below lists what it shows, what you can do, and where you go next. Mockups are drawn at 1920 x 1080 with the real colours and font sizes.

### 0. First-launch quick setup

Shown once, before the main menu, and again from Settings. One page with big previews: font, text size, subtitles, captions, colour vision preset, and motion comfort. Each choice changes the preview live. **Done** goes to the main menu; **Skip** keeps the defaults.

### 1. Main menu

A live 3D scene: your selected character stands in the snow at the Halcyon Labs outer gate at night, under a green Fenlight aurora, with the Oriel Biotechnic building and its red warning lights behind. Slow camera drift, falling snow. The menu sits on the left third over a dark fade.

- **Top left:** the wordmark "EXPERIMENT: UNDEAD" (UNDEAD in bio-green) with the four-point Fenlight star, and the line "A Fenlight survival story".
- **Enter World** (green, default focus): starts your own Lantern Post with the selected character (open to friends, F-66).
- **Servers**: the server browser (screen 2).
- **Character**: character select (screen 3).
- **Loadout**: the Character screen (screen 5) for the selected character.
- **Progression**: the Skill tree (screen 6) for the selected character.
- **Settings**, **Exit**.
- **Top right, profile card:** portrait, character name, level and a brass XP bar. Click it or press C to change character. Never a real name: the mockup uses "Survivor".
- **Bottom right, news card:** the latest update's title and one line, from the patch notes bundled with the build (no internet feed), with dots to page through the last 3. Replaces the concept's season banner: there are no seasons.
- **Bottom left:** game version and build number, for bug reports.

![Main menu mockup](images/ui_main_menu.jpg)

### 2. Server browser

There is no master server (F-66, ADR 0006), so the list holds servers you added or joined before, plus servers found on your local network: the browser sends an info query to each server's info port (game port + 1000, so 8777 for 7777) and broadcasts it on the LAN.

- **Left column tabs:** All, Favourites, Recent, LAN, and Refresh at the bottom. The concept's Official, Community and Modded tabs and its Region filter need a master server, so they are left out.
- **Filters:** Map, Players, Show full, Show other versions, and a search box.
- **Columns:** favourite star, server name, now playing (hub or map and round), players (3 / 8), ping (signal bars plus ms, orange above 80 ms), tags (LAN, Full, version in orange when it does not match yours). Sorted by ping.
- **Add by address** under the list: address and port, then Add and join. No password field until P8.
- **Detail panel** at the bottom for the selected row: map picture, name, what it is playing, version check, address, tags, players, and a green **Join Server** button.
- Favourite, rename and remove from a row (F, right-click or Y).
- Errors in plain words: "Server is full (8/8)", "Version mismatch: server 0.4.1, you 0.4.0".

![Server browser mockup](images/ui_server_browser.jpg)

### 3. Character select

Built in F-67 (plan needed). You pick one of a small roster of **preset survivors**, each with a name, a role, a short bio and 3 fixed traits (the person picked this over making your own character, 2026-11-17). Skills and loot still make your build; traits are a small flavour on top.

- **Left column:** a portrait for each survivor with name and level (no level shown if never played), the selected one with a teal frame.
- **Middle:** the selected survivor as a live 3D model in their equipped gear, lit by a warm lamp in a dark room. Drag or right stick to turn it.
- **Right panel:** name (large), role ("Field Lead · Salvager"), a 2-line bio, **Traits** (icon, name, one line each), then your progress with this survivor: level, brass XP bar, best round, and the equipped guns as small rarity cards.
- **Select Character** (green) under the panel: back to the main menu with this survivor on the profile card.
- Export and import a save file, so players can move PCs or back up.

**Provisional, for the F-67 plan to settle:**

- **Progress is per survivor:** each survivor has their own save (`user://characters/<survivor_id>.json`: level, skills, stash, Scrap), so playing a new survivor starts at level 1. This keeps today's one-file-per-character save.
- **Starting roster of 4** (names and bios are placeholders until the lore pass; no real people's names, ever):

| Survivor | Role | Bio | Traits |
| --- | --- | --- | --- |
| Elias Kell | Field Lead · Salvager | Former Cordon logistics sergeant. Knows the zone and its people. | Tenacious (less damage while downed), Field Experience (more ammo carried), Team Anchor (nearby squadmates regenerate a little faster between rounds) |
| Noor Wouters | Medic | Night nurse at Halcyon Labs who got out on Day 0. | Quick Hands (faster revives), Triage (revived squadmates get back more health), Calm (less screen shake when hit) |
| Jonas Leclercq | Engineer | Kessel Dam turbine fitter, now keeps Lantern Post's lamps lit. | Tinkerer (cheaper barricade repair points), Heavy Lifter (faster weapon swap), Night Shift (longer power-up timers) |
| Ines Haelen | Lab Tech | Oriel sample technician who knows how Fenlight behaves. | Sample Sense (Fenlight samples and drops show farther away), Cold Read (see a special zombie's tell a bit earlier), Steady (less sway when aiming) |

- **Trait numbers** come from the balance sheet, small (around 5 to 15%), and use existing stat keys where one exists. A new data type (`SurvivorData` in `content/survivors/`) holds name, role, bio, portrait, model and trait list.

![Character select mockup](images/ui_character_select.jpg)

### 4. Town HUD (Lantern Post)

No ammo or round number in town. Top left: level and XP bar. Top right: Scrap and contract tracker (3 lines). Bottom left: chat. Station names float over each building with the key to use them. A squad panel on the left shows your squad (up to 4) with ready ticks. Tab opens the player list with Inspect and Invite.

![Town HUD mockup](images/ui_town_hud.jpg)

### 5. Character screen: loadout, stash and inventory

One screen with three columns, opened with I anywhere in town or at the Stash.

- **Left: loadout.** Character model, Sidearm and Primary slots, Vest, Charm and Implant slots, the field ability picked for the next run, and total stats (health, damage bonus, luck).
- **Middle: stash grid.** 60 slots at start (10 x 6), more pages bought with Scrap. Filters: weapons, gear, rarity. Sort: rarity, item level, newest.
- **Right: tooltip.** Shows the hovered item. Hold Shift (or press X on controller) to compare with what you have equipped: better stats in teal with an up arrow, worse in orange with a down arrow.
- Drag and drop, or select and press E to equip. Double-click to send between stash and loadout. Marking items as "junk" (Z) lets the Workbench salvage them all in one go.

**Item tooltip** (one component, used everywhere: stash, pack, ground loot, Vault, inspect):

1. Name in rarity colour, rarity word and pips, item level.
2. Base stats (damage, fire rate, mag, handling) as numbers with small bars.
3. Affixes, one per line, with the rolled value and the possible range in grey ("+12% reload speed (8-20)").
4. Legendary or Prototype trait in its own box.
5. Salvage value in Scrap, and button hints.

![Character screen with item tooltip mockup](images/ui_character_screen.jpg)

### 6. Skill tree (Trainer)

Three columns side by side: Marksman, Survivor, Tinkerer. Nodes run top to bottom, with the keystone at 15 points and capstone at 25 drawn larger. A node shows ranks (2/3). Points spent per branch sit above each column. Points left and respec count (Free respecs: 2 of 3) at the top.

- Click or A to add a rank, right-click or B to remove before you confirm. Nothing is saved until **Confirm**.
- The field ability picker sits below the tree: 5 slots, locked ones show the unlock level.
- Open with K anywhere in town. Respec only works at the Trainer.

![Skill tree mockup](images/ui_skill_tree.jpg)

### 7. Workbench, Quartermaster, Contract Board, Hall of Records

These reuse the stash grid and tooltip with one action panel on the right:

- **Workbench:** Salvage (selected or all junk), Reroll affix (pick the line, see the cost), Raise item level (+5).
- **Quartermaster:** a shop grid with Scrap prices, the daily Rare offer pinned at the top.
- **Contract Board:** 3 daily and 3 weekly cards with progress bars and rewards. Pin up to 3 to the town and match HUD.
- **Hall of Records:** a table per map, weekly and all-time, best round, squad names.

### 8. Deploy Gate (map select and squad)

Walking into the Deploy Gate opens this. Left: map cards (picture, name, your best round, locked or not). Right: the squad (up to 4) with each player's level, primary and ready state, plus mode: **Squad**, **Solo**, or **Join public match** if one is filling.

- The squad leader picks the map. Everyone presses Ready. A 5-second countdown starts, any player can cancel it.
- Shows the server's match slots: "Matches running: 1 of 2". If both are busy: "Wait for a slot, about 8 min".

![Deploy Gate mockup](images/ui_deploy_gate.jpg)

### 9. Loading

Map art, the map name, and one rotating tip. A progress bar, and the names of squad members as they finish loading. Never longer than needed: no "press any key".

### 10. Match HUD

Follows the design doc table. Additions (the concept art on 2026-11-17 added the health panel, objective list, item slots and area name):

- **Top left:** round number, and under it the map and the area you are in ("Halcyon Labs · Containment").
- **Top right:** an objective list (exfil steps, map events, pinned contracts with a count, done ones ticked and struck through), then squad cards (name, health bar, down state with bleed-out timer).
- **Bottom left:** field ability icon with a cooldown ring, serums and the Pack count (4/6) in one row, and under it the health panel: portrait, health number and max (100 / 150) and a health bar. The red vignette under 40 HP and the heartbeat stay.
- **Bottom centre:** power-up timers, and a small item drop feed ("Rare Talon DMR" in rarity colour) that fades after 4 s.
- **Bottom right:** points, then the grenade and tactical slots (icon, count, key G and Q) next to the ammo panel (gun name with rarity shape, magazine big, reserve small).
- **Exfil:** from round 10, every 5 rounds, a marker and a 60 s hold bar appear at the top centre.
- **Not taken from the concept:** a minimap (Halcyon Labs is small; later if a bigger map needs it), armour and medkits (the game has neither), and a zombies-remaining count.

![Match HUD mockup over a first-playable screenshot](images/ui_match_hud.jpg)

### 11. Pack overlay

Tab in a match. A half-screen panel over the HUD. On top, your character in its worn gear (a live 3D view), with a box per gear slot on its left and your level, health and the guns in your hands on its right. Underneath, the 6 Pack slots. Every item shows a picture of itself (an icon rendered from its model by `tools/render_item_icons.gd`), in the Pack, the slot boxes, the item card and the town stash. The item card sits on the right half, comparing a Pack gear piece with the one you wear. The game keeps running behind it (it is a quick check, not a menu). You can drop items, swap a Pack gun into your hands, or wear a Pack vest, charm or implant (E; the piece you take off goes into that Pack slot). Mouse look is paused while it is open; movement keys still work. Layout from the person's pick, 2026-11-19 (plan [wear-gear-mid-run](../plans/wear-gear-mid-run.md)).

![Pack overlay mockup](images/ui_pack_overlay.jpg)

### 12. Pause

Esc. Resume, Settings, Controls, Leave match (asks to confirm and says "You keep all loot"). In solo the game pauses; in a squad it does not, and a banner says so.

![Pause with leave confirmation mockup](images/ui_pause.jpg)

### 13. Death and run results

When you die (or the whole squad goes down), the camera drifts up for 3 s, then the results screen:

- **Top:** "Round 17 reached" in red numeral, map, time.
- **Left column:** kills, headshots, points earned, Vault rolls, best weapon.
- **Middle:** loot kept, shown as item cards in rarity colours, the best one first and larger. Every item from the Pack goes to your stash automatically.
- **Right:** XP gained as a filling brass bar with level-ups called out, skill points earned, Scrap earned, contract progress.
- Buttons: **Back to town** (default), **View squad** (each player's stats).

Exfil uses the same screen with a green "Exfiltrated" banner and the exfil cache items.

![Run results mockup](images/ui_results.jpg)

### 14. Settings

Pages: Controls, Aim, Video, Audio, Accessibility, Comfort, with a search box at the top that finds any setting by name. Each row is a label, a control, and a one-line hint under it. The full list of rows lives in the [Controls and accessibility plan](controls.md); this doc only covers the layout. Changes apply live, with "Revert" and "Defaults" at the bottom. Video changes that need a restart say so.

- **Network tab (F-66):** Let friends join my world, Open router port automatically, World name, port.
- **Accessibility tab:** text size, colour-blind mode (3 presets for hitmarkers, drops and rarity), subtitles for audio tells, screen shake, reduce motion, hold or toggle for ADS, sprint and crouch, aim assist for controller.
- **Controls tab:** every action from the input map, with keyboard and controller columns and a "press a key" rebind.

![Settings, Accessibility page mockup](images/ui_settings.jpg)

## Godot structure

One autoload (`UI`) owns a stack of screens, one theme styles everything, and screens read their lists, tabs and items from Resources. Adding a town station or a settings row is a new `.tres` file, not new layout code.

**Folders** (fits the architecture doc):

```
core/ui/ui.gd                 autoload: screen stack, overlays, toasts, input prompts
systems/ui/theme/             main_theme.tres, ui_tokens.tres, fonts/
systems/ui/widgets/           item_card, item_tooltip, stat_row, rarity_pips, key_prompt,
                              cooldown_ring, tab_bar, confirm_dialog, list_row
systems/ui/screens/<name>/    one folder per screen: <name>.tscn + <name>.gd
systems/ui/hud/               hud.tscn + one scene per element (round, ammo, points, ...)
content/ui/screens/           ScreenData .tres (id, scene, layer, pauses_game, music)
content/ui/hud_layouts/       HudLayout .tres (which elements, anchor, offset, scale)
content/ui/settings/          SettingData .tres (one per settings row)
content/ui/tips/              loading tips
```

**Screen router.** `UI.push(&"stash")`, `UI.pop()`, `UI.replace(&"town_hud")`. The router looks up `content/ui/screens/stash.tres`, instances its scene on the right layer, gives it focus and plays the transition. Back (Esc, B) always calls `pop()`. Screens never load other screens directly, so the flow lives in one place and tests can push any screen on its own.

**Layers** (one CanvasLayer each, low to high): world labels 0, HUD 10, screens 20, overlays (pack, pause) 30, modals (confirm, rebind) 40, toasts and loading 50.

**Theme.** One `main_theme.tres` with type variations (`PanelRaised`, `ButtonPrimary`, `LabelDim`, `LabelMono`) so scenes never set colours by hand. `ui_tokens.tres` holds the colour table above plus rarity colours, and both the theme and shaders read from it, so a colour-blind preset swaps one resource. Font sizes are set at 1080p. The `UI` autoload multiplies every theme font size by the text size setting at startup and when the setting changes; layout uses containers, so panels grow with the text instead of clipping it.

**Data-driven content.**

- **Items:** `item_card` and `item_tooltip` take an item dictionary (the architecture doc rule: items as dicts) and read names, stats and affix ranges from `WeaponData`, `GearData` and `AffixData`. A new weapon or affix shows up in every screen with no UI work.
- **Stations:** each town station is a `StationData` .tres: id, display name, prompt text, and which screen plus which action panel it opens. Adding a station = one .tres and, if it needs one, an action panel scene.
- **Skill tree:** drawn from `SkillNodeData` (branch, row, column, max ranks, requires). The tree screen builds itself from the files, so moving a node is a data edit.
- **Settings:** each `SettingData` names its tab, label, hint, control type (toggle, slider, dropdown, keybind), range and the `Settings` autoload key. The settings screen is generated from these files.
- **HUD:** `hud.tscn` reads a `HudLayout` and places each element by anchor and offset. A "HUD editor" later only needs to write that resource.

**Signals and data flow.** Screens never change game state themselves. They call requests (`Economy.try_spend`, `ProgressionService.equip`) and listen to `Events` (`item_equipped`, `points_changed`, `round_started`). In multiplayer the server stays the authority and the UI just reflects what it hears, so the same screens work solo and online.

**Input.** Every screen sets `default_focus`. A `key_prompt` widget reads the input map and shows the right glyph (keyboard or controller) for the last device used. Mouse capture is handled only by the router: it frees the mouse when any screen above the HUD is open.

**Tests.** A GUT test pushes every `ScreenData` once and checks it loads, has a default focus, and that `pop()` returns to the screen below. A validator test checks every `SettingData` key exists in `Settings` and every `StationData` points at a real screen.

## Build order

UI is built in the same phases as the roadmap, so no screen is made before the system behind it exists.

| Phase | UI work |
| --- | --- |
| P0 Foundation | `UI` router, layers, theme and tokens, fonts, `key_prompt`, Settings screen (generated from `SettingData`), Pause |
| P1 Gun feel | Crosshair, hitmarkers, ammo, damage arcs, vignette |
| P2 Wave loop | Round number, points with floating numbers, interaction prompt, power-up timers, serum row, simple results screen |
| P4 Map 1 (v0.1) | Main menu, Loading, final HUD polish, results screen in final look |
| P5 Levels and skills | XP bar, level-up toast, Skill tree, field ability icon |
| P6 Loot (v0.2) | Item card and tooltip, Pack overlay, drop feed, Character screen (loadout, stash), results loot column, character select (F-67) |
| P7 Co-op | Squad cards, down and revive states, results View squad |
| P8 Server package | Server browser, direct connect, Host and play |
| P9 Town hub (v1.0) | Town HUD, stations (Workbench, Quartermaster, Contracts, Records), Deploy Gate, player list and inspect, chat |

**Provisional decisions (taken without a review, change any of them)**

- **Main menu background: a live 3D scene** of the selected character at the Halcyon Labs outer gate at night (snow, green aurora), from the concept art. A pre-rendered video is the fallback if loading takes too long.
- **Main menu Loadout and Progression** open the same Character screen and Skill tree as in town, for the selected character. **News card** reads the patch notes bundled with the build.
- **Pack overlay: the game keeps running at full speed**, solo too. Only mouse look pauses. This keeps it a quick check, not a safe spot.
- **Controller: supported at launch**, following the controller layouts in the [Controls and accessibility plan](controls.md). Every screen gets a default focus and button glyphs from P0, so this costs little up front.
