# Plan: Client and server updates

Status: Review
Roadmap: F-65
Phase: P8 (steps 1-5 land before Release v0.1.0, F-11)
Size: L
Approved by:

## Goal

When a new version ships, players and servers move to it without anyone
losing a character, an item or a match. Players' games update themselves,
servers update themselves between matches, and a player whose game does not
match the server is told which side is older and what to do, never left
staring at a timeout. Serves "Better together": friends can always get into
each other's servers.

## Scope

In:

- A handshake that every future version can read, so a mismatch always ends
  in a clear refusal (step 1).
- Saves that survive updates, test builds and going back to stable (step 2).
- CI guards: saved content ids and the save version can never go backwards,
  and an old released client must get a clear refusal from a new server
  (step 3).
- A launcher built into the game: it checks GitHub Releases, downloads a new
  version into its own folder next to the old one, and starts it, with patch
  notes and a stable/test switch (steps 4-5).
- A small server image that downloads the release you ask for and updates
  itself between matches, never during one (steps 6-7).
- Two release channels: stable and test.

Not in (non-goals, and where each one goes instead):

- A separate launcher program or project: the game exe is the launcher (see
  "How the launcher works"). Never, unless the built-in one hits a wall.
- A store app (itch.io, Steam): not now, the person chose our own launcher.
  A store can be added later on top; the launcher then simply finds nothing
  newer.
- A Windows installer: players unzip the game anywhere they own. If one is
  ever made, it installs per user (`%LOCALAPPDATA%\Programs`), never to
  Program Files, which the launcher could not write to.
- A Windows dedicated server package: Windows hosts use Host and play, which
  the launcher updates with the game. The dedicated server scene only loads
  in the `dedicated_server` export (`run/main_scene.dedicated_server`), so a
  Windows server would need its own export preset. F-44, only if someone asks.
- Delta patches: the launcher downloads the full platform zip (about 65 MB
  today). When builds grow past about 1 GB, download only the `.pck` when the
  engine binary did not change. Later, when it hurts.
- Playing an older version from the launcher: the previous version folder is
  kept only as an offline fallback. Later, if a crash ever needs it.
- A server browser, LAN discovery, server-side saves: their own features.
  Any future server save uses `SaveFile` with its own version.
- Code signing: still blocked for EU individuals (`docs/RELEASING.md`).
  Only the first zip, downloaded in a browser, gets the SmartScreen warning;
  files the launcher downloads itself do not carry the browser's "downloaded
  from the internet" mark.
- The rest of F-44 (server.cfg, download page): stays in F-44, which reuses
  steps 6-7.

## How it fits together

| Piece | Rule |
|---|---|
| Version | The git tag is the version (exists). Client and server must run exactly the same version, protocol and content (exists, kept: simplest, and no hidden desyncs). |
| Channels | **stable** = tags like `v0.2.0`. **test** = tags like `v0.2.0-test.1` (GitHub pre-releases). **dev** = main builds as Actions artifacts (exists). |
| Client updates | The launcher built into the game checks GitHub Releases for its channel, downloads the platform zip into `versions/<version>/`, checks its SHA-256, and starts it. Old files are never overwritten while running. |
| Server updates | The image is a runner. On start it downloads the newest release on its channel (or the version you pin) from GitHub Releases, checks its SHA-256, and runs it. Every 15 minutes it checks again; a new version makes the server finish the current match, tell players, and restart into the new version. |
| Saves | Unchanged format rules (ADR 0005). Test, dev and editor builds keep their own characters folder, copied once from stable, so a test build can never upgrade a stable save that stable then refuses. |
| Rollback | Roll forward: fix or revert, then tag the next patch. Never lower `SaveFile.CURRENT_VERSION` (CI checked). Emergency server pin: `EU_VERSION=0.2.0`. |

**How the launcher works.** The person chose our own updater over a store
app (2026-11-17) and asked for a launcher. A running Windows program cannot
overwrite its own `.exe` or `.pck`, so the launcher never replaces running
files: each version lives in its own folder and the launcher starts the one
it wants.

```
Experiment Undead/              the folder the player unzipped
  ExperimentUndead.exe + .pck   the "root" copy: starts in launcher mode
  versions/0.1.1/               full game, downloaded by the launcher
  versions/0.1.2/               newest; the launcher starts this one
```

- The launcher is the game itself, not a second program: when the exe runs
  from the root folder (not from `versions/`) in an exported stable or test
  build, it opens the launcher screen before the main menu. One build, one
  code base, GUT tests like everything else.
