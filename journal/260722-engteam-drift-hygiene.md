# Rule-ownership hygiene: consolidate, point, and a drift-scan to enforce it

**Date:** 2026-07-22. **PR:** feat/engteam-drift-hygiene. Follows the
rule-ownership index (#41): these are the three follow-ups that index's §4/§5
named. Point-in-time record; authoritative for nothing.

The rule-ownership index mapped each load-bearing invariant to its canonical home
but left three things open: a worktree-idiom command duplicated across files, four
free-standing copies of the announce-the-phase rule, and no *mechanical* guard so
the index can't rot into a lie. All three are now closed.

## #1 — Worktree-idiom consolidation (done, honestly scoped)

The constraint was "without any loss of accuracy or functionality." The idiom (the
`--path-format=absolute` resolution and detection commands) appeared in three
places. Only one was a pure restatement:

- **phase-3-development.md** carried the `$RUN_DIR`-resolution one-liner + the
  flag lecture, and *already* pointed to `SKILL.md` "The run directory". Since the
  router (`SKILL.md`) is loaded the whole run, that command is already in context
  during Phase 3 — so replacing phase-3's copy with the pointer is genuinely
  lossless. Removed it.
- **SKILL.md and worktree.md** both keep their copies, because the router must
  resolve these *at routing time* without loading another doc — the router-shrink
  journal already weighed cutting the router's copy and rejected it. So instead of
  risky prose surgery, the duplication is now **guarded**: the drift-scan asserts
  every `git rev-parse --git-dir`/`--git-common-dir` in the skill keeps
  `--path-format=absolute`, and the resolution one-liner stays byte-identical
  across copies. Guarded duplication beats a lossy consolidation, and it's what the
  index's §5 envisioned.

## #2 — Announce-the-phase pointers (done)

Each of the four phase docs restated "announce the phase" free-standing.
`SKILL.md` §"Announce phase transitions" is the home; each phase doc's "Announce
the phase" section now names it as the home rather than restating the rule. Cheap,
as the index predicted.

## #3 — The drift-scan (`tests/engineering-team-drift/drift_scan.py`)

The mechanical half the index promised. Four checks:

- **A. Worktree idiom (HARD)** — the flag-presence + one-liner-identity guard above.
- **B. Index homes resolve (HARD)** — every `` `<file>` §"Heading" `` the index
  cites must resolve to a real heading. This is the "the index doesn't lie about
  where truth lives" check — the failure §5 calls net-negative.
- **C. Signature at home (HARD)** — each curated invariant's signature phrase must
  still appear at its home, so a home that lost its statement reds.
- **D. Un-pointered restatement (WARN)** — a signature in a non-home file that
  never references the home is reported, not failed (the skill's "anything gameable
  is a warning" rule).

It lives at repo level, not in the skill — like the probe/triggering tests, its
value is skill-*editing*, not skill-*use*, so it must not deploy to `~/.claude`.
But unlike them it is **fully headless**, so CI runs the real scan (not just a
selftest), alongside the gates. Ships with a `--selftest` that seeds a red for
each check, per the skill's own "a gate ships with a test proving it goes red."

**Building it immediately earned its keep** (confirmed): the first real run caught
two defects in my *own* index — files cited by basename (`general-guidelines.md`)
not full path, and the index's `§"Heading"` format-*example* masquerading as a
real citation. Both fixed (basename-aware resolver; angle-bracket placeholders).

## The code review, again worth more than the code (confirmed)

The pre-merge review found **four** latent correctness bugs the `--selftest`
missed — the same "I write fixtures for the failures I designed for, and miss the
inputs I didn't imagine" pattern the last three gates hit:

1. `parse_home_citations` attributed a citation to any `.md` token earlier on the
   whole line, not the current table cell — a filename in a neighbouring cell would
   cause a **false RED** on a valid index. Fixed by scoping to the cell.
2. `check_worktree_idiom` matched per physical line, so a `\`-continued
   `git rev-parse`, or a flag dropped on only one of two calls on a line, slipped
   through — a **false negative on the exact bug it exists to catch**. Fixed by
   joining continuations and checking per-invocation.
3. The `run-dir-main-checkout` signature's second alternative matched unrelated
   branch-policy prose ("main checkout, and never on `main`"), so it would pass
   even if the real `$RUN_DIR` statement were deleted. Fixed by anchoring both
   alternatives to `$RUN_DIR`.
4. `headings()` treated `#` bash-comment lines inside code blocks as headings,
   polluting check B's heading list. Fixed by making it fence-aware.

Each fix ships with a regression case in `--selftest` that reds against the old
behaviour. None of the four was caught by the original selftest — the review, not
the fixtures, is where the correctness came from.

## Verified

- `drift_scan.py --selftest` green (10 signatures; A/B/C seeded red, D warns +
  no-false-positive) and the real scan green (0 warnings, 0 failures); `ruff` +
  `py_compile` clean.
- Full CI parity green locally: `shellcheck`/`shfmt`/`lint-steps`, all three skill
  gates, the triggering-parser selftest, and the drift-scan (selftest + real).
- The doc-freshness audit caught one staleness I introduced — a "next two rows"
  reference in `docs/development.md` that my new table row invalidated — fixed.
- `SKILL.md` is **untouched** this branch (3 insertions elsewhere), so the router
  comprehension-probe test, which detects *dropped* invariants, cannot regress.

## What is deliberately not done

- **The SKILL.md↔worktree.md idiom copies were not merged into one.** Both are
  operationally required at routing time; the honest fix is guarded duplication
  (the drift-scan), not a consolidation that would cost the router its
  self-containment. Stated plainly rather than forced.
- **The drift-scan's `SIGNATURES` table is deliberately partial** — ~10
  load-bearing cross-cutting invariants, not all ~50 in the index. A signature per
  single-home rule would add maintenance for no drift risk (a single-home rule
  can't drift).
- **Check D (un-pointered restatement) stays a warning forever.** Whether a
  restatement should be a pointer is a judgement call; making it hard would red
  honest prose — the exact "switch the gate off" failure the design rules warn of.
- **The scan does not check prose *rationale* consistency**, only the mechanical
  invariants (flag presence, home resolution, signature presence). Whether two
  copies of a war-story still *say the same thing* is not mechanically checkable
  and is left to the human editor the index guides.
