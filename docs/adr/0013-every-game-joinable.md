# 0013. Every game is joinable; alone means solo

- **Status:** proposed
- **Date:** 2026-11-17
- **Decided by:** the person asked for it (F-66); details are agent picks until the plan is approved

## Context

ADR 0004 made solo a server with no open port, so friends could only join a
game started with Host and play. The person wants every game to be joinable by
address and port, with no separate host step.

## Decision

Every player's own world (Enter world, into their Lantern Post) opens its
port (default 7777) as a listen server, unless the player turns "Let friends
join my world" off or the port is taken;
then it runs offline as before. UPnP opens the router port where it can.
Solo or co-op behaviour follows one rule, `Net.is_coop()`: co-op when this
peer is a client or when anyone else is connected, solo otherwise. It is read
when a rule is used, so a game turns co-op when a friend joins and solo again
when the last one leaves.

This replaces ADR 0004's "no open port" line. The rest of 0004 stands: one
code path, gameplay checks `Net.is_authority()`, the match is always
`/root/GameSession`.

## Consequences

- Never test "offline peer" to mean solo. Use `Net.is_coop()` for behaviour,
  and "peers exist" for whether an RPC has anyone to reach.
- Never cache solo or co-op at match start.
- No central service: players behind carrier-grade NAT host from the launcher
  or a rented box (ADR 0006).
- No password until P8; the setting is the off switch.
- Nothing joins a player straight into someone else's game: joining goes
  through the server browser (saved servers, add by address, LAN discovery).
  No master server (the person, 2026-11-17).

## Links

`docs/plans/join-any-game.md`, `docs/MULTIPLAYER.md`, ADR 0004, ADR 0006.
