# Rules for coding agents (Codex, Claude, others)

Experiment Undead is an original wave-based zombie FPS in **Godot 4.7.2**,
written in **typed GDScript**. It will get RPG progression and self-hosted
8-player servers later, so code must stay multiplayer-ready from day one.

Read `docs/DECISIONS.md` before you start. It lists what is built, what is
simplified on purpose, and what is not started.

## Folders

| Folder | What goes there |
|---|---|
| `core/` | Autoloads only (Events, Content, Net, ...) |
| `systems/<feature>/` | Code and scenes for one feature |
| `content/<type>/` | Data only: `.tres` files. The file name is the id |
| `levels/` | Maps |
| `assets/` | Models, sounds, textures |
| `tests/` | GUT tests (`unit/`, `content/`, `integration/`) |
| `tools/` | Editor and command-line scripts |
| `docs/` | Decisions and credits |

## Code rules

1. **Typed GDScript everywhere.** Untyped and inferred declarations are errors
   in this project. Write `var speed: float = 5.0`, never `var speed = 5.0` or
   `var speed := 5.0`. Type loop variables: `for id: StringName in ids:`.
2. **Content is data.** New guns, enemies, waves = new `.tres` files, not new
   code. Never change a loaded `.tres` at runtime; keep live state in a
   separate object (like `WeaponInstance`).
3. **Signals:** a node signals up to its parent. Game-wide facts go through
   the `Events` autoload, named in the past tense (`enemy_killed`). Requests
   are direct calls (`Economy.try_spend()`), never signals.
4. **No global player.** Loop over the `players` group.
5. **Multiplayer rules:**
   - The player reads `InputFrame`s, never the keyboard directly.
   - Damage, spawns, points and XP only change where `Net.is_authority()` is true.
   - Gameplay runs in `_physics_process`. `_process` is for visuals only.
   - All enemies come from `Spawner`.
   - Gameplay randomness uses `GameSession.rng`, never `randf()`.
   - XP and items go through `ProgressionService`.
6. **Performance target:** 120 fps with 24 zombies alive. No per-frame
   allocations in hot paths, no `get_node()` in loops, cache lookups.
7. Short doc comment (`##`) at the top of every new script. Few other comments.
8. Do not add third-party code or assets without listing them in
   `docs/CREDITS.md` with their licence (CC0 / MIT preferred).

## How to run checks

```bash
# Godot 4.7.2 headless binary, if not already installed:
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q godot.zip && mv Godot_v4.7.2-stable_linux.x86_64 godot && chmod +x godot

./godot --headless --path . --import                       # import assets
./godot --headless --path . --quit-after 300               # boot test: no SCRIPT ERROR / Parse Error
./godot --headless --path . -s addons/gut/gut_cmdln.gd     # all GUT tests
```

All three must pass before you open a pull request. CI runs the same steps.
If you cannot download Godot, say so in the PR and let CI run the checks.

## Quality checks (CI is the merge gate)

CI has two required checks. A PR can only merge when both are green.

- **`quality`** (pull requests only, checks only the files your PR changed):
  - `gdlint` with the repo `gdlintrc`: lines max 120, files max 350 lines,
    functions max 6 arguments, Godot style guide names and member order.
  - `gdformat --check --line-length 120`. Fix with
    `gdformat --line-length 120 <files>`. When you touch an old file, format
    the whole file.
  - Functions max 50 lines.
  - **Tests required:** if you change a `.gd` file in `core/` or `systems/`,
    you must also add or change a file in `tests/`. Only for visual-only or
    pure-rename changes, add the label `no-tests-needed` and say why in the PR.
- **`godot`**: import, boot test, all GUT tests. Any `SCRIPT ERROR` or
  `Parse Error` fails it. `tests/unit/test_scripts_compile.gd` loads every
  script, so unused variables, shadowing, unreachable code and the other
  warnings set to error in `project.godot` fail CI too. Do not lower those
  warning levels or skip a test to get green.

Run the same `quality` check locally before you push:

```bash
pip install "gdtoolkit==4.5.0"
python tools/ci/check_pr.py origin/main
```

### Test rules

- `tests/unit/`: one file per system, pure logic (no scene tree when possible).
- `tests/content/`: data checks for every `content/` type. New Resource type =
  new content checks.
- `tests/integration/`: a real `GameSession` run headless, for flows across
  systems (spawn, kill, points, rounds).
- Every bug fix adds a test that fails without the fix.
- Tests use `GameSession.rng` with a fixed seed, never real time or `randf()`.

## Merging

- When both checks are green you may mark your PR ready and merge it yourself
  (squash merge). No human approval is needed.
- Second-agent review first when the PR changes more than 300 lines, or touches
  `core/`, `project.godot`, `.github/` or networking code: Codex reviews Claude
  PRs and Claude reviews Codex PRs. Fix or answer every comment, then merge.
- Never merge with a red or pending check, and never merge someone else's PR.
- Each PR gets exactly one label for release notes: `new`, `fix`, `balance`
  or `tech`.

## Working rules

- One task = one branch = one pull request. Branch name: `codex/<task-name>`.
- Only touch the files and folders your task allows. If you must touch
  something else, stop and explain why in the PR instead of doing it.
- Adding an autoload: add exactly one line to the `[autoload]` block in
  `project.godot`, at the end.
- Add or update tests for everything you build.
- Add a short entry to `docs/DECISIONS.md` under the right heading when you
  build something listed there as "not started" or "simplified".
- Open the PR as a **draft** and fill in the PR template.
