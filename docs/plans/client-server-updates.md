# Plan: Client and server updates

Status: Review
Roadmap: F-65
Phase: P8 (steps 1-4 land before Release v0.1.0, F-11)
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
- Clients get updates through a store app (itch.io, see Open decisions), so
  the game itself has no updater code (step 4).
- A small server image that downloads the release you ask for and updates
  itself between matches, never during one (steps 5-6).
- Two release channels: stable and test.

Not in (non-goals, and where each one goes instead):

- Our own launcher or self-updater: a store app does this better with no code
  (see "Why no updater of our own" below). Never, unless we sell direct
  downloads.
- A Windows installer: the itch app (or Steam) installs the game. Direct zips
  stay on GitHub Releases. Only if we sell outside a store.
- Steam: later, when the game goes public. Step 4 notes the job to add.
- A Windows dedicated server package: Windows hosts use Host and play, or run
  the client with `--headless --server`; the store app updates it like the
  game. Revisit in F-44 only if someone asks.
- Delta patches of our own: itch (and Steam) already send only changed data.
  The Windows build is about 65 MB zipped today.
- A server browser, LAN discovery, server-side saves: their own features.
  Any future server save uses `SaveFile` with its own version.
- Code signing: still blocked for EU individuals (`docs/RELEASING.md`).
  Store apps do not trigger SmartScreen on their installs.
- The rest of F-44 (server.cfg, download page): stays in F-44, which reuses
  steps 5-6.

## How it fits together

| Piece | Rule |
|---|---|
| Version | The git tag is the version (exists). Client and server must run exactly the same version, protocol and content (exists, kept: simplest, and no hidden desyncs). |
| Channels | **stable** = tags like `v0.2.0`. **test** = tags like `v0.2.0-test.1` (GitHub pre-releases). **dev** = main builds as Actions artifacts (exists). |
| Client updates | stable: the itch app updates the game in the background (butler push from `release.yml`). test: zips from the GitHub pre-release. |
| Server updates | The image is a runner. On start it downloads the newest release on its channel (or the version you pin) from GitHub Releases, checks its SHA-256, and runs it. Every 15 minutes it checks again; a new version makes the server finish the current match, tell players, and restart into the new version. |
| Saves | Unchanged format rules (ADR 0005). Test, dev and editor builds keep their own characters folder, copied once from stable, so a test build can never upgrade a stable save that stable then refuses. |
| Rollback | Roll forward: fix or revert, then tag the next patch. Never lower `SaveFile.CURRENT_VERSION` (CI checked). Emergency server pin: `EU_VERSION=0.2.0`. |

**Why no updater of our own.** A running Windows game cannot replace its own
`.exe` or `.pck` (Godot keeps the pack open), so an updater needs a second
program, its own download, verify and swap logic, and an unsigned exe that
downloads files, which antivirus tools dislike. The itch app does all of it,
plus delta patches, for free, and the game needs zero lines for it.

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
  against one? No. New record [0012](../adr/0012-updates-and-release-channels.md)
  writes down the update model.
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
  dialog in the main menu. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (nothing here touches gameplay).
- Tests: `test_handshake.gd`, `test_build.gd`, `test_character_profile.gd`,
  `test_save_file.gd`, a new `test_dedicated_server_drain.gd`, Python tests
  in `tools/ci/`, and a shell test of the server image with a fake release
  server. The old-client check runs a real released client against the new
  server.
- Logging: `net.join_refused` gains `older`; new `save.profile_newer`,
  `server.drain_started`, `server.update_restart`; the runner prints its
  update checks to the Docker log.
- Performance: nothing per frame. The drain check reuses the existing 0.5 s
  stop-file timer.
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
- `docs/KEEP_IT_SIMPLE.md` rule 8: use the existing tool (here the store app)
  before writing our own.
