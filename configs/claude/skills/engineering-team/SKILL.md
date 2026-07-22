---
name: engineering-team
description: >
  Use when the user wants a thorough, multi-dimensional review or improvement of a whole codebase:
  "evaluate this repo", "assess this project", codebase assessment, project audit, code quality
  review, technical debt analysis, architecture review, systematic bug-finding, a security review
  of a project, checking documentation accuracy against the code, or a full evaluate-plan-implement
  cycle ("improve this codebase" end to end). Also use whenever the user explicitly asks for the
  engineering team. Also covers architecture and tradeoff discussion grounded in a specific
  codebase — "should we use X or Y here", "walk me through the options", "what would change if
  we moved to Z" — via its Discussion workflow, which explores without touching code. Do NOT use
  for a standalone research question with no codebase in play ("what is the state of the art in
  X") — that is the deep-research skill — nor for reviewing a single diff/PR or making a quick
  targeted fix.
---

# Engineering team — router

This skill orchestrates an evaluate → plan → develop → wrap-up cycle through
a lead engineer who dispatches subagents. The skill is split into a thin
router (this file) plus per-phase docs in `phases/` and cross-cutting
reference docs in `references/`.

It reports progress in plain prose and asks the user directly when input is
needed. There is no machine-readable marker contract and no external loop
driver: a human is in the loop at every gate.

## Project configuration

Some rules below reference a repo owner and a container registry. Detect
them; do not hardcode them.

- **Owner:** `git remote get-url origin`. **If there is no remote, ask —
  there is no default owner.** There used to be one, and it needed three
  separate warnings elsewhere in the skill to stop it doing damage. A
  default that has to be argued down at every use site is not a default;
  it is a wrong answer with a disclaimer attached.
- **Registry:** default `ghcr.io/<owner>/<repo-name>`. If the project
  already publishes images somewhere else, that is the registry — read it
  out of the existing workflow rather than asserting a different one.
- **Journal:** `/journal/` at the repo root unless the project already
  keeps one elsewhere.

A work repo is not a personal repo. Guidance that assumes an owner is
wrong on a project owned by someone else, and a finding derived from that
assumption is a false finding.

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

**Checked mechanically.** `scripts/check_run.py "$RUN_DIR"` validates this
file's schema (the `phase`/`scope`/`status` enums, and that an `abandoned`
unit carries a `why`) and reconciles `phase:` against the artifacts on disk —
the same cheap invariants "Decide which phase to load" reasons about, but as a
gate that exits non-zero rather than prose you have to remember. Run it when
you resume a run and after you rewrite `run.yaml`. A `phase:` that claims an
artifact which is not there is the "lies with authority" failure this section
exists to prevent; this is the check behind that claim.

Always write to `$RUN_DIR/<artifact>` — never to
`.engineering-team/<artifact>` directly. Add `.engineering-team/` to the
project's `.gitignore` if it isn't already there: run artifacts are
working state, not deliverables.

## Always work in a worktree

Every phase of every Build run happens inside a git worktree on a feature
branch — not in the project's main checkout, and never on `main`. This
holds for evaluation-only runs too, not just when code changes, for two
reasons: it lets several sessions work at once without colliding on the
shared main checkout, and work grows. An evaluation that turns up a
one-line fix becomes a code change, and by then it is too late to be on a
branch.

Note what the rule is *not* justified by: an evaluation-only run leaves the
worktree with **zero commits**, because its only output is the report and
that lives in `$RUN_DIR` in the main checkout, gitignored. So "the merge
step always has something to merge" is false here — and a rationale an
agent can disprove is one it will discount when the rule is inconvenient.
The two reasons above are the real ones and they are sufficient.

An empty worktree still has to be cleaned up, and no phase doc does it for
a run that stops at Phase 1 or Phase 2. "Closing a run" below is what
removes it.

**First check whether you are already in one** — before creating anything:

```bash
# --path-format=absolute on BOTH sides, or this is wrong. See below.
[ "$(git rev-parse --path-format=absolute --git-dir)" \
  != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo "already in a worktree"
```

The flags are load-bearing, for the same reason spelled out under "The run
directory" above: bare `git rev-parse` renders these paths absolute from a
subdirectory but relative from the root, so a string comparison of the
un-normalised forms reports a false difference and concludes you are in a
worktree when you are in a subdirectory of the main checkout. Normalise both
sides before comparing.

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

