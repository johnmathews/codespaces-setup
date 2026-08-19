# Multi-session coordination

> Loaded when a run has parallel lanes — by the router when it detects a role,
> by Phase 2 when deriving lanes, and by Phase 3 when acting as coordinator or
> worker. Describes how several independent Claude Code sessions work one plan
> without corrupting each other's state or losing what they learn.

This model is proven, not theoretical: one coordinator plus three worker sessions
merged six work units through file-disjoint PRs with **zero conflicts** and no
rebases.

## 1. The two failure modes it designs out

Parallel sessions don't share a conversation. They can't see each other's work,
and they merge into one `main` under squash-only, linear history, and no stacked
PRs. Two things must be made impossible:

1. **State corruption** — two sessions writing the same file (tracking *or*
   source) and clobbering each other.
2. **Lost knowledge** — a session discovers a gotcha, and it evaporates when that
   session ends, or never reaches the others.

## 2. The core rule: one artifact, one writer

Every artifact has **exactly one owner that writes it**; everyone else reads.
This is what makes concurrency safe **without locks**: there is never a
concurrent write to reconcile, so there is never a conflict to resolve.

| Artifact | Sole writer | Purpose |
| --- | --- | --- |
| `improvement-plan.md` | coordinator | the **what** — units, specs, acceptance criteria. Source of truth |
| `run.yaml` | coordinator | the **state** — phase, scope, per-unit status (`../SKILL.md`) |
| `progress.md` | coordinator | the **where** — live status board + the contract |
| `status-<lane>.md` | that one lane | its ticks, **surprises**, blockers |
| `journal/YYMMDD-*.md` | that one lane (via `/done`) | the durable, committed record |
| PR body and comments | that one lane | live progress, visible cross-session via `gh` |
| Memory (auto-memory) | coordinator | cross-session recall; the hook a fresh session loads |

No file is written by two sessions. That single fact is the whole trick.

**`run.yaml` follows the plan, not the lane.** A worker does not edit it, even
to mark its own unit done — it records ticks in `status-<lane>.md` and on its
PR, and the coordinator folds them in during reconciliation (§5.1). On a solo
run there is one session and no ambiguity: it writes `run.yaml` directly, which
is the ordinary case. The exception exists only so that the promotion from solo
to coordinator does not change who owns the file.

All of these except the journal and the PR live in `$RUN_DIR`, which is in the
**main checkout** — never inside a worktree, or the other sessions cannot read it
(see `../SKILL.md`, "The run directory").

## 3. The same rule applied to code: disjoint file footprints

Decompose the plan into **lanes whose file footprints do not overlap**, so their
PRs never conflict and merge in **any order, with no rebases**. In a squash /
no-stacked-PR repo this is the only way to truly parallelise.

**Derive lanes mechanically, before splitting.** List each unit's file footprint
(Phase 2 records this on every unit). Then:

> **Any overlap → same lane.**

Units that share a file are **not** parallelised. They are merged into one lane
and one PR, or sequenced so the second rebases onto the first. Forcing
shared-file units to run in parallel reintroduces exactly the conflicts this
avoids.

A worked example: two units both touched `pyproject.toml`, the lockfile, and
`config.py`, and one reused a setting the other added — so they became **one
lane**, not two colliding PRs. The check is mechanical and takes a minute; the
conflict it prevents costs an afternoon.

**When there is genuinely no way to avoid a shared seam**, say so on the
dashboard and name the merge order: the later lane rebases onto `main` and
reconciles the seam before merging. An acknowledged sequencing beats a surprise
conflict.

## 4. When to split at all

Do not reach for this by default. It has real overhead — a dashboard to maintain,
prompts to write, sessions to babysit.

**Split when all of these hold:**
1. Three or more work units.
2. At least two lanes with genuinely disjoint footprints.
3. Units sized M or larger (a lane that finishes in ten minutes wasn't worth a
   session).

**Otherwise stay solo** and use subagents inside one worktree. Which is the
distinction that matters most:

> **Subagent parallelism is for units inside one lane. Session parallelism is
> for lanes.** A subagent shares your worktree and your context and cannot own a
> PR. A session owns a worktree, a branch, and a PR, and has its own context.
> They are not substitutes.