- No numbers from the balance sheet are needed. The 15-minute check and
  2 cached versions are fixed constants (rule 10), not settings.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `systems/net/handshake.gd` | changed | hello and reply become objects with named keys; version checked first; refusal names the older side (step 1); `SERVER_UPDATING` refusal while draining (step 6) |
| `core/build.gd` | changed | `compare_versions()`, `is_stable()`, protocol bumps |
| `core/net.gd` | changed | `RefusalReason.SERVER_UPDATING` appended; the host-ended notice carries a reason (step 6) |
| `systems/save/save_file.gd` | changed | `saved_version()` tells "newer" from "broken" (step 2) |
| `systems/progression/character_profile.gd` | changed | `directory()` picks the stable or test folder; copies stable once (step 2) |
| `systems/ui/main_menu.gd`, `systems/ui/character_screen.gd` | changed | "saved by a newer version" message (step 2) |
| `systems/net/dedicated_server.gd` | changed | drain mode and exit code 3 (step 6) |
| `deploy/server/` | changed | runner image and entrypoint (steps 5-6) |
| `deploy/unraid/experiment-undead-server.xml` | changed | channel, pin and auto-update fields (step 5) |
| `.github/workflows/` | changed | itch job (step 4); runner image build and test, no per-version images (step 5) |
| `tools/ci/` | changed | saved-id and save-version guard, old-client check, runner test |
| `docs/` | changed | RELEASING, MULTIPLAYER, LOGGING, DECISIONS, ADR 0012 |

Autoloads, managers or base classes added: none.

## Data

- Handshake (step 1, `PROTOCOL_VERSION` bump). Hello:
  `{"t": "hello", "protocol": int, "version": String, "content": String,
  "fingerprint": String, "name": String, "level": int}`. Replies:
  `{"t": "accepted", "place": String}` and
  `{"t": "refused", "reason": int, "server_version": String,
  "server_protocol": int, "text": String}`. The keys `t`, `protocol`,
  `version`, `reason`, `text`, `server_version` are frozen forever: later
  versions add keys, never rename or remove these. `RefusalReason` values are
  on the wire: append only.
- Host-ended notice (step 6, protocol bump): gains `reason: StringName`
  (`&"stopped"` or `&"updating"`) and the new version string.
- Save format change: none. Non-stable builds read and write
  `user://characters-test/` instead of `user://characters/`.
- `tools/ci/saved_ids.txt` (step 3): every id that can end up in a save:
  `content/weapons/`, `content/loot/gear/`, `content/loot/affixes/`,
  `content/loot/rarities/`, `content/skills/`, and level folder names
  (`best_runs` keys written by `GameSession`). Grows only.
