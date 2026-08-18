# Coordination protocol

> Loaded when a run has lanes — by Phase 2 when the contract register is built,
> and by Phase 3 by every session that is a coordinator or a worker. Load it
> **with** `references/multi-session.md`: that file says how lanes are derived and
> who owns which artifact; this one says how coordinator and worker sessions talk,
> how a unit is cleared before its PR exists, how cross-lane seams are frozen, and
> what a coordinator may do unprompted.

This is additive to `references/multi-session.md`. Every invariant there still
holds; nothing here replaces one.

> **Not yet proven end to end.** Three of this protocol's five failure-injection
> tests have been observed firing; **two have not**: stall protection (§2.5 — a
> worker waiting on a coordinator that has gone silent) and `ADVISE` propagation
> (§4.3 — a warning reaching the lane whose ground truth just moved). Both need
> live sessions to exercise. On the first real multi-lane run, watch for those two
> behaviours specifically and record what happens. See
> `journal/260818-coordinator-redteam.md`.

## 1. The three planes

### 1.1 Three planes, strictly separated

- **Control plane (messages).** Wake, assign, request, verdict. It carries
  *pointers and decisions only*. Every message carries a ref to the place in the
  state plane where the fact is written; a message containing a fact that is
  written down nowhere else is a protocol violation.
- **State plane (files, issues, PRs).** Everything durable. Tiered by write
  semantics — §1.2.
- **Sensing plane (Monitor, scheduled wakeups).** Read-only observation of the
  state plane. It never writes and never acts — §5.

Keep them separate in both directions: do not put state in a message, and do not
treat an observation as an action.

### 1.2 The state plane is tiered by write semantics

The single-writer rule (`references/multi-session.md` §2) exists to prevent **lost
updates**, and lost updates only happen on *overwrite*. Append-only surfaces are
conflict-free by construction, so they are safe for many writers.

| Surface | Write semantics | Concurrency rule |
| --- | --- | --- |
| Files (`progress.md`, `run.yaml`, `improvement-plan.md`) | Overwrite | **One writer** |
| Issue / PR **bodies** | Overwrite | **One writer** |
| Issue / PR **comments** | Append-only | **Many writers, safely** — attributed and ordered |

So the comment stream is a *better* multi-writer surface than any file, and it
needs no one-file-per-lane discipline to be safe. It also reaches across machines,
which the run directory does not. But issues are not a drop-in for files: a `gh`
call is a network round-trip, and the tracker is a human-facing surface that
per-tick telemetry would ruin.

**Put each fact on exactly one tier:**

- **Issues** — what a human would want to read later, and anything that must cross
  machines: unit specs, blockers, surprises, merge decisions.
- **Files** — high-frequency scratch: ticks, in-progress notes, the live board.
  **Gate verdicts are files, not issues**, because the gate runs before the PR
  exists (§3.1); mirror them onto the PR once it is opened.
- **Messages** — pure control. Never the only home for a fact.

### 1.3 The two roles

**Coordinator.** Owns `improvement-plan.md`, `run.yaml`, `progress.md`, memory, the
contract register, and the gate.

> **A coordinator writes no code, enters no worktree, and runs no lane.** That rule
> is stated and argued at its home, `references/multi-session.md` §5.1. Everything
> here assumes it: a gate applied to your own work is not a gate.

**Worker.** Owns one lane — one `status-<lane>.md`, one worktree, one branch, one
PR — exactly as in `references/multi-session.md` §5.2, with one addition: it must
pass the gate (§3) before it may run `/done`.

## 2. The message protocol

### 2.1 Vocabulary — six types, and no others

| Direction | Type | Meaning | Frequency |
| --- | --- | --- | --- |
| W → C | `CLAIM` | Starting this lane; here is my branch and worktree | once per lane |
| W → C | `SURPRISE` | Reality diverged from the plan | rare, high-value |
| W → C | `GATE-REQUEST` | Unit believed done; requesting clearance | once per unit, plus resubmits |
| W → C | `BLOCKED` | Cannot proceed; named blocker | rare |
| C → W | `VERDICT` | `PASS` or `CHANGES`, answering a `GATE-REQUEST` | one per gate request |
| C → W | `ADVISE` | Ground truth you depend on has changed | rare, targeted |

Do not invent a seventh type. The set is closed, and §5.6 depends on it being
closed.

### 2.2 Envelope — every message, no exceptions

```
<TYPE> lane=<lane> unit=<U-id>
ref: <absolute path or URL where the detail lives>
<one to three fields specific to the type>
```

The `ref:` line is mandatory. It is the enforcement mechanism for "messages carry
no state": if you cannot name where the detail is written, you have not written it,
and the message is malformed.

### 2.3 The four rules

