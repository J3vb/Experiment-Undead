---
name: design-change
description: Change a game rule or number (gun damage, prices, round health, spawn rules, XP, loot) or add content so it stays in line with the design docs and balance sheet. Use before editing content/*.tres balance values, WaveRules, EconomyRules or design docs.
---

# Make a design or balance change

## Where the truth lives (in this order)

1. **Code and `content/*.tres`**: what the game does now.
2. **`docs/DECISIONS.md`**: what was built, simplified or changed on purpose.
3. **`docs/design/*.md`**: the design targets (game-design, maps, zombie-ai,
   game-feel, affixes, ...). Start at `docs/design/README.md`.
4. **`docs/design/balance/*.csv`**: export of the balance sheet. `weapons.csv`,
   `enemies.csv`, `rounds.csv`, `economy.csv`, `prices.csv`, `ttk.csv`,
   `xp_and_levels.csv`, `loot.csv`. `issues.csv` lists known balance problems.

If two of them disagree, follow the higher one and say so in the PR.

## Steps

1. **Find the number in the sheet.** Look it up in the CSV by its `id`
   (same id as the `.tres` file name, e.g. `kestrel_smg`).
2. **Scale it.** Gun damage in the game is sheet damage x **0.57** (provisional,
   see `DECISIONS.md`). Example: Kestrel 26 -> 14.82. Other numbers (prices,
   health, mag sizes, RPM) are used as they are.
3. **Change data, not code.** A new gun, zombie, wave mix or serum is a new
   `.tres` in `content/<type>/`. Never change a loaded `.tres` at run time.
4. **Check the knock-on numbers** in the CSV for the row you touched:
   shots to kill a round-1 Shambler, TTK at your round, DPS per 1000 points,
   wall ammo price. If your change moves one of them a lot, say which and why.
5. **Check the pillars** (`docs/PROCESS.md`): Guns feel great / The pressure
   always builds / Every run makes you stronger. A change that weakens one
   needs a reason in the PR.
6. **Use the design doc's names** (`SpecimenVault`, `MedDispenser`,
   `Reforger`, `WeaponData`, `WaveRules`, ...) and the names in
   `docs/design/lore.md` for anything players read.
7. **Record it.** Different from the doc or sheet on purpose? Add one line to
   `docs/DECISIONS.md` under the right heading: what, why, what it replaces,
   and mark it *provisional* if it still needs a play-test.
8. **Test it.** Add or update a test in `tests/content/` that locks the new
   number (see `test_kestrel_smg.gd`, `test_talon_dmr.gd`). The test checks the
   value and, where it matters, the result (e.g. a headshot still kills a
   round-1 Walker).

## Bigger changes

A change to a pillar, the scope, a whole system or the roadmap: write the
`DECISIONS.md` entry first and ask the person before building (`docs/PROCESS.md`,
Change control). New ideas go in an **Idea** issue, not straight into the game.

## Updating the design copies

The CSVs and `docs/design/*.md` are copies of the person's design docs and
balance sheet. Do not edit them to match your change; record the difference in
`DECISIONS.md` instead. Only refresh them when the source doc changed.

## PR checklist

- Old value -> new value, and the sheet row it came from.
- Which knock-on numbers moved.
- `DECISIONS.md` line added (or "matches the sheet").
- Test that locks it.
- Label `balance` for number changes, `new` for new content.
