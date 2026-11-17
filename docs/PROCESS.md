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
6. The order of features and what each waits on: [docs/ROADMAP.md](ROADMAP.md).

## Plan first

Big work is planned before it is built, so nothing is built twice.

1. Pick the next feature from [docs/ROADMAP.md](ROADMAP.md) whose needs are Done.
2. If its Plan column says **needed**, write a plan from
   [docs/plans/TEMPLATE.md](plans/TEMPLATE.md) and get it reviewed
   ([docs/plans/README.md](plans/README.md)). The plan must pass the
   [ready-to-build checklist](FOUNDATIONS.md#ready-to-build).
3. Build the plan one step per PR. Every PR and Codex prompt names the plan
   and step.
4. If building shows the plan is wrong, fix the plan first, then the code.

## Definition of done

A **PR** is done when the AGENTS.md merge rules hold (CI green, tests for the
change, review answered).

A **feature** is done when all of these hold:

- [ ] Every plan step is merged, and the plan's Acceptance list is ticked.
- [ ] Acceptance is checked by tests, or by a play-test recorded in a
      Play-test notes issue for feel and look.
- [ ] It works in co-op as the plan's co-op section says (host, client,
      dedicated server), with a test for the networked parts.
- [ ] It holds the frame budget (60 fps minimum with 24 zombies; no new
      per-frame allocations in hot paths).
- [ ] New early warnings are in the `docs/LOGGING.md` catalogue.
- [ ] New content types or recipes are in `docs/HOW_TO_ADD.md`.
- [ ] `docs/DECISIONS.md` says what was built and what was simplified.
- [ ] The plan says `Status: Done`, the roadmap row says Done, the issue is
      closed.

## Play-test loop

Once a week, play 15 minutes on the latest build and fill in a
**Play-test notes** issue. Each problem in it becomes its own Bug or Task.

## Change control

- Small changes: just do them.
- Big changes (a pillar, scope, a whole system, the roadmap): add an entry to
  `docs/DECISIONS.md` first (what, why, what it replaces).
- New ideas: an **Idea** issue, not straight into the game.
- Every design change (a rule, a number players feel, content scope): add one dated row to the
  [Change log](design/game-design.md#change-log) in `docs/design/game-design.md` in the same PR.

## Labels and milestones

Defined in `.github/repo-setup.json`. The **Repo setup** workflow creates or
updates them when that file changes on main. It never deletes anything.
