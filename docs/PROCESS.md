# How this game is made

Full plan: https://claude.ai/artifact/NvNZEWyueGnCSrsihhcy66

## Pillars

Every feature must serve at least one. If it serves none, it waits.

1. **Guns feel great.** Nothing ships that makes shooting feel worse.
2. **The pressure always builds.** Every round is harder than the last.
3. **Every run makes you stronger.** Levels, skills and loot carry over.

## Stages and milestones

| Stage | Milestone | Phases | Gate |
|---|---|---|---|
| Pre-production + vertical slice | v0.1 Vertical slice | P0-P4 | Halcyon Labs, 3 guns, rounds 1-10, final look and sound, 60 fps minimum |
| Production | v0.2 Progression and loot | P5-P6 | Levels, skills and loot work offline |
| Production to Alpha | v0.9 Alpha | P7-P9 | Feature complete. No new features after this |
| Beta to Release | v1.0 Release | - | No blocker bugs, 120 fps target met |

## How work flows

1. Every job is a GitHub issue in a milestone. Templates: Task, Bug, Play-test notes, Idea.
2. Board columns: Later, Next, Doing, Done. Pick from Next.
3. One issue = one branch = one PR. CI green = merge (see AGENTS.md).
4. `blocker` bugs go before everything else.
5. A milestone ends with a tag and a release (see docs/RELEASING.md).

## Play-test loop

Once a week, play 15 minutes on the latest build and fill in a
**Play-test notes** issue. Each problem in it becomes its own Bug or Task.

## Change control

- Small changes: just do them.
- Big changes (a pillar, scope, a whole system, the roadmap): add an entry to
  `docs/DECISIONS.md` first (what, why, what it replaces).
- New ideas: an **Idea** issue, not straight into the game.

## Labels and milestones

Defined in `.github/repo-setup.json`. The **Repo setup** workflow creates or
updates them when that file changes on main. It never deletes anything.
