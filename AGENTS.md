# Rules for coding agents (Codex, Claude, others)

Experiment Undead is an original wave-based zombie FPS in **Godot 4.7.2**,
written in **typed GDScript**. It will get RPG progression and self-hosted
8-player servers later, so code must stay multiplayer-ready from day one.

Read `docs/PROCESS.md` (pillars, milestones, how work flows) and
`docs/DECISIONS.md` before you start. DECISIONS.md lists what is built, what is
simplified on purpose, and what is not started.

**Design references:** read `docs/design/` before any UI, art, audio,
weapon, enemy or map work. Start with `docs/design/README.md`; for anything
visual, `docs/design/look-rules.md` is the style to match. Use its colours,
names and numbers instead of inventing new ones.

## Skills

Step-by-step guides in `.agents/skills/<name>/SKILL.md` (Codex) and the same
files in `.claude/skills/` (Claude Code). Load the one that fits your task:

| Skill | Use it for |
|---|---|
| `blender-model` | Building or changing a code-made model in `tools/assets/` |
| `godot-asset-import` | Import settings, files to commit and tests for anything in `assets/` |
| `look-check` | Rendering a visual change and comparing it with the style guide |
| `design-change` | Changing a game number or adding content in line with the balance sheet |

Third-party skills (Apache-2.0, from gamedev-skills/awesome-gamedev-agent-skills, see
`docs/CREDITS.md`). They are general Godot 4.7.2 and game-design guides:

| Skill | Use it for |
|---|---|
| `godot-3d-essentials` | Cameras, lights, `WorldEnvironment`, materials |
| `godot-shaders` | `.gdshader` syntax, errors, wiring |
| `godot-physics` | Bodies, areas, collision layers, raycasts, Jolt |
| `godot-resources` | Custom `Resource` data, `.tres`, shared vs duplicated |
| `godot-gdscript` | Typing, `await`, parse errors |
| `godot-signals-groups` | Signals, groups, deferred connections |
| `godot-nodes-scenes` | Scene structure, instancing, broken `res://` paths |
| `godot-animation` | `AnimationPlayer`, `AnimationTree`, tweens |
| `godot-audio` | Players, buses, volume |
| `godot-ui-control` | Control layout, themes, focus |
| `godot-multiplayer` | ENet, `@rpc`, spawner and synchronizer (P7) |
| `fps-shooter` | Shot model, TTK, recoil, spread, ADS sensitivity |
| `rpg` | Stats, XP curves, items, rarity, affixes |
| `game-feel` | Screen shake, hit-stop, knockback |
| `level-design` | Layout, player metrics, pacing |
| `game-ai` | Enemy FSM, perception, pathfinding |
| `camera-systems` | First-person look and camera feel |
| `input-systems` | Input actions, buffering, rebinding |
| `game-ui-ux` | HUD and menu rules, accessibility |
| `audio-design` | Mixing, ducking, adaptive music |
| `performance-optimization` | Profiling, draw calls, frame budget |

**Our rules win.** When a third-party skill disagrees with this file, `docs/KEEP_IT_SIMPLE.md`,
`docs/design/` or one of our own skills above, follow ours. For example: no new autoloads
or event buses without the Keep it simple check, GUT is our test runner, no multiplayer
code before P7, and numbers come from the balance sheet, not the skill's examples.
Their links to skills we did not copy (Unity, Roblox, `save-systems`, ...) can be ignored.
Do not edit these folders; update them by copying a newer upstream release.

Edit skills in `.agents/skills/` only, then run
`python tools/ci/check_skills_mirror.py --fix`. CI fails if the copies differ.

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
6. **Performance:** v0.1 (P4) must hold 60 fps with 24 zombies alive. The
   long-term target is 120 fps on an RTX 4080 Super at 1440p High, so keep
   code 120-friendly: no per-frame allocations in hot paths, no `get_node()`
   in loops, cache lookups.
7. Short doc comment (`##`) at the top of every new script. Few other comments.
8. **Assets.** Up to v0.1, art is built in code to match the style-guide
   previews (Cold Containment): Godot grey boxes and shaders, Blender Python
   scripts in `tools/assets/` that export `.glb` into `assets/`, and
   generated sounds (`tools/generate_sfx.py`). The script is the source; never
   hand-edit its output. Asset packs come after v0.1 to raise quality. Every
   third-party file (code or asset) gets one line in `docs/CREDITS.md`: name,
   author, link, licence. CC0 first, CC-BY with credit, MIT for code. No
   "non-commercial" or "no AI" licences. No Git LFS for now.
   How to build, import and check models (including `check_models.py` and the
   glTF validator the Assets CI runs): the skills below.