- Server environment (step 5): `EU_CHANNEL` (`stable` or `test`, default
  `stable`), `EU_VERSION` (empty = newest on the channel; set = pin),
  `EU_AUTO_UPDATE` (default from Open decisions), `EU_RELEASES_API` (default
  the repo's GitHub Releases API; tests point it at a fake server),
  `EU_DRAIN_FILE` (set by the image, like `EU_STOP_FILE`).
- Release assets: unchanged names (`ExperimentUndead-<version>-windows.zip`,
  `-linux.zip`, `-server.zip`). The runner uses the asset's SHA-256 digest
  from the GitHub API.
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
- Late joiner: during drain, refused with `SERVER_UPDATING` ("This server
  restarts for an update after this match. Try again in a few minutes.").
  Otherwise unchanged.
- Dedicated server (no screen, no local player): drain and auto-update exist
  only here. A listen server (Host and play) updates when its player restarts
  the game through the itch app.

## Performance

No cost in the game loop. The handshake runs once per join. The drain check
reuses `DedicatedServer`'s 0.5 s stop-file timer. The runner polls the
GitHub API every 15 minutes (4 calls an hour, under the 60 an hour
unauthenticated limit even with several servers on one home IP).

## Steps

Steps 1, 2 and 5 do not depend on each other. Steps 1-4 must merge before
Release v0.1.0 (F-11): whatever handshake and save layout v0.1.0 ships with
is what every later version has to read. Step 5 needs one GitHub Release to
exist (v0.1.0, or a test tag) so the runner has something to download; until
it merges, the current per-version image keeps working.

### Step 1: A handshake every future version can read

- Build: hello and replies as JSON objects with the keys in Data. The server
  reads `protocol` and `version` first and refuses with `WRONG_VERSION`
  whatever else the hello holds or lacks (today a hello with a different
  field count is ignored, so a mismatched client times out with "server
  unreachable"). Unknown keys are ignored. `Build.compare_versions(a, b) -> int`
  (numeric parts, a pre-release sorts before its release: `0.2.0-test.3`
  < `0.2.0` < `0.2.1`). The refusal text names the older side:
  "Your game is v0.1.0, the server runs v0.1.1. Update your game, then join
  again." / "The server runs v0.1.0, your game is v0.1.1. The host needs to
  update the server." / two dev builds: "Your game and the server are
  different builds. Use the same build on both." For a reason code it does
  not know, the client shows the server's `text`. Bump `PROTOCOL_VERSION`.
  `docs/MULTIPLAYER.md` gets the frozen-keys rule.
- Files: `systems/net/handshake.gd`, `core/build.gd`, `docs/MULTIPLAYER.md`,
  `docs/LOGGING.md`, `tests/unit/test_handshake.gd`, `tests/unit/test_build.gd`.
- Tests: a hello with protocol 99, extra unknown keys and no `name` gets
  `WRONG_VERSION` (fails today: silence). A reply with an unknown reason shows
  the server text. `compare_versions` table (10 vs 9, pre-release vs
  release, dev builds). The refusal text names the right side for an older
  client and an older server.
- Done when: every version or protocol mismatch ends in the refusal dialog,
  never a timeout, and the dialog says which side to update.

### Step 2: Saves stay safe across updates and channels

- Build: `Build.is_stable()` is true only for plain `X.Y.Z` versions.
  `CharacterProfile.directory()` returns `user://characters/` for stable and
  `user://characters-test/` for everything else (test tags, main builds, the
  editor); the first time the test folder is missing it is created as a copy
  of the stable folder. `SaveFile.saved_version(path) -> int` lets
  `CharacterProfile` tell a newer save from a broken one; a newer save logs
  `save.profile_newer` and the main menu and character screen show "This
  character was saved by a newer version of the game. Update the game to play
  it. Your save was not changed." (it is already never overwritten:
  `_can_save` stays false). Items whose base or affix id is unknown load, show
  as "Unknown item", and save back unchanged.
- Files: `core/build.gd`, `systems/save/save_file.gd`,
  `systems/progression/character_profile.gd`, `systems/ui/main_menu.gd`,
  `systems/ui/character_screen.gd`, `docs/LOGGING.md`,
  `tests/unit/test_character_profile.gd`, `tests/unit/test_save_file.gd`,
  `tests/integration/test_character_look.gd` (uses the folder path).
- Tests: a non-stable build writes only under `characters-test/` and copies
  stable once (never twice); a save with `save_version` above
  `CURRENT_VERSION` reports newer and the file bytes are unchanged after a
  save attempt; an item with an unknown base survives a load and save round
  trip.
- Done when: nothing a test or dev build does can change a stable save, and a
  player with a too-new save is told why.

### Step 3: CI guards for saves and old clients

- Build: `tools/ci/check_saved_ids.py` (runs in `quality` through
  `check_pr.py`): every id in the saved folders must be listed in
  `tools/ci/saved_ids.txt` (`--fix` appends new ones), and every listed id
  must still exist. The error says: "Saved ids are permanent. Restore the
  file, or add a SaveFile migration that renames it and remove the line in
  the same PR." The same script fails if `SaveFile.CURRENT_VERSION` is lower
  than at the newest `v*` tag (`git show <tag>:systems/save/save_file.gd`).
  `tools/ci/smoke_test.sh`: when a stable GitHub Release exists, download its
  Linux client, start the new exported server, join with the old client and
  require its log to show `join_refused` with `WRONG_VERSION` within 15 s.
  Until a release with step 1's handshake exists it prints "skipped: no
  release yet" and passes.
- Files: `tools/ci/check_saved_ids.py`, `tools/ci/saved_ids.txt`,
  `tools/ci/test_check_saved_ids.py`, `tools/ci/check_pr.py`,
  `tools/ci/smoke_test.sh`, `docs/RELEASING.md`.
- Tests: Python tests with a temp content folder: a removed listed id fails,
  a new unlisted id fails, `--fix` adds it, a lower save version than the tag
  fails. The old-client check is exercised by the Build run itself.
- Done when: deleting a saved `.tres` or lowering the save version turns
  `quality` red, and from v0.1.0 on every Build proves the previous release
  is refused cleanly by the new server.

### Step 4: Clients update through the itch app

- Build: a `itch` job in `release.yml` after `publish`, only for tags without
  a dash: install a pinned butler version, then `butler push` the Windows and
  Linux folders to `windows-stable` and `linux-stable` with
  `--userversion <version>`. It reads `BUTLER_API_KEY` (secret) and
  `ITCH_GAME` (repo variable, like `user/experiment-undead`) through `env`
  and is skipped while `ITCH_GAME` is empty, so CI stays green before the
  page exists. Test tags stay GitHub pre-releases only (two Windows uploads on
  one itch page would make the itch app ask players to choose).
  `docs/RELEASING.md` gets: the channel table, how players install and update
  (itch app; manual zips), how to cut a stable or test release, "save version
  bumps go to test first", and roll forward.
- Files: `.github/workflows/release.yml`, `tools/ci/test_workflows.py`,
  `docs/RELEASING.md`.
- Tests: `test_workflows.py`: the itch job runs only on stable tags, needs
  `publish`, passes secrets through `env` only, and is skipped without
  `ITCH_GAME`.
- Done when: tagging `vX.Y.Z` puts the build on itch and an installed itch
  app updates to it within 30 minutes (play-tested by the person on v0.1.0).
- If the person picks Steam instead: this step becomes a `steamcmd` upload to
  the default branch, with the test channel as a password-protected beta
  branch. Everything else in this plan stays the same.

### Step 5: A server image that downloads its release

- Build: the image becomes a runner: Debian slim with `ca-certificates`,
  `curl`, `unzip` and `jq`, no game baked in. `entrypoint.sh`: pick the
  target (`EU_VERSION`, else the newest release on `EU_CHANNEL`: `stable`
  reads `releases/latest`, `test` the newest release including
  pre-releases); download its `*-server.zip` into `/data/versions/<version>/`
  through a temp folder, check the SHA-256 against the asset digest, keep the
  2 newest versions; when GitHub cannot be reached, run the newest installed
  version; run the server and start again when it exits with code 3. Prints
  "Update check: running X, newest Y". Stop and ready files work as today.
  `build.yml` builds the runner, runs the runner test and pushes `latest` on
  main. `release.yml` stops pushing images (releases are just zips); the
  `edge` tag goes away (test tags replace it, and they come with matching
  client zips). Unraid template: `EU_CHANNEL`, `EU_VERSION`,
  `EU_AUTO_UPDATE`, no `docker login` (the person makes the package public).
- Files: `deploy/server/Dockerfile`, `deploy/server/entrypoint.sh`,
  `deploy/unraid/experiment-undead-server.xml`,
  `.github/workflows/server-image.yml`, `.github/workflows/build.yml`,
  `.github/workflows/release.yml`, `tools/ci/runner_test.sh` (new),
  `tools/ci/test_workflows.py`, `docs/RELEASING.md`.
- Tests: `runner_test.sh` serves a fake releases JSON and the freshly exported
  server zip with `python3 -m http.server`, then checks: the container
  downloads and boots ("Server ready"), stops cleanly, refuses a zip whose
  digest is wrong, runs the cached version when the fake API is down, and
  stays on a pinned `EU_VERSION`. `test_workflows.py`: no image push from
  `release.yml`, runner test runs on pull requests.
- Done when: `docker run -p 7777:7777/udp -v eu:/data
  ghcr.io/j3vb/experiment-undead-server` starts the newest stable release on
  any Docker host, and on the person's Unraid server.

### Step 6: Servers update between matches

- Build: with `EU_AUTO_UPDATE=true` the entrypoint checks every 15 minutes
  and creates `EU_DRAIN_FILE` when the newest release on the channel differs
  from the running one. `DedicatedServer` watches the drain file on its
  existing timer and logs `server.drain_started`. While draining: new hellos
  get `SERVER_UPDATING`; an empty server quits with code 3 at once; a server
  in the hub sends every client the "updating" notice and quits with code 3;
  a server in a match plays on, and after the results grace it sends the
  notice and quits instead of going back to the hub. Clients show "The server
  restarted for an update. Update your game if the itch app offers it, then
  join again." Bump `PROTOCOL_VERSION`. Close-out: `docs/DECISIONS.md` entry,
  ADR 0012 accepted, roadmap row Done, foundation 10 note.
- Files: `systems/net/dedicated_server.gd`, `systems/net/handshake.gd`,
  `core/net.gd`, `core/build.gd`, `systems/ui/main_menu.gd` (notice text),
  `deploy/server/entrypoint.sh`, `tools/ci/runner_test.sh`,
  `docs/LOGGING.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`,
  `docs/FOUNDATIONS.md`, `docs/adr/0012-updates-and-release-channels.md`,
  `tests/unit/test_dedicated_server_drain.gd` (new),
  `tests/unit/test_handshake.gd`.
- Tests: drain on an empty server exits with code 3; drain in the hub sends
  the notice and exits; drain in a match does not exit until game over, then
  exits instead of returning to the hub; a hello during drain gets
  `SERVER_UPDATING`. `runner_test.sh`: publishing a second fake release while
  the first runs makes the server restart into it, and never while a test
  match is running.
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
- [ ] Tagging `vX.Y.Z` publishes to itch and an installed itch app updates
  (play-test by the person, v0.1.0).
- [ ] A server on `stable` moves to a new release on its own and never
  restarts during a match (step 6 tests, and once on the person's Unraid).
- [ ] `EU_VERSION` keeps a server on one version across restarts (step 5 test).

## Risks

- A Godot upgrade changes how `SceneMultiplayer` frames the auth packet, so
  an old client cannot even read the refusal. The step 3 old-client check
  catches it on the PR that upgrades Godot; that release then says "update
  required" in its notes.
- GitHub's API is down or rate-limited: the server keeps running its cached
  version and tries again later. Never blocks a match.
- A bad migration ships: `SaveFile` already keeps `.vN.bak` backups, and the
  rule "save version bumps go to the test channel first" (step 4 docs) gives
  it a test round before stable.
- A match can run for hours, so drain can wait that long. The host can force
  it by restarting the container; players get the existing shutdown notice.
- Unraid may not restart containers the way plain Docker does: the entrypoint
  restarts the server itself on exit code 3, so the update does not depend on
  Docker's restart policy.
- Someone hosts with a pinned old version: their friends with an updated game
  get the "server is older" refusal, which says what to do.

## Open decisions

- [ ] How do players get the game and its updates? Recommended: the itch.io
  app (free, background updates and delta patches, one CI job, no updater
  code). Other options: Steam now (100 USD app fee, best for a public
  launch), our own updater (most code, antivirus risk), or GitHub zips only
  (no auto-update).
- [ ] How do servers update? Recommended: on their own, between matches
  (`EU_AUTO_UPDATE=true` by default), so servers keep up with players whose
  itch app already updated. Other option: only when the host restarts the
  container (`EU_AUTO_UPDATE=false` by default; same code).
