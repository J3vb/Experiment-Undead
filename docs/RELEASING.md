# Builds and releases

Plan and reasoning: https://claude.ai/artifact/HApjhDRXmDDVDYLezv4ozt

## What happens automatically

| When | Workflow | You get |
|---|---|---|
| Push or PR | `ci.yml` | tests and lint (owned by the code quality setup) |
| Merge to main | `build.yml` | Windows + Linux builds under the run's **Artifacts** (kept 3 days), server image `edge` |
| Pull request (not docs-only) | `build.yml` | same export and smoke test, builds under **Artifacts**, no image |
| Tag `v1.2.3` | `release.yml` | GitHub Release with zips and notes, server image `1.2.3`, `1.2`, `latest` |
| Actions tab, "Build", **Run workflow** | `build.yml` | builds of any branch, no image |

All exports run on Linux runners (the Windows .exe is cross-exported), so they
use the cheap 1x minutes. Every build is smoke-tested: the exported client and
server must boot without script errors, the client must join the server, and
the server must stop cleanly before anything is uploaded.

## Cut a release

1. Merge what you want into main and check the **Build** run is green.
2. GitHub, **Releases**, **Draft a new release**, type a new tag like `v0.1.0`
   on `main`, click **Generate release notes**, then **Publish**. (Or
   `git tag v0.1.0 && git push origin v0.1.0` and the workflow writes the notes.)
3. The **Release** workflow attaches the zips to that release (or creates it,
   notes from the PR titles grouped by the `new`, `fix`, `balance`, `tech`
   labels). About 10 minutes.

Tags with a dash (`v0.2.0-rc.1`) become pre-releases and do not move `latest`.

## Version numbers

- The git tag is the version. Never edit a version number by hand.
- Main builds are `next-patch-dev.N+commit`, for example `0.1.1-dev.4+a1b2c3d`.
- CI writes `version.json` before export; the `Build` autoload reads it and
  the HUD shows it bottom right. In the editor it shows `dev (editor)`.
- `Build.PROTOCOL_VERSION`: bump when client/server messages change.
- `SaveFile.CURRENT_VERSION`: bump when save fields change, and add an
  upgrade step plus a test (see `systems/save/save_file.gd`).

## Crash logs

- Logs: `%APPDATA%\Godot\app_userdata\Experiment Undead\logs` on Windows,
  `~/.local/share/godot/app_userdata/Experiment Undead/logs` on Linux. Godot
  keeps the last few runs. The first lines hold version, commit, OS and GPU.
- If the game did not quit cleanly, the next start shows "Last session crashed"
  with the log folder in the HUD corner.
- Release builds keep GDScript call stacks, so errors name the function.

## Server on Unraid

1. One time: GitHub, **Settings**, **Developer settings**, **Personal access
   tokens**, create a classic token with only `read:packages`.
2. On Unraid: `docker login ghcr.io -u <github user>` with that token as password.
3. Copy `deploy/unraid/experiment-undead-server.xml` to
   `/boot/config/plugins/dockerMan/templates-user/` and add the container from
   **Docker**, **Add Container**, template `experiment-undead-server`.
4. It runs as `99:100` (nobody:users) so it can write to appdata. Port 7777/udp.

Run it anywhere else:

```bash
docker run -d --name eu-server -p 7777:7777/udp -v eu-data:/data \
  ghcr.io/j3vb/experiment-undead-server:latest
```

Settings: `EU_PORT` (7777), `EU_MAX_PLAYERS` (8, max 8), or `-- --port=7777`.
`docker stop` shuts down cleanly (Godot ignores SIGTERM, so the entrypoint
drops a stop file the server watches).

The server is a placeholder until co-op lands: it opens the port and accepts
connections, but runs no match yet.

## Running a downloaded Linux build

Artifacts from the Actions page lose the executable bit: run
`chmod +x ExperimentUndead.x86_64` once. Release zips already have it.

## Costs and limits

- GitHub Pro includes 3,000 Actions minutes and 2 GB storage a month. A build
  takes about 10 to 15 minutes. Keep the Actions spending limit at $0 so
  nothing is ever charged; builds pause instead.
- The Godot download and export templates live in the Actions cache (not billed).
- Old untagged server images are deleted, keeping the newest 5.

## Not yet

- **Code signing:** Windows shows a SmartScreen warning on unsigned builds.
  Azure Artifact Signing is not open to individuals in the EU yet; Steam does
  not need signing. Revisit before a public download outside Steam.
- **itch.io:** add a `butler push` job to `release.yml` with a `BUTLER_API_KEY` secret.
- **Steam:** after the app fee, add a `steamcmd` upload job to a beta branch.
- **Windows file details:** the .exe shows Godot's icon and details because
  setting them needs rcedit + Wine on the runner.
