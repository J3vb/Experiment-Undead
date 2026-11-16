# 0009. CI is the merge gate, keep it simple

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** the person

## Context

Agents write and merge most of the code. Quality must be checked by machines,
and the code must stay small enough for agents to understand.

## Decision

A PR merges only when `quality` and `test` are green and review comments are
handled; agents may merge their own PRs then. Behaviour changes add tests.
Lint, size and structure rules are enforced by CI and may never be weakened to
get green. Code grows in small plain pieces: no abstraction before the third
use, no framework up front.

## Consequences

- No tests, no merge. Bug fixes add a test that fails without the fix.
- Ask the person before changing a check that seems wrong.
- Foundation rules that can be checked by CI should become CI rules.

## Links

AGENTS.md (quality checks, keep it simple), `docs/KEEP_IT_SIMPLE.md`, `tools/ci/check_rules.py`.