- It asks GitHub for the newest release on its channel (stable: newest
  non-pre-release; test: newest of all), shows its notes, downloads the
  platform zip, checks the SHA-256 against the asset digest, unzips into
  `versions/<version>/` through a temp folder, then starts that exe with
  `--from-launcher` and quits.
- If the root copy is the newest, it just continues to the main menu (no
  double start after a fresh unzip). With no network, it starts the newest
  installed version.
- A newer version started from `versions/` refreshes the root copy with its
  own exe and pck once the root process has exited (it retries for a few
  seconds, then tries again next start), so launcher fixes reach every
  player and the next start is a single start again. It keeps the 2 newest
  version folders.
- When a join is refused because the player's game is older, the dialog
  offers "Restart to update", which starts the root copy.

**Why the server image downloads the game instead of baking it in.** A
container cannot replace its own image without access to the Docker socket.
Watchtower, the usual tool for that, was archived in December 2025, and
Unraid's auto-update plugin restarts containers on a timer, mid-match. A
runner that downloads the release itself works the same on Unraid, plain
Docker and any Linux box, needs no host scripts, and can wait for the match
to end. This is how most self-hosted game server images update.

## Ready to build

- Foundations touched (numbers from docs/FOUNDATIONS.md): 1 co-op authority
  (handshake, drain), 3 save format, 9 tests and CI, 10 exported builds and
  dedicated server.
  Any of them shaky or missing? 1 is shaky only for the request-RPC pattern,
  which this plan does not use (the handshake runs before any RPC). Others solid.
- Decision records that apply (docs/adr/): 0003, 0005, 0006, 0009. Goes
  against one? Amends 0005 in one point: non-stable builds keep characters in
  `user://characters-test/` instead of `user://characters/`. New record
  [0012](../adr/0012-updates-and-release-channels.md) writes that down with
  the rest of the update model.
- Co-op:
  - Who decides: the server decides who joins (handshake) and when it
    restarts (drain). Each client owns its own saves.
  - How a client triggers it: it sends the hello; nothing else is requested.
  - What other players see: a refused player sees a dialog; players on a
    draining server get a notice before the server restarts.
  - Works on a dedicated server with no local player: yes, drain is
    dedicated-only.
- Data: no new Resource types or ids. New file `tools/ci/saved_ids.txt`.
  Code compares against a specific id anywhere: no.
- Save: format unchanged, `CURRENT_VERSION` unchanged. Non-stable builds use
  another folder (step 2). Renames or removes a saved id: no, and step 3
  makes CI refuse it.
- Events and UI: no new Events. Messages use the existing themed join error
  dialog. New screen: `launcher`, through the UI router (step 5).
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (nothing here touches gameplay).
- Tests: `test_handshake.gd`, `test_build.gd`, `test_net_errors.gd`,
  `test_character_profile.gd`, `test_save_file.gd`, new
  `test_release_feed.gd`, `test_version_installer.gd`,
  `test_launcher_screen.gd` and `test_dedicated_server_drain.gd`, Python
  tests in `tools/ci/`, an end-to-end launcher update of the exported client
  (Linux, plus Windows on release tags), and a shell test of the server image
  with a fake release server. The old-client check runs a real released
  client against the new server.
- Logging: `net.join_refused` gains `older`; new `save.profile_newer`,
  `launcher.check_failed`, `launcher.installed`, `launcher.install_failed`,
  `launcher.root_refreshed`, `server.drain_started`,
  `server.update_restart`; the runner prints its update checks to the
  Docker log.
- Performance: nothing per frame. The launcher runs before the game, the
  drain check reuses the existing 0.5 s stop-file timer.
- Out of scope: see Scope.

## Design references

- `docs/adr/0005-local-versioned-saves.md`: saves on the player's PC,
  migrations, newer saves refused, saved ids permanent.
- `docs/adr/0006-self-hosted-servers.md`: Docker image and Unraid template,
  no accounts. This plan keeps both and adds no central game service; GitHub
  Releases is only the download source, and a server keeps running its cached
  version when GitHub is down.
- `docs/adr/0003-trusted-client-co-op.md`: the server decides shared state.
- `docs/design/affixes.md` (Save format): items store ids and roll fractions,
  so a balance patch updates old items with no migration.
- `docs/RELEASING.md`: tags, version stamping, `PROTOCOL_VERSION`,
  `CURRENT_VERSION`, current image tags.
