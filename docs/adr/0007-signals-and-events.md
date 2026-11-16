# 0007. Signals up, Events for facts, direct calls for requests

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** architecture doc

## Context

Systems must talk without tangling into each other, without building a custom
event framework.

## Decision

A node signals up to its parent. Game-wide facts go through the `Events`
autoload, named in the past tense (`enemy_killed`). Requests are direct calls
that return a result (`Economy.try_spend()`), never signals.

## Consequences

- No new event bus, message queue or signal framework.
- New `Events` signals follow `docs/HOW_TO_ADD.md` and are past tense.
- In co-op, say which peers emit a new event (it fires only where the fact
  happens unless sync re-emits it).

## Links

`core/events.gd`, AGENTS.md code rule 3.
