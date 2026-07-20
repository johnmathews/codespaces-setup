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

## Project configuration

Some rules below reference a repo owner and a container registry. Detect
them; do not hardcode them.

- **Owner:** `git remote get-url origin`. If there is no remote, the
  default owner is `johnmathews`.
- **Registry:** default `ghcr.io/<owner>/<repo-name>`. If the project
  already publishes images somewhere else, that is the registry — read it
  out of the existing workflow rather than asserting a different one.
- **Journal:** `/journal/` at the repo root unless the project already
  keeps one elsewhere.

A work repo is not a personal repo. Guidance that assumes `johnmathews`
is wrong on a project owned by someone else, and a finding derived from
that assumption is a false finding.

## The run directory

All artifacts for a run — `evaluation-report.md`, `improvement-plan.md`,
`progress.md`, `status-<lane>.md`, anything else — live in a per-run
directory.

**`$RUN_DIR` always lives in the main checkout, never inside a worktree.**
Worktrees hold code; the main checkout holds the run. This matters for two
reasons, both of which have bitten real runs:

1. Wrap-up removes the worktree. A `$RUN_DIR` inside it would be deleted
   by the step that ends the cycle — destroying the evaluation report and
   the plan, the artifacts the whole cycle exists to produce.
2. Parallel sessions each have their own worktree (see
   `references/multi-session.md`). A per-worktree run dir means they
   cannot read each other's artifacts, which is the entire coordination
   mechanism.

So resolve the main checkout like this, and put `.engineering-team/` there:

```bash
MAIN_CHECKOUT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
RUN_DIR="$MAIN_CHECKOUT/.engineering-team/runs/<run-id>"
```

**`--path-format=absolute` is not optional.** Without it,
`git rev-parse --git-common-dir` returns a path *relative to the current
directory* (`.git` at the repo root, `../../.git` two levels down). The value
is correct where it is computed and silently wrong the moment you `cd` — which
this flow does constantly, since work happens in a worktree. A relative
`$RUN_DIR` also cannot be handed to another session, which is what
multi-session needs it for. (Needs git ≥ 2.31; on older git use
`git worktree list --porcelain | head -1 | sed 's/^worktree //'`, whose first
entry is always the main worktree.)

- **Resuming:** if `.engineering-team/current.txt` names a directory that
  still exists **and whose `run.yaml` has `phase:` other than `complete`**,
  that is `$RUN_DIR` — you are resuming an in-flight run (unless the user
  asks for a fresh one). Both halves are required: a finished run's
  directory also still exists, so existence alone cannot tell "in flight"
  from "done", and a pointer left behind by a run that ended without
  clearing it will otherwise hijack the next invocation.
- **Starting fresh:** on first write, create
  `.engineering-team/runs/manual-<utc-timestamp>/` (e.g.
  `.engineering-team/runs/manual-20260610T142500Z/`) in the **main
  checkout**, use it as `$RUN_DIR` for the rest of the run, write
  `run.yaml` (below), and write the directory's basename to
  `.engineering-team/current.txt` so later sessions can find it.
- **Housekeeping:** run directories accumulate — one repo reached 21 with
  no owner. When starting fresh, if there are more than ~10 completed runs
  under `.engineering-team/runs/`, say so and offer to delete the oldest.
  Never delete one without asking: a run dir holds the only copy of its
  evaluation report.

### `run.yaml` — the run's state, on disk

`$RUN_DIR/run.yaml` records what phase the run is in and what each work unit
has actually done. It exists because **everything else about run state was an
inference.** Phase was deduced from which files happened to exist; unit
completion was "reported" in chat prose, which does not survive the session
that said it. Both of those are the failure this skill warns about elsewhere —
a claim with no check behind it — applied to the skill's own bookkeeping.

```yaml
run: manual-20260610T142500Z
phase: 3                  # 1 | 2 | 3 | 4 | complete
scope: full               # evaluate | plan | full  (from the user's verb; set once, in Phase 1)
units:                    # mirrors the improvement plan's frontmatter; absent until Phase 2
  - { id: W1, status: done }
  - { id: W2, status: in-progress }
  - { id: W3, status: pending }        # pending | in-progress | done | abandoned
```

Three rules, and they are what make it worth having:

1. **Write it at the same moment you announce.** The prose announcement and
   the status change are one action, not two — "W2 done" in chat and
   `status: done` in `run.yaml` are written together, or the file is
   decoration. Same for entering a phase.
2. **`abandoned` needs a reason** — `{ id: W3, status: abandoned, why: <one line> }`.
   This is what stops "blocked" masquerading as "not done" across a session
   boundary, and it is the durable half of the rule that no started unit may
   be left unaccounted for.