- `docs/MULTIPLAYER.md` (step 5, run end and saves): hello checks protocol,
  version and content.
- `docs/FOUNDATIONS.md` foundation 3 ("Watch out": saved ids).
- `docs/KEEP_IT_SIMPLE.md` rule 8: Godot built-ins first: `HTTPRequest`,
  `ZIPReader`, `FileAccess.get_sha256()`, `ConfigFile`, `OS.create_process`.
- `docs/design/look-rules.md` and `docs/design/ui-hud.md`: the launcher
  screen uses the existing panel style; no mockup exists, so its look is
  provisional until the person sees it.
- No numbers from the balance sheet are needed. The 15-minute check and
  2 cached versions are fixed constants (rule 10), not settings.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `systems/net/handshake.gd` | changed | hello and reply become objects with named keys; version checked first (step 1); `SERVER_UPDATING` refusal while draining in the hub (step 7) |
| `core/build.gd` | changed | `compare_versions()`, `is_stable()`, protocol bumps |
| `core/net.gd` | changed | `report_refusal()` survives reason codes it does not know (step 1); `RefusalReason.SERVER_UPDATING` appended and the host-ended notice carries a reason (step 7). The file is at 326 of 350 lines: keep both changes small |
| `systems/ui/net_error_dialog.gd` | changed | wrong-version text names the older side; unknown reasons show the server's text (step 1); "server updating" text (step 7) |
| `systems/save/save_file.gd` | changed | `saved_version()` tells "newer" from "broken" (step 2) |
| `systems/progression/character_profile.gd` | changed | `directory()` replaces `DIRECTORY`, picks the stable or test folder and copies stable once (step 2) |
| `systems/ui/main_menu.gd` | changed | "saved by a newer version" message before the character screen opens (step 2; `character_screen.gd` is at 340 of 350 lines, so not there) |
| `systems/loot/item_roller.gd`, `systems/ui/pack_overlay.gd` | changed | an unknown affix or rarity id no longer crashes (step 2) |
| `systems/launcher/` | new | `ReleaseFeed`, `VersionInstaller` (step 4), launcher screen (step 5) |
| `content/screens/launcher.tres` | new | the launcher screen for the UI router (step 5) |
| `systems/net/dedicated_server.gd` | changed | drain mode and exit code 3; owns `draining` and hands it to each new session's `Handshake` in `_swap_session` (step 7) |
| `deploy/server/` | changed | runner image and entrypoint (steps 6-7) |
| `deploy/unraid/experiment-undead-server.xml` | changed | channel, pin and auto-update fields (step 6) |
| `.github/workflows/` | changed | launcher end-to-end test, Windows launcher check (step 5); runner image build and test, no per-version images (step 6) |
| `tools/ci/` | changed | saved-id and save-version guard, old-client check, runner test |
| `docs/` | changed | RELEASING, MULTIPLAYER, LOGGING, DECISIONS, ADR 0012 |

Autoloads, managers or base classes added: none.

## Data

- Handshake (step 1, `PROTOCOL_VERSION` bump). Hello:
  `{"t": "hello", "protocol": int, "version": String, "content": String,
  "fingerprint": String, "name": String, "level": int}`. Replies:
  `{"t": "accepted", "place": String}` and
  `{"t": "refused", "reason": int, "server_version": String,
  "server_protocol": int, "text": String}`; the client's acknowledgement of a
  refusal is `{"t": "refused_ack"}`. The keys `t`, `protocol`, `version`,
  `reason`, `text`, `server_version` and the `t` values `hello`, `accepted`,
  `refused`, `refused_ack` are frozen forever: later versions add keys, never
  rename or remove these. `RefusalReason` values are on the wire: append only.
- Host-ended notice (step 7, protocol bump): gains `reason: StringName`
  (`&"stopped"` or `&"updating"`) and the new version string.
- Save format change: none. Non-stable builds read and write
  `user://characters-test/` instead of `user://characters/`.
- `tools/ci/saved_ids.txt` (step 3): every id that can end up in a save:
  `content/weapons/`, `content/loot/gear/`, `content/loot/affixes/`,
  `content/loot/rarities/`, `content/skills/`, and level folder names
  (`best_runs` keys written by `GameSession`). Grows only.
