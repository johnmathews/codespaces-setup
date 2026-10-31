# Footprint check as a script, and no Haiku

Follows [the mid-tier change](261031-mid-tier-model-for-bounded-dispatches.md).

## Decision

The question was whether any part of the skills could run on Haiku. Only one
dispatch was mechanical enough: the pre-PR gate's footprint check, which asks
whether a diff stayed inside the paths its units declared. A string comparison
needs no model at all, so it became `scripts/check_footprint.py` (PR #96), and
the floor stays absolute: no dispatch goes below the mid tier.

The mid-tier list is now four dispatches: the wide-survey surveyors, the
acceptance-criteria check, `/done`'s docs cross-check, and S-sized units.

## How the script reads a plan

Run against the plans already on this machine (22 run directories), it parsed all
35 units that carry a **Files (footprint):** field. Two shapes needed handling:

- numbered unit headings (`## 2.1 W1 — …`), the house style for plans;
- a repo name or note beside a backticked path, and `{a,b}` brace lists. Only
  backticked spans count as paths when the field uses backticks.

Older plans list only **Changes:**, with no footprint. For those the script
exits 2 ("cannot check") instead of guessing a footprint from prose. Exit 1 is
a file outside the footprint; exit 0 is a clean diff.

The diff is `git diff --name-only --no-renames <base>...HEAD`, so a rename
counts both paths, and uncommitted edits are not checked.

## Wiring

`ci.yml` and `/sync-skills` run its selftest, which builds its own git repo.
The docs and `CLAUDE.md` now list all five gates. Before this they named three
and left out `check_board.py`.