1. **Every message carries a `ref`.** The message notifies; the `ref` records.
2. **Workers message only the coordinator — never each other.** This preserves
   invariant 6 of `references/multi-session.md` (one reconciliation point; lanes
   never need to know each other exist). Lane-to-lane messaging rebuilds exactly
   the coupling that disjoint footprints remove, and makes adding or removing a
   lane ripple across the others.
3. **No permission laundering.** Never ask a peer session to perform an action your
   own session's permissions blocked. Route it back to the human.
4. **Events, not narration.** Send when something happened that the other session
   must decide on — not to report that you are still working.

### 2.4 Deliberate absences — do not add these

- **No `TICK`.** Progress narration is what degrades a protocol into a chat log.
  Ticks belong in `status-<lane>.md`, which the coordinator reads when it senses.
- **No `STATUS` request.** The coordinator observes the state plane; interrogating a
  worker costs it a context switch to report something already on disk.
- **No `ACK`.** Messages enqueue and drain at the receiver's next tool round; an
  acknowledgement layer doubles traffic to confirm what the transport guarantees.

### 2.5 Stall protection — required, because the gate blocks

A worker that sent `GATE-REQUEST` and received no `VERDICT` **resends once** after a
timeout. If still unanswered it writes `gate pending since <t>` to its status file,
stops, and reports in its own terminal that it is waiting on an unresponsive
coordinator.

**It never self-clears.** A stalled lane is recoverable; an ungated merge is the
thing the gate is being paid to prevent.

## 3. The gate

The gate is **blocking, and it runs before the PR exists.** A worker does not open a
PR for a unit that has not passed it.

**The gate is per unit; the PR is per lane. The barrier reconciles them by
requiring every open unit to have passed.** A lane is one branch and one PR
(`references/multi-session.md` §5.2) but may carry several units, and pushing the
branch ships all of them at once. So a lane may open its PR only when **every unit
the board assigns to that lane whose Status is not already `merged`** has a `PASS`
gate file. Units already merged — a U0 that landed before the lanes launched, say —
are excluded: they were gated in their own round and are not on this branch to be
cleared again. One unit's `PASS` is not a licence to ship the units beside it.

### 3.1 The handshake

1. **Worker** finishes the unit, self-checks against its acceptance criteria,
   **commits and pushes the branch — no PR** — and writes its evidence to
   `status-<lane>.md`.
2. **Worker** sends `GATE-REQUEST` with a one-line claim and a `ref`.
3. **Coordinator** reviews from the main checkout via `git diff main...<branch>`.
   The branch ref is visible there because the worktree shares the repository, so
   "never touch another lane's worktree" (`references/multi-session.md` §9) holds
   unchanged.
4. **Coordinator** writes `gate-<lane>-<unit>.md` in the run directory **on
   receipt**, recording `Verdict PENDING` (§3.6) — that is the line §5.3's Monitor
   watches for. It updates the same file to `PASS` or `CHANGES` when review returns,
   then sends `VERDICT`.
5. `PASS` → the worker runs `/done` and opens the PR. `CHANGES` → the worker fixes
   and resubmits as the next round.

### 3.2 The coordinator dispatches reviewers; it does not read the diff itself

Send the diff to review subagents and read their findings. Two reasons, both
load-bearing: a coordinator that has read six lanes' diffs is no longer a
clean-context reviewer by lane four, and — because the gate blocks — coordinator
latency *is* lane stall time, so parallel dispatch is what makes a blocking gate
affordable.

### 3.3 Panel selection — by what the unit touched

**Always dispatch both:**

- **Acceptance-criteria check** — an agent reading *only* the unit spec and the
  diff, answering met/unmet per criterion. This is what catches "the wrong thing was
  built correctly".
- **Footprint check** — mechanical: did the diff stay inside the declared paths.
  Cheap, and it is the scope-creep guard.

**Add, conditional on the diff:**

| Trigger | Reviewer |
| --- | --- |
| Error handling / fallbacks touched | `pr-review-toolkit:silent-failure-hunter` |
| Interfaces or types changed | `pr-review-toolkit:type-design-analyzer` |
| New behaviour | `pr-review-toolkit:pr-test-analyzer` |
| Docs / comments changed | `pr-review-toolkit:comment-analyzer` |
| Unit sized M or larger | `code-reviewer` or `/code-review` |

Name agent types from the roster the session provides (`references/team-structure.md`).

### 3.4 What makes a verdict `CHANGES` — exactly four things

1. An unmet acceptance criterion.
2. A correctness bug with a concrete failure scenario.
3. A footprint breach.
4. A broken declared interface contract (§4).

Everything else — style, taste, "could be simpler" — is recorded as a
**non-blocking note** that rides along to the PR. It does not block.

Every blocking finding must name a **falsifiable failure scenario**: inputs or state
→ wrong output. "This feels fragile" is not a gate finding. Without this rule a
blocking gate becomes a nitpick machine, which would *add* complexity rather than
limit it — the opposite of why the gate exists.

