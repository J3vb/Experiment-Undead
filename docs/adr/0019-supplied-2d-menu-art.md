# 0019. Supplied painted art may go in assets/ui/ as menu backdrops

- **Status:** accepted
- **Date:** 2026-11-20
- **Decided by:** the person ("Painted backdrops, full-res" card 2026-11-20, plan F-88)

## Context

ADR 0008 and AGENTS rule 8 say art is built in code, and ADR 0017 only opens
`assets/` to Tripo models that pass through intake. The person made painted
concept art for the menus (2026-11-20) and wants the menus to look exactly
like it. Rebuilding those scenes in 3D would take weeks.

## Decision

Painted, text-free 2D images that the person supplies may go in
`assets/ui/backdrops/` as full-screen menu backdrops. The source of truth is
the supplied image (kept as given in the project files and as a design
reference in `docs/design/concepts/screens/`). The game file is a JPEG copy at
the supplied size, never painted over by hand. Logos, lettering and buttons are
never taken from the images: they are our own code-built art on top
(`tools/assets/menu_art.py`).

## Consequences

- Each backdrop gets one line in `docs/CREDITS.md`: made for this project with
  an AI image tool, owned by the project.
- The Steam store page needs the AI-generated content disclosure (as ADR 0017).
- Backdrops are only for front-end screens (menus, loading). World art stays
  code-built (ADR 0008) or Tripo (ADR 0017).
- About 0.5 MB per backdrop; no Git LFS.

## Links

`docs/plans/front-end-concept.md`, ADR 0008, ADR 0017.
