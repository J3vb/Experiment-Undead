# Plan: Skill tree screen (Research)

Status: Done
Roadmap: F-21 / issue #112
Phase: P5
Size: M
Approved by: plan PR #464 (fresh Claude review, 4 blocking findings fixed); the person approved the plan and picked the gates on decision cards (2026-11-20)
Lore link: docs/design/lore.md#front-end-screens: Research is Dr. Corvelyn's lab, where the Fenlight samples you bring back are studied and teach you the salvager trades (provisional row, already there). The three branches are the "Skill branches" row. The bio-green lines and tank are the Fenlight samples themselves, so the look-rules "bio-green only for the experiment" rule holds.

## Goal

Players spend their skill points on a Research screen that looks like the
person's concept art (`research_concept.jpg`): a dark lab with a glowing
Fenlight tank on the left and a circuit-board graph of skill tiles linked by
green lines. Today ranks can only change by editing a save. Pillar: every
run makes you stronger.

## Scope

In:

- The main menu RESEARCH row opens a new Research screen for the local
  character (same profile and newer-save guard as LOADOUT).
- Three branch lanes (Marksman, Survivor, Tinkerer). Each lane: its regular
  skills, then the keystone, then the capstone, linked by lines. A tile shows
  an icon, the name and ranks (2/3). Gated tiles show a lock and "8 in
  branch" (or whatever the gate is) until reachable.
- A detail panel for the focused tile: name, description, current and next
  rank value, gate.
- Points left at the top, points spent above each lane.
- Click / A adds a rank, right-click / B removes a rank added this visit.
  Nothing is saved until **Confirm**. Back with unsaved ranks asks once
  ("Discard changes?").
- **Reset all**: clears every rank (a respec), saved on Confirm. Free and
  unlimited for now (see Data).
- One SVG line icon per skill, hand-written like the HUD Serum icons, white
  strokes tinted at run time.
- The keystone/capstone gate numbers (open decision below).
- Mouse, keyboard and gamepad focus.

Not in (non-goals, and where each one goes instead):

- Opening the tree with K in the town, and the Trainer NPC who owns respecs:
  both need a mid-session loadout resend and a town station (later: F-45).
  This screen lives in the main menu only, like LOADOUT, so ranks only change
  between sessions.
- Respec cost (3 free, then Scrap): Scrap does not exist yet (later: F-45
  economy). DECISIONS line until then.
- The field ability picker under the tree (later: F-22).
- The gear `skill_rank` affix ("+1 rank to a named skill") and the
  `bonus_skill_ranks` cap (later: F-31, with the other loot traits).
- More skill nodes to reach "about 30 points per branch", and the gates back
  to 15/25 (later: F-90).
- A painted lab backdrop: waits on a clean, text-free image from the person,
  like the Loadout armoury backdrop. Until then a dark shade with a code-drawn
  green glow where the tank sits.

## Ready to build

```
### Ready to build
- Foundations touched: 2 data ids (skills are .tres, id = file name), 5 UI router
  (new screen through UI.push). Both solid.
- Decision records that apply: ADR 0019 (supplied painted menu art, only if the
  person sends a backdrop). ADR 0003 not touched: no new network message.
  Does this go against one? no
- Co-op:
  - Who decides: the owning client, on its own save, outside any session.
  - How a client triggers it: n.a. The ranks reach the server the existing way:
    LoadoutSync.submit_loadout on spawn, checked by SkillEffects (F-20).
  - What other players see: nothing new.
  - Works on a dedicated server with no local player: yes, the server hands over
    before the menu builds; no screen there.
- Data: new SkillNodeData.icon (Texture2D). Gates stay branch_points_needed in
  content/skills/*.tres. Code compares against a specific id anywhere: no.
- Save: changes what is saved? no. skill_ranks is already saved. Renames or
  removes a saved id: no.
- Events and UI: no new Events. New screen content/screens/research.tres through
  the UI router: yes.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: n.a. (menu screen, no gameplay).
- Tests: unit tests for the new spend rules (test_skill_tree.gd), a screen test
  (new test_research_screen.gd), main menu test, content test for icons and gates.
- Logging: Log.warn(&"ui", &"skill_icon_missing") when a skill has no icon;
  Log.warn(&"progression", &"skill_ranks_over_budget") when a loaded save holds
  more ranks than the level allows (the screen then offers Reset only).
- Performance: menu only. Lines are drawn in one _draw() and redrawn on change.
- Lore link: see header.
- Out of scope: see Not in.
```

## Design references

- `docs/design/concepts/screens/research_concept.jpg`: the look target.
- docs/design/game-design.md#skill-tree: 54 points by level 50, branches,
  keystone 15 / capstone 25, respec rule.
