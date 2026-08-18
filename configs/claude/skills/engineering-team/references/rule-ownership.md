# Rule ownership index

> Purpose
>
> For each load-bearing invariant this skill enforces, name its **single
> canonical home** — the one file and section you edit to change the rule — so a
> restatement anywhere else is a *pointer*, not a competing source of truth. This
> is a **map, not a source**: it deliberately does **not** restate the rules
> (that would just add one more copy to drift). It says where they live. When a
> rule and this index disagree about *what the rule says*, the rule's home wins;
> when they disagree about *where the rule lives*, this index is wrong and should
> be fixed.

## 1. How to use it

- **Changing a rule:** edit it at its canonical home (below), then scan the
  "also stated in" files and update any pointer whose *quoted* wording went
  stale. A restatement should point home and not re-argue the rule.
- **Adding a restatement:** when a phase doc or reference needs a rule it doesn't
  own, state the one-line application and link the home — do not paste the
  rationale/war-story. Those live at the home so there is one place to edit them.
- **Anchors are section headings, not line numbers**, because line numbers rot on
  the first edit above them. `<file>` §<heading> is the durable address.
- This index lists the **cross-cutting** invariants — the ones stated in one file
  and applied in others, where drift is possible. A rule that appears in exactly
  one file owns itself; §2 tells you which file that would be.

## 2. Homes at a glance — which file owns which family

