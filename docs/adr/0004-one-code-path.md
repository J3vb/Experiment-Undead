# 0004. One code path: solo is a server with one player

- **Status:** proposed (agent pick, easy to change)
- **Date:** 2026-11-15
- **Decided by:** agent (provisional)

## Context

Solo, host-and-play and dedicated server could each grow their own code, and
bugs would hide in whichever path is tested least.

## Decision

Solo runs as a server with one player and no open port (Godot's offline peer
counts as the server). *ADR 0013 (proposed) would replace "no open port": every
game opens its port, and solo means nobody else is connected.* Host-and-play is the same scene with an open port. A
dedicated server runs the same `GameSession` with no local player. The match
is always `/root/GameSession`.

## Consequences

- Gameplay checks `Net.is_authority()`, never "am I in solo".
- Features must work with no local player (dedicated server): no HUD, camera
  or local-player lookups in server code.
- Use the `players` group, never a global player.

## Links

`docs/MULTIPLAYER.md` provisional picks.
