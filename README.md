# Experiment Undead

Wave-based zombie survival FPS built in Godot 4.7 (Forward+). Original game.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build, not .NET).
2. Clone the repo.
3. Open `project.godot` in Godot and press F5.

## Controls

| Action | Key |
|---|---|
| Move | WASD (physical keys, so it works on AZERTY too) |
| Look | Mouse |
| Fire / Aim | Left / Right mouse |
| Sprint / Crouch / Jump | Shift / Ctrl or C / Space |
| Reload | R |
| Switch weapon | Q or mouse wheel up |
| Pause | Esc |
| Restart after death | Enter |

## Tests

```bash
godot --headless --path . --import                  # first time only
godot --headless --path . -s addons/gut/gut_cmdln.gd # all tests
```

Tests cover content validation, damage and wave maths, and a headless
integration match (navmesh, spawning, chasing, shooting, points, XP, round end).

## Where things live

```
core/          autoloads: Events (signal hub), Content (id lookup), Net (authority)
systems/       code + scenes per feature: player, weapons, damage, enemies,
               waves, economy, progression, input, level, effects, ui, game
content/       data only (.tres): weapons, enemies, waves, economy
levels/        maps and their materials
assets/        raw audio (later models, textures)
tests/         GUT tests: unit/, content/, integration/
tools/         helper scripts (input map, placeholder sound generator, screenshots)
docs/          decisions and credits
```

Add a gun: copy `content/weapons/rifle_ar.tres`, change `id` to the new file
name and tune the numbers. Add a zombie type: copy a file in
`content/enemies/` and add it to `content/waves/default_waves.tres`.

See [docs/DECISIONS.md](docs/DECISIONS.md) for the choices made so far.

## Licence

All rights reserved. See [LICENSE](LICENSE). Third-party parts keep their own
licences and are listed in [docs/CREDITS.md](docs/CREDITS.md).
