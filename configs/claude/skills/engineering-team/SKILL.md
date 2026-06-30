---
name: engineering-team
description: >
  Use when the user wants a thorough, multi-dimensional review or improvement of a whole codebase:
  "evaluate this repo", "assess this project", codebase assessment, project audit, code quality
  review, technical debt analysis, architecture review, systematic bug-finding, a security review
  of a project, checking documentation accuracy against the code, or a full evaluate-plan-implement
  cycle ("improve this codebase" end to end). Also use whenever the user explicitly asks for the
  engineering team. Do NOT use for brainstorming, tradeoff discussions, or "should I use X or Y"
  questions — those belong to the brainstorming and research skills — nor for reviewing a single
  diff/PR or making a quick targeted fix.
---

# Engineering team — router

This skill orchestrates an evaluate → plan → develop → wrap-up cycle through
a lead engineer who dispatches subagents. The skill is split into a thin
router (this file) plus per-phase docs in `phases/` and cross-cutting
reference docs in `references/`.

This is the **interactive variant**: it reports progress in plain prose and
asks the user directly when input is needed. It emits no `[[engteam:...]]`
sentinels and assumes no external loop driver. If the preamble contains a
`RELAY_PHASE:` or `RELAY_RUN_DIR` line, you are in a relay-driven run —
stop and use the `engineering-team-sentinels` skill instead.

## The run directory

All artifacts for a run — `evaluation-report.md`, `improvement-plan.md`,
`discussions/`, anything else — live in a per-run directory.

- **Resuming:** if `.engineering-team/current.txt` exists and names a
  directory under `.engineering-team/runs/` that still exists, that is
  `$RUN_DIR` — you are resuming an in-flight run (unless the user asks
  for a fresh one).
- **Starting fresh:** on first write, create
  `.engineering-team/runs/manual-<utc-timestamp>/` (e.g.
  `.engineering-team/runs/manual-20260610T142500Z/`) in the project root,
  use it as `$RUN_DIR` for the rest of the run, and write its basename to
  `.engineering-team/current.txt` so later sessions can find it.

Always write to `$RUN_DIR/<artifact>` — never to
`.engineering-team/<artifact>` directly.

## Decide which phase to load

When this skill activates, your first action is to determine the current
phase and load the matching `phases/phase-N-<name>.md`. Infer the phase
from the user's request and on-disk state:

1. If `$RUN_DIR/evaluation-report.md` does not exist → load `phases/phase-1-evaluation.md`.
2. Else if `$RUN_DIR/improvement-plan.md` does not exist → load `phases/phase-2-planning.md`.
3. Else if the plan has at least one work unit not yet reported complete → load `phases/phase-3-development.md`.
4. Else → load `phases/phase-4-wrap-up.md`.

Scope the cycle by the user's verb: "evaluate" / "assess" / "review" →
run only Phase 1; "plan" → Phases 1-2; "develop" / "improve" / "fix" or
a general instruction → the full cycle (Phases 1-4; Phase 4 runs
automatically after Phase 3). After a partial cycle, the artifact is the
deliverable — offer the next phase, but do not start it unbidden.

If the user has explicitly asked for the Discussion workflow instead of
Build (e.g. "let's discuss the architecture before I commit to a plan"),
load `references/discussion.md` instead and follow it.

## Announce phase transitions

Once you've loaded the matching phase doc, tell the user which phase you
are entering in one plain-prose line (e.g. "Entering Phase 2: planning").
If a single session completes one phase and naturally begins another (e.g.
Phase 1 → Phase 2 after synthesis), announce each phase as you enter it.

## Progress, pausing, and completion

There is no machine-readable marker contract in this variant. Instead:

- **Progress:** announce work-unit starts and completions in plain prose
  ("Starting W1: <title>", "W1 done — full suite green"). Never leave a
  started unit unaccounted for: by the end of the session each started
  unit is either reported done or reported abandoned with a reason.
- **Pausing:** when a decision genuinely needs user input (see the phase
  docs for the criteria), stop work, ask the user directly — with the
  AskUserQuestion tool or a plain question — and wait for the answer
  before continuing. Do not pick on the user's behalf and do not silently
  continue.
- **Completion:** when the cycle is complete, say so plainly in the final
  summary; when stopping early, say what remains.

## Documentation formatting

Whenever this skill produces or updates any documentation — evaluation reports,
improvement plans, discussion reports, journal entries, runbooks, project docs in
`/docs/`, anything markdown — **number every heading and subheading
hierarchically using decimal notation**. The number is part of the heading text,
inside the `#` line.

Example:

```markdown
# 1. Evaluation report

## 1.1 Scope and context

## 1.2 Findings
### 1.2.1 Security
### 1.2.2 Code quality

# 2. Recommendations
## 2.1 Critical
## 2.2 Important
```

Rules:

- Apply to every level (H1 through H6).
- Restart numbering only at the top of a brand new document, not across sections.
- When you add, remove, or reorder sections during an edit, renumber the affected
  sibling and descendant headings so the sequence stays contiguous.
- This applies to docs you write directly AND to docs subagents return — if a
  subagent's report comes back without numbered headings, add the numbering
  before persisting it to disk.
- Code blocks and inline markdown inside body text are not headings and are
  not numbered.

Why: these documents are read and re-read in long form (run dirs, archived
plans, journal history). Hierarchical numbers make it trivial to reference a
specific section in conversation ("see 1.2.1") and make structural drift obvious
when sections are added or removed.

## Living-document status stamp

Any **living** document — one that describes current truth and misleads when
stale (README, spec, runbooks, architecture docs, security/controls registers,
persistent plans) — carries a status stamp as the first line under its title:

```
**Status:** active. **Last updated:** YYYY-MM-DD. **Last verified:** YYYY-MM-DD (how). **Supersedes:** <doc-or-none>.
```

- **Last updated** — when the prose last changed.
- **Last verified** — when its claims were last checked against reality (the
  code, a real run, the live config), and briefly how. Use "not yet — <reason>"
  until first verified; never leave it blank.
- When you edit a living doc, bump **Last updated**; when you confirm its claims
  still hold (e.g. a runbook executed green, settings match the remote), bump
  **Last verified** with the date and method.

Point-in-time records (ADRs, accepted RFCs, journal entries) are exempt — they
are historical by design and are allowed to age. ADRs instead carry a
`Proposed | Accepted | Superseded by <id>` status. This stamp is what lets a
reader, and the CI doc-freshness gate, tell live docs from stale ones at a
glance.

## Cross-cutting references

Load these on demand when their topic becomes relevant:

- `references/team-structure.md` — roles (lead engineer, product owner,
  engineer), output formatting, and how to ask questions.
- `references/workflows.md` — Build vs Discussion overview.
- `references/worktree.md` — working directory invariants, worktree
  isolation, linter detection.
- `references/discussion.md` — Discussion workflow details.
- `references/general-guidelines.md` — cross-cutting rules and the triage
  entry point for urgent reports.

## What this router does NOT contain

This file is intentionally short. It does NOT contain:

- Per-phase steps — those are in `phases/`.
- Team / workflow / worktree details — those are in `references/*.md`.

When in doubt, the per-phase doc is authoritative for that phase's behavior.
