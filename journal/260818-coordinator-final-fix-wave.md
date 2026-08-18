# Final fix wave on the coordinator-sessions branch — two Criticals, both fail-open

**Date:** 2026-08-18. **Branch:** `feat/coordinator-sessions`. A whole-branch review
returned *not fit to merge*; this is the single pass that answered it. Full
before/after in
`.superpowers/sdd/2026-08-18-coordinator-sessions/final-fix-report.md`.
Point-in-time record; authoritative for nothing.

## The two that mattered

**A gate that hard-failed an honest board.** `check_board.py` selected contract
entries with `startswith("C")` over the *whole* `## 3. Contract register` section —
which holds two tables. The reservations row `| Config keys / env vars | … |` starts
with "C", so a board copied verbatim from the protocol's own §4.2 produced three
errors. This is the second time on this branch that the same defect class shipped
(the first rejected `pyproject.toml`), and it is the exact failure gate-design rule 1
names: *an honest plan trips it and the gate gets switched off.*

The lesson generalises past this script: **a check that selects rows by prefix from a
section containing more than one table is selecting by luck.** Selection is now by row
shape — five cells and an ID matching `C\d+`. Chasing it turned up a second bug
underneath: `_cells` split on every `|`, and a contract cell legitimately contains
`Account \| None`, so the shape test would have silently emptied the register and
disabled E4/E6 with it. Neither E4 nor E6 had a fixture, so nothing would have said
so. They have fixtures now.

**A barrier whose trigger was undefined.** `done.md` §`8a` item 1 used `$RUN_DIR`,
`$LANE` and `$UNIT` — none defined anywhere in `done.md`, which runs standalone
without the skill loaded. Unset `$RUN_DIR` made the guard test `/progress.md`, always
absent, so the whole gate step was silently skipped. Three fail-open bugs in this one
predicate now, which is why it finally got committed fixtures.

The interesting part was the fix's shape, not the bug. "Default to stop" is wrong:
`/done` runs on ordinary work far more often than on lanes, and a barrier that stops
by default gets switched off within a day. What closes the hole is making every
continue answer a **positive finding** and enumerating all four branches, including
the one nobody writes down — *identifier unresolvable → stop and ask the human.* An
unresolvable identifier is never evidence that no gate is needed. Two-way tests are
where fail-open lives; the unknown case has to be written out or it defaults to
whichever branch the `if` falls through to.

## Two smaller things worth remembering

**The gate is per unit; the PR is per lane.** Nothing reconciled them. A lane carrying
W1 (PASS) and W3 (never gated) opened its PR citing W1 and pushed both. The barrier
now needs a PASS for every non-merged unit on the lane. Worth noting that extracting
that unit list hit the *same* two-tables trap as Critical 1 — the register's rows look
like board rows — and had to be bounded to the status-board section.

**"Phase 8 step 0" never existed.** The barrier is section `8a`, item 1, and was cited
by the wrong address in nine places — including inside the edit-together pair whose
entire job is keeping that address in sync. The link-check verifies file paths, not
step numbers, so nothing caught it for the life of the branch. A citation that names a
structure inside a file is only as good as the check that resolves it, and we have no
such check.

## What is still not cleared

The red-team gate remains **PARTIALLY SATISFIED, NOT PASSED**: injections 4 (stall
protection) and 5 (`ADVISE` propagation) need live coordinator and worker sessions and
have never been observed to fire. The design doc now says so in its status stamp
rather than reading as a finished spec, and §6.5's scorecard was downgraded from
"three rules remain policy" to four policy plus one partly structural — the
"coordinator cannot assign work" row was graded structural on the strength of a prose
rule, when `SendMessage` takes free text and nothing rejects an `ADVISE` that assigns.

A human opening live sessions for injections 4 and 5 is the remaining gate before this
protocol touches real work.
