# 0018. A separate launcher program

- **Status:** proposed
- **Date:** 2026-11-19
- **Decided by:** the person (a separate program that installs and updates
  the game, 2026-11-19); the toolkit (Tauri) and the Windows installer by the person on
  decision cards, see [plans/separate-launcher.md](../plans/separate-launcher.md)

## Context

ADR 0012 put the launcher inside the game exe. The person wants a separate
program, like Steam or Battle.net, that installs and updates the game and is
not part of the game exe.

## Decision

- The launcher is a Tauri 2 app in `launcher/` (Rust core, plain
  HTML/CSS/JS window, about 10 MB), installed per user by its own NSIS setup
  exe. It installs the game into `game/versions/<version>/` next to itself,
  from GitHub Releases, with the SHA-256 check and channels from ADR 0012.
- It updates itself with Tauri's updater plugin from the same release,
  checking a signature made with a key kept as a GitHub secret.
- It hosts a dedicated server by running the installed game with `--server`.
- The game exe has no launcher screen. It only starts the launcher for
  "Restart to update".
- This replaces the "built into the game exe" line of ADR 0012. The rest of
  0012 stands.

## Consequences

- Release assets add the setup exe, its `.sig` and `latest.json`; they join
  the asset contract from v0.1.0.
- Rust and JS live only in `launcher/`, with their own fmt, clippy and test
  job. No JS framework or bundler without a new record.
- Version compare exists in GDScript and Rust; one shared fixture table
  tests both.
- Do not add launcher screens back into the game without a new record.

## Links

`docs/plans/separate-launcher.md`, `docs/plans/client-server-updates.md`,
ADR 0012, PR #331.
