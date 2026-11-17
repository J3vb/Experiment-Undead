# Logging and diagnostics

Every run of the game or server writes a structured log that a person or an
AI agent can read to find, debug and fix problems. Code: `core/log.gd` (the
`Log` autoload), `systems/diagnostics/`.

## Where the files are

Folder `user://logs/`:

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Experiment Undead\logs\` |
| Linux | `~/.local/share/godot/app_userdata/Experiment Undead/logs/` |
| Docker / Unraid server | `/data/godot/app_userdata/Experiment Undead/logs/` (the `/data` volume) |

Per run (the last 20 runs are kept):

- `run_<UTC time>_<client|server>_<pid>.jsonl`: the log, one JSON object per line.
- `run_<...>.summary.json`: counts, distinct problems and perf numbers.
  Written at start, every 30 s and on exit. `"clean_exit": false` means the run crashed
  or was killed.
- `godot.log`: Godot's own plain-text output (prints, engine errors). Use it
  only when the JSON log is not enough.

The server also prints every warning and error to stdout as
`[WARN] system.event {data}`, so `docker logs` shows them.

## Line format

```json
{"time":"2026-11-14T19:43:24","up_ms":2016,"frame":108,"level":"warn","system":"perf",
 "event":"long_frames","round":3,"peer":1,"session":"run_20261114T194323_client",
 "data":{"count":2,"worst_ms":143.9}}
```

- `level`: `info` (normal fact), `warn` (early warning sign, game goes on),
  `error` (something is broken).
- `system` + `event`: what happened. The catalogue is below.
- `up_ms` / `frame`: time since start and render frame, to line events up.
- `round`: current wave round (0 = between matches or not started).
- `peer`: network peer id (1 = server or solo).

## How to diagnose (steps for an AI agent)

1. Open the newest `*.summary.json`. Check `clean_exit`, `levels`, `problems`
   (each distinct warning/error with its first line and a count) and `perf`.
2. If `clean_exit` is false, read the last 50 lines of the matching `.jsonl`:
   the crash happened right after the last line. The next run also logs
   `build.previous_run_crashed` with the old log's path.
3. List warnings and errors: `grep -v '"level":"info"' run_X.jsonl`
   (or `jq -c 'select(.level != "info")'`).
4. For each problem, read the lines around its `frame` / `up_ms` to see what
   led up to it (round start, door bought, navmesh rebake ...).
5. `engine.*` lines carry `where` (file:line) and `stack`: go straight to that
   code.
6. Compare `perf.health` samples and `waves.round_started` lines over time:
   steadily rising `nodes`, `objects`, `orphan_nodes` or `memory_mb` across
   rounds is a leak.
7. Fix the cause, add a test that fails without the fix (AGENTS.md rule).

## Event catalogue

| system.event | level | Meaning / what to check |
|---|---|---|
| `build.run_started` | info | Version, commit, OS, CPU, GPU, args, log path |
| `build.run_ended` | info | Clean quit, run length |
| `build.previous_run_crashed` | warn | Last run did not quit cleanly; `previous_log` = its file |
| `engine.engine_error` / `engine_script` / `engine_shader` | error | `push_error` or a script/shader error. `where`, `function`, `stack` |
| `engine.engine_warning` | warn | `push_warning` or an engine warning |
| `player.body_clips_missing` | warn | The player model has no third-person clips, so teammates show a still body; rebuild `player.glb` |
| `perf.long_frames` | warn | Frames over 50 ms in the last second (`count`, `worst_ms`). Hitch at load is normal; in a round it is not |
| `perf.low_fps` | warn | Under 50 fps for 3 s in a row (windowed builds only), with a health snapshot |
| `perf.health` | info | Every 30 s: fps, process/physics ms, memory, objects, nodes, orphan nodes, enemies, draw calls |
| `perf.orphan_nodes_growing` | warn | Over 200 orphan nodes and still rising: nodes created and never freed |
| `level.navmesh_baked` / `navmesh_bake_slow` | info / warn | Navmesh bake time (`reason` load/rebake). Over 100 ms = visible hitch |
| `level.navigation_ready` | info | Time from load until zombies can path |
| `level.navigation_not_ready` | error | No usable navmesh 10 s after load: zombies will not move |
| `enemies.zombie_stuck` | warn | A chasing zombie moved under 0.3 m in 2 s while out of reach (logged once per zombie). `at`, `next_path_point`, `path_finished`: navmesh hole, bad spawn point or geometry snag |
| `enemies.zombie_fell_out` | warn | Zombie below y = -50: missing floor collision (it relocates at once) |
| `enemies.zombie_relocated` | warn | A lost zombie moved to a hidden spawn: `reason` unreachable (20 s without progress), far (over 60 m for 15 s) or fell_out; `from`, `to` (spawn point). Many from one place = navmesh hole there |
| `waves.round_started` | info | Round number, enemies this round, health snapshot |
| `waves.round_ended` | info | Round cleared |
| `waves.round_stalled` | warn | 90 s in a round with no kill; lists where the living zombies are |
| `player.player_spawned` / `player_died` | info | Player `net_id`, spawn position |
| `player.weapon_has_no_grip` | warn | A gun has no `GripData`, so it shows no first-person arms. `weapon` id; once per gun per run. Add `content/grips/<base id>.tres` and set the gun's `grip` |
| `progression.profile_save_failed` | warn | Character could not be saved; `id`, `path`, `error` (Godot Error code). Check folder permissions and disk space |
| `progression.profile_unreadable` | warn | Existing character is unreadable, malformed or newer; file stays untouched, this match uses a temporary character. `id`, `path`; inspect nearby engine errors |
| `game.game_over` | info | Final stats |
| `net.peer_connected` / `peer_disconnected` | info | Server side, peer id |
| `net.round_state_ignored` | warn | A round message reached a peer that must not take it (`sender`): the server got one, or a client got one not from the server. Should never appear |
| `net.interaction_rejected` | warn | Server refused a client's interact request (`peer`, `reason`, `path`): `player_not_alive`, `match_over`, `unknown_path`, `out_of_range`, `grant_pending` (last gun grant not applied yet), `bad_facts` (gun facts with wrong fields or ids). At most one per second. Many `out_of_range` = `InteractionSync.REACH_SLACK` too tight |
| `net.hit_claim_rejected` | warn | Server refused a client's hit or gravity well claim (`peer`, `reason`): `player_not_alive`, `zombie_not_alive`, `hit_out_of_bounds`, `zone_missing`, `claims_too_fast`, `well_out_of_bounds`, `well_wrong_weapon` (well or orb request named a gun whose `effect` is not WELL: a mismatched build or a cheat). At most one per second |
| `net.loadout_rejected` | warn | Server refused a client's equipped loadout (`peer`, `reason`): `not_a_dictionary`, `too_much_gear` (over 3 gear items), `too_many_guns` (more than the player's weapon slots), `unknown_gun` (gun base not in content). The server keeps the last good loadout; check that both builds have the same content |
| `net.interaction_rate_limited` | warn | A client sent interact requests less than 0.1 s apart; extra ones are refused. At most one per second |
| `ui.unknown_screen` | warn | `UI.push` or `UI.replace` got an id with no `content/screens/<id>.tres`; `id`. Nothing opens |
| `ui.pop_empty` | warn | `UI.pop()` with no screen open: a screen emitted `closed` twice or something popped a screen it did not push |

## Adding log lines (rules for agents)

- Call `Log.info/warn/error(&"system", &"event_name", {data})`. System = the
  `systems/` folder name; event = past tense or a state, snake_case.
- `warn` is for early signs: things that should not happen but the game
  survives. Every new system should warn on its own "this looks wrong" cases.
- Put the facts needed to debug in `data`: ids, positions, counts, timings.
  No player names or other personal data.
- Never log per frame, per shot or per hit. Group repeats (see
  `perf.long_frames`) or report once per object (see `zombie_stuck`).
- Add new events to the catalogue above in the same PR.

## Soak test

Run `godot --headless --path . --script res://tools/soak/soak.gd -- --rounds 10 --seed 1 --timescale 4`.
It loads the normal Halcyon Labs session, powers on and opens every door, keeps
an immortal player stationary, and hits one living zombie every 30 physics ticks
only after spawning and window entry finish. Stops after the target round ends
or 10 real minutes. The table includes rounds, kills, points, real run time,
and counts plus the first JSON line for each warning/error in this run's log.

