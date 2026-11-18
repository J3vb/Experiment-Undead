# Plan: <feature name>

Status: Draft
Roadmap: <F-xx> / issue #<n>
Phase: <P0-P10>
Size: <S / M / L>
Approved by: <who approved and when, empty until Approved>
Lore link: <the story reason for what the player sees, from docs/design/lore.md#story-links-for-game-content, or "none: <why>" for pure tech work>

<!--
Copy this file to docs/plans/<feature-name>.md and fill every section.
Write "none" instead of deleting a section. Plain words, short lines.
Rules for writing and approving plans: docs/plans/README.md.
-->

## Goal

What the player gets, in one or two sentences. Which pillar it serves
(docs/PROCESS.md).

## Scope

In:

- ...

Not in (non-goals, and where each one goes instead):

- ... (later: F-xx / idea issue #n / never)

## Ready to build

Copy the checklist from [docs/FOUNDATIONS.md](../FOUNDATIONS.md#ready-to-build)
here and tick it. Every unticked line needs a reason or a step below that
fixes it first.

## Design references

Links to the exact sections this plan follows. Quote numbers, do not invent
them.

- docs/design/<file>.md#<section>
- docs/design/balance/<file>.csv rows ...
- docs/DECISIONS.md lines for the systems involved (design differences, simplifications)
- docs/adr/<file>.md decisions this plan must respect

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/<feature>/ | new | ... |

Autoloads, managers or base classes added: none / list + which Keep it simple
rule allows it.

## Data

New or changed Resource types, fields, `.tres` files, save fields and
network messages. For each: name, type, default, who reads it.

- Save format change: none / what, and how old saves still load
- Content checks to add in `tests/content/`: ...

## Co-op behaviour

Answer each line. "Not networked" is only fine if the feature truly never
matters to another player.

- Who owns the state (server / owning client / each client):
- What clients send, what the server sends back:
- What a client sees that the host sees too (and what only the owner sees):
- Late joiner: what they must receive:
- Dedicated server (no screen, no local player): what is skipped:

## Performance

Cost per frame with 24 zombies and 4 players, and what keeps it cheap (pooling,
cached lookups, no per-frame allocations). Budget it may not exceed.

## Steps

One step = one PR = one Codex prompt or one thread. Each step leaves the game
playable and CI green. Order matters; later steps may only use what earlier
steps built.

### Step 1: <short name>

- Build: ...
- Files: ...
- Tests: which test file, what it checks (it must fail without this step)
- Done when: ...

### Step 2: <short name>

- Build: ...
- Files: ...
- Tests: ...
- Done when: ...

## Acceptance

How we know the whole feature is done. Each line is checked by a test or by a
recorded play-test.

- [ ] ...

## Risks

What could force a redo, and how this plan avoids or tests it early.

- ...

## Open decisions

Questions that change the goal, the look or the feel, for the person.
Must be empty (or every line answered) before Status: Approved.

- none
