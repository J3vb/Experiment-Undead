# 0006. Self-hosted dedicated servers, no accounts or anti-cheat

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** the person

## Context

Players host their own servers (like Valheim), max 8 players. There is no
budget or need for a backend at the start.

## Decision

The dedicated server is a headless export of this same project. Port 7777 UDP
for now. Docker image and Unraid template for hosting. No accounts, no master
server, no anti-cheat for now.

## Consequences

- The exported server must boot and accept a join in CI (Build workflow
  smoke test). A red Build on main blocks server work.
- No code that assumes a central service or account id.
- Server-only code must not need a window, GPU or local player.

## Links

`docs/MULTIPLAYER.md`, `docs/RELEASING.md`, `deploy/`.