- Server environment (step 6): `EU_CHANNEL` (`stable` or `test`, default
  `stable`), `EU_VERSION` (empty = newest on the channel; set = pin),
  `EU_AUTO_UPDATE` (default `true`), `EU_DRAIN_FILE` (set by the
  image, like `EU_STOP_FILE`). Test hooks, not shown in the Unraid template:
  `EU_RELEASES_API` (default the repo's GitHub Releases API; the runner test
  points it at a fake server) and `EU_UPDATE_CHECK_SECONDS` (default 900).
- A release only counts for the runner when it has a `*-server.zip` asset
  with a SHA-256 digest. A release made in the web UI has no zips for about
  10 minutes, so it is ignored until they arrive.
- Release assets: unchanged names (`ExperimentUndead-<version>-windows.zip`,
  `-linux.zip`, `-server.zip`), each with the exe and pck at the zip's root.
  From v0.1.0 on, these names, that layout, the GitHub Releases API and the
  asset `digest` field are a contract: the launcher in every released version
  depends on them. Change them only with a new ADR and a release that still
  publishes the old names.
- Launcher settings: `user://launcher.cfg`, `[launcher] channel = "stable"`
  (or `"test"`). Not a save; no version needed. Downloads go to
  `user://launcher/` and are deleted after install.
- Content checks to add in `tests/content/`: none (step 3's guard is a CI
  script).

## Co-op behaviour

- Who owns the state (server / owning client / each client): the server
  decides admission and restarts; each client owns its saves.
- What clients send, what the server sends back: the hello; the server
  answers accepted or refused (with its version and a text for reasons the
  client does not know yet). While draining, the server sends each client an
  "updating" notice before it closes.
- What a client sees that the host sees too: nothing shared changes. A
  refused player sees the reason; the server log shows the same refusal.
- Late joiner: a player who drops out of a match can still rejoin it during
  drain (mid-match joins land in the running match, `docs/MULTIPLAYER.md`).
  Only a draining server in the hub refuses joins, with `SERVER_UPDATING`
  ("This server is restarting for an update. Try again in a minute.").
- Dedicated server (no screen, no local player): drain and auto-update exist
  only here. The launcher never runs on a server (the server export has its
  own main scene). A listen server (Host and play) updates when its player
  restarts the game.

## Performance

No cost in the game loop. The launcher makes one GitHub API call per start
(the unauthenticated limit is 60 an hour per IP). The handshake runs once per join. The drain check
reuses `DedicatedServer`'s 0.5 s stop-file timer. The runner polls the
GitHub API every 15 minutes (4 calls an hour, under the 60 an hour
unauthenticated limit even with several servers on one home IP).

## Steps

Steps 1, 2, 4 and 6 do not depend on each other. Steps 1-5 must merge before
Release v0.1.0 (F-11): whatever handshake, save layout and launcher v0.1.0
ships with is what every later version has to read, and a v0.1.0 without the
launcher would leave its players to update by hand once. Step 6 needs one
GitHub Release to exist (v0.1.0, or a test tag) so the runner has something
to download; until it merges, the current per-version image keeps working.
Auto-update (step 7) works from the first release that contains it; a server
on an older release moves to it on its next restart.

### Step 1: A handshake every future version can read

- Build: hello, replies and the refusal acknowledgement as JSON objects with
  the keys in Data. The server reads `protocol` and `version` first and
  refuses with `WRONG_VERSION` whatever else the hello holds or lacks (today
  a hello with a different field count is ignored, so a mismatched client
  times out with "server unreachable"). Unknown keys are ignored.
  `Build.compare_versions(a, b) -> int` (numeric parts, a pre-release sorts
  before its release: `0.2.0-test.3` < `0.2.0` < `0.2.1`).
  `NetErrorDialog.message_for(&"wrong_version", ...)` names the older side:
  "Your game is v0.1.0, the server runs v0.1.1. Update your game, then join
  again." / "The server runs v0.1.0, your game is v0.1.1. The host needs to
  update the server." / two dev builds: "Your game and the server are
  different builds. Use the same build on both." `Net.report_refusal()` and
  the `join_refused` log line no longer index `RefusalReason.keys()` with a
  code they may not know: an unknown code is reported as `&"refused"` and the
  dialog shows the server's `text`. Bump `PROTOCOL_VERSION`.
  `docs/MULTIPLAYER.md` gets the frozen-keys rule.
- Files: `systems/net/handshake.gd`, `core/build.gd`, `core/net.gd`,
  `systems/ui/net_error_dialog.gd`, `docs/MULTIPLAYER.md`, `docs/LOGGING.md`,
  `tests/unit/test_handshake.gd`, `tests/unit/test_build.gd`,
  `tests/integration/test_net_errors.gd`, `tests/manual/net_error_peer.gd`.
