# 0011. One UI router owns screen flow and the mouse

- **Status:** accepted (built in plans/ui-router.md, 2026-11-17)
- **Date:** 2026-11-16
- **Decided by:** UI design doc; build timing is an agent pick

## Context

Screens currently change scenes and capture the mouse by hand in several
scripts. The skill tree, town hub and more pause pages are coming, and each
would add its own flow.

## Decision

One `UI` autoload owns screen flow: `UI.push(id)`, `UI.pop()`,
`UI.replace(id)`. Screens never open other screens directly, Back always pops,
and only the router captures or frees the mouse. Build the minimal version
(push, pop, replace, mouse) before the next new screen; layers, transitions and
toasts come when a screen needs them.

## Consequences

- New screens are opened through the router, not `change_scene_to_file`.
- `UI` must be added to the allowed autoloads in `tools/ci/check_rules.py`
  when it is built.
- Tests can open any screen on its own.

## Links

`docs/design/ui-hud.md` (screen router), `docs/FOUNDATIONS.md` foundation 5.
