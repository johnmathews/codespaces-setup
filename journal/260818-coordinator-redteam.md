# Red-teaming the coordination protocol — three gates fired, two were never run

**Date:** 2026-08-18. **Branch:** `feat/coordinator-sessions`. Final task of the
coordinator-sessions plan; the design calls it the release gate
(`design/coordinator-sessions-design.md` §7.5, §8 item 7). Point-in-time record;
authoritative for nothing.

## The headline, stated before anything else

**The red-team gate is only PARTIALLY satisfied. The protocol is not cleared for
real use.**

Three injections were run mechanically and fired. **Injections 4 (stall protection)
and 5 (`ADVISE` propagation) were NOT RUN** — both are prose behaviours of live
coordinator and worker Claude Code sessions, and this session cannot open terminals.
Those two gates **have never been observed to fire.** Nothing was simulated, inferred
or written up as "this would produce…"; an unobserved gate is recorded here as
unobserved.

Per the design's own build order — item 7, "the red-team dry run — gate on this
before real use" — the protocol does not go near real work until those two
injections are run with live sessions.

| # | Injected failure | Verdict |
| --- | --- | --- |
| 1 | Kill a worker's terminal mid-lane | **OBSERVED** |
| 2 | Lane edits a file outside its footprint | **OBSERVED** |
| 3 | `/done` with no PASS gate file | **OBSERVED (predicate only)** — and it found a hole |
| 4 | `GATE-REQUEST` to a stopped coordinator | **NOT RUN** — needs live sessions |
| 5 | Lane proposes a contract change | **NOT RUN** — needs live sessions |

3 OBSERVED · 0 SILENT · 2 NOT RUN. Full transcript in
`.superpowers/sdd/2026-08-18-coordinator-sessions/task-8-report.md`.

## The scratch run

A throwaway git repo and run directory under `/tmp/coord-redteam/` — never
committed, nothing from it added to the repo. Three units, two lanes with disjoint
footprints, one contract (so U0 exists), matching the design's spec. The board was
validated with the real gate before anything was injected:
`check_board.py /tmp/coord-redteam/run` → `board check: 0 error(s), 0 warning(s)`.

## 1 — killing a lane produces a quiet-band notification. Observed.

The Monitor was **extracted programmatically from the fenced block under §5.3** of
`coordination-protocol.md` and run as a real long-running process — the actual
`while true; … sleep 60; done` loop, not a hand-rolled single pass. `diff` proves the
only edit was substituting the two placeholders on line 1.

Iteration 1, with lane-b 47 minutes quiet and lane-c 180 minutes quiet:

```
HEAD eng-lane-a bf7e079
HEAD eng-lane-b bf7e079
QUIET lane=lane-b band=3
QUIET lane=lane-c band=4
```

Then lane-a's terminal was "killed": its status file stopped advancing (backdated 20
minutes) and its `GATE-REQUEST` was left outstanding at `Verdict PENDING`. What the
next poll emitted, verbatim:

```
/tmp/coord-redteam/run/gate-lane-a-U1.md
/tmp/coord-redteam/run/gate-pending-U1.md
GATE-OPEN gate-lane-a-U1.md
GATE-OPEN gate-pending-U1.md
HEAD eng-lane-a 61ebfdc
QUIET lane=lane-a band=1
```

`QUIET lane=lane-a band=1` is the gate. The dead lane surfaced on the very next
60-second poll. Three secondary behaviours confirmed at the same time, all correct:
iteration 2 did **not** re-emit lane-b or lane-c (their bands had not changed, so the
`comm -13` delta works); lane-c, silent long enough for band 12, reported the capped
`band=4`, so it stops nagging as designed; and `gh pr list` failing outside a GitHub
repo did not kill the monitor.

**Cosmetic defect, found in passing.** The first two lines above are noise. The
gate-scan sub-loop uses `grep -l 'Verdict PENDING' "$g" && printf 'GATE-OPEN …'`, and
`grep -l` prints the matched filename to stdout as well as setting the exit status —
so every pending gate emits two lines, one of them an unlabelled absolute path in a
stream whose whole contract is one-event-per-line. `grep -q` is the intended idiom.
The gate fired; its output is just wrong.

## 2 — the drift check names the breach exactly. Observed.

lane-a declared `src/accounts/api.py`. With only that file edited, §5.5's `comm`
one-liner printed nothing — correctly silent. Then lane-a edited `docs/shared.md`
(shared, undeclared) and `src/reports/monthly.py` (undeclared **and inside lane-b's
footprint**, the sharper case):

```
=== declared footprint ===
src/accounts/api.py
=== actual diff ===
docs/shared.md
src/accounts/api.py
src/reports/monthly.py
=== drift check (protocol 5.5) ===
docs/shared.md
src/reports/monthly.py
```

