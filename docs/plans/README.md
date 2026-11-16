# Plans: think first, then build

Skills for this workflow (Codex and Claude): `write-plan`, `review-plan`,
`finish-feature` in `.agents/skills/`.

A feature is planned on paper before any code is written, so nobody builds
on a guess and redoes it later. Example of the cost of skipping this: co-op
doors, wall-buys and machines were built for solo only and must now be
reworked (issue #138).

## When a plan is needed

Write a plan when the work does **any** of these:

- adds a new system or a new folder in `systems/`
- adds or changes a Resource type, a save field or a network message
- touches more than one system folder
- is size M or L in [docs/ROADMAP.md](../ROADMAP.md)
- would take more than one PR

No plan needed (the Task issue is enough) for: a bug fix, a balance number,
new content that follows a recipe in `docs/HOW_TO_ADD.md`, docs and tooling
changes that fit in one PR.

## Lifecycle

| Status | Meaning | Who moves it |
|---|---|---|
| Draft | Being written | The writer |
| Review | Plan PR is open and waiting for review | The writer |
| Approved | Review passed, open decisions answered. Building may start | The writer, after review |
| Building | Steps are being built | The first step's PR |
| Done | All steps merged, acceptance ticked | The last step's PR |
| Dropped | Not doing it; say why in one line | Anyone, with a reason |

`tools/ci/check_plans.py` checks every plan in this folder: required
sections, a valid status, `Approved by` filled in from Approved on, and no
open decisions left once approved.

## How to write one

1. Copy [TEMPLATE.md](TEMPLATE.md) to `docs/plans/<feature-name>.md`
   (snake_case or kebab-case, same as the roadmap name).
2. Read the code that the feature touches before writing the steps. A plan
   that names files that do not exist, or skips a system it must change, is
   the most common way plans fail.
3. Fill every section. "none" is a valid answer; a missing section is not.
4. Size each step for one PR: one Codex prompt or one thread, roughly under
   400 changed lines, with its own tests.
5. Put the plan's link in the roadmap row and in the issue.

## How a plan is reviewed (light)

A plan goes in a **docs-only PR** with `Status: Review`. The automatic Codex
review on that PR is the plan review. The reviewer (Codex, or a Claude thread
that did not write the plan) answers these:

1. Does the goal serve a pillar, and is it in the current milestone?
2. Is everything in "Not in" really safe to leave out, or will a later step
   need it?
3. Are all dependencies in the roadmap Done, or built by an earlier step?
4. Do the named files and functions exist (or is it clear they are new)?
5. Does the co-op section say who owns every piece of state?
6. Does any step change a save format or network message without saying how
   old data still works?
7. Does every step have a test that fails without it?
8. Can each step merge alone and leave the game playable?
9. Does it follow `docs/KEEP_IT_SIMPLE.md` (no framework, no third-use
   abstraction early)?
10. Is any number invented instead of taken from `docs/design/`?

Fix what the review finds, set `Status: Approved` and `Approved by:`, and
merge on green CI.

**When the person approves instead:** if the plan has open decisions about
goal, look or feel, or it is size L, each decision goes to the person as a
decision card (one card per decision) before approval. Their answers are
written into the plan. Everything else is approved by the review above.

## Building from a plan

- Every build PR names its plan and step: `Plan: docs/plans/<file>.md, step N`.
- Every Codex prompt starts with the plan link and the step number, and pastes
  that step's Build, Files, Tests and Done when lines.
- Build only what the step says. If the step turns out wrong, stop, fix the
  plan in the same PR (or a plan PR first) and say what changed. Do not quietly
  build something else.
- The last step's PR ticks Acceptance, sets `Status: Done` and updates the
  roadmap row.
