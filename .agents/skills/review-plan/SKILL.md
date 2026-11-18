---
name: review-plan
description: Review a feature plan in docs/plans/ before it is approved. Use when reviewing a PR that adds or changes a plan file, or when asked to check a plan.
---

# Review a feature plan

You check that the plan can be built step by step without rework. You do
not rewrite it; you list problems with the section and a concrete fix.

## Checklist

Answer each one. A "no" is a finding.

1. **Pillar and milestone.** Does the goal serve a pillar in
   `docs/PROCESS.md` and belong to the current milestone in `docs/ROADMAP.md`?
2. **Dependencies.** Is every id in the roadmap Needs column Done, or built by
   an earlier step of this plan?
3. **Real code.** Open the files the plan names. Do they exist, and do the
   named classes and functions exist? Is anything the feature must change
   missing from "Systems touched"?
4. **Ready to build.** Is the `docs/FOUNDATIONS.md#ready-to-build` checklist
   copied and ticked, with a reason or a fixing step for each unticked line?
5. **Non-goals.** Is everything under "Not in" safe to leave out, or will a
   later step quietly need it?
6. **Co-op.** Does every piece of state have an owner? Is what clients send
   and receive clear? Late joiners? Dedicated server with no local player?
7. **Data.** Does any save field, Resource or network message change without
   saying how old saves and older builds behave?
8. **Steps.** Is each step one PR, with a test that fails without it, and does
   the game still run after each step? Is the riskiest part early?
9. **Simple.** Does it follow `docs/KEEP_IT_SIMPLE.md`: no new autoload,
   manager, base class or framework without the rule that allows it, no
   abstraction before the third use?
10. **Numbers.** Is every number taken from `docs/design/` or the balance CSVs,
    not invented?
11. **Performance.** Is the cost with 24 zombies and 4 players stated, with no
    per-frame allocations in hot paths?
12. **Acceptance.** Can each acceptance line be checked by a test or a recorded
    play-test?
13. **Lore link.** Does the `Lore link:` line point to a real reason in
    `docs/design/lore.md` for everything new the player sees and every new
    name? Does nothing contradict the lore (colours, factions, timeline)?

## Output

- Findings, most serious first: section, problem, fix.
- Mark a finding **Blocking** if building it as written would mean redoing
  work later (wrong owner in co-op, missing system, save break, missing
  dependency). Everything else is a Suggestion.
- If there are no findings, say so. The plan writer then sets
  `Status: Approved`.