9. **Names.** Use the design doc's words in code and data:
   - Machines: `SpecimenVault` (random gun), `MedDispenser` (gives a serum),
     `Reforger` (upgrades a gun). Not "mystery box" or "perk machine".
   - Data types: `WeaponData`, `RecoilData`, `EnemyData`, `WaveRules`,
     `EconomyRules`, `SerumData`, `AmmoModData`, `BuyableData`,
     `PowerUpData`, `MapData`. Not `PerkData` or `RoundCurve`.

## Keep it simple

The game will grow to loot, co-op and a town hub, but it grows by adding
**small, plain pieces**, not by building frameworks up front. When two readings
of a task are possible, pick the one with less code. Examples and the list of
things to build only when needed: `docs/KEEP_IT_SIMPLE.md`.

1. **Build only what your task's phase needs.** The phases are P0 to P10 in the
   architecture doc. Do not add fields, functions, signals, enum values, settings
   or files for a later phase "because we'll need it". Later phases add them.
2. **No abstraction before the third use.** Write the code plainly the first
   time, copy it the second time, and only pull out a shared function, base
   class or helper when the third real use arrives. Two similar 10-line blocks
   are fine.
3. **No interface with one implementation.** No base class whose methods are
   empty stubs, no "Service" that only forwards to another class.
4. **Size limits** (CI enforces these in the `quality` check):
   - function: 50 lines max
   - file: 350 lines max
   - function arguments: 6 max

   If you hit a limit, split by job (move the zombie's attack logic to its own
   function), not by layer (no `ZombieAttackHelper`, `ZombieAttackManager`).
5. **New autoload:** only the ones in the architecture doc's autoload table
   (Events, Content, Settings, Audio, Pool, Game, Net), and only when your task
   actually needs it. Any other autoload: stop and ask in the PR.
6. **New manager / director / service node:** only if it owns state or a rule
   that no existing node owns. If it would just pass calls through, put the code
   in the node that owns the data.
7. **New base class:** only when there are already 3 concrete classes that need
   it, or the architecture doc names it (HealthComponent, HitZone, Interactable).
8. **Godot first.** Use the built-in tool before writing your own: signals,
   groups, Timer/Tween, AnimationPlayer, Resources, NavigationAgent3D,
   AudioStreamRandomizer, ConfigFile, JSON, MultiplayerSpawner/Synchronizer.
   No custom event bus, state-machine framework, dependency injection,
   object factory, plugin system or service locator.
9. **Multiplayer: only the seams the architecture already reserves.** They are
   listed in code rule 5 above (InputFrame, `Net.is_authority()`,
   physics ticks, one Spawner with net ids, `GameSession.rng`,
   ProgressionService, items as dicts, no global player). Before P7 do **not**
   add RPCs, MultiplayerSpawner/Synchronizer, peer handling, serialization,
   prediction, interpolation or lag compensation code.
10. **No config for things nobody tunes.** Export a value to data only if a
    designer will change it for balance or feel. Fixed rules stay as constants.
11. **Delete, don't disable.** Remove dead code, unused functions and
    commented-out blocks in the same PR that makes them dead. Git keeps history.
12. **Prefer changing data over changing code.** A new gun, zombie, wave mix or
    serum is a `.tres` file. If it needs code, add the smallest script that data
    can point to.

### Simplicity check (every PR)

Add this section to the PR description and answer each line in a few words.
Reviewers (human or AI) reject the PR if an answer is "no" without a good reason.

```
### Simplicity check
- Only builds what this phase needs: yes / no (why)
- New autoloads, managers or base classes: none / list + which rule allows it
- New abstraction used in fewer than 3 places: none / list
- Anything a Godot built-in already does: none / list
- Dead code removed: yes / n.a.
```

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
- **`test`**: import, boot test, all GUT tests. Any `SCRIPT ERROR` or
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

## Logs and diagnostics

Each run writes a JSON-lines log and a summary to `user://logs/` (engine
errors with file, line and stack included). To debug a bug report, a crash or
a test run, read `docs/LOGGING.md` first: it says where the files are, how to
read them and what each event means. When you build a system, add `Log.warn`
lines for its early warning signs and list them in that doc's catalogue.

## Merging

- **Codex reviews every PR**, from Claude and from Codex. It runs when the PR
  is opened as ready or marked ready. It does **not** run on later pushes:
  after each push with changes, comment `@codex review` on the PR once.
- You may merge your PR yourself (squash merge), no human approval needed,
  when all of these hold for the current head commit:
  1. `quality` and `test` checks are green.
  2. The Codex review for that commit is finished: its "Codex Review
     Summary" comment shows ✅ Completed for that commit (or a 👍 reaction).
  3. Every review comment is fixed, or answered with a reason if it is a
     "Suggestion" you decline, and its conversation is resolved. A comment
     marked "Blocking" or a P0/P1 finding must be fixed, not declined.
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
