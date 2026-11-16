# 0001. Godot 4 with typed GDScript, no C#

- **Status:** accepted
- **Date:** 2026-11-14
- **Decided by:** the person (engine), architecture doc (language)

## Context

The game is fully written by AI agents and needs better graphics than
Three.js. Every file must be easy for an agent to read and edit, with no build
step.

## Decision

Godot 4 (now 4.7.2), Forward+ renderer, Jolt physics at 60 Hz with physics
interpolation. All code is typed GDScript; untyped and inferred declarations
are errors. No C#. GDExtension only if profiling proves it is needed.

## Consequences

- Write `var speed: float = 5.0`, never `var speed = 5.0` or `:=`.
- Do not add C# files, a .NET build or GDExtension without a new record.
- Engine upgrades are their own PR with a full test run.

## Links

Architecture doc (https://claude.ai/artifact/XNJ12WAbMJAy2mRNPd5PCx), AGENTS.md code rule 1.
