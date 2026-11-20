# Plan: Front-end screens to the concept art

Status: Approved
Roadmap: F-88 / no issue
Phase: P7, pulled forward 2026-11-20 with the new menu concept art and the rename to FENLIGHT
Size: M
Approved by: Claude plan review in the plan PR (7 blocking findings fixed); the person answered all four look decisions on 2026-11-20
Lore link: docs/design/lore.md#front-end-screens (new table in "Story links for game content"): the menus are Lantern Post at night, the Loadout is Odile's armoury table, Research is Dr. Corvelyn's lab (provisional)

## Goal

The main menu and the Loadout screen look like the person's concept art
(2026-11-20): the FENLIGHT logo with green Fenlight veins, a left column of
spaced capitals with an orange brush stroke on the selected item, and a painted
night scene behind. Every menu action that works today keeps working. Serves
the "it looks like a real game" bar for the first public test builds.

## Scope

In:

- The three concept images saved as design references in
  `docs/design/concepts/screens/` (done in the plan PR).
- A FENLIGHT logo image drawn by a script (`tools/assets/menu_art.py`), used
  by every front-end screen.
- A shared brush-stroke menu button look (normal, hover, focus, disabled) as
  a theme type variation in `systems/ui/theme.tres`.
- ADR 0019: supplied painted art may go in `assets/ui/backdrops/` (done in
  the plan PR).
- Main menu: painted Lantern Post backdrop with a slow drift and light snow,
  the new item list, Research shown greyed out until F-21.
- Loadout (the `CharacterScreen`): armoury backdrop, logo, LOADOUT heading and
  five tabs like the art: Weapons (primary, sidearm) and Field Gear (vest,
  charm, implant) filter the slots and the stash; Serums, Perks and Customize
  are shown greyed and locked until a feature exists.

Not in (non-goals, and where each one goes instead):

- Renaming the game in the window title, config, launcher, docs and releases
  (thread "Rename the game to Fenlight").
- The Research screen itself (the skill tree): F-21, which takes
  `research_concept.jpg` as its look target. This plan only adds the greyed
  menu entry.