## 5. The roles

Detected from on-disk state by the router, never guessed.

### 5.1 Coordinator

Owns the plan, the dashboard, and memory. Does **not** write any lane's status
file.

A session **becomes** the coordinator by writing `progress.md` — that file is what
makes the run multi-lane, so writing it is the promotion. A solo session that splits
its plan at the Phase 2 gate is the coordinator from that moment, and the
single-writer rule binds it from there.

1. Derive lanes from footprints (§3) and record them on the dashboard.
2. Write `progress.md` — the board *and* the contract, restated in full, so a
   fresh session needs no other document.
3. **Give every lane a distinct branch and worktree name** — `eng-<plan-short-name>-<lane>`
   — and put them on the board. This is not cosmetic: every lane reads the *same*
   plan, so any name derived from the plan alone is identical across all of them, and
   every session after the first collides on a branch that already exists.
4. Emit one hand-off prompt per lane (use `/prompt`). The human opens the
   sessions and pastes them in.
5. **Reconcile**: poll `gh pr list`, read each `status-<lane>.md`, update the
   board, and fold surprises back into the plan.
6. **Writes no code and runs no lane.** The coordinator owns the gate
   (`coordination-protocol.md` §3), and a gate applied to your own work is not a
   gate — nor is a reviewer independent once it has written the code it reviews.
   A run with no spare session stays solo; it does not get a coordinator that
   also builds.

The coordinator is a **role, not a required living process.** If its session
dies, a new one reads the dashboard and memory and adopts the role. Nothing is
lost, because nothing load-bearing lived in its conversation.

### 5.2 Worker

Owns exactly one lane: one `status-<lane>.md`, one worktree, one branch, one PR.

1. Read the plan and your lane's contract. **Never write the plan or the
   dashboard** — if the plan is wrong, report it; don't fix it.
2. Work only inside your declared footprint. If you must touch a file outside it,
   that is a **surprise** — record it, flag it on the PR, and say where the fix
   lands.
3. Record ticks, surprises, and blockers in your status file as you go, and on
   your PR. The status file is scratch; the PR and the `/done` journal are the
   durable record.
4. Run `/done` at the end, which creates the PR.

### 5.3 Solo

The default: the run has one lane, so one session writes every artifact, there is no
dashboard and no coordinator, and `run.yaml` is written directly rather than reconciled.

**Solo is a fact about the run, not about the machine.** It does not mean you are the only
session on the repo — see `../SKILL.md` §"You are never the only session", which is assumed
by every rule in this file. So the *isolation* half of this model still binds a solo run in
full: work in a worktree, treat the main checkout as read-only shared state, check that a
branch name is free before taking it, and touch no worktree, branch or PR you did not
create (§9). What solo drops is the *coordination* half — the dashboard, the message
protocol, the gate — because there are no lanes to coordinate, not because the repo is
quiet.

## 6. The artifacts

### 6.1 `progress.md` — coordinator-owned

```markdown
# <run title> — progress dashboard

_Run: <run-id> · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

## 1. Tracking contract
<the single-writer table + "record ticks in your status file and PR; the plan is
read-only; your journal is the permanent record; ping the user for a merge">

## 2. Status board

Statuses: `not-started` · `in-progress` · `pr-open` · `merged` · `blocked`

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

## 3. Contract register
<frozen cross-lane interfaces and reservations — `coordination-protocol.md` §4.
Interfaces: ID, producer lane, consumer lanes, the contract, frozen-at.
Reservations: a fixed three-column table — Kind | Lane | Reserved — one row per
lane per kind, machine-read by `scripts/check_board.py` E5.>

## 4. Proposals (coordinator → human, never self-enacted)
<plan changes, re-lanes, and new units the coordinator has sensed a need for and
is asking for. `coordination-protocol.md` §5.>

## 5. Cross-session facts (verified this session)
<shared ground truth, each naming how it was verified>

## 6. Coordinator log
<append-only, timestamped. Includes corrections of the coordinator's own earlier claims>
```

The **`Owns` column holds the file footprint, not a description** — it is the
disjointness contract made visible. "the auth stuff" is not a footprint;
`src/auth/**, tests/test_auth.py` is.

