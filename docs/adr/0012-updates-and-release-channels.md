# 0012. Exact versions, store-updated clients, self-updating servers

- **Status:** proposed
- **Date:** 2026-11-17
- **Decided by:** agent (provisional), waiting on the person's picks in
  [plans/client-server-updates.md](../plans/client-server-updates.md)

## Context

Players keep characters and loot across versions, servers are self-hosted
(ADR 0006), and a new version must reach both sides without breaking saves
or interrupting matches. Nothing has been released yet, so the handshake and
save layout of the first release become a contract every later version must
read.

## Decision

- Client and server must run exactly the same version, protocol and content.
- The hello and refusal are JSON objects whose keys `t`, `protocol`,
  `version`, `reason`, `text` and `server_version` never change. A mismatch
  always ends in a refusal that names the older side.
- Two channels: stable (`vX.Y.Z`) and test (`vX.Y.Z-test.N`). Test, dev and
  editor builds keep their own characters folder, copied once from stable.
  This amends ADR 0005's folder rule for non-stable builds only.
- Clients update through a store app (itch.io first, Steam later). The game
  has no updater of its own.
- The server image is a runner that downloads the release for its channel
  (or a pinned `EU_VERSION`) from GitHub Releases, checks its SHA-256 and
  restarts into a new release only when no match is running.
- Rollback means roll forward: a new patch release. The save version never
  goes down.

## Consequences

- Handshake changes add keys; they never rename or remove the frozen ones.
  `RefusalReason` values are append only.
- Saved content ids and `SaveFile.CURRENT_VERSION` can never go backwards
  (CI checked).
- Save format bumps ship on the test channel before stable.
- Do not add a launcher, self-updater, installer or our own patcher without a
  new record.
- Servers depend on GitHub Releases only to download updates; with GitHub
  down they keep running their cached version.

## Links

`docs/plans/client-server-updates.md`, `docs/RELEASING.md`,
`docs/MULTIPLAYER.md`, ADR 0005, ADR 0006.