3. **A missing `run.yaml` is not an error.** Runs created before this file
   existed don't have one, and a run dir written by hand won't either. Fall
   back to inferring from which artifacts exist (below), and write a
   `run.yaml` reflecting what you inferred, so the next session doesn't have
   to infer it again.

Always write to `$RUN_DIR/<artifact>` — never to
`.engineering-team/<artifact>` directly. Add `.engineering-team/` to the
project's `.gitignore` if it isn't already there: run artifacts are
working state, not deliverables.

## Always work in a worktree

Every phase of every Build run happens inside a git worktree on a feature
branch — not in the project's main checkout, and never on `main`. This
holds for evaluation-only runs too, not just when code changes: it is what
lets several sessions work at once without colliding, and it means the
merge step always has something to merge. An evaluation that turns up a
one-line fix becomes a code change, and by then it is too late to be on a
branch.

**First check whether you are already in one** — before creating anything:

```bash
# --path-format=absolute on BOTH sides, or this is wrong. See below.
[ "$(git rev-parse --path-format=absolute --git-dir)" \
  != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo "already in a worktree"
```

The flags are load-bearing. Bare `git rev-parse --git-dir` returns an
**absolute** path from a subdirectory while `--git-common-dir` returns a
**relative** one — the same location, rendered differently, so a string
comparison reports "different" and concludes you are in a worktree when you
are standing in a subdirectory of the main checkout. Normalise both sides
before comparing them.

- **Already in a worktree** (the user invoked the skill from one, or a
  previous phase created it) → **work in it. Do not create another.**
  Nested worktrees are always wrong here: the inner tree is orphaned when
  the outer one is removed, and it splits the work across two branches so
  the PR gets half of it. Note the branch you are on; that is the branch
  this run ships.
- **In the main checkout** → create the worktree now (`references/worktree.md`).

The full discipline is in `references/worktree.md`. Two exceptions:

- A **non-git project**, or a repo where the user declined `git init` —
  work in place; wrap-up degrades to "ask whether to commit."
- The **Discussion workflow**, which writes no code and needs no branch
  (`references/discussion.md`).

Either way `$RUN_DIR` resolves to the main checkout (above), which is why
that resolution must not depend on where you are standing.

Remember: the worktree holds code, `$RUN_DIR` stays in the main checkout
(above).

## Decide your role

Before working out the phase, work out whether this run has parallel
lanes. Read it off disk — do not guess:

1. `$RUN_DIR/progress.md` exists and names lanes → this is a multi-lane
   run. If the prompt that started this session names a lane you own
   (e.g. "you own lane B"), you are a **worker**; otherwise you are the
   **coordinator**.
2. No `progress.md` → you are **solo**. This is the default and the common
   case; nothing about single-session behaviour changes.

Roles differ in what they may write, and the rule is absolute: **one
artifact, one writer.** A worker never writes the plan or the dashboard; a
coordinator never writes a lane's status file. Load
`references/multi-session.md` before acting as either.

**The role is not fixed for the session.** A **solo** session becomes the
**coordinator** the moment Phase 2 writes `progress.md` — that file is what
makes the run multi-lane, so writing it is the promotion. From that point
the single-writer rule binds you: you own the plan, the dashboard, and
memory, and you do not write any lane's status file. Re-read your role
after Phase 2; the one you were assigned at activation is stale.