| Home file | Owns (rule families) |
|---|---|
| `references/general-guidelines.md` | verification integrity (claim ≤ check, "green" is named, exemptions expire, caller can't verify callee); evidence grading + severity; disconfirmation; subagent independence / shared priors; structural-enforcement-over-policy; triage; Playwright/UI verification |
| `references/documentation-model.md` | the six doc types; authority precedence; living-vs-point-in-time (split by path); heading numbering + stable IDs; the living-document **status stamp** incl. "method matches the claim" and the stamp size-budget *rule* |
| `references/worktree.md` | worktree isolation + the **detection idiom**; "already in one → don't nest"; project-conventions-outrank-defaults; linter setup; the **documentation gates**, the **make-a-check-required laws**, and "gate the code no other gate reads" |
| `references/multi-session.md` | single-writer / one-artifact-one-owner; disjoint file footprints; append-only coordinator-owned plan; never-touch-another-lane's-worktree; the multi-session invariant list |
| `references/coordination-protocol.md` | the three planes (control / state / sensing); the six-type message vocabulary + the mandatory `ref`; the blocking pre-PR gate + its four CHANGES criteria + the round limit; the contract register + unit zero + the integration gate; the sense-don't-act autonomy boundary |
| `references/team-structure.md` | the **findings contract**; dispatch mechanics + the read-the-roster rule; numbered-lists-to-the-user; clarifying-questions-first |
| `SKILL.md` (router) | `$RUN_DIR`-in-the-main-checkout + the **`run.yaml`** state rules; owner detection (no default owner); scope-by-verb + phase reconciliation; closing-a-run; announce-the-phase |
| `references/workflows.md` + `references/discussion.md` | Build-vs-Discussion boundary (needs a codebase, else deep-research); discussion-changes-no-code; phase-invocation mapping |
| `references/wide-survey.md` | the Phase-1 fan-out: coverage-not-independence, say-so-if-capped, merge-keeps-strongest-never-raises-a-grade |

## 3. Cross-cutting invariants → canonical home

Grouped by home. "Also stated in" lists files that apply/restate the rule and
should point here.

### Homed in `general-guidelines.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| A claim may not be stronger than the check behind it (runtime claim needs a runtime observation) | §"Verification integrity" rule 2 | `documentation-model.md` §8 (the doc-stamp specialization); `worktree.md`; phases 1, 4 |
| A check that cannot fail is not evidence; "green" is a named, executed check | §"Verification integrity" rules 1 & 3 | `worktree.md`; `wide-survey.md`; phases 1, 4 |
| A new gate ships with a test proving it goes red | §"Verification integrity" (rule 1 corollary) | `documentation-model.md` §6; `worktree.md`; phases 1, 2 |
| Grade every finding [VERIFIED]/[SUPPORTED]/[SUSPECTED], naming what earned it; SUSPECTED is the default | §"Grade every finding…" | `team-structure.md` (findings contract); `wide-survey.md` (schema); phases 1–4 |
| Severity is the cost if true, independent of grade | §"Severity: what it would cost if it is true" | `team-structure.md`; phase 2 (orders by it, does not redefine) |
| Name what would refute a load-bearing finding, then make that (differing) observation | §"Name what would refute it…" | `wide-survey.md`; phases 1, 2, 3 |
| Subagents share priors — agreement is not independence; more skeptics ≠ more evidence | §"General Guidelines" (Subagent coordination) | `wide-survey.md`; phase 1 |
| Prefer structural enforcement to policy | §"Prefer structural enforcement to policy" | `team-structure.md` (schema makes ungraded findings unrepresentable) |

### Homed in `documentation-model.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| Status stamp: the verification method must match the kind of claim it certifies | §8 "The living-document status stamp" | `SKILL.md` §"Writing documentation"; `worktree.md` (freshness gate); `general-guidelines.md` rule 2 (general form); phases 1–4 |
| Status-stamp size budget: ratchet down, never raise to turn a red doc green | §8 (rule + rationale) | `worktree.md` §"Documentation gates" (the *gate*) — split by design, cross-linked |
| Heading numbering (decimal, one H1) and stable IDs (`D1`/`W3`/`F7`) | §7 "Heading numbering and stable IDs" | `SKILL.md` §"Writing documentation"; phase docs; `multi-session.md` (stable W-ids) |
| Living vs point-in-time is drawn by path (`journal/`, `docs/adr/`, `docs/rfc/` are exempt) | §3 | `worktree.md` (gate excludes by path) |

### Homed in `worktree.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| Worktree-detection idiom: compare `--git-dir` vs `--git-common-dir` with `--path-format=absolute` **on both sides** | §"Worktree Isolation" | `SKILL.md` §"Always work in a worktree" carries the same command (both needed at routing time); the drift-scan (§5) holds the two byte-identical |
| Always work in a worktree; already in one → don't nest a second | §"Worktree Isolation" | phases 1, 3, 4; `multi-session.md` (assumed throughout) |
| Doc freshness is change-driven (`git log` over covered paths), not a calendar | §"Documentation gates" | `documentation-model.md` §6 (points here) |
| The laws for promoting a check to required (unfiltered triggers, aggregator name, required ≠ enabled) | §"Making a check required…" | phase 4 (points here) |
| Project conventions outrank this skill's defaults | §"The project's own conventions outrank this skill's defaults" | phase docs (branch/journal/docs locations are defaults) |

### Homed in `multi-session.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| One artifact, one writer (single-writer per artifact) | §2 "The core rule: one artifact, one writer" (and §7) | `SKILL.md` §"Decide your role"; phases 2, 3 |
| Disjoint file footprints per lane; any overlap → same lane | §3 | phase 2 (lane derivation) |
| The plan is append-only and coordinator-owned; W-ids never reused/renumbered | §8 | phase 2; `documentation-model.md` §7 (why IDs are stable) |
| Never touch another lane's worktree, even when it looks idle | §9 | phase 4 / `/done` housekeeping (propose-and-confirm) |

### Homed in `coordination-protocol.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| The state plane is tiered by write semantics: overwrite surfaces (files, issue/PR bodies) take one writer; append-only surfaces (issue/PR comments) take many, safely | §1 "The three planes" | `multi-session.md` §2 (the single-writer rule this qualifies) |
| Messages carry no state — every message names a `ref` to where the fact is written | §2 "The message protocol" | `multi-session.md` §7 (pointer); phase 3 |
| No message type can assign work; sense autonomously, act only on request | §5 "Sensing and the autonomy boundary" | `multi-session.md` §7 (pointer); phase 3 |
| The gate blocks before the PR exists; CHANGES for exactly four falsifiable reasons; escalate after two rounds | §3 "The gate" | `commands/done.md` Phase 8 step 0 (the **enforcement** — see §4); phase 3 |
| Contracts are frozen and coordinator-owned; a non-empty register requires unit zero | §4 "Interface contracts and unit zero" | phase 2 Step 3.5 |
| A coordinator writes no code and runs no lane | `multi-session.md` §5.1 | §1 here (pointer) |

### Homed in `SKILL.md` (the router)

| Invariant | Canonical home | Also stated in |
|---|---|---|
| `$RUN_DIR` lives in the main checkout, never inside a worktree | §"The run directory" | `worktree.md`; `multi-session.md`; phases 1, 3, 4 |
| `run.yaml` state rules: write-at-announce, `abandoned` needs a `why`, a missing file is not an error, phase reconciles against artifacts | §"The run directory" | phases 1–4; `multi-session.md` (coordinator-owned) |
| No default repo owner — read the remote, ask if none | §"Project configuration" | `worktree.md` |
| Scope by the user's verb (evaluate/plan/full); scope gates what may merge | §"Decide which phase to load" | phases 1, 2, 4 |
| Closing a run: three steps, in the main checkout | §"Closing a run" | phases 1, 2, 4 |
| Announce the phase in one plain-prose line | §"Announce phase transitions" | phases 1–4 (four parallel copies — **see §4**) |

### Homed in `team-structure.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| The findings contract (one shape: severity, grade, title, location, evidence, detail, `covered`) | §"The findings contract — every brief carries it" | `wide-survey.md` (the machine form — the file says "change one, change the other in the same edit"); phases 1–3 |
| Read the agent-type roster the session provides; never name a type from memory | §"Choosing an agent type" | phases 1, 3 |

## 4. Edit-together pairs, and the two rules with no single home

These are where drift actually happens — two places each stating a rule *in full*.

1. **Findings contract** — `team-structure.md` §"The findings contract" ↔
   `wide-survey.md` §"The script". Already coupled: wide-survey says "change one,
   change the other in the same edit." Keep it that way.
2. **Status-stamp size budget** — rule/rationale in `documentation-model.md` §8 ↔
   the *gate* in `worktree.md` §"Documentation gates". Split by design (rule vs
   enforcement) and cross-linked both ways; keep the number in sync.
3. **Claim-≤-check vs the status-stamp specialization** —
   `general-guidelines.md` rule 2 states the general principle;
   `documentation-model.md` §8 states its doc-stamp instance. They share a
   war-story pattern and can diverge; edit the general form first.
4. **The gate rule vs its enforcement** — the rule in
   `coordination-protocol.md` §3 "The gate" ↔ the barrier in
   `commands/done.md` Phase 8 step 0. Split by design (rule vs enforcement),
   exactly like the status-stamp pair above. If the gate-file name or its
   `Verdict PASS` line changes in one, it must change in the other in the same
   edit, or `/done` silently stops gating.

Two rules used to lack a clean owner; both are now resolved:

- **The worktree idiom** (the `--path-format=absolute` resolution and detection
  commands). `phase-3-development.md`'s copy was a pure restatement and now points
  to `SKILL.md` §"The run directory". The two remaining copies —
  `SKILL.md` and `worktree.md` §"Worktree Isolation" — are both operationally
  required (the router must resolve these at routing time without loading another
  doc), so they are **kept but guarded**: the drift-scan (§5) asserts every
  `git rev-parse --git-dir`/`--git-common-dir` in the skill keeps
  `--path-format=absolute` (dropping it — the actual bug — reds), and that the
  `$RUN_DIR`-resolution one-liner stays byte-identical across its copies.
  `worktree.md` remains the home for the *rationale*.
- **Announce-the-phase.** `SKILL.md` §"Announce phase transitions" is the home;
  each phase doc's "Announce the phase" section now names it as such rather than
  restating the rule free-standing.

## 5. What this is not, and the follow-up

- **Not a source.** The rules live at their homes; this only maps them. Do not
  cite this file *as* the rule.
- **Mechanically checked.** A **drift-scan** (`tests/engineering-team-drift/`,
  wired into CI) now enforces the parts of this index that are unambiguous: every
  `<file>` §<heading> home this index cites must resolve to a real heading; each
  catalogued invariant's signature phrase must still appear at its home; and every
  duplicated worktree-idiom command must keep its `--path-format=absolute` flag
  (with the resolution one-liner identical across copies).
  Occurrences of a signature phrase outside its home are reported as **warnings**
  (a restatement that should be a pointer is a judgement call, not a mechanical
  fault). Run it after editing this index or moving a rule.
- **A stale index is worse than none.** If you rename a section or move a rule's
  home, update the affected row here in the same edit — the map lying about where
  truth lives is the one failure mode that makes it net-negative, and the
  home-resolution check above is what reds when it happens.
