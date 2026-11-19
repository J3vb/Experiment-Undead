# Plan: Separate launcher program

Status: Review
Roadmap: F-82
Phase: P8 (steps 1-4 land before Release v0.1.0, F-11)
Size: L
Approved by:
Lore link: the launcher shows the game's name, its news and the Oriel/Halcyon/Cordon names from docs/design/lore.md (Factions); the tagline "A Fenlight survival experience" is a provisional row in "Story links for game content"

## Goal

Players install one small program, the Experiment Undead launcher, like
Steam or Battle.net. It installs the game, keeps it updated, shows news and
patch notes, hosts a server, and keeps itself updated. The game exe itself
goes straight to the main menu. Serves "Better together": friends are always
on the same version with no manual downloads.

This replaces the launcher built into the game (F-65 steps 5-6, PR #331).
The person changed direction on 2026-11-19: "with launcher I mean a separate
program that updates and installs the game, not a built-in launcher into the
.exe that just goes to the menu screen".

## Scope

In:

- A second, small Godot 4.7.2 project in `launcher/` that exports its own
  exe (step 1). It moves the tested `ReleaseFeed` and `VersionInstaller`
  code out of the game.
- The launcher updates itself from the same GitHub Release (step 2).
- The in-game launcher screen is deleted; "Restart to update" in the join
  error dialog starts the launcher instead (step 3).
- Host a server from the launcher, updated between matches (step 4, moves
  `ServerHost` and takes over F-65 step 9).
- The concept look: sidebar (Play, News, Patches, Settings, Support), hero
  banner, news list, big green Play, channel dropdown, install size and free
  space (step 5).
- A per-user Windows installer, `ExperimentUndead-Setup-<version>.exe`
  (step 6, the person's pick).

Not in (non-goals, and where each one goes instead):

- Mods page: no mod system exists. Added when one does (never before).
- Accounts, login, friends list, store: no accounts (ADR 0006).
- Delta patches: full zip download, as in F-65. Later, when builds pass 1 GB.
- Moving the game folder from the launcher: later, if someone asks.
- Playing an older version: later, if a crash ever needs it.
- macOS: no Mac build exists.
- Code signing: still blocked for EU individuals (`docs/RELEASING.md`).
- Server image, handshake, saves, channels: unchanged, stay in F-65 (steps
  1-3, 7-8).

## How it fits together

```
%LOCALAPPDATA%\Programs\Experiment Undead\   installer target (or any folder)
  ExperimentUndead-Launcher.exe              the launcher (pck embedded)
  game\versions\0.1.0-test.2\                full game, installed by the launcher
  game\versions\0.1.0-test.3\                newest; Play starts this one
```

| Piece | Rule |
|---|---|
| Launcher project | `launcher/project.godot`, its own name ("Experiment Undead Launcher"), so its own `user://` (`launcher.cfg`, downloads, logs). Godot skips a subfolder that holds a `project.godot`, so the game project never imports it (step 1 checks this first). Compatibility renderer, embedded pck, one exe. |
| Shared code | `ReleaseFeed`, `VersionInstaller`, `ServerHost` move into `launcher/` (the game no longer needs them). `Build.compare_versions()` is copied once into `launcher/core/version.gd` (second use, Keep it simple rule 2); a CI test runs the same version table against both copies. |
| Game install | `game/versions/<version>/` next to the launcher exe, as F-65: download zip, check SHA-256 against the asset digest, unzip through a temp folder, keep the 2 newest. Play starts the newest with `--from-launcher`. |
| Launcher version | Built from the same tag as the game, so it has the same version. |
| Launcher self-update | On start, if the newest release on its channel has a launcher zip newer than itself: download, check SHA-256, rename the running exe to `.old` (Windows allows renaming a running exe, not overwriting it), unzip the new one in its place, start it with `--updated` and quit. The new one deletes `.old`. Any failure keeps the old launcher running. |
| Release assets | Add `ExperimentUndead-Launcher-<version>-windows.zip` and `-linux.zip` (exe at the zip root) and, with step 6, `ExperimentUndead-Setup-<version>.exe`. Existing names unchanged. From v0.1.0 these names join the F-65 asset contract. |
| Game finds the launcher | Two folders up from `game/versions/<v>/`. Not found (unzipped by hand, dev build): no "Restart to update" button. |
| News | `launcher/news/news.json` + images on `main`, fetched from `raw.githubusercontent.com` (one call per start). Offline: the copy baked into the launcher at build time. Adding news = a docs-style PR, no release. |
| Patches | The release notes of every release on the channel, from the Releases call the launcher already makes. |

## Ready to build

- Foundations touched (docs/FOUNDATIONS.md): 9 tests and CI, 10 exported
  builds. Both solid. Step 1 adds a second Godot project to CI.
- Decision records: 0012 (built-in launcher, "do not add a second launcher
  program without a new record"), 0006, 0005. Goes against 0012 in that one
  point: new record [0018](../adr/0018-separate-launcher.md), proposed in
  this PR.
- Co-op: the launcher has no network game code. The hosted server is the
  game build with `--server`, unchanged.
- Data: no Resource types, no save change. New `launcher/news/news.json`.
- Events and UI: no new Events. The game loses the `launcher` screen
  (`content/screens/launcher.tres`) in step 3.
- Input, gameplay, randomness: not touched.
- Tests: new GUT suite in `launcher/tests/` (run in CI with the game's
  `addons/gut` copied in, not committed twice), `launcher_smoke_test.sh`
  end to end, Windows runner check, game tests updated for the removed screen.
- Logging: launcher logs `launcher.check_failed`, `launcher.installed`,
  `launcher.install_failed`, `launcher.self_updated`,
  `launcher.self_update_failed` to its own log file; `docs/LOGGING.md`.
- Performance: nothing in the game loop.

## Design references

- `docs/plans/client-server-updates.md` "How the launcher works", steps 4-6
  and 9: the install, channel and hosting rules this plan keeps.
- `docs/adr/0012-updates-and-release-channels.md`: amended by ADR 0018.
- `/mnt/project-files/launcher/launcher_concept.png` (copied to
  `docs/design/reference/launcher_concept.png` in step 5): the look target.
- `docs/design/look-rules.md`: Cold Containment colours for the launcher
  theme; the concept's acid green is Fenlight green.
- `docs/RELEASING.md`: tags, channels, asset names.
- `docs/KEEP_IT_SIMPLE.md` rule 8: `HTTPRequest`, `ZIPReader`,
  `FileAccess.get_sha256()`, `ConfigFile`, `OS.create_process`,
  `DirAccess.get_space_left()`.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `launcher/` | new | Godot project: `project.godot`, `export_presets.cfg`, `main.tscn`/`launcher.gd`, `core/version.gd`, `install/release_feed.gd`, `install/version_installer.gd`, `install/self_updater.gd` (step 2), `host/server_host.gd` (step 4), `ui/` pages (step 5), `news/`, `tests/` |
| `systems/launcher/` | removed | moved to `launcher/` (steps 1, 3, 4) |
| `content/screens/launcher.tres` | removed | step 3 |
| `systems/ui/main_menu.gd` | changed | no launcher hand-over, no root refresh (step 3); `--server` stays |
| `systems/ui/net_error_dialog.gd` | changed | "Restart to update" starts the launcher (step 3) |
| `.github/workflows/export.yml`, `release.yml`, `ci.yml` | changed | export and test the launcher, attach its zips (step 1-2), installer (step 6) |
| `tools/ci/launcher_smoke_test.sh` | new | end-to-end install and self-update with a fake feed |
| `tools/installer/experiment-undead.iss` | new | Inno Setup script (step 6) |
| `docs/` | changed | RELEASING, LOGGING, DECISIONS, ADR 0018, F-65 plan note, lore row |

Autoloads, managers or base classes added: none. The launcher project has
no autoloads.

Files over 300 lines this plan grows: `systems/launcher/launcher_screen.gd`
(320) is deleted, not grown; the launcher's own UI is split into one script
per page from the start.

## Data

- `launcher/news/news.json`: `{"items": [{"title", "summary", "date",
  "image", "url"}]}`; `image` is a path under `launcher/news/`. The first
  item is the hero banner. Provisional first items: the v0.1.0-test.2 notes
  and the Halcyon Labs map.
- Launcher settings: launcher `user://launcher.cfg`, `[launcher] channel`,
  `[server] port`, `max_players` (same keys as today, new file location).
  Not a save.
- Save format change: none.
- Content checks: none (`launcher/tests/test_news.gd` checks news.json).

## Co-op behaviour

- Who owns the state: the launcher owns nothing shared. The hosted server is
  the game build run as a dedicated server (F-65 step 6), unchanged.
- What clients send: nothing new.
- What players see: nothing changes in a match.
- Late joiner: not affected.
- Dedicated server: the launcher never runs on a server. The Docker image
  stays as in F-65.

## Performance

No cost in the game. The launcher makes two calls per start (Releases API,
news.json), far under GitHub's 60 an hour unauthenticated limit. It runs no
3D; Compatibility renderer, low CPU while idle (`low_processor_mode`).

## Steps

### Step 1: The launcher project installs and starts the game

- Build: `launcher/` Godot project with one plain screen: channel dropdown,
  status, progress bar, Play. Move `ReleaseFeed` and `VersionInstaller` into
  it (installer target `game/versions/` next to the launcher exe; drop the
  root-copy refresh, which only made sense for the built-in launcher). Copy
  `compare_versions`/`is_release_version` into `launcher/core/version.gd`.
  The version is stamped by `tools/ci/stamp_version.sh` like the game.
  Export presets Windows and Linux (embedded pck). `export.yml` exports the
  launcher next to the game; `ci.yml` runs the launcher GUT suite. First
  check: the game project's import and boot ignore `launcher/`; if not, add
  `launcher/.gdignore` handling and write down why. The game's in-game
  launcher still works in this step (game files untouched). ADR 0018 Status
  accepted.
- Files: `launcher/**`, `.github/workflows/export.yml`, `ci.yml`,
  `tools/ci/test_workflows.py`, `tools/ci/test_version_tables.py` (new),
  `docs/LOGGING.md`, `docs/adr/0018-separate-launcher.md`.
- Tests: `launcher/tests/test_release_feed.gd` and
  `test_version_installer.gd` (moved from `tests/unit/`, pointed at
  `game/versions/`); `test_version_tables.py` runs one version table through
  both `compare_versions` copies (fails if they differ). Boot test of the
  game shows no launcher scripts loaded.
- Done when: the exported launcher, run on a clean folder, installs the
  newest release on its channel and Play starts it.

### Step 2: The launcher updates itself; releases carry it

- Build: `SelfUpdater` (new, `Node`): newest launcher zip on the channel,
  rename-and-replace as in "How it fits together", `--updated` cleanup.
  `release.yml` zips and attaches the launcher builds. Test hook
  `--releases-api=<url>` (as today). `tools/ci/launcher_smoke_test.sh`
  (Linux, in Build): a fake feed serves a "newer" game zip and a "newer"
  launcher zip; the launcher must install the game, replace itself, and the
  new copy must delete `.old`. The same check runs on `windows-latest` on
  release tags and on PRs touching `launcher/` (file locking).
- Files: `launcher/install/self_updater.gd`, `launcher/launcher.gd`,
  `launcher/tests/test_self_updater.gd`, `.github/workflows/release.yml`,
  `export.yml`, `tools/ci/launcher_smoke_test.sh`,
  `tools/ci/test_workflows.py`, `docs/RELEASING.md`.
- Tests: GUT: a newer launcher zip replaces the exe through `.old`; a bad
  digest or a half download leaves the running exe untouched; an equal or
  older version does nothing. `test_workflows.py`: release attaches the
  launcher zips. Smoke test as above.
- Done when: a launcher one release behind updates itself and the game on
  start, on Windows and Linux.

### Step 3: Remove the launcher from the game

- Build: delete `systems/launcher/launcher_screen.gd`, `.tscn`,
  `content/screens/launcher.tres`, the hand-over and root refresh in
  `MainMenu._hand_over()` (keeps `--server`), the root-refresh code in
  `VersionInstaller` and its tests. `NetErrorDialog.can_update()` is true
  only when the launcher exe exists two folders up; the button starts it and
  quits. `tools/ci/smoke_test.sh` drops `--launcher` checks and keeps
  `--from-launcher` (still harmless). Players who unzipped v0.1.0-test.1 keep
  their old built-in launcher, which still installs new versions; the
  RELEASING notes tell testers to install the new launcher.
- Files: `systems/launcher/*` (except `server_host.gd` until step 4),
  `content/screens/launcher.tres`, `systems/ui/main_menu.gd`,
  `systems/ui/net_error_dialog.gd`, `tools/ci/smoke_test.sh`,
  `tests/unit/test_launcher_screen.gd` (removed),
  `tests/unit/test_net_error_dialog.gd` (or the existing dialog test),
  `docs/RELEASING.md`, `docs/plans/client-server-updates.md` (steps 5-6 and
  9 point here).
- Tests: the release-build exe in a root folder goes straight to the main
  menu (fails today: launcher opens); "Restart to update" shows only with a
  launcher exe two folders up.
- Done when: the game exe never shows a launcher screen.

### Step 4: Host a server from the launcher

- Build: move `ServerHost` into `launcher/host/`. A **Host a server** panel
  (port, max players 1-8, Start, Stop, running version, Open logs, the
  firewall/port-forward line). It starts `game/versions/<newest>/<exe>
  --headless -- --server ...` as today. Closing the launcher while a server
  runs asks, then stops it through the stop file. Plus F-65 step 9: every 15
  minutes check the channel, install a newer game while the server runs,
  write the drain file, restart on exit code 3 only. "Open logs" opens the
  game's user folder logs (the server is the game build).
- Files: `launcher/host/server_host.gd`, `launcher/ui/host_page.gd`/`.tscn`,
  `launcher/tests/test_server_host.gd` (moved + new cases),
  `systems/launcher/` (now empty, removed), `tools/ci/launcher_smoke_test.sh`,
  `docs/RELEASING.md`.
- Tests: argument building and clamping (moved); a newer release installs
  and writes the drain file without stopping the server; exit 3 restarts on
  the new version, exit 0 or a crash does not; the running version is never
  pruned. Smoke: the launcher hosts the exported game, a client joins, stop
  file stops it.
- Done when: a player hosts, stops and auto-updates a server from the
  launcher with no second download.

### Step 5: The concept look

- Build: the concept layout at 1280x720 minimum, resizable: left sidebar
  (Play, News, Patches, Settings, Support; News dot when an item is newer
  than the last one seen), logo and tagline, hero banner from the first news
  item with Read more, Latest news list (3 items, View all), bottom bar with
  the big Fenlight-green **Play** (Update / Installing 42% / Play), Game
  version dropdown (Stable vX / Test vX) with "Up to date", Installation
  (installed size, free space with `DirAccess.get_space_left()`, "..." menu:
  open game folder, check files, uninstall game). Patches page: release notes
  list. Settings: channel, close launcher on Play, game folder (shown). Support:
  logs folder, GitHub issues link. Background: a render of Halcyon Labs at
  night (provisional, made with the look-check skill). Theme colours from
  look-rules. Mods is left out (no mod system).
- Files: `launcher/ui/*.gd`/`.tscn` (one per page), `launcher/ui/theme.tres`,
  `launcher/news/news.json` + images, `launcher/assets/`,
  `launcher/tests/test_news.gd`, `test_pages.gd`,
  `docs/design/reference/launcher_concept.png`, `docs/design/lore.md` (row).
- Tests: news.json parses, every image exists, a broken feed falls back to
  the baked copy; the Play button text follows installer state; the version
  dropdown lists both channels and saves the pick. Look: headless render
  of the launcher next to the concept (look-check), sent to the person.
- Done when: the person signs off the launcher look against the concept.

### Step 6: Windows installer

- Build: `tools/installer/experiment-undead.iss` (Inno Setup,
  `PrivilegesRequired=lowest`, installs to
  `{localappdata}\Programs\Experiment Undead`, Start menu + optional desktop
  shortcut, uninstall entry that also offers to remove `game\`).
  `release.yml` builds it on `windows-latest` and attaches
  `ExperimentUndead-Setup-<version>.exe`. The launcher never needs it to
  update (it updates itself, step 2).
- Files: `tools/installer/experiment-undead.iss`,
  `.github/workflows/release.yml`, `tools/ci/test_workflows.py`,
  `docs/RELEASING.md`, `docs/CREDITS.md` (Inno Setup, tool only).
- Tests: the release workflow installs the setup silently (`/VERYSILENT`) on
  the Windows runner and checks the launcher exe and shortcut exist, then
  uninstalls silently and checks they are gone.
- Done when: a release has a setup exe that installs and uninstalls cleanly.

## Acceptance

- [ ] A player with only the launcher (or setup exe) gets the newest game on
  their channel and plays it (step 1 + smoke test).
- [ ] A launcher one release behind updates itself and the game, on Windows
  (step 2 Windows check, and a play-test by the person on v0.1.0-test.3).
- [ ] The game exe never shows a launcher screen (step 3 test).
- [ ] A player hosts and stops a server from the launcher, and it updates
  between matches (step 4 tests).
- [ ] The launcher matches the concept (step 5, the person's sign-off).
- [ ] Setup installs and uninstalls cleanly (step 6 test, if picked).

## Risks

- Godot imports `launcher/` into the game project: step 1 checks it first.
  Fallback: move the launcher project to `tools/launcher/` with
  `.gdignore` in the parent only.
- Renaming a running exe fails on some Windows setups (antivirus locks):
  self-update fails safe, keeps the old launcher, logs
  `launcher.self_update_failed`, and shows the release page link.
- Unsigned exe that downloads exes looks like malware to some scanners:
  same as F-65; the setup exe gets one SmartScreen warning.
- Two copies of the version compare drift: the shared table test fails CI.
- Launcher exe size (~70 MB, a full Godot runtime): fine for a game that is
  hundreds of MB; a stripped export template can shrink it later.

## Open decisions

- [ ] What is the launcher built with? Recommended: a small Godot app
  (card sent 2026-11-19).
- [x] How do players first get the launcher: Windows installer (the person,
  2026-11-19, decision card). Step 6 stays.
