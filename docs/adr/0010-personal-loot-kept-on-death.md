# 0010. Personal loot, kept on death, no trading in v1

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** design doc, the person

## Context

"Every run makes you stronger" is a pillar. Shared loot in co-op causes
fights and needs trading code.

## Decision

The server rolls loot per player and sends each drop only to its owner. What
is in the Pack is kept on death and banked into the local stash at every run
exit. No trading in v1. Transmog is out; dyes only.

## Consequences

- Loot code never replicates one player's drops to others.
- Loot rolls use the session RNG on the server.
- New item effects must work for clients (see 0003).

## Links

`docs/design/affixes.md`, `docs/design/gear-visuals.md`, `docs/DECISIONS.md` (personal zombie loot).