### 6.2 `status-<lane>.md` — lane-owned

```markdown
# <lane> — status log (lane: <what it does>)

_Owner: <lane> session. Branch `<branch>` at `<worktree path>`. Plan §N.
This file is my scratch log; the PR + `/done` journal are the durable record._

## 1. Contract
<what I was asked to do, including any scope fence — "do NOT execute X">

## 2. Ticks
- [x] append-only, as I go

## 3. Surprises / plan deviations (flag on PR)
**SURPRISE 1 (load-bearing):** <what> → Fix lands in: <where>

## 4. Blockers
<named blocker, owner, date — or "none">
```

Two details that make these work in practice: the header **disclaims its own
authority**, so nobody mistakes scratch for record; and surprises are **graded**
(load-bearing or not) and each names **where the fix lands** — including when it
breaches the declared scope.

## 7. The invariants

1. **Single-writer per artifact** → no lost updates on shared state (§2).
2. **Disjoint file ownership per lane** → no merge conflicts; any merge order (§3).
3. **Idempotent, re-runnable actions** → a partial failure doesn't wedge the next
   attempt.
4. **Verify separately from mutate** → a read-only probe confirms reality before
   and after a change, so "did it work?" is answered by observation.
5. **A human gate at every merge** → nothing auto-merges.
6. **One reconciliation point** → the coordinator aggregates; lanes never need to
   know about each other, so adding or removing a lane doesn't ripple.
7. **Messages carry no state** → a session dying loses nothing
   (`coordination-protocol.md` §2).
8. **No message can assign work** → the autonomy boundary is structural
   (`coordination-protocol.md` §5).
9. **The gate blocks before the PR exists** → broken work never becomes a review
   artifact (`coordination-protocol.md` §3).

## 8. Staying flexible when not everything is known

Plans are written under uncertainty. This model treats discovery as a first-class
event, not a deviation.

- **The plan is append-only and coordinator-owned.** New knowledge *adds* a unit;
  IDs are never reused or renumbered after approval. In the reference run, a probe
  revealed a missing database privilege and a new unit was added mid-run — the plan
  grew to fit reality, instead of reality being forced to fit the plan.
- **Probe before you commit.** Resolve unknowns empirically before work depends on
  them. A read-only probe turns an assumption into a fact, cheaply.
- **Surprises flow back.** Worker records it → coordinator folds it into the plan
  and the board.
- **Dependencies are re-derived as facts emerge**, not frozen at plan time.
- **Blocked work is explicit** — named blocker, owner, date. So "not done" never
  masquerades as "done".

## 9. Never touch another lane's worktree

Even when it looks idle. Even when cleared to.

> A coordinator was cleared to rebase an "idle" lane. On entering the worktree it
> found a **rebase already in progress** — the `git rebase` failed harmlessly,
> because git refused. **`git status -sb` can look clean the instant before a
> session starts a rebase.** The coordinator stood down; the lane owned its own
> rebase.

If you must touch another lane's tree, check for `.git/rebase-merge`,
`rebase-apply`, and `MERGE_HEAD`, and check file mtimes — then don't anyway. Ask
the lane, or ask the user. This is also why worktree housekeeping proposes and
confirms rather than reaping silently.

## 10. Residual risks — be honest about these

- **Same-machine assumption.** `$RUN_DIR` is git-untracked, so parallel sessions
  must share a filesystem to read it by absolute path. A session on a different
  host needs its context **inlined into its prompt** — `/prompt` can do this when
  asked. The append-only tier of the state plane (issue and PR comments —
  `coordination-protocol.md` §1) is reachable from anywhere and lifts part of
  this, but `$RUN_DIR` itself is still local.
- **Coordinator as aggregation point.** Not a single point of failure (state is
  durable), but if the coordinator is absent, reconciliation pauses until a
  session adopts the role.
- **Shared-file units.** If two units genuinely must touch one file, they are
  **sequenced**, never forced parallel (§3).

## 11. In one line

Give every file a single writer, give every parallel lane a disjoint file
footprint, keep all state on disk and in git rather than in chat, verify reality
with idempotent probes, and let a coordinator fold discoveries back into an
append-only plan — then independent sessions collaborate safely and adapt to what
they learn.
