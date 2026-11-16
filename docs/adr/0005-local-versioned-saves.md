# 0005. Characters saved on the player's PC as versioned JSON

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** architecture doc, the person (no accounts)

## Context

There are no accounts or backend. Players carry their character to any
server, and the save format will change many times during development.

## Decision

Characters and stash are JSON files in `user://characters/`, written through
`SaveFile`: every file has `save_version`, writes go to a temp file first,
old versions are backed up and upgraded one step at a time, newer versions are
refused. The server rolls XP and loot and sends grants; the client saves them.
Dedicated servers never save characters.

## Consequences

- A format change bumps `CURRENT_VERSION`, adds one migration step and a test
  that loads an old sample.
- New fields need a default so old saves load.
- Saved content ids are permanent (see 0002).
- Items are stored as plain dictionaries, not Resources.

## Links

`systems/save/save_file.gd`, `docs/FOUNDATIONS.md` foundation 3.
