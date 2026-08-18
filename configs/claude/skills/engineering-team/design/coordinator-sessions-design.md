# Coordinator sessions — design

**Status:** design complete (2026-08-18). Sections 1–7 approved. Not yet implemented.

> **This file is documentation, not skill instruction. Nothing loads it at runtime.**
> `SKILL.md` is the only auto-loaded file in this skill; every other file is pulled
> by explicit path from the list in `SKILL.md`, and there are no globs. `design/` is
> named nowhere in `SKILL.md`, so it can never enter a run's context. Do not add a
> reference to this directory from `SKILL.md` or any `references/*.md`.
>
> **The directory name is load-bearing — it must not be `docs/`.**
> `tests/engineering-team-command-links/check_command_links.py` builds its
> reference pattern from the skill's *actual* top-level subdirectory names,
> specifically so that project-relative paths like `docs/roadmap.md` (which
> `commands/done.md` cites, meaning the **project's** docs) are not mistaken for
> skill cross-references. Creating a `docs/` directory inside the skill makes those
> three references resolve as skill paths and dangle — CI reds. Verified: with
> `docs/` present the link-check fails; renamed to `design/` it passes.
>
> To change the skill's behaviour, edit `references/` and `phases/` under the rules
> in `references/rule-ownership.md`. This file records *why* those changes look the
> way they do.

## 0. Context

`references/multi-session.md` already defines a complete parallel-lane model:
lanes derived mechanically from file footprints (Phase 2, Step 3.5), one artifact
one writer, disjoint footprints so PRs merge in any order, a coordinator that
reconciles and never reaches into lanes. It is proven — one coordinator plus three
workers merged six units with zero conflicts.

What it does **not** have is a transport. The skill contains zero references to
cross-session messaging; it predates the feature. Today:

| Step | Mechanism |
| --- | --- |
| Hand-off | Coordinator emits prompts; **the human opens terminals and pastes** |
| Status | Coordinator **polls** `gh pr list` and reads `status-<lane>.md` |
| Gate | The human, at every merge |

So lane decomposition is solved and the control loop is not. This design adds the
control loop. It is **additive**: every invariant in `multi-session.md` survives.

### Decisions taken

| Decision | Choice |
| --- | --- |
| Coordinator's jobs | All four: independent gate, relay removal, scope guard, scheduling |
| Coordinator writes code? | **No.** Pure coordinator — no worktree, no lane |
| Gate authority | **Blocking, before the PR exists** |
| Lane launch | Human opens local terminals, as today. All sessions share a filesystem |
| Autonomy | **Sense autonomously; act only on request** |

## 1. Roles and planes

### 1.1 Three planes, strictly separated

- **Control plane (messages).** Wake, assign, request, verdict. Carries *pointers
  and decisions only*. A message containing a fact that is not written down
  somewhere else is a protocol violation.
- **State plane (files, issues, PRs).** Tiered by write semantics, below.
- **Sensing plane (Monitor, scheduled wakeups).** Read-only observation of the
  state plane. Never writes, never acts.

### 1.2 The state plane is tiered by write semantics

The single-writer rule exists to prevent **lost updates**, which only occur on
*overwrite*. Append-only surfaces are conflict-free by construction and therefore
safe for many writers.

| Surface | Write semantics | Concurrency rule |
| --- | --- | --- |
| Files (`progress.md`, `run.yaml`, `improvement-plan.md`) | Overwrite | **One writer** |
| Issue / PR **bodies** | Overwrite | **One writer** |
| Issue / PR **comments** | Append-only | **Many writers, safely** — attributed and ordered |

Consequences:

- The comment stream is a *better* multi-writer surface than any file, and it does
  not need one-file-per-lane to be safe.
- It dissolves the residual risk in `multi-session.md` §10 (the same-machine
  assumption): `$RUN_DIR` is git-untracked and needs a shared filesystem, but
  issues are reachable from anywhere. A future remote/cloud lane becomes possible.
- Issues are **not** a drop-in for files: a `gh` call is a network round-trip, and
  the tracker is a human-facing surface that per-tick telemetry would ruin.

**The split:**

- **Issues** — what a human would want to read later, and anything that must cross
  machines: unit specs, blockers, surprises, merge decisions. **Gate verdicts are
  files, not issues**, because the gate runs *before* the PR exists (§3.1); they are
  mirrored onto the PR once it is opened.
- **Files** — high-frequency scratch: ticks, in-progress notes, the live board.
- **Messages** — pure control. Never the only home for a fact.

### 1.3 Two roles

**Coordinator.** Owns `improvement-plan.md`, `run.yaml`, `progress.md`, memory, and
the gate. Writes no code, enters no worktree, runs no lane.

> **This tightens the current rule.** `multi-session.md` §5.1 permits a coordinator
> to also run a lane ("wears both hats"). That is now forbidden: a gate applied to
> your own work is not a gate, and a coordinator that has written code no longer has
> the clean context that makes its review independent.

**Worker.** Owns one lane: one `status-<lane>.md`, one worktree, one branch, one PR.
Unchanged from today, except it must pass the gate before `/done`.

### 1.4 Autonomy boundary

C's autonomy separates into two halves with very different risk:

| Half | Behaviour | Risk |
| --- | --- | --- |
| **Sensing** — Monitor + scheduled wakeups | Coordinator wakes itself to *look*: PR states, status-file mtimes, lane silence, stalled gates | Near-zero; reading changes nothing |
| **Acting** — auto-assign, auto-re-lane | Coordinator mutates the plan or dispatches work unprompted | High; the system reorganises itself unobserved |

**Sensing is in scope and unrestricted. Acting is out of scope.** The coordinator
may always look, summarise, and flag; discovery becomes a *proposal to the human*,
never a fact on the board. Autonomous sensing is also what makes a blocking gate
safe — the coordinator notices its own unanswered gate requests.

## 2. The message protocol

### 2.1 Vocabulary — six types, complete

| Direction | Type | Meaning | Frequency |
| --- | --- | --- | --- |
| W → C | `CLAIM` | Starting this lane; here is my branch and worktree | once per lane |
| W → C | `SURPRISE` | Reality diverged from the plan | rare, high-value |
| W → C | `GATE-REQUEST` | Unit believed done; requesting clearance | once per unit, plus resubmits |
| W → C | `BLOCKED` | Cannot proceed; named blocker | rare |
| C → W | `VERDICT` | `PASS` or `CHANGES`, answering a `GATE-REQUEST` | one per gate request |
| C → W | `ADVISE` | Ground truth you depend on has changed | rare, targeted |

### 2.2 Envelope — every message, no exceptions

```
<TYPE> lane=<lane> unit=<U-id>
ref: <absolute path or URL where the detail lives>
<one to three fields specific to the type>
```

The `ref:` line is mandatory and is the enforcement mechanism for "messages carry
no state". If you cannot name where the detail is written, you have not written it,
and the message is malformed.

### 2.3 Rules

1. **Every message carries a `ref`.** The message notifies; the `ref` records.
2. **Workers message only the coordinator — never each other.** This preserves
   invariant 6 of `multi-session.md` (one reconciliation point; lanes never need to
   know each other exist). Direct lane-to-lane messaging rebuilds exactly the
   coupling the disjoint-footprint rule removes, and makes adding or removing a lane
   ripple across the others.
3. **No permission laundering.** Never ask a peer to perform an action your own
   session's permissions blocked. Route it back to the human.
4. **Events, not narration.**

### 2.4 Deliberate absences

- **No `TICK`.** Progress narration is what degrades a protocol into a chat log.
  Ticks belong in `status-<lane>.md`, which the coordinator reads when it senses.
- **No `STATUS` request.** The coordinator observes the state plane; interrogation
  costs a worker a context switch to report something already on disk.
- **No `ACK`.** Messages enqueue and drain at the receiver's next tool round. An
  acknowledgement layer doubles traffic to confirm what the transport guarantees.

### 2.5 Stall protection (required, because the gate blocks)

A worker that sent `GATE-REQUEST` and received no `VERDICT` resends once after a
timeout, then writes `gate pending since <t>` to its status file, stops, and reports
in its own terminal that it is waiting on an unresponsive coordinator.

**It never self-clears.** A stalled lane is recoverable; an ungated merge is the
thing the gate is being paid for.

## 3. The gate

### 3.1 Handshake

1. Worker finishes the unit, self-checks against its acceptance criteria,
   **commits and pushes the branch — no PR** — and writes evidence to
   `status-<lane>.md`.
2. Worker sends `GATE-REQUEST` with a one-line claim and a `ref`.
3. Coordinator reviews **from the main checkout** via `git diff main...<branch>`.
   The branch ref is visible there because the worktree shares the repository, so
   §9 ("never touch another lane's worktree") holds unchanged.
4. Coordinator writes `gate-<lane>-<unit>.md` in `$RUN_DIR` **on receipt**, with
   `Verdict PENDING` — this is what §5.3's Monitor watches for. It updates the same
   file to `PASS` or `CHANGES` when review returns, then sends `VERDICT`.
5. `PASS` → worker runs `/done` and opens the PR. `CHANGES` → worker fixes and
   resubmits as the next round.

### 3.2 The coordinator does not read the diff itself

It dispatches review subagents. Two load-bearing reasons:

- **Context hygiene.** A coordinator that has read six lanes' diffs is no longer a
  clean-context reviewer by lane four.
- **Throughput.** The gate blocks, so coordinator latency *is* lane stall time.
  Parallel dispatch is what makes a blocking gate affordable.

### 3.3 Panel selection — by what the unit touched, not fixed

**Always:**

- **Acceptance-criteria check** — an agent reading *only* the unit spec and the
  diff, answering met/unmet per criterion. This is what catches "the wrong thing
  was built correctly".
- **Footprint check** — mechanical: did the diff stay inside the declared paths.
  Cheap, and it is the scope-creep guard.

**Conditional:**

| Trigger | Reviewer |
| --- | --- |
| Error handling / fallbacks touched | `pr-review-toolkit:silent-failure-hunter` |
| Interfaces or types changed | `pr-review-toolkit:type-design-analyzer` |
| New behaviour | `pr-review-toolkit:pr-test-analyzer` |
| Docs / comments changed | `pr-review-toolkit:comment-analyzer` |
| Unit sized M or larger | `code-reviewer` or `/code-review` |

### 3.4 What makes a verdict `CHANGES` — exactly four things

1. An unmet acceptance criterion
2. A correctness bug with a concrete failure scenario
3. A footprint breach
4. A broken declared interface contract

Everything else — style, taste, "could be simpler" — is recorded as a
**non-blocking note** that rides along to the PR. It does not block.

Every blocking finding must name a **falsifiable failure scenario**: inputs or
state → wrong output. "This feels fragile" is not a gate finding.

> Without this rule a blocking gate becomes a nitpick machine — which would *add*
> complexity rather than limit it, defeating the reason the gate exists.

### 3.5 Round limit

After **two** `CHANGES` verdicts on the same unit, the coordinator stops and
escalates to the human. Repeated failure means the *spec* is wrong, not the
implementation — and the spec is the coordinator's own artifact. This converts a
stuck loop into a planning correction.

### 3.6 Gate file format — coordinator-owned

```markdown
# Gate: <unit-id> / lane <lane> — round <n>
_Requested <t> · Verdict <PENDING|PASS|CHANGES> · Coordinator-owned_

## Claim
<the worker's one-line claim, verbatim>

## Acceptance criteria
| # | Criterion | Met | Evidence |

## Blocking findings
**MUST-FIX 1:** <defect> — failure: <inputs → wrong output> — <file:line>

## Non-blocking notes
- <rides along to the PR; does not block>

## Footprint
Declared: <paths> / Actual: <paths> / Breach: none | <paths>
```

## 4. Interface contracts and the integration gate

### 4.1 The gap: disjoint footprints prevent conflicts, not composition failures

Lane A defines a function in `src/accounts/api.py`; lane B calls it from
`src/reports/monthly.py`. Footprints are disjoint, both PRs merge cleanly, `main`
is broken.

The sharper case, because no file is even conceptually shared: two lanes each add a
migration numbered `0007_*.py`. Different files, clean merge, broken schema.

`multi-session.md` §3 was built to prevent **merge conflicts**. A composition
failure is not a merge conflict, and it survives every check the skill currently
has — including the per-unit gate, which reviews each branch in isolation.

### 4.2 The contract register — coordinator-owned, on `progress.md`

Filled in at the split, before any lane launches. It covers two kinds of seam.

**Interfaces** — anything one lane produces and another consumes:

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | lane-a | lane-b | `def resolve_account(id: str) -> Account \| None` in `src/accounts/api.py` | plan approval |

**Reservations** — things that collide *without sharing a file*. The coordinator
assigns ranges per lane:

| Kind | Example collision | Allocation |
| --- | --- | --- |
| Migration numbers | two lanes both add `0007_*` | lane-a: 0007–0009, lane-b: 0010–0012 |
| Ports | two dev servers on 8080 | lane-a: 8080, lane-b: 8081 |
| Config keys / env vars | same key, different meaning | namespaced per lane |
| Feature-flag names | duplicate flag | registered in advance |
| Enum / error-code values | same numeric code | ranges per lane |

### 4.3 Contracts are frozen

A lane that needs a contract changed raises `SURPRISE` naming the proposed
replacement. The coordinator amends the register and sends `ADVISE` to every
consumer lane.

**A lane never changes a seam unilaterally — even when the file is inside its own
declared footprint.** Footprint ownership grants the right to edit a file, not the
right to change a promise another lane is coding against.

### 4.4 Unit zero — contract-first

> **If the contract register is non-empty, the plan gets a unit U0 that lands every
> cross-lane seam as stubs and types, and merges to `main` before any lane
> launches.** If the register is empty, there is no U0 and nothing changes.

Every lane then branches from a `main` that already contains the seams, so each
compiles and tests independently against a **real signature rather than an assumed
one**.

Cost: one serialisation point — a small PR every lane waits on.
Benefit: the entire class of composition bugs, deleted, **without stacked PRs**
(which the skill forbids: squash-only, linear history).

U0 is written by a worker lane running alone, not by the coordinator — the
coordinator writes no code (§1.3). It is an ordinary sequenced unit; nothing about
the existing model changes to accommodate it.

### 4.5 The integration gate

Per-unit gates review branches in isolation. Something must verify the combination.

**Trigger:** whenever the set of gate-passing lanes changes — including when a lane
resubmits after `CHANGES`. Not only once at the end.

**Procedure:**

1. Coordinator creates its own throwaway worktree `eng-<plan>-integration`.
2. Merges every gate-passing lane branch into it.
3. Runs the full test suite, build, and lint.
4. **Green** → greenlight the merges to the human, in the recorded order.
   **Red** → attribute the failure to a seam and `ADVISE` the owning lane.

**Why this respects the coordinator's constraints.** The rules are *never enter
another lane's worktree* (§9) and *write no product code* (§1.3). A scratch
integration tree owned by the coordinator is neither.

**The integration worktree is a probe, never merged.** That is invariant 4 —
verify separately from mutate — and invariant 3 — idempotent and re-runnable:
delete and rebuild it at any time, at no cost.

## 5. Liveness and reconciliation

### 5.1 What messaging cannot tell you

Every failure worth catching here presents as a **silence**:

| Failure | What you observe |
| --- | --- |
| Lane session crashed / terminal closed | nothing, ever again |
| `GATE-REQUEST` sent but never received | lane waits; coordinator idle |
| Lane finished but forgot to request the gate | nothing |
| Lane working outside its declared footprint | nothing — the worker does not know it is a breach |
| Human merged a PR out of band | board goes stale |

None of these produce a message. This is the `Monitor` tool's own warning — silence
is indistinguishable from progress — and it is why push notification needs a
poll-based **floor**, not a replacement.

### 5.2 `ListAgents` is the liveness primitive

It enumerates live sessions directly: if a lane is not listed, it is dead. No mtime
heuristics required. It is a tool call rather than a shell command, so it belongs on
the scheduled wakeup, not inside the `Monitor`.

### 5.3 The Monitor — persistent, 60s poll, emits only on change

Four signals: lane branch heads, status-file quiet-bands, PR state transitions, and
outstanding gate requests. Quiet is **banded into 15-minute buckets** so a silent
lane produces four notifications and then stops, rather than one per minute forever.

```bash
RUN_DIR="<absolute run dir>"; MAIN="<absolute main checkout>"
prev=""
while true; do
  now=$(date +%s)
  cur=$(
    for f in "$RUN_DIR"/status-*.md; do
      [ -e "$f" ] || continue
      lane=$(basename "$f" .md); lane=${lane#status-}
      age=$(( now - $(stat -f %m "$f") ))
      band=$(( age / 900 ))                      # 15-minute buckets
      [ "$band" -gt 4 ] && band=4                # cap: 4 notifications, then quiet
      [ "$band" -ge 1 ] && printf 'QUIET lane=%s band=%s\n' "$lane" "$band"
    done
    git -C "$MAIN" for-each-ref --format='HEAD %(refname:short) %(objectname:short)' \
      'refs/heads/eng-*' 2>/dev/null || true
    gh pr list --json number,headRefName,state \
      --jq '.[] | "PR \(.number) \(.headRefName) \(.state)"' 2>/dev/null || true
    ls "$RUN_DIR"/gate-*.md 2>/dev/null | while read -r g; do
      grep -l 'Verdict PENDING' "$g" 2>/dev/null && printf 'GATE-OPEN %s\n' "$(basename "$g")"
    done
  )
  cur=$(printf '%s\n' "$cur" | sort)
  comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur")
  prev="$cur"
  sleep 60
done
```

Run with `persistent: true`. Every remote call is `|| true` guarded so one failed
request cannot kill the monitor.

### 5.4 The reconciliation tick — `ScheduleWakeup`, ~1800s

A long fallback, because the Monitor is the primary wake signal. Each tick:

1. `ListAgents` — which lane sessions are still alive?
2. Read every `status-<lane>.md`.
3. `gh pr list` — current PR states.
4. **Footprint drift check** (below).
5. Check for gate requests outstanding beyond threshold.
6. Re-render `progress.md`.
7. Append a timestamped entry to the coordinator log.
8. Write any needed plan change as a **proposal**, not an enactment (§5.6).

### 5.5 Footprint drift check — the complexity guard

```bash
comm -13 <(sort declared-footprint.txt) \
         <(git -C "$MAIN" diff --name-only main...<branch> | sort)
```

Any line in the output is a file the lane touched but never declared.

Mechanical, instant, and it catches scope creep **while it is happening** rather
than at gate time. This is the single strongest complexity guard in the design and
it costs one shell command. A drift hit becomes an `ADVISE` to the lane and a note
on the board; a persistent drift becomes a proposal to amend the footprint.

### 5.6 The autonomy boundary is structural, not disciplinary

Anything requiring a plan change, a re-lane, or a new unit is written to the board
as a **proposal** and surfaced to the human. Never enacted.

The enforcement is not the coordinator's restraint — it is the vocabulary:

> **No message type in the protocol can assign work.** There are six types and none
> of them is `ASSIGN`. A coordinator wanting to dispatch autonomously would have to
> invent a message that does not exist.

**Sensing may, unprompted:** read anything in the state plane, re-render the board,
append to its own log, and send `ADVISE`.

`ADVISE` is permitted autonomously because it changes nothing, it relays a fact
already recorded (and must carry the `ref` proving it), and warning a lane that its
ground truth just moved is the cheapest bug prevention available.

**Sensing may never, unprompted:** edit the plan, assign or re-assign a unit, enter
a lane worktree, write a lane's status file, or merge anything.

## 6. Artifacts and file changes

### 6.0 Where the skill actually lives

**Source of truth:** `/Users/john/projects/codespaces/configs/claude/skills/engineering-team`
(git-tracked). `~/.claude/skills/engineering-team` is a **deployed copy** — byte-identical
apart from this `design/` directory. All edits go to the source repo; nothing takes
effect until synced.

The drift-scan lives outside the skill, at
`/Users/john/projects/codespaces/tests/engineering-team-drift/drift_scan.py`, and is
wired into CI.

### 6.1 Constraints imposed by `references/rule-ownership.md`

That file is not advisory. It requires:

1. **Every load-bearing rule has exactly one canonical home.** A restatement
   elsewhere is a *pointer*, never a second copy of the rationale.
2. **Homes are addressed as `<file>` §<heading>** — headings, not line numbers.
3. **The index is updated in the same edit that moves or adds a rule.** "A stale
   index is worse than none."
4. **The drift-scan mechanically verifies** that every cited home resolves to a real
   heading and that each invariant's signature phrase still appears there. Adding
   rules without registering them **reds CI**.

### 6.2 New file — `references/coordination-protocol.md`

Canonical home for the entire new rule family:

- the three-plane separation (§1.1)
- the six-type vocabulary, the envelope, and the four protocol rules (§2)
- the gate handshake, the four `CHANGES` criteria, the round limit (§3)
- the contract register and unit zero (§4)
- the sensing boundary (§5.6)

### 6.3 Changes to existing files

| File | Change |
| --- | --- |
| `references/multi-session.md` §5.1 | **Behaviour change at its canonical home:** delete "may run a lane itself — but then it wears both hats". Coordinators no longer run lanes (§1.3) |
| `references/multi-session.md` §6.1 | `progress.md` template gains the contract register (§4.2) and a Proposals section (§5.6) |
| `references/multi-session.md` §7 | Invariant list gains **pointer lines** to `coordination-protocol.md`; rationale stays in the new file — one home per rule |
| `references/multi-session.md` §10 | Same-machine residual risk updated: the issue tier (§1.2) partially lifts it |
| `phases/phase-2-planning.md` Step 3.5 | After lane derivation, build the contract register |
| `phases/phase-2-planning.md` Step 3.6 | Emit U0 when the register is non-empty; hand-off prompt must inline the protocol |
| `phases/phase-3-development.md` | Worker: gate before `/done`. Coordinator: arm Monitor, schedule reconciliation, run gates, run the integration gate |
| `SKILL.md` | Add `references/coordination-protocol.md` to its file list — the only place that makes it loadable |
| `references/rule-ownership.md` | New home row in §2; new "Homed in coordination-protocol.md" subsection in §3; the §5.1 change reflected |
| `commands/done.md` Phase 8 | Gate barrier — below |

### 6.4 The `/done` change — the most important row in the table

`commands/done.md` Phase 8 ("Commit & Open a PR") is where the PR gets created.
Insert a **step 0**:

> If this run has lanes, refuse to open a PR unless
> `$RUN_DIR/gate-<lane>-<unit>.md` exists and records `Verdict PASS`.

This converts the gate from a rule workers are asked to follow into a **barrier they
cannot walk past**, which is what the blocking-gate decision actually requires to be
real.

### 6.5 Honest scorecard — policy vs structure

`general-guidelines.md` §"Prefer structural enforcement to policy" is one of this
skill's own invariants. Audited against it:

| Rule | Enforcement |
| --- | --- |
| Coordinator cannot assign work | **Structural** — no such message type exists (§5.6) |
| Gate blocks the PR | **Structural** — `/done` Phase 8 step 0 (§6.4) |
| Footprint drift detected | **Structural** — mechanical `comm` (§5.5) |
| Board / register well-formed | **Structural** — `check_board.py` (§7) |
| Every message carries a `ref` | **Policy** — checkable only on recorded gate files |
| Workers never message each other | **Policy** — unenforceable |

Two rules remain policy. This is not believed fixable, and the scorecard is recorded
rather than the design being described as fully structural.

## 7. Validation

### 7.1 `scripts/check_board.py` — matching the sibling gates

Same conventions as `check_plan.py` / `check_run.py` / `check_report.py`:

```
python3 check_board.py <run_dir>     # gate a real run
python3 check_board.py --selftest    # run scripts/fixtures_board/
```

Fixtures follow the existing naming: `good/`, `eN_<slug>/`, `wN_<slug>/`.

**Calibrated to `check_plan.py`'s two gate-design rules**, quoted from its
docstring:

> 1. A hard failure must be unambiguous and mechanically fixable, **or an honest
>    plan trips it and the gate gets switched off.**
> 2. Softer signals are WARNINGS.

### 7.2 Checks

**ERRORs — unambiguous and mechanically fixable:**

| Code | Condition |
| --- | --- |
| E1 | No status board table in `progress.md` |
| E2 | An `Owns` cell containing prose rather than paths ("the auth stuff" is not a footprint) |
| E3 | **Definite** footprint overlap — identical path, or one a directory-prefix of another |
| E4 | Contract register names a lane absent from the board |
| E5 | Reservation ranges overlap between lanes (migrations, ports, codes) |
| E6 | Contract register non-empty but the plan declares no U0 (§4.4) |
| E7 | The board names the coordinator as a lane owner (violates §1.3) |
| E8 | A gate file at round ≥ 3 with no escalation note (violates §3.5) |

**WARNs — real signals that honest work can legitimately trip:**

| Code | Condition |
| --- | --- |
| W1 | A lane on the board with no `status-<lane>.md` yet (may simply not have started) |
| W2 | A branch named on the board that does not exist in git yet |
| W3 | *Possible* overlap via globs that cannot be resolved against the working tree |
| W4 | A plan unit assigned to no lane |

W3 exists specifically to honour gate-design rule 1: unresolvable globs are a real
signal but an ambiguous one, so they must not hard-fail.

### 7.3 The overlap check is the headline

`multi-session.md` §3 says the disjointness check "is mechanical and takes a
minute; the conflict it prevents costs an afternoon" — and then **nothing runs
it.** A human reads the table.

E3 is the largest single conversion of policy into structure in this design, and
it guards the invariant every other part rests on.

### 7.4 Drift-scan additions

Add to `tests/engineering-team-drift/drift_scan.py`:

1. The new home rows resolve to real headings in `coordination-protocol.md`.
2. Signature phrases for the new invariants, so CI catches their removal:
   - `Every message carries a ref`
   - `No message type in the protocol can assign work`
   - `sense autonomously; act only on request`

**One registration that is not optional.** The gate *rule* lives in
`coordination-protocol.md`; its *enforcement* lives in `commands/done.md` Phase 8
step 0. That is a rule/enforcement split across two files — structurally identical
to the status-stamp pair already catalogued in `rule-ownership.md` §4 — so it must
be added there as **edit-together pair #4**, or the two will silently diverge.

### 7.5 The red-team dry run — required before trusting any of this

`general-guidelines.md` requires that **a new gate ships with a test proving it
goes red**. A coordination protocol that has only been reasoned about will deadlock
on first contact.

Before this is used on real work: a throwaway run on a scratch repo — 3 units,
2 lanes, 1 contract — with each failure mode **deliberately injected**.

| Injected failure | Must produce |
| --- | --- |
| Kill a worker's terminal mid-lane | Monitor quiet-band notification (§5.3) |
| Lane edits a file outside its footprint | Drift check flags it (§5.5) |
| Lane runs `/done` with no PASS gate file | Phase 8 step 0 refuses (§6.4) |
| `GATE-REQUEST` to a stopped coordinator | Stall protection escalates; lane does **not** self-clear (§2.5) |
| Lane proposes a contract change | `ADVISE` reaches the consumer lane (§4.3) |

Five injections. **If any stays silent, that gate is decorative.**

## 8. Build order

1. `references/coordination-protocol.md` + `rule-ownership.md` registration (§6.2, §6.3)
2. `multi-session.md` §5.1 change + `progress.md` template (§6.3)
3. `commands/done.md` Phase 8 step 0 — the barrier (§6.4)
4. `check_board.py` + fixtures (§7.1–7.2)
5. Phase 2 / Phase 3 edits (§6.3)
6. Drift-scan additions (§7.4)
7. **The red-team dry run (§7.5) — gate on this before real use**
