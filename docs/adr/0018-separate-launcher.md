# 0018. A separate launcher program

- **Status:** proposed
- **Date:** 2026-11-19
- **Decided by:** the person (a separate program that installs and updates
  the game, 2026-11-19); the toolkit and install method by the person on
  decision cards, see [plans/separate-launcher.md](../plans/separate-launcher.md)

## Context

ADR 0012 put the launcher inside the game exe. The person wants a separate
program, like Steam or Battle.net, that installs and updates the game and is
not part of the game exe.

## Decision

- The launcher is its own small Godot project in `launcher/` with its own
  exe. It installs the game into `game/versions/<version>/` next to itself,
  from GitHub Releases, with the SHA-256 check and channels from ADR 0012.
- It updates itself from the same release: rename the running exe to
  `.old`, put the new one in place, restart.
- It hosts a dedicated server by running the installed game with `--server`.
- The game exe has no launcher screen. It only starts the launcher for
  "Restart to update".
- This replaces the "built into the game exe" line of ADR 0012. The rest of
  0012 stands.

## Consequences

- Release assets add the launcher zips (and a setup exe if picked); they join
  the asset contract from v0.1.0.
- The launcher has no autoloads and no game code; launcher code lives only
  in `launcher/`. Version compare is copied once, guarded by a CI test.
- CI exports and tests two Godot projects.
- Do not add launcher screens back into the game without a new record.

## Links

`docs/plans/separate-launcher.md`, `docs/plans/client-server-updates.md`,
ADR 0012, PR #331.