- Intel on the main menu: no feature exists (the person's pick).
- What the locked Serums, Perks and Customize tabs will hold: their own
  features later. Customize comes with Dyes (F-46). Perks has no roadmap row;
  skills live in Research (F-21), so what Perks holds is a question for then.
- Restyling Settings, Servers, Pause and Results: a later pass once more art
  arrives.
- Menu sounds: the menu stays music only (PR #399).

## Ready to build

```
### Ready to build
- Foundations touched: 5 (UI router). Solid; screens still open through UI.push/replace.
- Decision records that apply: none go against this. ADR 0003 not touched (no network).
- Co-op:
  - Who decides: each client, local screens only.
  - How a client triggers it: n.a. (no shared state).
  - What other players see: nothing.
  - Works on a dedicated server with no local player: yes, "--server" hands over before the menu builds.
- Data: no new ids or numbers. Colours from docs/design/look-rules.md.
  Code compares against a specific id anywhere: no (slot ids stay in CharacterScreen.SLOTS).
- Save: no.
- Events and UI: no new Events. No new screens; main_menu and character stay in content/screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: n.a. (menus; snow uses a particle node, not gameplay randomness).
- Tests: tests/unit/test_main_menu.gd, test_main_menu_screens.gd, a new tests/unit/test_character_tabs.gd, tests/content/test_screens.gd.
- Logging: Log.warn when a backdrop texture fails to load (falls back to the dark shade).
- Performance: the menu stops loading the whole Halcyon Labs map as its backdrop, so boot gets faster and lighter.
- Lore link: see header.
- Out of scope: see Not in.
```

## Design references

- `docs/design/concepts/screens/main_menu_concept.jpg`, `loadout_concept.jpg`,
  `research_concept.jpg` (the person's art, 2026-11-20).
- `docs/design/look-rules.md`: Cold Containment palette, bio-green `#8DFF3A`
  for Fenlight, body text at least 24 px at 1080p in Atkinson Hyperlegible.
- `docs/design/ui-hud.md` main menu and character screen sections.
- `docs/DECISIONS.md`: one new line for the orange brush (see Risks).
- ADR 0008 (code-built art), ADR 0017 (Tripo models), new ADR 0019 (supplied
  painted menu backdrops), ADR 0011 (one UI router: screens unchanged).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `tools/assets/menu_art.py` | new | Draws `assets/ui/fenlight_logo.png` (chipped letters, melt drips, green Fenlight veins) and `assets/ui/brush_stroke.png`; fixed seed |
| `tools/assets/fonts/BebasNeue-Regular.ttf` | new | OFL display font, input to the script only (the game never loads it) |
| `systems/ui/theme.tres` | changed | `MenuBrush` Button type variation: StyleBoxTexture brush on hover/focus, flat on normal, dimmed when disabled |
| `systems/ui/main_menu.tscn` / `.gd` | changed | Logo, backdrop image instead of the Halcyon map + Camera3D, new items, CREDITS const lines |
| `systems/ui/character_screen.tscn` / `.gd` | changed | Backdrop, logo, heading, tab column replacing the `%Category` filter; focus rewired per tab |
| `systems/ui/character_stash.gd` | new | Stash list, filters and its focus grid, moved out of `character_screen.gd` |
| `assets/ui/backdrops/` | new | `main_menu.jpg`, `loadout.jpg` (painted, no text in them, ADR 0019) |
| `docs/design/ui-hud.md` | changed | Section 1 (main menu) and 5 (character screen) to the new look; brush token in the UI style table |
| `docs/design/look-rules.md` | changed | Brush colour token |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: `systems/ui/character_screen.gd` (345).
Step 3 first moves the stash list and filters into a new
`systems/ui/character_stash.gd` (split by job) before adding tabs.

## Data

- No Resource types, save fields or network messages change.
- Save format change: none.
- Content checks to add in `tests/content/`: none (backdrops live in
  `assets/`, not `content/`). The backdrop size checks go in the screens' unit
  tests: at least 1600 px wide (the clean main menu art is 1672x941).

## Co-op behaviour

- Who owns the state: each client. Menus are local.
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: n.a.
- Late joiner: n.a.
- Dedicated server: the menu scene never builds its look ("--server" hands
  over in `_hand_over()` first), so nothing is loaded.

## Performance

Menu only. One full-screen texture, one small particle node (about 150 snow
flakes), one logo texture. Cheaper than today's backdrop, which loads and
renders the whole Halcyon Labs map behind the menu.

## Steps

### Step 1: FENLIGHT logo and brush buttons

- Build: `tools/assets/menu_art.py` and its two PNGs; the `MenuBrush` Button
  type variation in `theme.tres` (burnt orange brush on hover and focus,
  spaced capitals in Atkinson Hyperlegible, dimmed text when disabled). Swap
  the main menu's EXPERIMENT / UNDEAD labels for a logo TextureRect and give
  its buttons `MenuBrush`. Items and backdrop unchanged. Brush colour token in
  `look-rules.md` and the `ui-hud.md` UI style table; DECISIONS line.
- Files: `tools/assets/menu_art.py`, `tools/assets/fonts/` (font + OFL text),
  `assets/ui/fenlight_logo.png`, `assets/ui/brush_stroke.png` (+ `.import`),
  `systems/ui/theme.tres`, `systems/ui/main_menu.tscn`, `systems/ui/main_menu.gd`
  (CREDITS const: font line), `docs/CREDITS.md`, `docs/design/look-rules.md`,
  `docs/design/ui-hud.md`, `docs/DECISIONS.md`, `tests/unit/test_main_menu.gd`.
- Tests: `test_main_menu.gd`: the title is the logo texture (no EXPERIMENT
  label left), every menu button uses the `MenuBrush` variation and its focus
  style is the brush StyleBoxTexture; credits text names the font. A Python
  test in `tools/ci/` runs `menu_art.py` into a temp folder and checks the
  output matches the committed PNG sizes (the script still runs).
- Done when: look-check screenshot next to `main_menu_concept.jpg`.

### Step 2: Main menu backdrop and items

- Build: replace the Halcyon map instance and Camera3D with a full-screen
  TextureRect (slow drift in `_process`), a left-side shade for legibility and
  a light snow particle layer. Reduce motion stops both the drift and the
  snow. Items, top to bottom: PLAY (today's Enter World), SERVERS, LOADOUT,
  RESEARCH (disabled, tooltip "Coming soon"), SETTINGS, CREDITS, QUIT. Focus
  order wraps and skips Research; gamepad works. Update `ui-hud.md` section 1.
- Files: `systems/ui/main_menu.tscn` / `.gd` (CREDITS const: backdrop line),
  `assets/ui/backdrops/main_menu.jpg` (+ `.import`), `docs/CREDITS.md`,
  `tests/unit/test_main_menu.gd`, `tests/unit/test_main_menu_screens.gd`,
  `docs/LOGGING.md`, `docs/design/ui-hud.md`.
- Tests: Play still calls `enter_world()`; Research is disabled and not in the
  focus loop; the scene has no `Camera3D` and does not instance
  `levels/halcyon_labs/map.tscn` (replaces today's "Backdrop process_mode is
  disabled" assert); the backdrop is at least 1600 px wide; with Reduce motion
  on, the backdrop does not move and the snow is not emitting.
- Done when: look-check screenshot next to the concept; boot test clean.

### Step 3: Loadout screen look and tabs

- Build: first move the stash list, the Rarity and Sort filters and the stash
  focus grid into `character_stash.gd` (split by job, keeps both files under
  350 lines). Then add the armoury backdrop (dark shade until the clean art
  arrives), logo, LOADOUT heading and a left tab column with `MenuBrush`:
  WEAPONS, SERUMS, PERKS, FIELD GEAR, CUSTOMIZE. The tabs replace the
  `%Category` OptionButton (deleted). Weapons opens by default and shows the
  primary and sidearm slots and gun items; Field Gear shows vest, charm and
  implant slots and gear items. Serums, Perks and Customize are disabled with a
  "Coming soon" tooltip and skipped by focus. `_wire_focus()` is rebuilt on
  every tab change from the visible slot buttons, so gamepad focus never lands
  on a hidden slot. The dressed turntable stays. Update `ui-hud.md` section 5.
- Files: `systems/ui/character_screen.*`, new `systems/ui/character_stash.gd`,
  `assets/ui/backdrops/loadout.jpg` when supplied, `docs/design/ui-hud.md`,
  `tests/unit/test_character_screen.gd` (the Category test becomes a tab test),
  new `tests/unit/test_character_tabs.gd`.
- Tests: Weapons shows only primary and sidearm slots and gun items; Field
  Gear shows vest, charm, implant and gear items; Rarity still combines with
  the tab; locked tabs are disabled and not in the focus loop; after each tab
  change every focus neighbour points at a visible control; equip and save
  still work from both tabs (existing character tests stay green).
- Done when: look-check screenshot next to `loadout_concept.jpg`; plan Done.

## Acceptance

- [ ] Main menu and Loadout match the concept art in a look-check screenshot.
- [ ] Every action the menu had before (Enter world, Servers, Loadout,
      Settings, Credits, Quit, command-line join/host/server) still works:
      existing main menu tests green.
- [ ] Equip, unequip and save on the Loadout screen work from both tabs.
- [ ] Menu is still music only.

## Risks

- **Painted backdrops are AI images in `assets/`.** ADR 0008 and rule 8 say
  art is built in code; ADR 0019 (this plan PR) allows supplied painted
  backdrops for menus only, credited in `docs/CREDITS.md`.
- **Orange brush vs the "one green main button" rule** (ui spec, 2026-11-17).
  The art uses an orange brush on the selected item; Legendary is also orange
  `#FF8A1C`. Pick: a darker burnt orange `#D9662B` for the brush so it does
  not read as Legendary; added as a token in `look-rules.md` and the
  `ui-hud.md` UI style table, plus one DECISIONS line.
- **Clean art per screen.** The main menu has a clean 1672x941 image. Step 3
  needs a clean, text-free armoury image; until it arrives step 3 uses the
  dark shade only.

## Open decisions

- [x] Background: painted backdrops from clean, text-free versions of the art (the person, 2026-11-20; clean main menu image supplied, 1672x941).
- [x] Main menu items: PLAY, SERVERS, LOADOUT, RESEARCH (greyed until F-21), SETTINGS, CREDITS, QUIT; no Intel (the person, 2026-11-20).
- [x] Loadout tabs: all five like the art, WEAPONS, SERUMS, PERKS, FIELD GEAR, CUSTOMIZE; the three with no feature yet are greyed and locked (the person, 2026-11-20).
- [x] Title: FENLIGHT is the game's new name (the person, 2026-11-20). The rename runs in its own thread.