Either way `$RUN_DIR` resolves to the main checkout, which is why that
resolution must not depend on where you are standing.

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

## Closing a run

**Every run closes itself, whatever its `scope:`.** Once the last phase
that scope calls for has produced its artifact, do these three things — in
the **main checkout**, where `$RUN_DIR` lives, never in the worktree:

1. **Remove the worktree this run created, if it holds zero commits**
   (`git worktree remove <path>`, then delete the branch). If it holds
   commits, do not remove it: say what is on it and ask what to do with it.
   An evaluation-only run normally leaves it empty.
2. **Set `phase: complete`** in `$RUN_DIR/run.yaml`.
3. **`rm -f .engineering-team/current.txt`.**

Then state in one line what the scope was and what the next phase would
be, so the artifact reads as a finished deliverable rather than an
interrupted run. Offer the next phase; do not start it unbidden.

`full` reaches this through Phase 4's Step 4, which does the same three
things after the merge. `evaluate` and `plan` reach it at the end of Phase
1 and Phase 2 respectively — they have no Phase 4, which is exactly why the
step has to live here rather than only there. A scope that never closes
leaves its worktree and branch behind and leaves `current.txt` naming a
finished run. **Both of those were observed** — two evaluation-only runs of
this skill on identical repos, one before this section existed and one
after, differed in exactly those artifacts and in nothing else.

Whether the stale pointer then *hijacks* the next invocation depends on
`run.yaml`: the resume rule above skips a run marked `complete`, so the
hijack fires only when `phase:` is stale too. Do not read that as a safety
margin. It means the failure is intermittent rather than certain — which is
the kind that survives testing and shows up later.

**Do not close a run that ended early** — a question still outstanding, a
unit abandoned mid-flight, a lane unmerged. Leave `phase:` where it is and
leave the pointer in place; that is what lets a later session resume.

## Progress, pausing, and completion

There is no machine-readable marker contract. Instead:

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

## Writing documentation

This skill has strong conventions for any documentation it produces or touches —
evaluation reports, plans, journal entries, project docs in `/docs/`, anything
markdown. They are **not** in this file, because they are only needed when you
are actually writing a document, and this file is loaded on every invocation:

- **Heading numbering** — one unnumbered H1; H2 and below numbered decimally
  from `## 1.`; a `> Purpose` blockquote as the lead. Applies to docs you write
  *and* to docs subagents hand back.
- **The living-document status stamp** — what it records, the ~600-character
  budget, where displaced prose goes, and the rule that carries it: **the
  verification method must match the kind of claim it certifies.** A runtime
  claim needs a runtime observation; reading other documents proves only that
  the documents agree.
- **Stable IDs** (`D1`, `W3`, `F7`) for anything referenced from outside a
  document, since section numbers move.

All of it lives in `references/documentation-model.md` — load that before
writing or auditing docs.

## Cross-cutting references

Load these on demand when their topic becomes relevant:

- `references/team-structure.md` — roles (lead engineer, product owner,
  engineer), output formatting, and how to ask questions.
- `references/workflows.md` — Build vs Discussion overview.
- `references/worktree.md` — working directory invariants, worktree
  isolation, linter detection, and the CI-gate laws.
- `references/documentation-model.md` — the six document types, authority
  precedence, explainers, the documentation gates, **and how to write a doc**:
  heading numbering, stable IDs, and the living-document status stamp.
- `references/multi-session.md` — parallel lanes across sessions:
  single-writer, disjoint footprints, coordinator/worker roles.
- `references/discussion.md` — Discussion workflow details.
- `references/general-guidelines.md` — cross-cutting rules, verification
  integrity, how findings are graded, and the triage entry point for
  urgent reports.
- `references/wide-survey.md` — the Workflow fan-out for Phase 1
  reconnaissance on large projects. Loaded only after the user agrees to
  one; Phase 1's Step 2 decides whether to offer it.
- `references/rule-ownership.md` — for **editing** this skill, not running it:
  the map of which file owns each load-bearing invariant, so a restatement is a
  pointer rather than a competing source. Consult it before changing a rule.

## What this router does NOT contain

This file is intentionally short: per-phase steps live in `phases/` and
team / workflow / worktree details in `references/*.md` (listed above). When
in doubt, the per-phase doc is authoritative for that phase's behavior.
