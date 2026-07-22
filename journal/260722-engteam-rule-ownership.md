# A rule-ownership index for the skill

**Date:** 2026-07-22. **PR:** feat/engteam-rule-ownership. The last of the menu of
five engineering-team improvements (#4). Point-in-time record; authoritative for
nothing.

The skill's real risk isn't its size (~5,700 lines), it's **drift**: the same
load-bearing rule restated slightly differently across files, diverging over time.
The status-stamp "method must match the claim" rule already trends that way across
~7 files. `references/rule-ownership.md` maps each cross-cutting invariant to its
**single canonical home** — the one file+section you edit to change it — so a
restatement elsewhere is a pointer, not a competing source.

## The decision: ship it (not recommend against)

The brief explicitly allowed the honest outcome "an ownership index is a
maintenance liability; recommend against it." I weighed that and shipped, for
three reasons the systematic read established:

1. **Clear homes exist** for every load-bearing invariant — verification
   integrity and grading in `general-guidelines.md`, the doc model and status
   stamp in `documentation-model.md`, worktree/CI-gate laws in `worktree.md`,
   single-writer in `multi-session.md`, `$RUN_DIR`/`run.yaml`/scope/closing in
   `SKILL.md`, the findings contract in `team-structure.md`.
2. **The skill already practices ownership-pointing.** Almost every restatement
   in the phase docs *already* cites its home ("see `../SKILL.md`", "per
   `general-guidelines.md` rule 2"). The index formalizes an existing discipline
   rather than inventing one, so it fights the grain far less than feared.
3. **The rot is bounded by design.** The index is a *map, not a source*: it does
   not restate any rule (that would just add another copy to drift). It has almost
   no content that *can* go stale except the home addresses themselves — and those
   are cited by **section heading, not line number**, so ordinary edits don't
   touch them.

## How the homes were found (not from memory)

The brief warned: a stale index that lies about where truth lives is worse than
none, so you need a systematic read. I did three passes and cross-checked them:

- A **grep census** of the named invariants across the whole tree (which found,
  e.g., the status-stamp rule in 5 files, the worktree idiom in 3).
- **Two parallel catalogue subagents** — one over the eight `references/`, one
  over the four `phases/` — each returning invariant → home → restatement sites
  with `file:line`. They independently agreed on the homes and each surfaced the
  same drift-prone pairs.
- My own full reads of `SKILL.md` and `general-guidelines.md`.

Then, the anti-rot check that matters most: **every one of the 26 canonical-home
section headings the index cites was mechanically verified to resolve** in its
named file (`grep` for the heading), and the two verbatim quotes I make ("change
one, change the other in the same edit"; the doc-model→worktree gate pointer) were
confirmed at source. The index cannot silently lie about a home today.

## What the read surfaced (beyond the index itself)

- **The genuinely drift-prone pairs** — two places each stating a rule *in full*:
  the findings contract (`team-structure.md` ↔ `wide-survey.md`, already coupled
  with "change one, change the other"), the stamp size-budget (rule in
  `documentation-model.md` ↔ gate in `worktree.md`, split by design), and
  claim-≤-check vs its status-stamp specialization. §4 of the index lists them.
- **Two rules with no clean single home** — honest gaps the index names rather
  than papers over: the worktree-detection command is duplicated verbatim in
  three files (the router-shrink journal already flagged this as the remaining
  cross-file cut), and `announce-the-phase` lives as four parallel copies in the
  phase docs though `SKILL.md` §"Announce phase transitions" is the natural home.

## Verified

- All 26 cited home headings resolve (grepped, printed ok for each); the two
  quoted facts confirmed at `wide-survey.md:111` and `documentation-model.md:188`.
- `SKILL.md` change is **purely additive** (3 insertions, 0 deletions) — one
  bullet in the cross-cutting-references list — so the router comprehension-probe
  test, which detects *dropped* invariants, structurally cannot regress; not run.
- Shell CI parity green (`shellcheck`/`shfmt`/`lint-steps`) and both skill gates
  green — this change is markdown-only and touches nothing structural.

## What is deliberately not done

- **The drift-scan.** The index's value is only fully realized paired with a
  mechanical scan (grep each invariant's signature phrase; assert it appears at
  its home and that other occurrences sit next to a link rather than re-arguing
  the rule). Explicitly out of scope per the brief; noted in §5 as the natural
  follow-up. An index without a scan still answers "which file do I edit?".
- **The two gaps were surfaced, not fixed.** Consolidating the worktree-idiom
  copies and adding the `announce-the-phase` pointer are small, real follow-ups
  left as separate changes — fixing them here would have widened a
  documentation-only PR into edits across four phase docs and the router.
- **Single-home rules are not listed individually.** A rule stated in exactly one
  file has no drift risk and an obvious owner; enumerating all ~50 would add bulk
  and its own rot for no value. §2's family map still lets an editor find them.
- **Not deployed to `~/.claude`.** This PR changes the vendored source of truth
  only; deploy is a separate action (`deploy-engineering-team-skill.sh`).
