# Hardening /done, and guarding the commands' worktree idiom

**Date:** 2026-07-22. **PR:** feat/engteam-done-hardening. Follow-on to the
command→skill link-check (#43): the same session's review of `/done` surfaced a
list of improvements; this lands the ones worth landing. Point-in-time record;
authoritative for nothing.

## Context

`/done` and `/merge-push` are vendored slash commands (`configs/claude/commands/`),
deployed alongside the engineering-team skill but not part of it. #43 added a
link-check for their *cross-references* into the skill. Reviewing `/done` itself
turned up five candidate improvements; the user picked all five, but one changed
shape once I checked the coupling.

## What shipped

**1. The commands' worktree idiom is now guarded (the load-bearing change).**
`done.md`, `merge-push.md`, and `prompt.md` all embed the worktree-detection idiom
`git rev-parse --path-format=absolute --git-common-dir`. The drift-scan's check A is
exactly the guard for "a `git rev-parse --git-*-dir` that dropped
`--path-format=absolute`" — but its corpus was `SKILL.rglob("*.md")`, so it never
looked at `configs/claude/commands/`. The command copies were unguarded: drop the
flag from one and nothing reds. Widened check A's corpus (only A) to include the
command files, with selftest assertions that the corpus actually reaches them.
**Verified by seeding:** removing the flag from `merge-push.md` made the real scan
exit 1 naming `commands/merge-push.md`; restoring went green. This is the same
"commands ship separately, so they fall outside the skill-scoped guard" gap that
motivated #43 — same class, different invariant.

**2–5. `/done` editorial improvements:**
- A scannable "Phase checklist" block near the top — one imperative line per phase,
  authoritative rules still below.
- That block also makes the phase **numbering self-documenting** (`7b`/`8c` are full
  phases; `8a`/`8b` are branches of Phase 8) — see the decision below for why this
  replaced a renumber.
- A `ghcr.io` owner guard in Phase 1: `<owner>` is read from `git remote`, **never**
  hardcoded (not even to `johnmathews`), so a future edit can't regress the
  deliberate generalization of the personal-default convention.
- A Phase 5 loop-back note: on a re-pass, re-audit **only** the doc surfaces the
  review fixes touched (or carry the prior Phase 2 result forward explicitly),
  rather than blindly re-dispatching the whole subagent audit — which burns a pass
  and tempts the self-certification Phase 2 exists to prevent.

## The decision that changed: renumber → self-document

The original suggestion for the phase-numbering smell (`7b`, `8c`, `8a`/`8b`) was a
clean sequential renumber. Checking first (`grep -rn "Phase"` across the skill)
showed the numbers are **load-bearing cross-references**: `phase-3-development.md`
says "its Phase 7b" and `phase-4-wrap-up.md` says "its Phase 8", both pointing at
`/done`'s numbering. A renumber would silently rot those two references — the exact
rot the drift-scan and #43 exist to prevent — for purely cosmetic gain. So instead
of renumbering, the checklist block documents the numbering in place: zero ripple,
skill references stay valid.

## Verification

`confirmed` (observed): full local CI-equivalent suite green after all edits —
drift-scan (selftest + real, now spanning commands), command-link check, the three
skill gates, the triggering parser selftest, `ci/lint-steps.sh`. The seeded-red test
for the widened check A was run and observed to red on the right file and go green on
restore. `shellcheck`/`shfmt` are out of scope for this change (no shell touched).

## What is deliberately not done

- **No full phase renumber of `/done`** — see the decision above; the cross-file
  coupling makes it net-negative.
- **The skill→`/done` phase-number references are still unguarded.** "its Phase 7b"
  / "its Phase 8" in the skill would rot if `/done` is ever renumbered. Noted as a
  possible future guard (a check that those referenced numbers resolve to real
  `/done` phase headers), not built here — it's speculative until a renumber is
  actually on the table.
- **The Phase 4 / Phase 5 security overlap in `/done`** (secrets scan vs. the code
  review's security bullet) was left as-is; the dedup is a judgement call, not a
  fault.