- Tests: a hello with protocol 99, extra unknown keys and no `name` gets
  `WRONG_VERSION` (fails today: silence). A refusal with an unknown reason
  code reaches the dialog with the server's `text` (fails today: index out of
  range). `compare_versions` table (10 vs 9, pre-release vs release, dev
  builds). The dialog names the right side for an older client and an older
  server.
- Done when: every version or protocol mismatch ends in the refusal dialog,
  never a timeout, and the dialog says which side to update.

### Step 2: Saves stay safe across updates and channels

- Build: `Build.is_stable()` is true only for plain `X.Y.Z` versions.
  `CharacterProfile.directory()` replaces the `DIRECTORY` constant and
  returns `user://characters/` for stable and `user://characters-test/` for
  everything else (test tags, main builds, the editor, tests); the first time
  the test folder is missing it is created as a copy of the stable folder.
  `SaveFile.saved_version(path) -> int` lets `CharacterProfile` tell a newer
  save from a broken one; a newer save logs `save.profile_newer` and the main
  menu shows "This character was saved by a newer version of the game. Update
  the game to play it. Your save was not changed." before it opens the
  character screen (the save is already never overwritten: `_can_save` stays
  false). An item whose affix or rarity id is unknown no longer crashes:
  `ItemRoller.affix_value()` returns 0 and `PackOverlay._colour()` falls back
  to the common colour (unknown bases already load and save unchanged).
- Files: `core/build.gd`, `systems/save/save_file.gd`,
  `systems/progression/character_profile.gd`, `systems/ui/main_menu.gd`,
  `systems/loot/item_roller.gd`, `systems/ui/pack_overlay.gd`,
  `docs/LOGGING.md`, `tests/unit/test_character_profile.gd`,
  `tests/unit/test_save_file.gd`, and every test that builds a characters
  path, switched to `CharacterProfile.directory()`:
  `tests/unit/test_character_screen.gd`, `tests/unit/test_inventory_order.gd`,
  `tests/unit/test_run_end_grants.gd`, `tests/integration/test_item_loadout.gd`,
  `tests/integration/test_character_save.gd`,
  `tests/integration/test_character_look.gd`,
  `tests/integration/test_look_session.gd`,
  `tests/manual/character_save_quit.gd`, `tests/manual/main_menu_flow.gd`.
- Tests: a non-stable build writes only under `characters-test/` and copies
  stable once (never twice); a save with `save_version` above
  `CURRENT_VERSION` reports newer and the file bytes are unchanged after a
  save attempt; an item with an unknown affix and an unknown rarity opens in
  the Pack overlay and tooltip without errors (fails today: null lookup).
- Done when: nothing a test or dev build does can change a stable save, and a
  player with a too-new save is told why.

### Step 3: CI guards for saves and old clients

- Build: `tools/ci/check_saved_ids.py` (runs in `quality` through
  `check_pr.py`, which already gets the base ref): every id in the saved
  folders must be listed in `tools/ci/saved_ids.txt` (`--fix` appends new
  ones), and every id listed in the base branch's copy of `saved_ids.txt`
  must still exist, so deleting a file and its line together still fails.
  The error says: "Saved ids are permanent. Restore the file, or add a
  SaveFile migration that renames it." The same script fails if
  `SaveFile.CURRENT_VERSION` is lower than at the newest stable `v*` tag
  (`git show <tag>:systems/save/save_file.gd`).
  `tools/ci/smoke_test.sh`: find the newest stable GitHub Release whose tag
  is not this build's own version and that has a Linux zip (`gh release`
  with `GH_TOKEN`, so shared runner IPs do not hit the 60-an-hour limit).
  Download its client, start the new exported server, join with the old
  client and require its log to show `join_refused` with `WRONG_VERSION`
  within 15 s. No such release, or the old release predates step 1: print
  "skipped: no older release" and pass.
- Files: `tools/ci/check_saved_ids.py`, `tools/ci/saved_ids.txt`,
  `tools/ci/test_check_saved_ids.py`, `tools/ci/check_pr.py`,
  `tools/ci/smoke_test.sh`, `.github/workflows/export.yml` (passes
  `GH_TOKEN`), `docs/RELEASING.md`.