**If the user asks for parallel work up front** ("split this across
sessions", "run this in parallel"), that is a **preference, not a role** —
record it and raise it at the Phase 2 gate. You cannot coordinate a plan
that doesn't exist yet, so a fresh session that was asked for lanes is
still solo through Phases 1–2. Do not create a dashboard early to honour
the request; derive the lanes first and let the footprints decide whether
the split is real (`phases/phase-2-planning.md`, Step 3.5). If the plan
turns out not to qualify, say so and recommend solo — the user asked for
parallelism to go faster, not for ceremony.

## Decide which phase to load

Once you know your role, determine the current phase and load the matching
`phases/phase-N-<name>.md`.

**If `$RUN_DIR/run.yaml` exists, read it — then reconcile it against the
artifacts before acting on it.** `phase:` is a record, and a record can be
stale: a session that ended abruptly may have skipped its last write. Check
the cheap invariants — `phase:` of 2 or later implies `evaluation-report.md`
exists; 3 or later implies `improvement-plan.md` exists — and where the file
and the directory disagree, **the artifacts win and you correct the file.**

Trust `run.yaml` outright for what the artifacts *cannot* tell you: `scope:`,
and each unit's `status:`. Nothing on disk records those, which is the reason
the file exists at all.

That split is not fussiness. Making `run.yaml` authoritative for everything
would reintroduce, one level up, the failure it was added to fix: an absent
file triggers inference and self-corrects, whereas a **stale file lies with
authority.** A claim may not be stronger than the check behind it
(`references/general-guidelines.md` rule 2) — and that applies to the claims
this skill makes about its own state, not only to the ones it makes about
the project.

**Only if it does not**, infer from which artifacts exist — then write a
`run.yaml` recording what you concluded:

1. If `$RUN_DIR/improvement-plan.md` exists → you are at least in Phase 3;
   read the plan's frontmatter for the unit list and ask the user which
   units are done, because nothing on disk records it. Do not assume none
   are.
2. Else if `$RUN_DIR/evaluation-report.md` exists → load `phases/phase-2-planning.md`.
3. Else → load `phases/phase-1-evaluation.md`.

Check the plan **before** the report, not after. A run directory can hold a
plan and no evaluation report — the user asked for a plan directly, or the
report was written elsewhere — and the old order sent those runs back to
Phase 1 to redo an evaluation whose output already existed. Five of one
repo's 21 run directories are in exactly that shape.

Scope the cycle by the user's verb, and record it as `scope:` in `run.yaml`
so a later session does not have to re-guess it from a request it cannot
see: "evaluate" / "assess" / "review" → `evaluate`, run only Phase 1;
"plan" → `plan`, Phases 1-2; "develop" / "improve" / "fix" or a general
instruction → `full`, Phases 1-4 (Phase 4 runs automatically after Phase 3,
and **only** when Phase 3 ran). After a partial cycle, the artifact is the
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
`/docs/`, anything markdown — **number every heading hierarchically using decimal
notation, except the H1.** The number is part of the heading text, inside the `#`
line.

Example:

```markdown
# Evaluation report

> Purpose
>
> One short paragraph: what this document is for.

## 1. Scope and context

## 2. Findings
### 2.1 Security
### 2.2 Code quality

## 3. Recommendations
### 3.1 Critical
### 3.2 Important
```

Rules:

- **One H1 per document, and it is not numbered.** It is the title — there is
  only ever one, so a number adds nothing. Never open a second H1 to mean
  "part 2"; that's an H2.
- **H2 and below are numbered, starting at `## 1.`**, nesting decimally
  (`### 1.1`, `### 1.2`). The first section of a document is `## 1.`, not `## 2.`.
- The lead paragraph under the title is an unnumbered `> Purpose` blockquote.
- When you add, remove, or reorder sections during an edit, renumber the affected
  sibling and descendant headings so the sequence stays contiguous, and update any
  in-doc cross-references (`§2.1`, "see 2.3") in the same edit.
- This applies to docs you write directly AND to docs subagents return — if a
  subagent's report comes back without numbered headings, add the numbering
  before persisting it to disk.
- Code blocks and inline markdown inside body text are not headings and are
  not numbered.

Why: these documents are read and re-read in long form (run dirs, archived
plans, journal history). Hierarchical numbers make it trivial to reference a
specific section in conversation ("see 2.1") and make structural drift obvious
when sections are added or removed.

**Numbering things that outlive their position.** Section numbers move when a
document is restructured, so anything referenced from outside the document —
decisions, work units, findings — gets a **stable ID of its own** (`D1`, `W3`,
`F7`) that never changes and is never reused, rather than being cited by
section number. A decision recorded as "see 7.2" becomes a lie the moment a
section is inserted above it.

## Living-document status stamp

Any **living** document — one that describes current truth and misleads when
stale (README, spec, runbooks, architecture docs, security/controls registers,
persistent plans) — carries a status stamp as the first line under its title.

**A stamp records state; it does not narrate.** It is a fixed-size header taken
in at a glance: status, dates, one link to evidence, and the scope of what was
*not* verified. Everything else belongs in a document that owns it — cited from
the stamp by link, never copied into it.

```
**Status:** active. **Last updated:** YYYY-MM-DD. **Last verified:** YYYY-MM-DD ([evidence](link)). **Supersedes:** <doc-or-none>.
```

- **Last updated** — when the prose last changed.
- **Last verified** — when its claims were last checked against reality (the
  code, a real run, the live config). **It cites evidence; it never contains
  it** — one link out to the run, the command, or the section that holds the
  detail. Use "not yet — <reason>" until first verified; never leave it blank.
- **Covers** *(optional)* — the paths this doc describes (`infra/`,
  `src/api/**`). It lets the freshness gate ask the only question that means
  anything — *has the thing this doc describes changed since it was last
  verified?* — instead of counting calendar days. Omit it for a doc that
  describes no particular code.
- When you edit a living doc, bump **Last updated**; when you confirm its claims
  still hold, **re-stamp** — replace the date and the evidence link rather than
  appending a second one.

**Budget the stamp: ~600 characters, and gate it** beside the link and freshness
checks (`references/worktree.md`, "Documentation gates"). Land the threshold where
it **reds real documents on arrival**, so the migration lands in the same change
and the gate is real from its first run; ratchet down from there. **Never raise
the budget to turn a red doc green** — the red is the gate working, and the
overflow is content that belongs elsewhere. 600 is a starting point, not a law.

**Where the displaced prose goes:**

| Content | Destination |
| --- | --- |
| narrative, "what changed", what bit us | the journal |
| why a decision was made | an ADR |
| what the system does now | the spec body, under a heading |
| what is deployed right now | a dedicated live-state doc |
| verification state, evidence, per-pass method records | the verification doc |

Then link the destination from the stamp. Without a named destination "keep it
short" loses to the deadline, because there is nowhere obvious to put things.

**Corrections replace; they never accumulate.** A retraction is not retired by
appending it to the stamp. Fix the claim where it lives, and date the correction
in the journal. A stamp carrying its own errata grows with every fix — so the
document gets harder to read each time it gets more accurate.

**The method must match the kind of claim it certifies.** This is the rule that
makes the stamp worth anything, and it is the one most easily filled in honestly
and still got wrong. A **runtime** claim ("deployed", "live", "the worker calls
the model") requires a **runtime observation** — a run id, a job name, a log
line. Reading other documents is a valid method for a doc-derived claim and an
invalid one for a runtime claim: doc-to-doc consistency proves only that the
documents agree with each other.

The failure this prevents is real and looks like diligence. A stamp reading
`Last verified: 2026-07-15 (re-derived from RFC-0001…0006 and the spec)` was
complete, honest, and per the convention — and it certified a claim about live
model calls that had never happened. The stamp refuted itself in its own words,
and nobody noticed, because the convention never required the method to match
the claim.

So when one document mixes claim kinds, say **which claims were not
re-verified** — "verified" with no scope reads as "all of it", and a reader
without that clause is misled. **Split what that produces.** The scope is state:
one short clause in the stamp naming what is not covered. The **per-pass method
record** — which pass ran, when, how, against what evidence — is history: it goes
to a change-history section in the document body or to the journal, linked from
the stamp. That split is what stops this rule ratcheting: the protection is
per-document and bounded, the log it generates is per-pass and unbounded.

The mirror failure, and why the budget exists: across 34 living docs in one repo,
stamps had grown to **112,790 characters** — median 1,495, worst 21,096 on a
single line, the agent-facing `CLAUDE.md` at 14,826 (a six-layer dated changelog,
an evidence ledger, post-mortems about the file's own past errors, corrections to
its own prose). ~90% restated documents that already owned those facts, so the
copies drifted from their sources — one still asserted an inference its owner had
retracted. All of it passed a green doc gate that only checked the field *names*
were present. Same idiom as the failure above, opposite direction: a check that
could not fail on the defect actually present.

Point-in-time records (ADRs, accepted RFCs, journal entries) are exempt — they
are historical by design and are allowed to age. ADRs instead carry a
`Proposed | Accepted | Superseded by <id>` status. This stamp is what lets a
reader, and the CI doc-freshness gate, tell live docs from stale ones at a
glance. See `references/documentation-model.md` for which documents are living,
which are point-in-time, and why the split is drawn by path.

## Cross-cutting references

Load these on demand when their topic becomes relevant:

- `references/team-structure.md` — roles (lead engineer, product owner,
  engineer), output formatting, and how to ask questions.
- `references/workflows.md` — Build vs Discussion overview.
- `references/worktree.md` — working directory invariants, worktree
  isolation, linter detection, and the CI-gate laws.
- `references/documentation-model.md` — the six document types, authority
  precedence, explainers, and the documentation gates.
- `references/multi-session.md` — parallel lanes across sessions:
  single-writer, disjoint footprints, coordinator/worker roles.
- `references/discussion.md` — Discussion workflow details.
- `references/general-guidelines.md` — cross-cutting rules, verification
  integrity, and the triage entry point for urgent reports.

## What this router does NOT contain

This file is intentionally short. It does NOT contain:

- Per-phase steps — those are in `phases/`.
- Team / workflow / worktree details — those are in `references/*.md`.

When in doubt, the per-phase doc is authoritative for that phase's behavior.
