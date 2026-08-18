# Coordinator Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the engineering-team skill a control loop — a pure coordinator session that messages, monitors, and blocking-gates worker sessions — on top of the parallel-lane model it already has.

**Architecture:** Three strictly separated planes. Messages are control-only (six types, mandatory `ref:`, no way to express "assign"). Files and issues/PRs are state, tiered by write semantics. Monitor and scheduled wakeups are read-only sensing. The gate is enforced structurally by `/done` refusing to open a PR without a PASS, not by asking workers to behave.

**Tech Stack:** Markdown skill/reference/phase docs; Python 3.13 gate scripts (stdlib only, matching `check_plan.py`); GitHub Actions CI.

**Spec:** `configs/claude/skills/engineering-team/design/coordinator-sessions-design.md`

## Global Constraints

- **Source of truth is the repo**, not the deployed skill. All edits go to `/Users/john/projects/codespaces/configs/claude/skills/engineering-team/`. `~/.claude/skills/engineering-team/` is a deployed copy; never edit it directly.
- **One canonical home per rule.** `references/rule-ownership.md` must be updated in the *same commit* that adds or moves a rule. A restatement elsewhere is a pointer, never a second copy of the rationale (spec §6.1).
- **Never name a skill subdirectory `docs/`.** `check_command_links.py` builds its reference pattern from the skill's real top-level subdir names so that project-relative paths like `docs/roadmap.md` — which `commands/done.md` cites three times, meaning the *project's* docs — are not read as skill cross-references. A `docs/` dir inside the skill makes those dangle and reds CI. This is why the design doc lives in `design/`.
- **Gate-design rules for any new check script** (verbatim from `check_plan.py`'s docstring): (1) "A hard failure must be unambiguous and mechanically fixable, or an honest plan trips it and the gate gets switched off." (2) "Softer signals are WARNINGS."
- **A new gate ships with a test proving it goes red** (`references/general-guidelines.md`).
- **Every task ends green on:** `python3 tests/engineering-team-drift/drift_scan.py --selftest && python3 tests/engineering-team-drift/drift_scan.py` and `python3 tests/engineering-team-command-links/check_command_links.py --selftest && python3 tests/engineering-team-command-links/check_command_links.py`. Call this **the gate pair**.
- Python: type annotations on all signatures, stdlib only, target 3.13.

## Deviation from the spec's build order

Spec §8 lists the drift-scan additions as step 6. **Task 1 pulls the `design/` corpus exclusion forward to first.** Reason: `drift_scan.py:86 skill_docs()` globs `SKILL.rglob("*.md")` and excludes only `scripts/`, so `design/` is currently in the restatement corpus. It passes today only because the design doc contains no *current* signature phrase verbatim. Task 7 adds signatures whose phrases the design doc quotes verbatim — so without Task 1 first, Task 7 turns CI yellow with self-inflicted restatement warnings. Everything else follows spec §8 order.

---

### Task 1: Exclude `design/` from the drift-scan corpus

**Files:**
- Modify: `tests/engineering-team-drift/drift_scan.py` (`skill_docs()`, ~line 86; `selftest()`, ~line 298)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `skill_docs() -> dict[str, str]` keyed by SKILL-relative path, now excluding both `scripts/` and `design/`. Tasks 2, 3, 6, 7 rely on design-doc prose not counting as rule prose.

- [ ] **Step 1: Write the failing assertion in `selftest()`**

Find `def selftest() -> int:` (~line 298). Add this assertion inside it, alongside the existing `fails` accumulation:

```python
    # design/ holds design docs, not rule prose: it must not enter the corpus,
    # or a design doc quoting a signature phrase self-reports as a restatement.
    docs = skill_docs()
    if any(rel.startswith("design/") for rel in docs):
        fails.append("skill_docs() must exclude design/ (design docs are not rule prose)")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd /Users/john/projects/codespaces && python3 tests/engineering-team-drift/drift_scan.py --selftest`
Expected: FAIL, naming `skill_docs() must exclude design/`. (The design doc from PR #46 is present, so the corpus contains it.)

- [ ] **Step 3: Make the minimal change to `skill_docs()`**

Replace the docstring and the skip condition:

```python
def skill_docs() -> dict[str, str]:
    """All skill prose markdown, keyed by SKILL-relative path. Excludes scripts/
    (gate code + fixtures) and design/ (design documents) — neither is rule prose.

    design/ matters specifically: a design doc argues *about* the rules and quotes
    their signature phrases verbatim, so including it would make every such doc
    self-report as a restatement of the rule it documents."""
    out: dict[str, str] = {}
    for p in sorted(SKILL.rglob("*.md")):
        rel = p.relative_to(SKILL).as_posix()
        if rel.startswith(("scripts/", "design/")):
            continue
        out[rel] = p.read_text()
    return out
```

- [ ] **Step 4: Run to verify it passes**

Run: `python3 tests/engineering-team-drift/drift_scan.py --selftest && python3 tests/engineering-team-drift/drift_scan.py`
Expected: selftest OK, then `drift-scan OK (0 warnings, no failures)`.

- [ ] **Step 5: Commit**

```bash
git add tests/engineering-team-drift/drift_scan.py
git commit -m "test(drift-scan): exclude design/ from the rule-prose corpus

A design doc argues about the rules and quotes their signature phrases
verbatim, so including design/ makes every such doc self-report as a
restatement of the rule it documents. scripts/ was already excluded for
the same class of reason."
```

---

### Task 2: `references/coordination-protocol.md` + rule-ownership registration

**Files:**
- Create: `configs/claude/skills/engineering-team/references/coordination-protocol.md`
- Modify: `configs/claude/skills/engineering-team/references/rule-ownership.md` (§2 table, §3 new subsection, §4 pair list)
- Modify: `configs/claude/skills/engineering-team/SKILL.md` ("Cross-cutting references" list)

**Interfaces:**
- Consumes: Task 1's corpus exclusion.
- Produces: the canonical home for every new rule. Tasks 3, 5, 6, 7 all cite `references/coordination-protocol.md` §<heading> and depend on these **exact headings existing**, because `drift_scan.check_index_homes` resolves every cited home to a real heading:
  - `## 1. The three planes`
  - `## 2. The message protocol`
  - `## 3. The gate`
  - `## 4. Interface contracts and unit zero`
  - `## 5. Sensing and the autonomy boundary`

- [ ] **Step 1: Write `references/coordination-protocol.md`**

Content is spec §1–§5, rewritten as *instruction* rather than *design argument* (drop the "what came out of it" framing; keep the rules). Section-by-section source mapping — read the spec alongside this plan:

| New heading | Spec source | Must contain verbatim (Task 7 greps for these) |
|---|---|---|
| `## 1. The three planes` | §1.1, §1.2 | the three-plane list and the write-semantics tier table |
| `## 2. The message protocol` | §2.1–§2.5 | `Every message carries a ref` |
| `## 3. The gate` | §3.1–§3.6 | the four `CHANGES` criteria, the round limit, the gate-file template incl. `PENDING` |
| `## 4. Interface contracts and unit zero` | §4.1–§4.5 | the register tables, the U0 rule, the integration-gate procedure |
| `## 5. Sensing and the autonomy boundary` | §5.1–§5.6 | `No message type in the protocol can assign work` and `sense autonomously; act only on request` |

Follow `references/documentation-model.md` heading numbering (decimal, one H1). Open with a `> Loaded when …` blockquote matching `multi-session.md`'s style.

- [ ] **Step 2: Register it in `rule-ownership.md` §2**

Add this row to the "Homes at a glance" table, after the `multi-session.md` row:

```markdown
| `references/coordination-protocol.md` | the three planes (control / state / sensing); the six-type message vocabulary + the mandatory `ref`; the blocking pre-PR gate + its four CHANGES criteria + the round limit; the contract register + unit zero + the integration gate; the sense-don't-act autonomy boundary |
```

- [ ] **Step 3: Add the §3 subsection**

Insert after the "Homed in `multi-session.md`" block:

```markdown
### Homed in `coordination-protocol.md`

| Invariant | Canonical home | Also stated in |
|---|---|---|
| Messages carry no state — every message names a `ref` to where the fact is written | §2 "The message protocol" | `multi-session.md` §7 (pointer); phase 3 |
| No message type can assign work; sense autonomously, act only on request | §5 "Sensing and the autonomy boundary" | `multi-session.md` §7 (pointer); phase 3 |
| The gate blocks before the PR exists; CHANGES for exactly four falsifiable reasons; escalate after two rounds | §3 "The gate" | `commands/done.md` Phase 8 step 0 (the **enforcement** — see §4); phase 3 |
| Contracts are frozen and coordinator-owned; a non-empty register requires unit zero | §4 "Interface contracts and unit zero" | phase 2 Step 3.5 |
| A coordinator writes no code and runs no lane | `multi-session.md` §5.1 | §1 here (pointer) |
```

- [ ] **Step 4: Add the edit-together pair to §4**

Append as item 4 in the numbered list under "## 4. Edit-together pairs":

```markdown
4. **The gate rule vs its enforcement** — the rule in
   `coordination-protocol.md` §3 "The gate" ↔ the barrier in
   `commands/done.md` Phase 8 step 0. Split by design (rule vs enforcement),
   exactly like the status-stamp pair above. If the gate-file name or its
   `Verdict PASS` line changes in one, it must change in the other in the same
   edit, or `/done` silently stops gating.
```

- [ ] **Step 5: Add it to `SKILL.md`'s reference list**

In "## Cross-cutting references", after the `multi-session.md` bullet:

```markdown
- `references/coordination-protocol.md` — how coordinator and worker sessions
  talk: the message vocabulary, the blocking pre-PR gate, interface contracts,
  and the sensing boundary. Load it with `multi-session.md` whenever a run has
  lanes.
```

- [ ] **Step 6: Run the gate pair**

Run both commands from **Global Constraints**.
Expected: drift-scan OK 0 warnings; link-check OK. If drift-scan reports an unresolved home, a heading in Step 1 does not match what Step 3 cites — fix the heading, not the citation.

- [ ] **Step 7: Commit**

```bash
git add configs/claude/skills/engineering-team/references/coordination-protocol.md \
        configs/claude/skills/engineering-team/references/rule-ownership.md \
        configs/claude/skills/engineering-team/SKILL.md
git commit -m "feat(engineering-team): add the coordination protocol reference

Canonical home for the control plane the multi-session model never had:
the six-type message vocabulary, the blocking pre-PR gate, frozen interface
contracts plus unit zero, and the sense-don't-act autonomy boundary.
Registered in rule-ownership so the drift-scan guards it."
```

---

### Task 3: Tighten `multi-session.md`

**Files:**
- Modify: `configs/claude/skills/engineering-team/references/multi-session.md` (§5.1, §6.1, §7, §10)

**Interfaces:**
- Consumes: `references/coordination-protocol.md` headings from Task 2.
- Produces: §5.1 without the both-hats permission. Task 6's phase-3 edits assume a coordinator never runs a lane.

- [ ] **Step 1: Remove the both-hats permission in §5.1**

Delete item 6 entirely:

```markdown
6. May run a lane itself — but then it wears both hats and must respect the
   single-writer rule on both.
```

Replace with:

```markdown
6. **Writes no code and runs no lane.** The coordinator owns the gate
   (`coordination-protocol.md` §3), and a gate applied to your own work is not a
   gate — nor is a reviewer independent once it has written the code it reviews.
   A run with no spare session stays solo; it does not get a coordinator that
   also builds.
```

- [ ] **Step 2: Add the contract register and Proposals to the §6.1 template**

In the `progress.md` template, after the `## 2. Status board` block and before `## 3. Cross-session facts`, insert:

```markdown
## 3. Contract register
<frozen cross-lane interfaces and reservations — `coordination-protocol.md` §4.
Interfaces: ID, producer lane, consumer lanes, the contract, frozen-at.
Reservations: migration-number / port / config-key / flag-name / error-code
ranges, allocated per lane.>

## 4. Proposals (coordinator → human, never self-enacted)
<plan changes, re-lanes, and new units the coordinator has sensed a need for and
is asking for. `coordination-protocol.md` §5.>
```

Renumber the existing `## 3. Cross-session facts` → `## 5.` and `## 4. Coordinator log` → `## 6.`

- [ ] **Step 3: Add pointer lines to §7**

Append to the numbered invariant list (pointers only — the rationale lives in `coordination-protocol.md`, per the one-home rule):

```markdown
7. **Messages carry no state** → a session dying loses nothing
   (`coordination-protocol.md` §2).
8. **No message can assign work** → the autonomy boundary is structural
   (`coordination-protocol.md` §5).
9. **The gate blocks before the PR exists** → broken work never becomes a review
   artifact (`coordination-protocol.md` §3).
```

- [ ] **Step 4: Soften the §10 same-machine risk**

Replace the **Same-machine assumption** bullet's final sentence with:

```markdown
  A session on a different host needs its context **inlined into its prompt** —
  `/prompt` can do this when asked. The append-only tier of the state plane
  (issue and PR comments — `coordination-protocol.md` §1) is reachable from
  anywhere and lifts part of this, but `$RUN_DIR` itself is still local.
```

- [ ] **Step 5: Run the gate pair**

Expected: both green. The drift-scan's `single-writer` signature (`one artifact, one writer`) must still be present at this file — do not touch §2.

- [ ] **Step 6: Commit**

```bash
git add configs/claude/skills/engineering-team/references/multi-session.md
git commit -m "feat(engineering-team)!: a coordinator no longer runs a lane

Removes the both-hats permission in 5.1. With a blocking gate, a coordinator
that also builds is gating its own work, and a reviewer that wrote the code
is not independent. Adds the contract register and Proposals to the progress.md
template, and points 7 at the new protocol invariants."
```

---

### Task 4: The `/done` barrier — Phase 8 step 0

**Files:**
- Modify: `configs/claude/commands/done.md` (Phase 8, section `### 8a — Remote exists (the normal path)`)

**Interfaces:**
- Consumes: the gate-file name and `Verdict PASS` line from `coordination-protocol.md` §3 (Task 2).
- Produces: the structural barrier. Task 8's injection 3 tests exactly this.

- [ ] **Step 1: Insert step 0 into `### 8a`**

Insert **before** the current item 1 ("Check you're not on `main`"), and renumber the existing items 1–5 to 2–6:

```markdown
1. **Gate check — lanes only.** If `$RUN_DIR/progress.md` exists, this run has
   lanes and you are a worker. Do **not** open a PR unless
   `$RUN_DIR/gate-<lane>-<unit>.md` exists and contains `Verdict PASS`:

   ```bash
   grep -l 'Verdict PASS' "$RUN_DIR/gate-$LANE-$UNIT.md" 2>/dev/null \
     || echo "BLOCKED: no PASS verdict for $LANE/$UNIT"
   ```

   If it is missing or reads `PENDING`/`CHANGES`, **stop**. Send `GATE-REQUEST`
   to the coordinator if you have not already, and wait. Never self-clear — a
   stalled lane is recoverable, an ungated merge is what the gate is paid to
   prevent (`~/.claude/skills/engineering-team/references/coordination-protocol.md` §3).
   On a solo run (`progress.md` absent) this step does not apply; continue.
```

- [ ] **Step 2: Run the gate pair**

Expected: link-check OK — the new `references/coordination-protocol.md` path must resolve, which it does because Task 2 created it. **If Task 2 was skipped this reds**, which is the correct dependency signal.

- [ ] **Step 3: Verify the barrier text is reachable from the rule**

Run: `grep -n "Phase 8 step 0" configs/claude/skills/engineering-team/references/rule-ownership.md`
Expected: one hit, from Task 2 Step 4's edit-together pair. If zero, the pair was not registered and the two halves can drift.

- [ ] **Step 4: Commit**

```bash
git add configs/claude/commands/done.md
git commit -m "feat(done): refuse to open a lane's PR without a PASS verdict

Makes the gate structural instead of advisory. Without this, 'blocking gate'
means whatever the worker feels like, and broken work still becomes a review
artifact. Solo runs are unaffected: no progress.md, no gate."
```

---

### Task 5: `check_board.py` and its fixtures

**Files:**
- Create: `configs/claude/skills/engineering-team/scripts/check_board.py`
- Create: `configs/claude/skills/engineering-team/scripts/fixtures_board/good/progress.md`
- Create: `configs/claude/skills/engineering-team/scripts/fixtures_board/e2_prose_footprint/progress.md`
- Create: `configs/claude/skills/engineering-team/scripts/fixtures_board/e3_overlap/progress.md`
- Create: `configs/claude/skills/engineering-team/scripts/fixtures_board/e7_coordinator_lane/progress.md`
- Create: `configs/claude/skills/engineering-team/scripts/fixtures_board/w1_no_status_file/progress.md`

**Interfaces:**
- Consumes: the board format from `multi-session.md` §6.1 as amended by Task 3 (six numbered sections; contract register is §3).
- Produces: `python3 check_board.py <run_dir>` → exit 0 clean / 1 on any ERROR; `--selftest` → exit 0 if every fixture behaves as its directory name declares. Task 7 wires both into CI.

- [ ] **Step 1: Write the fixtures first**

`fixtures_board/good/progress.md` — a minimal valid board. Two lanes, disjoint footprints, one contract, no U0 needed because the register has one entry so U0 *is* required — include it:

```markdown
# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

## 1. Tracking contract
Single-writer per artifact. Lanes record ticks in their own status file.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| U0 | a | `src/api/types.py` | eng-demo-a | merged | 1 | — | contract stubs |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | a | b | `def resolve(id: str) -> Account \| None` in `src/api/types.py` | plan approval |

## 4. Proposals
none

## 5. Cross-session facts
none

## 6. Coordinator log
- 2026-08-18 board created
```

`e2_prose_footprint/progress.md` — copy `good`, change W2's `Owns` cell to `the reporting stuff`.

`e3_overlap/progress.md` — copy `good`, change W2's `Owns` cell to `src/api/reports.py` (a definite overlap: it sits under lane a's `src/api/**`).

`e7_coordinator_lane/progress.md` — copy `good`, add a row `| W3 | coordinator | \`src/misc/**\` | eng-demo-c | not-started | — | — | — |`.

`w1_no_status_file/progress.md` — identical to `good`. The warning comes from no `status-a.md` sitting beside it, which is true of every fixture dir; assert it as a WARN so honest early-run boards are not hard-failed.

- [ ] **Step 2: Write `check_board.py`**

```python
#!/usr/bin/env python3
"""Structural gate for an engineering-team progress dashboard.

`progress.md` is what makes a run multi-lane, and until this gate it was
unchecked. Two of its claims are load-bearing and mechanically verifiable:
lane file footprints must be disjoint (`references/multi-session.md` §3 calls
the check "mechanical" but nothing ran it — a human read the table), and a
non-empty contract register requires a unit zero
(`references/coordination-protocol.md` §4).

Same two gate-design rules as the sibling gates:

1. A hard failure must be unambiguous and mechanically fixable, or an honest
   board trips it and the gate gets switched off. This is why only *definite*
   overlaps are ERRORs — identical paths, or one a directory-prefix of another.
   A glob that cannot be resolved against the working tree is a WARN (W3), not
   a failure.
2. Softer signals are WARNINGS: a lane with no status file yet (it may simply
   not have started), and a board branch that does not exist in git yet.

Usage:
    python3 check_board.py <run_dir>     # gate a real run
    python3 check_board.py --selftest    # run the fixtures beside this file
"""

from __future__ import annotations

import pathlib
import re
import sys

ROW = re.compile(r"^\|(?P<cells>.+)\|\s*$")
PATHISH = re.compile(r"[/*]")


def _cells(line: str) -> list[str]:
    m = ROW.match(line.rstrip())
    if not m:
        return []
    return [c.strip().strip("`") for c in m.group("cells").split("|")]


def _section(text: str, heading_re: str) -> list[str]:
    """Lines belonging to the first heading matching heading_re."""
    out: list[str] = []
    inside = False
    for line in text.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = bool(re.search(heading_re, line, re.I))
            continue
        if inside:
            out.append(line)
    return out


def _footprints(cell: str) -> list[str]:
    return [p.strip().strip("`") for p in cell.split(",") if p.strip()]


def _definite_overlap(a: str, b: str) -> bool:
    """True only for unambiguous overlap: identical, or one a dir-prefix of the
    other. Glob subtleties are deliberately left to W3."""
    if a == b:
        return True
    for x, y in ((a, b), (b, a)):
        base = x[:-2].rstrip("/") if x.endswith("**") else None
        if base and (y == base or y.startswith(base + "/")):
            return True
    return False


def check(run_dir: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    board = run_dir / "progress.md"
    text = board.read_text()

    rows = [c for line in _section(text, r"Status board") if (c := _cells(line))]
    body = [r for r in rows if len(r) >= 4 and r[0].lower() not in ("unit", "") and not set(r[0]) <= {"-"}]
    if not body:
        errors.append("ERROR E1 progress.md: no status board rows found")
        return errors, warnings

    owns: dict[str, list[str]] = {}
    for r in body:
        unit, lane, cell = r[0], r[1], r[2]
        if lane.lower() == "coordinator":
            errors.append(f"ERROR E7 {unit}: the coordinator is listed as a lane owner "
                          "(a coordinator writes no code — multi-session.md §5.1)")
        if not PATHISH.search(cell):
            errors.append(f"ERROR E2 {unit}: Owns cell {cell!r} is prose, not a file footprint")
            continue
        owns.setdefault(lane, []).extend(_footprints(cell))

    lanes = sorted(owns)
    # W1 is per lane, not per row: a lane with three units must not warn three times.
    for lane in lanes:
        if not (run_dir / f"status-{lane}.md").is_file():
            warnings.append(f"WARN  W1 lane {lane}: no status-{lane}.md yet")

    for i, la in enumerate(lanes):
        for lb in lanes[i + 1:]:
            for pa in owns[la]:
                for pb in owns[lb]:
                    if _definite_overlap(pa, pb):
                        errors.append(f"ERROR E3 lanes {la}/{lb}: footprints overlap "
                                      f"({pa} vs {pb}) — any overlap means one lane")

    reg = [c for line in _section(text, r"Contract register") if (c := _cells(line))]
    entries = [r for r in reg if len(r) >= 2 and r[0].upper().startswith("C")]
    if entries and not any(r[0].upper() == "U0" for r in body):
        errors.append("ERROR E6 progress.md: contract register is non-empty but the "
                      "board declares no U0 (coordination-protocol.md §4)")
    for r in entries:
        for lane in (r[1], *(x.strip() for x in r[2].split(","))) if len(r) > 2 else (r[1],):
            if lane and lane not in owns:
                errors.append(f"ERROR E4 contract {r[0]}: names lane {lane!r}, not on the board")

    return errors, warnings


def selftest() -> int:
    fixtures = pathlib.Path(__file__).parent / "fixtures_board"
    if not fixtures.is_dir():
        print(f"FAIL: no fixtures directory at {fixtures}")
        return 1
    fails: list[str] = []
    for case in sorted(p for p in fixtures.iterdir() if (p / "progress.md").is_file()):
        errors, warnings = check(case)
        name = case.name
        if name == "good":
            if errors:
                fails.append(f"{name}: expected clean, got {errors}")
        elif name.startswith("e"):
            code = name.split("_")[0].upper()
            if not any(code in e for e in errors):
                fails.append(f"{name}: expected {code}, got {errors or 'nothing'}")
        elif name.startswith("w"):
            code = name.split("_")[0].upper()
            if errors:
                fails.append(f"{name}: expected only warnings, got errors {errors}")
            if not any(code in w for w in warnings):
                fails.append(f"{name}: expected {code}, got {warnings or 'nothing'}")
    for f in fails:
        print(f"  - {f}")
    print("BOARD SELFTEST FAILED:" if fails else "OK: every fixture behaves as specified")
    return 1 if fails else 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_board.py <run_dir> | --selftest", file=sys.stderr)
        return 2
    if argv[1] == "--selftest":
        return selftest()
    run_dir = pathlib.Path(argv[1]).expanduser().resolve()
    if not (run_dir / "progress.md").is_file():
        print(f"ERROR: no progress.md at {argv[1]}", file=sys.stderr)
        return 2
    errors, warnings = check(run_dir)
    for line in errors + warnings:
        print(line)
    print(f"\nboard check: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 3: Run the selftest and watch it go red first**

Before creating the fixtures, run: `python3 configs/claude/skills/engineering-team/scripts/check_board.py --selftest`
Expected: `FAIL: no fixtures directory` — proving the selftest can fail. Then create the fixtures from Step 1 and re-run.

- [ ] **Step 4: Run to verify it passes**

Run: `python3 configs/claude/skills/engineering-team/scripts/check_board.py --selftest`
Expected: `OK: every fixture behaves as specified`

- [ ] **Step 5: Prove E3 catches the real-world case from the spec**

Run: `python3 configs/claude/skills/engineering-team/scripts/check_board.py configs/claude/skills/engineering-team/scripts/fixtures_board/e3_overlap`
Expected: exit 1, with `ERROR E3 lanes a/b: footprints overlap (src/api/** vs src/api/reports.py)`

- [ ] **Step 6: Commit**

```bash
git add configs/claude/skills/engineering-team/scripts/check_board.py \
        configs/claude/skills/engineering-team/scripts/fixtures_board/
git commit -m "feat(engineering-team): gate the progress dashboard

multi-session.md 3 calls the disjointness check 'mechanical' and then nothing
ran it — a human read the table. E3 runs it. Also catches prose footprints,
a coordinator listed as a lane owner, and a contract register with no U0.
Only definite overlaps hard-fail; unresolvable globs warn."
```

---

### Task 6: Phase 2 and Phase 3 edits

**Files:**
- Modify: `configs/claude/skills/engineering-team/phases/phase-2-planning.md` (Step 3.5, Step 3.6)
- Modify: `configs/claude/skills/engineering-team/phases/phase-3-development.md` ("If this run has lanes")

**Interfaces:**
- Consumes: `coordination-protocol.md` §3/§4/§5 (Task 2); the no-lane rule (Task 3); `check_board.py` (Task 5).
- Produces: the operational entry points. Nothing later consumes these.

- [ ] **Step 1: Extend phase-2 Step 3.5 with the contract register**

Append to Step 3.5, after the existing footprint/lane derivation:

```markdown
**Then build the contract register.** Disjoint footprints prevent merge
conflicts, not composition failures: two lanes each adding a migration numbered
`0007_*` is a clean merge and a broken schema. List every seam where one lane's
output is another's input (signatures, types, wire formats, schemas) and every
resource that collides without sharing a file (migration numbers, ports, config
keys, flag names, error codes). Allocate ranges per lane. Full rules and the
table shapes: `../references/coordination-protocol.md` §4.

**If the register is non-empty, the plan gets a U0** that lands every seam as
stubs and types and merges before any lane launches. If it is empty, there is
no U0.
```

- [ ] **Step 2: Update phase-2 Step 3.6**

Replace the sentence "Do not start a lane's work yourself unless you are also running that lane." with:

```markdown
   **Do not run a lane yourself.** As coordinator you own the gate, and a gate
   applied to your own work is not a gate (`../references/multi-session.md` §5.1).
```

Then append a new numbered item 5:

```markdown
5. **Validate the board before handing out prompts:**
   `python3 scripts/check_board.py "$RUN_DIR"`. It catches footprint overlaps,
   prose footprints, and a non-empty register with no U0 — all of which are
   cheap now and expensive after three sessions have started.
```

- [ ] **Step 3: Extend phase-3's worker rules**

In the "If this run has lanes" section, append to the worker bullet list:

```markdown
- **Pass the gate before `/done`.** When you believe the unit is complete,
  commit and push your branch — **no PR** — then send `GATE-REQUEST` to the
  coordinator. `/done` will refuse to open a PR without a `Verdict PASS`
  (`../references/coordination-protocol.md` §3). If no verdict arrives, resend
  once, then stop and say so. Never self-clear.
```

- [ ] **Step 4: Extend phase-3's coordinator paragraph**

Replace "If you are the **coordinator**, load `../references/multi-session.md` and follow it" with:

```markdown
If you are the **coordinator**, load `../references/multi-session.md` *and*
`../references/coordination-protocol.md`, and follow both: you own the plan, the
dashboard, memory, and the gate, and you reconcile — you do not reach into lanes
and you do not run one. Arm the liveness monitor and the reconciliation tick
(§5 of the protocol) before the first lane starts, so a silent lane looks
different from a working one.
```

Then append a new bullet to the same section:

```markdown
- **Run the integration gate whenever the set of gate-passing lanes changes** —
  including after a resubmit, not only at the end. Create your own throwaway
  worktree `eng-<plan>-integration`, merge every passing lane branch into it,
  and run the full suite, build, and lint. Green greenlights the merges to the
  user in the recorded order; red attributes the failure to a seam and `ADVISE`s
  the owning lane. The tree is a **probe, never merged** — delete and rebuild it
  freely (`../references/coordination-protocol.md` §4).
```

- [ ] **Step 5: Run the gate pair**

Expected: both green. Every `../references/...` path cited must resolve.

- [ ] **Step 6: Commit**

```bash
git add configs/claude/skills/engineering-team/phases/
git commit -m "feat(engineering-team): wire the coordination protocol into phases 2 and 3

Phase 2 builds the contract register and validates the board before prompts go
out. Phase 3 workers gate before /done; coordinators arm sensing and no longer
run a lane."
```

---

### Task 7: Drift-scan signatures and CI wiring

**Files:**
- Modify: `tests/engineering-team-drift/drift_scan.py` (`SIGNATURES`, ~line 57)
- Modify: `.github/workflows/ci.yml` (`engineering-team gates (fixtures)` step, ~line 60)

**Interfaces:**
- Consumes: the exact headings and verbatim phrases from Task 2; Task 1's corpus exclusion (without it these signatures warn against the design doc); `check_board.py --selftest` from Task 5.
- Produces: CI enforcement. Nothing later consumes it.

- [ ] **Step 1: Add the signatures**

Add to the `SIGNATURES` dict:

```python
    "messages-carry-no-state": ("references/coordination-protocol.md",
                                r"Every message carries a `?ref`?"),
    "no-assign-message": ("references/coordination-protocol.md",
                          r"No message type in the protocol can assign work"),
    "sense-dont-act": ("references/coordination-protocol.md",
                       r"[Ss]ense autonomously.{0,3} act only on request"),
```

- [ ] **Step 2: Run to verify it fails without the phrases**

Run: `python3 tests/engineering-team-drift/drift_scan.py`
Expected: if Task 2's file is missing any phrase verbatim, FAIL naming the signature. This is the check proving the gate can go red. Fix `coordination-protocol.md` — not the regex — if a phrase is absent.

- [ ] **Step 3: Wire `check_board.py` into CI**

In `.github/workflows/ci.yml`, extend the `engineering-team gates (fixtures)` step:

```yaml
      - name: engineering-team gates (fixtures)
        run: |
          python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
          python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
          python3 configs/claude/skills/engineering-team/scripts/check_plan.py --selftest
          python3 configs/claude/skills/engineering-team/scripts/check_board.py --selftest
```

- [ ] **Step 4: Run everything CI runs, locally**

```bash
cd /Users/john/projects/codespaces
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_plan.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_board.py --selftest
python3 tests/engineering-team-drift/drift_scan.py --selftest
python3 tests/engineering-team-drift/drift_scan.py
python3 tests/engineering-team-command-links/check_command_links.py --selftest
python3 tests/engineering-team-command-links/check_command_links.py
```

Expected: all eight green, drift-scan at **0 warnings**. Any restatement warning naming `design/` means Task 1 was not applied.

- [ ] **Step 5: Commit**

```bash
git add tests/engineering-team-drift/drift_scan.py .github/workflows/ci.yml
git commit -m "ci: guard the coordination protocol's invariants and gate the board

Adds drift-scan signatures for the three rules whose removal would silently
un-make the design, and runs check_board.py in the fixtures gate."
```

---

### Task 8: The red-team dry run — the release gate

**Files:**
- Create: `/tmp/coord-redteam/` (scratch git repo — throwaway, never committed)
- Create: `journal/<yymmdd>-coordinator-redteam.md` in this repo

**Interfaces:**
- Consumes: everything from Tasks 1–7.
- Produces: the evidence that the gates go red. **Nothing ships to real work before this passes.**

- [ ] **Step 1: Build the scratch run**

Create a throwaway git repo with a 3-unit plan, 2 lanes with disjoint footprints, and 1 contract (so U0 exists). Write `$RUN_DIR/progress.md` in the Task 3 format. Open one coordinator session and two worker sessions.

- [ ] **Step 2: Run the five injections**

Each row must produce its stated observation. Record the actual output for each.

| # | Injected failure | Must produce |
|---|---|---|
| 1 | Kill a worker's terminal mid-lane | Monitor quiet-band notification (protocol §5) |
| 2 | Lane edits a file outside its footprint | drift check flags it (protocol §5) |
| 3 | Lane runs `/done` with no PASS | Phase 8 step 0 refuses (Task 4) |
| 4 | `GATE-REQUEST` to a stopped coordinator | stall protection escalates; lane does **not** self-clear |
| 5 | Lane proposes a contract change | `ADVISE` reaches the consumer lane |

- [ ] **Step 3: Judge honestly**

**If any injection stays silent, that gate is decorative.** Do not record it as passing. Open an issue naming the gap and stop — the protocol is not ready.

- [ ] **Step 4: Write the journal entry**

`journal/<yymmdd>-coordinator-redteam.md`: what was injected, what was observed verbatim, and what stayed silent. A silent gate is the finding, not a footnote.

- [ ] **Step 5: Commit**

```bash
git add journal/
git commit -m "docs(journal): red-team run for the coordination protocol

Five injected failures, what each gate actually produced. Gate 7 of the
build order: nothing uses this protocol on real work until these observations
exist."
```