- Tests: Python tests with a temp content folder and git repo: a removed
  listed id fails, removing the id and its line together fails, a new
  unlisted id fails, `--fix` adds it, a save version lower than the tag's
  fails. The old-client check runs in every Build, including on release tags
  (where it compares against the previous release, not itself).
- Done when: deleting a saved `.tres` or lowering the save version turns
  `quality` red, and from v0.1.1 on every Build proves the previous release
  is refused cleanly by the new server.

### Step 4: Download and install a version (no screen yet)

- Build: `systems/launcher/` (new). `ReleaseFeed` (new, `RefCounted`, pure
  functions): from the GitHub Releases JSON, pick the newest release on a
  channel that has this platform's zip with a SHA-256 digest (a release made
  in the web UI has no zips for about 10 minutes and is skipped), and compare
  it with installed versions through `Build.compare_versions()` (step 1).
  `VersionInstaller` (new, `Node`): download the zip with `HTTPRequest`
  (`download_file` to `user://launcher/`, a `User-Agent` header, which
  GitHub requires), check `FileAccess.get_sha256()` against the digest,
  unzip with Godot's `ZIPReader` into `versions/<version>.tmp/` next to the
  exe, set the executable bit on Linux (`FileAccess.set_unix_permissions`),
  rename the folder to `versions/<version>/`, and delete all but the 2
  newest version folders. A folder it cannot write (Program Files, read-only)
  fails with a plain message and the release page link. Test hook:
  `--releases-api=<url>` (default the repo's GitHub Releases API).
- Files: `systems/launcher/release_feed.gd`,
  `systems/launcher/version_installer.gd` (new), `docs/LOGGING.md`,
  `tests/unit/test_release_feed.gd`, `tests/unit/test_version_installer.gd`
  (new), `tests/fixtures/releases.json` (new).
- Tests: `ReleaseFeed` on a fixture JSON: stable skips pre-releases, test
  takes them, a release without this platform's zip or digest is skipped,
  nothing newer gives nothing. `VersionInstaller` on a zip built in the test
  with `ZIPPacker` and served from `user://` (no network): a good zip lands
  in `versions/<version>/`, a wrong digest leaves nothing behind, a half
  download leaves no folder, only the 2 newest folders stay.
- Done when: the game can install any release into a version folder,
  checked and complete or not at all. Nothing calls it yet, so the game
  plays as before.

### Step 5: The launcher screen

- Build: a `launcher` screen through the UI router, following the screen
  recipe in `docs/HOW_TO_ADD.md` (`content/screens/launcher.tres`,
  `systems/launcher/launcher_screen.tscn` and `.gd`, new). `MainMenu` opens it first when the exe runs from the
  install root, in an exported build (`OS.has_feature("template")`) whose
  version is stable or test, and was not started with `--from-launcher`,
  `--join` or `--host` (smoke tests and tools start the game that way); dev
  builds and the editor never see it. The screen shows: the installed
  and newest version, the newest release's notes (the release body, as plain
  text), a progress bar, Play, a stable/test switch saved in
  `user://launcher.cfg` (`ConfigFile`), and "Play offline" when GitHub
  cannot be reached. It downloads a newer version on its own (with Cancel),
  then starts `versions/<newest>/<exe> --from-launcher` with
  `OS.create_process` and quits; if the root copy is the newest it opens the
  main menu. A version started from `versions/` copies its exe and pck over
  the root copy when the root is older, retrying while the root is still
  closing, through a temp name so a failed copy never leaves a broken root. `NetErrorDialog` gets a "Restart to
  update" button for "your game is older" that starts the root copy and
  quits. Look: the existing Cold Containment panel style
  (`docs/design/look-rules.md`), provisional until the person sees it.
  `docs/RELEASING.md` gets: the channel table, how players install (unzip
  anywhere they own, run `ExperimentUndead.exe`) and update, how to cut a
  stable or test release, "save version bumps go to test first", roll
  forward, and the frozen asset names. `tools/ci/stamp_version.sh` ignores
  test tags when it finds the last release (`--exclude 'v*-*'`), so main
  builds after `v0.2.0-test.1` count up from the last stable release.
- Files: `systems/launcher/launcher_screen.gd`, `.tscn` (new),
  `content/screens/launcher.tres` (new), `systems/ui/main_menu.gd`,
  `systems/ui/net_error_dialog.gd`, `tools/ci/smoke_test.sh`,
  `tools/ci/stamp_version.sh`, `.github/workflows/export.yml` (Windows
  launcher check), `tools/ci/test_workflows.py`, `docs/RELEASING.md`,
  `tests/unit/test_launcher_screen.gd` (new).
