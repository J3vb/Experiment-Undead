# Plan: Player names

Status: Done
Roadmap: F-81
Phase: P7
Size: S
Approved by: review (size S, no open goal or look decisions); the person asked for the feature on 2026-11-19
Lore link: docs/design/lore.md#gear-and-abilities, row "Your name": the name you sign in Pell's run log at the Deploy gate (provisional)

## Goal

Players type their own name, and teammates see it in co-op. Serves the co-op
pillar: you know who you are playing with.

## Scope

In:

- A name box on the Character screen (main menu), saved with the character.
- One cleaning rule, `CharacterProfile.clean_name()`, used by the name box,
  by loading a save, and by the server when it reads a hello.

Not in (non-goals, and where each one goes instead):

- Name tags above teammates' heads and a scoreboard: neither exists yet (later:
  own row when the HUD gets them).
- Renaming while connected: the name is read when you enter a world or join.
  The Character screen only opens from the main menu, so this cannot happen.
- Preset survivors with their own names: F-67. The typed name stays the
  player's name; the survivor is the character they play.
- Profanity filter and unique names: never for self-hosted friend servers.

## Ready to build

- Foundations touched: save files (CharacterProfile), the handshake. Both solid.
- Decision records that apply: docs/adr/0003-trusted-client-co-op.md. Does this go against one? no
- Co-op:
  - Who decides: the server cleans the name in each hello; the owner cleans its own.
  - How a client triggers it: the existing hello `name` key (frozen key, no new message).
  - What other players see, and how it reaches them: the existing path, handshake
    `player_name()` to `Player.display_name` to PlayerStateSync state (squad cards,
    ready-up panel, revive prompt).
  - Works on a dedicated server with no local player: yes
- Data: no new ids or numbers in content. NAME_MAX = 16 is a fixed rule, a constant.
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no (`display_name` already saved; loading now cleans it)
  Renames or removes a saved id: no
- Events and UI: no new Events. No new screen.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: n.a. (menu only)
- Tests: tests/unit/test_player_name.gd (rule, save load, typing on the screen),
  tests/unit/test_handshake.gd (server cleans a messy hello name).
- Logging: none; a bad name is cleaned, not an early warning sign.
- Performance: two RegEx compiles per clean, only on join, load and typing. Nothing per frame.
- Lore link: see the header.
- Out of scope: see Scope.

## Design references

- docs/design/lore.md#gear-and-abilities, row "Your name"
- docs/DECISIONS.md "Provisional picks", line "Player names"
- docs/MULTIPLAYER.md, hello frozen keys (`name` already there)
- docs/adr/0003-trusted-client-co-op.md

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/progression/character_profile.gd | changed | `clean_name()`, `NAME_MAX`, `DEFAULT_NAME`; loading cleans the name |
| systems/net/handshake.gd | changed | server and owner clean names with `clean_name()` (was trim to 24) |
| systems/ui/name_field.gd | new | LineEdit that writes the cleaned name into the profile |
| systems/ui/character_screen.tscn / .gd | changed | Name label becomes the name box; screen keys ignored while typing |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: character_screen.gd by 1 line (341), so
the name logic lives in name_field.gd.

## Data

- No Resource types, no new save fields, no network messages.
- Save format change: none. Old saves load; a name that breaks the rule is cleaned on load.
- Content checks to add in `tests/content/`: none.

## Co-op behaviour

- Who owns the state: the server keeps each peer's accepted name.
- What clients send, what the server sends back: the hello `name` key, as before.
- What a client sees that the host sees too: every player's cleaned name.
- Late joiner: gets names through the existing player state snapshot.
- Dedicated server: nothing skipped; it only cleans names.

Protocol version: unchanged. The hello keeps its keys; only the server's trim rule changed.

## Performance

None per frame.

## Steps

### Step 1: Name box and one cleaning rule

- Build: everything in Systems touched, plus this plan, the roadmap row, the
  lore row and the DECISIONS line.
- Files: as listed above.
- Tests: tests/unit/test_player_name.gd, tests/unit/test_handshake.gd.
- Done when: a typed name is saved on Back and a co-op server shows the cleaned name.

## Acceptance

- [x] Typing a name on the Character screen saves it on Back (test_player_name).
- [x] Typing E or Escape in the name box does not equip or close (test_player_name).
- [x] The server cleans a long or marked-up hello name (test_handshake).

## Risks

- Names in scripts the menu font cannot draw: only Latin letters are allowed.

## Open decisions

- none
