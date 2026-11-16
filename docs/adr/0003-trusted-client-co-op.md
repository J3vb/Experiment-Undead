# 0003. Trusted-client co-op, server owns shared state

- **Status:** accepted
- **Date:** 2026-11-15
- **Decided by:** the person

## Context

Co-op is for friends on self-hosted servers, up to 8 players. Shooting must
feel instant at any ping, and the code must stay small.

## Decision

Each player's PC moves its own character and decides its own hits, then tells
the server. The server owns everything shared: zombies, waves, health,
downed/dead, points, XP, loot, doors and machines. Clients change shared state
only by asking the server, and the server runs the same code it runs in solo.
Godot high-level multiplayer (ENet, `@rpc`, `MultiplayerSpawner`,
`MultiplayerSynchronizer`), no netfox.

## Consequences

- Every feature says who decides (owner or server) and how a client asks.
- A client action on shared state = request RPC to the server, which checks
  sender, range and state before acting. Never apply it on the client.
- Effects that depend on a hit (leech, points per hit) run where the server
  applies the hit.
- Co-op features need a test that runs the action from a client, not only as
  host.
- Cheating is possible by design; a stricter server can come later because
  gameplay already reads `InputFrame`s.

## Links

`docs/MULTIPLAYER.md` (who owns what, build order), issues #138, #145.