- docs/design/ui-hud.md "6. Skill tree (Trainer)": ranks shown as 2/3, points
  per branch, add/remove before Confirm, nothing saved until Confirm.
- docs/design/look-rules.md: bio-green `#8DFF3A` for the Fenlight glow and
  owned ranks, cold teal `#7FD6E0` for focus, body text at least 24 px at
  1080p.
- docs/DECISIONS.md "Skill tree" line (rewritten by this plan).
- docs/plans/front-end-concept.md: logo, brush heading and backdrop pattern.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/progression/skill_tree.gd | changed | `can_rank_down(pending, saved, id)` and `rank_down` (mirror of `can_rank_up`/`rank_up`) |
| systems/progression/skill_node_data.gd | changed | `icon: Texture2D` |
| systems/ui/research_screen.gd/.tscn | new | the screen: lanes, tiles, detail panel, Confirm/Reset/Back |
| systems/ui/skill_tile.gd | new | one tile: icon, name, ranks, locked/owned/focus looks |
| systems/ui/skill_links.gd | new | a Control that draws the lines between tiles |
| content/screens/research.tres | new | ScreenData for the router |
| systems/ui/main_menu.gd/.tscn | changed | RESEARCH row enabled (not disabled, focusable, no "Coming soon"), focus neighbours rewired so Loadout goes to Research, `research_button.pressed` opens the screen; the newer-save guard remembers which screen asked (`_pending_screen: StringName`) |
| assets/ui/skills/<id>.svg | new | 20 line icons |
| content/skills/*.tres | changed | `icon`, and gate numbers per the decision |
| docs/DECISIONS.md, docs/HOW_TO_ADD.md, docs/ROADMAP.md | changed | Skill tree line, "A skill" gets the icon step, F-21 status |
| docs/design/game-design.md, docs/design/ui-hud.md | changed | gate numbers from the decision (design-change skill, Change log row); ui-hud section 1 Research enabled, section 6 points to the DECISIONS line for K key and Trainer |
| docs/LOGGING.md | changed | the two new warnings |
| tests/content/test_skills.gd, tests/unit/test_skill_tree.gd | changed | gate tests stop hard-coding 15/25: keystones and capstones found by row 3/4 |

Autoloads, managers or base classes added: none. `SkillTile` and `SkillLinks`
are leaf Controls owned by the screen.

Files over 300 lines this plan grows: `systems/ui/main_menu.gd` is 286; it
gains about 15 lines: `_open_research`, and `_open_character`/`_close_error` take
the pending screen id instead of always pushing `&"character"`. No split needed.

## Data

- `SkillNodeData.icon: Texture2D = null`, read by `SkillTile`. Content test:
  every skill has one.
- Gates: `branch_points_needed` on the 6 keystone/capstone `.tres` files, set
  by the open decision. Content test: every gate is reachable, meaning the
  branch's other nodes below that gate hold at least that many ranks.
- Respec: Reset is free and unlimited until Scrap exists. DECISIONS line.
- Pending ranks live in the screen only (`Dictionary[StringName, int]`), read
  through `SkillEffects.ranks_from(profile.skill_ranks)` (the save holds String
  keys and maybe float values from JSON). Confirm writes them back with String
  keys and calls `profile.save()`. A loaded `.tres` is never changed.
- Save fails (newer or unreadable save, `_can_save` false, or a disk error):
  same as `CharacterScreen._close`: a status line "Could not save (...). Back
  again closes without saving."
- `SkillTree.can_rank_down(pending, saved, id)`: true only when `pending[id] >
  saved[id]` and every other ranked gated node in that branch still meets its
  gate after the removal. `rank_down` returns a copy, like `rank_up`.
- Save format change: none.
- Content checks to add in `tests/content/test_skills.gd`: icon set, gate
  reachable (counting every other node in the branch, keystone included, the
  way `points_in_branch` does), (row, column) unique inside a branch.
  The existing checks that hard-code 15/25 (lines 21, 28, 92-95) find
  keystones and capstones by row 3 and 4 instead.

## Co-op behaviour

- Who owns the state: the owning client's save file.
- What clients send, what the server sends back: nothing new. On spawn the
  owner already sends its ranks in `LoadoutSync.submit_loadout`; the server
  checks them with `SkillEffects` (ids, 1..max_ranks, total at most 54).
- What a client sees that the host sees too: nothing; the screen is local.
- Late joiner: n.a. Ranks travel with the loadout as today.
- Dedicated server: no screen; nothing skipped.

## Performance

Menu screen only. Tiles are built once on open; a rank change repaints the
changed tiles and calls `queue_redraw()` on the links. The only animation is
a looping Tween on the tank glow, off when
`Settings.get_value(&"accessibility", &"reduce_motion")` is true. No cost in a
match.

## Steps

### Step 1: Spend rules and a working Research screen

Risky part first: the undo and gate rules, and the save round-trip.

- Build: `SkillTree.can_rank_down` / `rank_down`; the gate numbers from the
  decision (design-change skill: game-design.md, Change log row); `research_screen` with three plain lanes of tiles (name and
  ranks, no icons yet), points left and per branch, add/remove, Confirm,
  Reset all, Back with the discard question; `content/screens/research.tres`;
  main menu RESEARCH row enabled with focus neighbours and the shared
  newer-save guard; failed-save status like CharacterScreen. Gamepad and
  keyboard focus between tiles. LOGGING.md lines.
- Files: systems/progression/skill_tree.gd, systems/ui/research_screen.gd/.tscn,
  systems/ui/skill_tile.gd, content/screens/research.tres,
  systems/ui/main_menu.gd/.tscn, content/skills/ (gates),
  docs/design/game-design.md, docs/design/ui-hud.md, docs/LOGGING.md, tests.
- Tests: `tests/unit/test_skill_tree.gd` (remove only pending ranks, removing
  a rank that would break a held keystone is refused, reset; the old
  `test_keystone_requires_fifteen` / `test_capstone_requires_twenty_five`
  read the gate from data); new
  `tests/unit/test_research_screen.gd` (open with a level 12 profile, add 3
  ranks, points left drops, Back discards, Confirm saves and a fresh
  `CharacterProfile` load from disk holds the same ranks, a locked keystone
  does not take a click, a newer save shows the could-not-save status); `tests/unit/test_main_menu.gd`
  (RESEARCH enabled and opens the screen, Loadout focus goes to Research,
  the newer-save dialog then opens Research not Loadout; replaces the greyed
  and focus-skips-Research checks);
  `tests/content/test_skills.gd` (gates reachable).
- Done when: a player can spend and save points from the main menu and the
  next run's stats change (already covered by F-20's spawn path).

### Step 2: Concept look

- Build: 20 SVG icons and `SkillNodeData.icon`; `SkillTile` looks (dark
  plate, thin teal frame, bio-green frame and glow when owned, grey with a
  lock when gated, larger tiles for keystone and capstone); `SkillLinks`
  draws right-angle lines with arrow heads between tiles in a lane (green
  when the next tile is reachable, dim grey dashed when not), like the
  concept; FENLIGHT logo and RESEARCH heading with the brush line; detail
  panel; backdrop slot with the dark shade and a code-drawn green tank glow
  until the person sends an image; Reduce motion stops the glow pulse.
- Files: assets/ui/skills/*.svg (+ .import), systems/progression/skill_node_data.gd,
  content/skills/*.tres, systems/ui/skill_tile.gd, systems/ui/skill_links.gd,
  systems/ui/research_screen.gd/.tscn, docs/HOW_TO_ADD.md, tests.
- Tests: `tests/content/test_skills.gd` (every skill has an icon);
  `tests/unit/test_research_screen.gd` (owned, locked and focused tile looks;
  links report reachable/unreachable per pair; Reduce motion stops the pulse).
- Done when: a headless screenshot sits next to the concept in the PR (the
  look-check skill) and the close-out below is done.
- Close-out (same PR, finish-feature skill): DECISIONS "Skill tree" line
  rewritten (free respec, no K key or Trainer yet), ROADMAP F-21 Done,
  issue #112 closed.

## Acceptance

- [ ] RESEARCH on the main menu opens the screen (test_main_menu).
- [ ] Spending, removing a pending rank, Reset and Confirm work and save
      (test_research_screen, test_skill_tree).
- [ ] Every keystone and capstone can be reached with the tree's nodes
      (test_skills content check).
- [ ] Every skill has an icon (test_skills).
- [ ] The screen matches the concept's look (screenshot in the step 2 PR,
      the person's look play-test).

## Risks

- The concept shows a free-form graph; our data is three lanes. Lanes keep
  it readable with 20 nodes and need no per-node positions beyond the
  existing `row` and `column`. If the person wants a free graph later, only
  `SkillLinks` and the tile layout change.
- 20 hand-written icons may look uneven. They are simple line drawings on a
  64 px grid like the Serum icons, checked together in one contact sheet.
- A save could hold more ranks than its level allows (edited saves, or a
  gate change). The screen shows the over-budget state and offers Reset;
  the server only rejects totals over 54, not totals over the player's
  level or broken gates (trusted client, ADR 0003). DECISIONS line says so.

## Open decisions

- [x] Keystone and capstone gates (15/25 cannot be reached; the tree is 43
      points against 54 earned): lower the gates to 8 and 11 now; a later
      row (F-90) adds about 5 nodes per branch and puts them back to 15/25.
      The person's pick, 2026-11-20.
