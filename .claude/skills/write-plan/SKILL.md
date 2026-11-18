---
name: write-plan
description: Write a feature plan in docs/plans/ before any code is built. Use when a roadmap feature says "Plan: needed", when asked to plan a feature, or before work that adds a system, a data type, a save field or a network message.
---

# Write a feature plan

Rules and lifecycle: `docs/plans/README.md`. Template: `docs/plans/TEMPLATE.md`.

## Steps

1. **Find the feature** in `docs/ROADMAP.md`. Check every id in its Needs
   column is Done. If not, stop and say which one blocks it.
2. **Read the sources** before writing a line:
   - the issue, and the design sections it points to (`docs/design/README.md`
     says which file covers what)
   - `docs/DECISIONS.md` and `docs/adr/` entries for the systems involved
   - `docs/FOUNDATIONS.md` (the ready-to-build checklist and known weak spots)
   - `docs/MULTIPLAYER.md` for who owns state in co-op
   - **the actual code** the feature touches: open each file you will name.
     List real class, function and file names. Mark new ones as new.
3. **Copy the template** to `docs/plans/<feature-name>.md`, `Status: Draft`,
   and fill every section. Write "none" rather than deleting a section.
4. **Co-op first.** For every piece of state, say who owns it (server, owning
   client, each client), what is sent, and what a late joiner gets. A solo-only
   design is the most common cause of rework (issue #138).
5. **Lore link.** Fill the `Lore link:` line: which part of
   `docs/design/lore.md` gives what the player sees (a zombie, gun, prop,
   sign, screen, name) its story reason. If nothing fits, add a row to its
   "Story links for game content" section in the same PR, marked
   provisional; a story or tone choice goes to the person as a decision.
   Pure tech work writes `none: <why>`.
6. **Numbers come from `docs/design/`** and `docs/design/balance/*.csv`. Never
   invent one; if the docs have none, put it under Open decisions.
7. **Cut steps to one PR each** (one Codex prompt or one thread, roughly under
   400 changed lines). Each step: Build, Files, Tests (a test that fails without
   the step), Done when. Each step must leave the game playable and CI green.
   Put risky or unknown parts in the earliest step so a bad idea fails cheap.
8. **Open decisions** are only for goal, look or feel questions the person
   must answer. Technical choices: pick the simplest option that follows
   `docs/KEEP_IT_SIMPLE.md` and write why in one line.
9. **Check it** with `python tools/ci/check_plans.py`.
10. **Open a docs-only PR** with `Status: Review`, label `tech`, and add the plan
   link to the roadmap row (Status: Planning). The Codex review on that PR
   runs the `review-plan` checklist.

## After review

- Fix what the review found.
- If the plan is size L or has open decisions, each decision goes to the
  person as a decision card first. Write their answers into the plan as
  `- [x] question: answer`.
- Set `Status: Approved` and `Approved by:` (review PR number, and the
  person if they approved). Roadmap row Status: Ready. Merge on green CI.