### 3.5 The round limit — escalate after two

After **two** `CHANGES` verdicts on the same unit, stop and escalate to the human.
Repeated failure means the *spec* is wrong rather than the implementation — and the
spec is the coordinator's own artifact — so the escalation converts a stuck loop
into a planning correction.

### 3.6 The gate file — coordinator-owned

One file per unit per lane, `gate-<lane>-<unit>.md`, in the run directory. Written
at `PENDING` on receipt and updated in place:

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

The verdict word is the machine-readable part: `Verdict PENDING` is what the
liveness Monitor greps for, and `Verdict PASS` is what `/done` requires before it
will open a PR (`commands/done.md` §`8a` item 1 — see §4 of
`references/rule-ownership.md`: change the file name or the verdict line in one and
you must change it in the other in the same edit).

The `_Requested <t> · Verdict <…> · Coordinator-owned_` status line is the **only**
place a verdict may be declared, and it must appear in the file's **header
block** — line 2, immediately under the H1, per the template above. Both readers
bound their search to that header region (the first few lines) and match nothing
below it, so a verdict word anywhere in the body (a finding, a non-blocking note,
or a quoted/fenced example showing the format) is prose and must never be treated
as a verdict.

## 4. Interface contracts and unit zero

### 4.1 Disjoint footprints prevent conflicts, not composition failures

Lane A defines a function in `src/accounts/api.py`; lane B calls it from
`src/reports/monthly.py`. Footprints are disjoint, both PRs merge cleanly, `main` is
broken. Sharper still: two lanes each add a migration numbered `0007_*.py` — different
files, clean merge, broken schema.

Disjoint footprints (`references/multi-session.md` §3) are built to prevent **merge
conflicts**. A composition failure is not a merge conflict and survives every other
check in this skill, including the per-unit gate, which reviews each branch in
isolation. Sections 4.2–4.5 are what catch it.

### 4.2 The contract register — coordinator-owned, on `progress.md`

Fill it in at the split, **before any lane launches**. It covers two kinds of seam.

**Interfaces** — anything one lane produces and another consumes:

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | lane-a | lane-b | `def resolve_account(id: str) -> Account \| None` in `src/accounts/api.py` | plan approval |

**Reservations** — things that collide *without sharing a file*: migration
numbers (two lanes both adding `0007_*`), ports, config keys and env var names,
feature-flag names, enum and error-code values. The coordinator assigns each lane
a range or a namespace.

**The table is machine-read, so its shape is fixed** — `scripts/check_board.py`
E5 uses it to catch two lanes reserving the same thing. Exactly three columns,
**one row per lane per kind**:

| Kind | Lane | Reserved |
| --- | --- | --- |
| Migration numbers | a | 0007-0009 |
| Migration numbers | b | 0010-0012 |
| Ports | a | 8080 |
| Ports | b | 8081 |
| Config key prefix | a | `billing_` |
| Config key prefix | b | `reporting_` |

- **Kind** groups rows that compete for the same resource. Two rows conflict if
  their Kind matches once casefolded and stripped of surrounding markdown
  emphasis and trailing punctuation — `Ports`, `**Ports**`, and `Ports:` are the
  same Kind.
- **Lane** is a single lane id from the status board — not a list.
- **Reserved** is one of:
  - a **numeric range** (`8080`, or `0007-0009` inclusive — use a plain hyphen,
    not an en dash). Ranges overlap numerically.
  - a **backtick-escaped opaque token** — `` `billing_` ``, `` `08-2026` ``.
    Tokens conflict only when identical. **The backticks are load-bearing, not
    decoration:** without them, a two-part numeric identifier like a date prefix
    (`08-2026`) or a tenant id (`01-99`) parses as a range instead of a token —
    escape it with backticks whenever the value could be misread as one.
  - a **placeholder meaning "this lane reserves nothing of this Kind"** — an
    em dash `—`, a plain hyphen `-`, `none`, `n/a`, or an empty cell. Required
    because the table is one row per lane per kind: a lane that needs nothing
    of a Kind another lane reserves still needs a row. Silently skipped — not
    an error, not a warning.
  - a **placeholder meaning "not decided yet"** — `TBD` or `?`. Reported as
    **W5**: the gate genuinely cannot check a reservation that hasn't been made.

A Reserved cell that parses as none of the above is also reported as **W5** —
the gate says it could not check that row rather than guessing. Splitting one
lane's allocation across several rows of the same Kind is fine.

Any contract-register row that is table-shaped but matches neither a valid
Interfaces row nor a valid Reservations row — a fourth column added to this
table, a Lane cell holding a list (`a, b`) — is also **W5**, naming the row.
It is not dropped silently: a silently-dropped reservation is the exact failure
E5 exists to prevent.


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
one**. The cost is one serialisation point — a small PR every lane waits on. The
benefit is the whole class of composition bugs, deleted, without stacked PRs (which
this skill forbids: squash-only, linear history).