Both breaches named, the declared file correctly absent. No false positive, no miss.
For the price of one shell command, as advertised.

## 3 — the `/done` barrier refuses, but it fails open on prose

**What was tested, precisely.** `commands/done.md` is prose and cannot execute. This
tests the mechanical predicate the prose embeds — the `grep` on line 368 — **not**
whether an agent reading Phase 8 step 0 obeys it. Agent compliance is still
unobserved.

With `progress.md` present (so the run has lanes and step 0 applies), the four gate
states:

```
--- LANE=missing UNIT=U1 ---
BLOCKED: no PASS verdict for missing/U1
--- LANE=pending UNIT=U1 ---
BLOCKED: no PASS verdict for pending/U1
--- LANE=changes UNIT=U1 ---
BLOCKED: no PASS verdict for changes/U1
--- LANE=passing UNIT=U1 ---
/tmp/coord-redteam/run/gate-passing-U1.md
```

All three refusal cases block; the PASS control correctly does not. The predicate
fires.

**Then it stopped firing.** `grep -l 'Verdict PASS' <file>` matches the string
*anywhere in the file*, not on the `_Requested … Verdict … Coordinator-owned_`
metadata line that §3.6 designates as "the machine-readable part". So a `CHANGES`
gate file that merely mentions a PASS verdict in prose clears the barrier:

```
$ grep -l 'Verdict PASS' "$RUN_DIR/gate-proseleak-U1.md" 2>/dev/null \
    || echo "BLOCKED: no PASS verdict for proseleak/U1"
/tmp/coord-redteam/run/gate-proseleak-U1.md

--- what the metadata line actually says ---
2:_Requested t · Verdict CHANGES · Coordinator-owned_
8:- Fix the above and resubmit; a Verdict PASS then unblocks /done.
```

The sentence that defeats it — "resubmit; a Verdict PASS then unblocks `/done`" — is
exactly what a coordinator would naturally write in a non-blocking note. This is the
one blocking, mechanical gate in the entire protocol, and it fails **open**. Anchoring
the match to the metadata line fixes it; that edit is edit-together pair #4 in
`rule-ownership.md` §4, so `coordination-protocol.md` §3.6 changes in the same commit.
**Not fixed here** — this task's remit was to observe and report, and it commits only
this entry.

## 4 and 5 — NOT RUN, and there is nothing mechanical to substitute

**Injection 4 (`GATE-REQUEST` to a stopped coordinator → stall protection escalates,
lane does not self-clear).** §2.5 is entirely a behavioural rule for a live worker:
resend once after a timeout, write `gate pending since <t>` to the status file, stop,
report in its own terminal. No script, no predicate, no artifact.

**Injection 5 (lane proposes a contract change → `ADVISE` reaches the consumer).**
§4.3 needs a worker to raise `SURPRISE`, a coordinator to amend the register, and an
`ADVISE` to reach every consumer lane — two live sessions over a transport that does
not exist headlessly.

Both were checked for any executable surface that could stand in:

```
$ grep -rn "gate pending since\|resends once\|self-clear" --include="*.py" --include="*.sh" --include="*.yml" .
NONE — no script mentions it
$ grep -rn "ADVISE" --include="*.py" --include="*.sh" --include="*.yml" .
NONE — no script mentions it
```

Both rules live only in `coordination-protocol.md` and the design doc. `check_board.py`
E4 (a contract naming a lane not on the board) is adjacent to injection 5 but tests
board consistency, not message delivery — it is not a substitute and is not counted as
one.

## CI

All headless checks in `.github/workflows/ci.yml` re-run locally on this branch,
green: `check_report` (13 fixtures), `check_run` (15), `check_plan` (12), `check_board`,
the triggering parser selftest (7 verdict cases, 18-prompt set), drift-scan selftest
(13 signatures, A/B/C seeded red) **and the real scan** (0 warnings), and the
command→skill link-check selftest **and the real check**.

## What this does not clear

Restating it because the temptation to round three-out-of-five up to "done" is exactly
what this task exists to resist:

- **Stall protection (§2.5) has never been seen to fire.** A worker that sends
  `GATE-REQUEST` into a dead coordinator might self-clear and merge ungated; nothing
  here rules that out.
- **`ADVISE` propagation (§4.3) has never been seen to fire.** A frozen contract might
  change without its consumers ever hearing; nothing here rules that out.
- **Agent compliance with Phase 8 step 0 has never been seen.** Only its `grep` was
  exercised — and that `grep` was then shown to fail open.

Two things before this protocol touches real work: a human opens live coordinator and
worker sessions and runs injections 4 and 5; and the unanchored `Verdict PASS` grep
gets fixed with injection 3 re-run including the prose-leak probe. Until both, the
honest statement is that the release gate is **not passed**.
