---
name: finish-feature
description: Check a feature against the Definition of done and close it out. Use in the PR that builds the last step of a plan, or when asked whether a feature is done.
---

# Finish a feature

The Definition of done is in `docs/PROCESS.md`. Go through it with evidence,
not memory.

## Steps

1. **Plan steps.** Open the plan in `docs/plans/`. For each step, find its
   merged PR. List step number and PR number. Any step without a merged PR
   means the feature is not done: stop and say which.
2. **Acceptance.** For each acceptance line, name the test that checks it
   (file and test name) or the Play-test notes issue that recorded it. Feel and
   look lines need a play-test by the person; if none exists, say so and leave
   the line unticked.
3. **Co-op.** Check the networked parts have a test (for example the two-peer
   tests in `tests/integration/`) and that what the plan's co-op section
   promised is what the code does.
4. **Performance.** No new per-frame allocations, `get_node()` in loops or
   `load()` in hot paths in the feature's code. If the feature adds enemies,
   effects or many nodes, ask for a GPU performance check.
5. **Docs.** New early warnings in `docs/LOGGING.md`, new content recipes in
   `docs/HOW_TO_ADD.md`, a `docs/DECISIONS.md` entry for what was built and
   simplified.
6. **Close out** in the same PR: tick Acceptance, set the plan to
   `Status: Done`, set the roadmap row to Done, and put `Closes #<issue>` in the
   PR body.

## Output

A short table: Definition of done line, evidence, pass / missing. Anything
missing becomes a fix in this PR or a new Task issue linked from the plan.