U0 is written by a worker lane running alone, never by the coordinator (§1.3). It is
an ordinary sequenced unit; nothing else about the lane model changes to
accommodate it.

### 4.5 The integration gate

Per-unit gates review branches in isolation, so something must verify the
combination.

**Trigger:** whenever the set of gate-passing lanes changes — including when a lane
resubmits after `CHANGES`. Not only once at the end.

**Procedure:**

1. Create a throwaway coordinator-owned worktree, `eng-<plan>-integration`.
2. Merge every gate-passing lane branch into it.
3. Run the full test suite, build, and lint.
4. **Green** → greenlight the merges to the human, in the recorded order.
   **Red** → attribute the failure to a seam and `ADVISE` the owning lane.

This respects both standing constraints: the scratch tree is the coordinator's own,
not another lane's worktree, and merging lane branches into it writes no code — the
coordinator composes what the lanes already wrote and runs the checks. **The
integration worktree is a probe, never merged** — delete and rebuild it at any time,
at no cost.

## 5. Sensing and the autonomy boundary

> **Sense autonomously; act only on request.**

### 5.1 Every failure worth catching presents as a silence

| Failure | What you observe |
| --- | --- |
| Lane session crashed / terminal closed | nothing, ever again |
| `GATE-REQUEST` sent but never received | lane waits; coordinator idle |
| Lane finished but forgot to request the gate | nothing |
| Lane working outside its declared footprint | nothing — the worker does not know it is a breach |
| Human merged a PR out of band | board goes stale |

None of these produce a message. Push notification is therefore not enough on its
own: it needs a poll-based **floor** underneath it (§5.3, §5.4).

### 5.2 `ListAgents` is the liveness primitive

It enumerates live sessions directly: if a lane is not listed, it is dead — no mtime
heuristics required. It is a tool call rather than a shell command, so run it on the
scheduled wakeup, not inside the Monitor.

### 5.3 The Monitor — persistent, 60s poll, emits only on change

Four signals: lane branch heads, status-file quiet-bands, PR state transitions, and
outstanding gate requests. Quiet is **banded into 15-minute buckets**, so a silent
lane produces four notifications and then stops rather than one every minute
forever.

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
      head -5 "$g" 2>/dev/null \
        | grep -qE '^_Requested.*·[[:space:]]*Verdict PENDING[[:space:]]*·' \
        && printf 'GATE-OPEN %s\n' "$(basename "$g")"
    done
  )
  cur=$(printf '%s\n' "$cur" | sort)
  comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur")
  prev="$cur"
  sleep 60
done
```

Run it with `persistent: true`. Guard every remote call with `|| true` so one failed
request cannot kill the monitor.

### 5.4 The reconciliation tick — `ScheduleWakeup`, ~1800s

A long fallback, because the Monitor is the primary wake signal. Each tick:

1. `ListAgents` — which lane sessions are still alive?
2. Read every `status-<lane>.md`.
3. `gh pr list` — current PR states.
4. Run the footprint drift check (§5.5).
5. Check for gate requests outstanding beyond the threshold.
6. Re-render `progress.md`.
7. Append a timestamped entry to the coordinator log.
8. Write any needed plan change as a **proposal**, not an enactment (§5.6).

### 5.5 Footprint drift check

```bash
comm -13 <(sort declared-footprint.txt) \
         <(git -C "$MAIN" diff --name-only main...<branch> | sort)
```

Any line in the output is a file the lane touched but never declared. Mechanical,
instant, and it catches scope creep **while it is happening** rather than at gate
time — the strongest complexity guard here, for the price of one shell command.

A drift hit becomes an `ADVISE` to the lane and a note on the board; persistent
drift becomes a proposal to amend the footprint.

### 5.6 The boundary is structural, not disciplinary

Anything requiring a plan change, a re-lane, or a new unit is written to the board
as a **proposal** and surfaced to the human. Never enacted.

What holds the line is not the coordinator's restraint — it is the vocabulary:

> **No message type in the protocol can assign work.** There are six types (§2.1)
> and none of them is `ASSIGN`. A coordinator wanting to dispatch autonomously
> would have to invent a message that does not exist.

**Unprompted, sensing may:** read anything in the state plane, re-render the board,
append to its own coordinator log, and send `ADVISE`. `ADVISE` is allowed
autonomously because it changes nothing, it relays a fact already recorded (and must
carry the `ref` proving it), and warning a lane that its ground truth just moved is
the cheapest bug prevention available.

**Unprompted, sensing may never:** edit the plan, assign or re-assign a unit, enter
a lane worktree, write a lane's status file, or merge anything.

That is the whole rule in one line: sense autonomously; act only on request.
