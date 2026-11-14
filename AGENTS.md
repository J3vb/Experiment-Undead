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
4. **Size limits** (CI enforces these through gdlint):
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
    perk is a `.tres` file. If it needs code, add the smallest script that data
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

## Working rules

- One task = one branch = one pull request. Branch name: `codex/<task-name>`.
- Only touch the files and folders your task allows. If you must touch
  something else, stop and explain why in the PR instead of doing it.
- Adding an autoload: add exactly one line to the `[autoload]` block in
  `project.godot`, at the end.
- Add or update tests for everything you build.
- Add a short entry to `docs/DECISIONS.md` under the right heading when you
  build something listed there as "not started" or "simplified".
- Open the PR as a **draft**. In the PR description write: what you built,
  which files changed, how you tested it, and anything you left out.