Exit 1: any `error` level, `waves.round_stalled`, `enemies.zombie_fell_out`,
`perf.orphan_nodes_growing`, `level.navigation_not_ready`, an unreadable or
malformed log, or a target round that never finishes. `enemies.zombie_stuck`
and `perf.long_frames` only warn (exit 0); other warning lines are also listed.
The event lists are constants at the top of `tools/soak/soak.gd`.
The separate PR/manual Soak workflow writes the table to the job summary and
uploads `user://logs/` on failure. It is a required check (`soak`).

**Fight mode (balance runs, not in CI).** Add `--fight 1 --wall <gun id>`, for
example `--rounds 16 --fight 1 --wall kestrel_smg`. The player is mortal and a
bot (`tools/soak/soak_bot.gd`) plays: it turns toward the nearest zombie it can
see at a human-like turn rate, aims down sights at the chest (no headshots),
holds fire, reloads when empty, walks backwards when a zombie is within 4 m,
buys the named wall gun the moment it can pay (from anywhere, no walking), and
rebuys its ammo when dry. A zombie it cannot see for 10 s is killed outright,
standing in for the player walking over to it. The run ends when the player
dies; the last table line says `died in round N` (or `survived`), how many
zombies were hunted that way and the gun in hand. A death is not a failure, but
log errors still are. Run several seeds and use the median death round. It is
a rough stand-in for a player: it never trains zombies or picks a spot, so read
it as a trend between two sets of numbers, not as how a human will do.