- Tests: GUT: the screen opens only for an exported stable or test build in
  the root folder, never for dev, editor or `--from-launcher`; it picks the
  newest of root, installed and online, plays offline with no network, and
  saves the channel, and is skipped with `--join`. The existing smoke test
  and step 3's old-client check pass `--from-launcher`, because on a release
  tag the exported client is a stable build. End to end (`smoke_test.sh`,
  Linux): serve a fake
  releases JSON whose "newer" release is the freshly exported zip under a
  higher version, start the exported client from a root folder with
  `--releases-api`, and require it to install `versions/<v>/`, start it,
  and the started copy to refresh the root. The same check runs on a
  `windows-latest` runner on release tags and on pull requests that touch
  `systems/launcher/` (Windows file locking is the risky part).
  `stamp_version.sh` in a temp repo with `v0.1.0` and `v0.2.0-test.1` tags
  prints `0.1.1-dev.N`.
- Done when: a player who unzipped v0.1.0 gets v0.1.1 by starting the game,
  on Windows, with one click or none (play-tested by the person on v0.1.1,
  since v0.1.0 has nothing to update from).

### Step 6: A server image that downloads its release

- Build: the image becomes a runner: Debian slim with `ca-certificates`,
  `curl`, `unzip` and `jq`, no game baked in. `entrypoint.sh`: pick the
  target (`EU_VERSION`, else the newest release on `EU_CHANNEL` that has a
  server zip with a digest: `stable` looks only at non-pre-releases, `test`
  at all); download its `*-server.zip` into `/data/versions/<version>/`
  through a temp folder, check the SHA-256 against the asset digest, keep the
  2 newest versions; when GitHub cannot be reached, run the newest installed
  version; run the server and start again when it exits with code 3. Prints
  "Update check: running X, newest Y". Stop and ready files work as today.
  `build.yml` builds the runner and runs the runner test on pull requests and
  main, and pushes `latest` only when `deploy/server/**` changed, with no
  per-commit label, so the image digest only changes when the runner does
  (otherwise Unraid shows "update ready" after every merge).
  `release.yml` stops pushing images (releases are just zips); the `edge` tag
  goes away (test tags replace it, and they come with matching client zips).
  Unraid template: `EU_CHANNEL`, `EU_VERSION`, `EU_AUTO_UPDATE`, no
  `docker login` (the person makes the package public).
- Files: `deploy/server/Dockerfile`, `deploy/server/entrypoint.sh`,
  `deploy/unraid/experiment-undead-server.xml`,
  `.github/workflows/server-image.yml`, `.github/workflows/build.yml`,
  `.github/workflows/release.yml`, `tools/ci/runner_test.sh` (new),
  `tools/ci/test_workflows.py`, `docs/RELEASING.md`.
- Tests: `runner_test.sh` serves a fake releases JSON and the freshly exported
  server zip with `python3 -m http.server`, then checks: the container
  downloads and boots ("Server ready"), stops cleanly, refuses a zip whose
  digest is wrong, ignores a release with no server zip, runs the cached
  version when the fake API is down, and stays on a pinned `EU_VERSION`.
  `test_workflows.py`: no image push from `release.yml`, the runner test runs
  on pull requests, `latest` is pushed only for `deploy/server/**` changes.
- Done when: `docker run -p 7777:7777/udp -v eu:/data
  ghcr.io/j3vb/experiment-undead-server` starts the newest stable release on
  any Docker host, and on the person's Unraid server.

### Step 7: Servers update between matches

- Build: with `EU_AUTO_UPDATE=true` the entrypoint checks every
  `EU_UPDATE_CHECK_SECONDS` (900) and creates `EU_DRAIN_FILE` when the newest
  counted release on the channel differs from the running one.
  `DedicatedServer` watches the drain file on its existing timer, logs
  `server.drain_started`, and owns `draining` (handed to each new session's
  `Handshake` in `_swap_session`). While draining:
  - In a match: nothing changes. Rejoins still work, and the match ends the
    usual way: results stay up, the held place change sends the squad back
    to the hub (`Net._go_to_place`), so nobody loses the results screen.
  - In the hub with players: refuse new hellos with `SERVER_UPDATING`, send
    every client the "updating" notice, and quit with code 3.
  - In the hub with nobody: wait `EMPTY_GRACE` (a squad changing place looks
    empty for a moment), then quit with code 3.
  Clients show (`NetErrorDialog`): "The server restarted for an update.
  Restart the game to update it, then join again." with the "Restart to
  update" button from step 5. Bump
  `PROTOCOL_VERSION`. Close-out: `docs/DECISIONS.md` entry, ADR 0012
  accepted, roadmap row Done, foundation 10 note.
