# 0002. Content is Resource data, id = file name

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** architecture doc

## Context

The game must grow by adding content (guns, zombies, serums, gear) without
touching code, and agents must find every piece of content in one place.

## Decision

Content lives in `content/<type>/*.tres` as custom Resources (`WeaponData`,
`EnemyData`, `SerumData`, ...). The file name is the id. The `Content`
autoload finds them by id. Live state (ammo, rolled affixes) lives in separate
objects such as `WeaponInstance` and `ItemInstance`; loaded `.tres` files are
never changed at runtime.

## Consequences

- A new gun or zombie is a new `.tres`. If it needs new behaviour, add a
  field to its data type and the smallest script that field points to.
- Code must not compare against a specific id (`if id == &"siphon"`). Put the
  difference in a data field instead.
- Ids that can be saved (guns, gear bases, affixes) are permanent. Renaming
  one needs a save migration step (see 0005).
- Every new content type gets content tests.

## Links

`docs/HOW_TO_ADD.md`, `docs/FOUNDATIONS.md` foundation 2.