- Files: `systems/net/dedicated_server.gd`, `systems/net/handshake.gd`,
  `core/net.gd`, `core/build.gd`, `systems/ui/net_error_dialog.gd`,
  `deploy/server/entrypoint.sh`, `tools/ci/runner_test.sh`,
  `docs/LOGGING.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`,
  `docs/FOUNDATIONS.md`, `docs/adr/0012-updates-and-release-channels.md`,
  `tests/unit/test_dedicated_server_drain.gd` (new),
  `tests/unit/test_handshake.gd`.
- Tests (GUT): drain on an empty hub exits with code 3 only after
  `EMPTY_GRACE`; drain in the hub with a client sends the notice and exits;
  drain in a match does not exit and still accepts a rejoin; after game over
  the squad goes back to the hub with results kept and the server then exits;
  a hello in a draining hub gets `SERVER_UPDATING`. `runner_test.sh` with
  `EU_UPDATE_CHECK_SECONDS=5`: publishing a second fake release while the
  first runs makes the empty server restart into it.
- Done when: a server left alone on its channel is on the new release within
  15 minutes of a release when nobody is playing, and right after the match
  when someone is.

## Acceptance

- [ ] A client one version behind or ahead of the server gets a refusal that
  says which side to update, never a timeout (step 1 tests, step 3 old-client
  check).
- [ ] Test and dev builds never change stable characters (step 2 test).
- [ ] A save from a newer version shows a message and is never overwritten
  (step 2 test).
- [ ] Deleting or renaming a saved content id, or lowering the save version,
  fails CI (step 3 tests).
- [ ] A player who unzipped v0.1.0 on Windows gets v0.1.1 by starting the
  game, without overwriting running files (step 5 end-to-end test, and a
  play-test by the person).
- [ ] A broken or partial download never leaves a version folder behind
  (step 4 tests).
- [ ] A server on `stable` moves to a new release on its own and never
  restarts during a match (step 7 tests, and once on the person's Unraid).
- [ ] `EU_VERSION` keeps a server on one version across restarts (step 6 test).

## Risks

- A Godot upgrade changes how `SceneMultiplayer` frames the auth packet, so
  an old client cannot even read the refusal. The step 3 old-client check
  catches it on the PR that upgrades Godot; that release then says "update
  required" in its notes.
- GitHub's API is down or rate-limited: the server keeps running its cached
  version and tries again later. Never blocks a match.
- A bad migration ships: `SaveFile` already keeps `.vN.bak` backups, and the
  rule "save version bumps go to the test channel first" (step 5 docs) gives
  it a test round before stable.
- A match can run for hours, so drain can wait that long. The host can force
  it by restarting the container; players get the existing shutdown notice.
- Unraid may not restart containers the way plain Docker does: the entrypoint
  restarts the server itself on exit code 3, so the update does not depend on
  Docker's restart policy.
- Windows file locking: the launcher never overwrites a running file, and
  the only copy (a new version refreshing the root) happens after the root
  has quit. The Windows runner check in step 5 proves it on every release.
- Antivirus: an unsigned exe that downloads and starts another exe is what
  some antivirus heuristics look for. If a scanner blocks the start, the
  launcher shows the release page link so the player can unzip by hand.
  Code signing fixes it for good once it is open to EU individuals.
- A compromised repo or release would reach every player who updates. The
  SHA-256 check only catches broken downloads. Signing releases is the
  fix if the game goes public; until then only people the person trusts
  can push tags.
- GitHub can be unreachable: the launcher starts the newest installed
  version ("Play offline"). One API call per start stays far under the
  60 an hour limit, even for a LAN party behind one IP.
- Someone hosts with a pinned old version: their friends with an updated game
  get the "server is older" refusal, which says what to do.

## Open decisions

- [x] How do players get the game and its updates? Our own updater
  (the person, 2026-11-17), as a launcher (the person's follow-up the same
  day). Built into the game exe rather than as a second program (technical
  pick, see "How the launcher works").
- [x] How do servers update? On their own, between matches:
  `EU_AUTO_UPDATE=true` by default (the person, 2026-11-17).
