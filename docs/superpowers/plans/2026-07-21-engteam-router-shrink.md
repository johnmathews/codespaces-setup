# engineering-team Router Shrink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink `configs/claude/skills/engineering-team/SKILL.md` by removing internal repetition, and prove no load-bearing meaning was lost with a before/after comprehension-probe test.

**Architecture:** Test-first. Build a probe harness (10 invariant questions, each answered by a fresh router-only subagent, graded by an independent judge subagent) and run it against the **current** router to establish an all-pass baseline — this also validates the probes. Only then edit `SKILL.md` to collapse three confirmed redundancies. Re-run the identical harness against the shrunk router; it must stay all-pass. Finish with functional regression checks.

**Tech Stack:** Markdown (the skill), the Agent tool (parallel subagent dispatch — NOT the Workflow tool), `python3` (the existing `check_report.py` gate), `shellcheck`/`shfmt` (repo CI parity).

## Global Constraints

- **One file only:** all edits land in `configs/claude/skills/engineering-team/SKILL.md`. Phase docs, references, and slash commands are out of scope.
- **Do NOT touch the `description:` frontmatter** (lines 1–15) — triggering must be preserved by construction.
- **Drop no distinct invariant and no war-story.** Only *repetition of the same rule* is removed. Every rule that appears once stays, identical in meaning.
- **Grading independence:** the shrink author does not grade probes; a judge subagent does.
- **Use the Agent tool, not the Workflow tool** (no explicit Workflow opt-in from the user).
- **Green at the end:** `python3 scripts/check_report.py --selftest` and `shellcheck`/`shfmt -i 2 -ci -kp`/`ci/lint-steps.sh` all pass.
- Scratchpad for all temp files: `/private/tmp/claude-501/-Users-john-projects-codespaces/401d3120-782a-43a3-9008-8466bcf98a2e/scratchpad`.

---

### Task 1: Probe harness + all-pass baseline on the current router

**Files:**
- Create: `<scratchpad>/SKILL.original.md` (snapshot of the current router)
- Create: `<scratchpad>/probes.md` (the 10 probes + expected-answer keys)
- Read: `configs/claude/skills/engineering-team/SKILL.md`

**Interfaces:**
- Produces: `<scratchpad>/probes.md` — the frozen probe set reused verbatim in Task 3. Each probe has an `id` (P1–P10), a `question`, and an `expected` key (the correct answer, derived from the current router).
- Produces: a **baseline results table** (P1–P10 → PASS) that Task 3's after-table must match.

- [ ] **Step 1: Snapshot the current router**

```bash
cd /Users/john/projects/codespaces
SP=/private/tmp/claude-501/-Users-john-projects-codespaces/401d3120-782a-43a3-9008-8466bcf98a2e/scratchpad
cp configs/claude/skills/engineering-team/SKILL.md "$SP/SKILL.original.md"
wc -l "$SP/SKILL.original.md"   # record baseline line count
wc -c "$SP/SKILL.original.md"   # record baseline byte count
```

Expected: prints the current size (≈394 lines). Record both numbers — they are the "before" figures for spec §4.1.

- [ ] **Step 2: Write the probe set with expected-answer keys**

Create `<scratchpad>/probes.md` with exactly these 10 probes. The `expected` keys are the correct answers read out of the current router; they are the grading rubric.

```
P1. Q: Where must $RUN_DIR live, and what are the two failures if it lives inside the worktree?
    expected: In the MAIN CHECKOUT, never inside a worktree. Failure 1: wrap-up removes the worktree, deleting the report/plan. Failure 2: parallel sessions each have their own worktree, so a per-worktree run dir breaks cross-session artifact sharing.
P2. Q: You are in a SUBDIRECTORY of the main checkout. Does a comparison of BARE `git rev-parse --git-dir` vs `--git-common-dir` correctly report "not a worktree"? Why or why not?
    expected: No — it wrongly reports "worktree". From a subdir the bare --git-dir renders ABSOLUTE while --git-common-dir renders RELATIVE, so the strings differ though the location is the same. You must pass --path-format=absolute on BOTH sides before comparing.
P3. Q: run.yaml says `phase: 3` but no improvement-plan.md exists on disk. Which wins, and what do you do?
    expected: The ARTIFACTS win. A stale run.yaml is corrected to match reality. phase>=3 implies improvement-plan.md exists; if it doesn't, fix the file (the claim can't be stronger than the check behind it).
P4. Q: What TWO conditions must BOTH hold for current.txt to identify an in-flight run you should resume?
    expected: (1) The named run directory still exists, AND (2) its run.yaml has phase: other than complete. Existence alone is insufficient because a finished run's dir also still exists.
P5. Q: When exactly can a stale current.txt hijack the next invocation?
    expected: Only when phase: is ALSO stale (not `complete`). The resume rule skips a run marked complete, so a leftover pointer to a finished run whose run.yaml still says complete cannot hijack; the hijack fires only when the phase record is stale too. (Intermittent, not a safety margin.)
P6. Q: An evaluation-only run finishes. What THREE things close it, and are they done in the worktree or the main checkout?
    expected: In the MAIN CHECKOUT: (1) remove the worktree this run created if it holds zero commits (and delete the branch); (2) set phase: complete in run.yaml; (3) rm -f .engineering-team/current.txt.
P7. Q: A SOLO session reaches Phase 2 and writes progress.md. What is its role now, and what may it no longer write?
    expected: Writing progress.md promotes it to COORDINATOR. As coordinator it owns the plan, the dashboard, and memory, and it may NOT write any lane's status file (single-writer: one artifact, one writer).
P8. Q: The user tells a FRESH session "split this across sessions." Are you the coordinator yet, and what do you do with the request?
    expected: No — that is a preference, not a role. A fresh session is still SOLO through Phases 1–2. Record the request and raise it at the Phase 2 gate; do not create a dashboard early. Let the plan's footprints decide if the split is real.
P9. Q: Which scope values run which phases, and when does Phase 4 run?
    expected: evaluate → Phase 1 only; plan → Phases 1–2; full → Phases 1–4. Phase 4 runs automatically after Phase 3, and ONLY when Phase 3 ran.
P10. Q: Why is run.yaml authoritative for `scope:` and unit `status:` but NOT for `phase:`?
     expected: Nothing on disk records scope/status, so run.yaml is the only source — trust it. But phase can be cross-checked against which artifacts exist; a stale phase "lies with authority," so there the artifacts win. Making run.yaml authoritative for everything would reintroduce the inference-failure it was added to fix.
```

- [ ] **Step 3: Run the 10 answerer subagents against the ORIGINAL router (parallel)**

Dispatch 10 Agent calls **in a single message** (concurrent), one per probe, each synchronous (`run_in_background: false`). Every answerer prompt is:

> Read the file `<scratchpad>/SKILL.original.md` and nothing else. Using ONLY its contents, answer this question concisely (3–5 sentences, no preamble). If the file does not contain the answer, say exactly "NOT IN FILE". Question: `<probe question>`

Use `subagent_type: Explore` or `general-purpose` (read-only is fine). Collect the 10 answers verbatim.

- [ ] **Step 4: Grade the baseline with one independent judge subagent**

Dispatch ONE judge Agent call. Prompt:

> You are grading answers against a rubric. For each of the 10 items you are given the question, the `expected` key, and a candidate `answer`. Mark each PASS if the answer conveys the essential content of the expected key (wording may differ; it need not be verbatim), else FAIL, with a one-line reason. Output a table: id | verdict | reason. Items: `<paste the 10 (question, expected, answer) triples>`

- [ ] **Step 5: Gate — baseline must be all-PASS**

Expected: P1–P10 all PASS. 

- If any probe FAILs on the **original** router, the probe is defective (asks something the router never stated) — **fix the probe/expected key in `<scratchpad>/probes.md` and re-run Steps 3–4 for that probe.** A shrink cannot be blamed for content the baseline never had. Do not proceed to Task 2 until baseline is all-PASS.

- [ ] **Step 6: Commit the harness**

```bash
cd /Users/john/projects/codespaces
# probes live in scratchpad (not shipped); commit only the recorded baseline into the plan/journal later.
# Nothing to commit in the repo yet — the baseline table is captured in the session and folded into the journal in Task 4.
echo "baseline recorded; no repo files changed in Task 1"
```

---

### Task 2: The shrink (collapse three confirmed redundancies)

**Files:**
- Modify: `configs/claude/skills/engineering-team/SKILL.md`

**Interfaces:**
- Consumes: nothing (self-contained edits).
- Produces: a shrunk `SKILL.md` and recorded "after" size numbers, consumed by Task 3.

- [ ] **Step 1: Redundancy #1 — collapse the 4× "$RUN_DIR in main checkout"**

Keep the statement + two-reason justification + resolution snippet at `SKILL.md:54–71` **as-is**. Remove the two pure reminders that add no new content:
- Line 193: `Either way $RUN_DIR resolves to the main checkout (above), which is why that resolution must not depend on where you are standing.` → keep only the load-bearing clause about resolution not depending on cwd, folded into the sentence before it; drop the "resolves to the main checkout (above)" restatement.
- Lines 196–197: `Remember: the worktree holds code, $RUN_DIR stays in the main checkout (above).` → **delete** (pure repetition of line 54 and 193).

- [ ] **Step 2: Redundancy #2 — state the `--path-format=absolute` gotcha once**

The gotcha is explained in full twice: `SKILL.md:73–81` (RUN_DIR resolution) and `:171–176` (worktree detection). Keep BOTH bash snippets (the commands differ). Keep the FULL explanation at its first occurrence (73–81). At the second occurrence (171–176), replace the re-explanation with a one-line back-reference, e.g.:

> The flags are load-bearing here for the same reason as in "The run directory" above — bare `git rev-parse` renders these paths relative-vs-absolute inconsistently; normalise both sides before comparing.

- [ ] **Step 3: Redundancy #3 — collapse the closing "What this router does NOT contain"**

Lines 387–394 restate the "Cross-cutting references" framing (365–385). Reduce the closing block to the single non-redundant point (the per-phase doc is authoritative), e.g. keep one line:

> **This file is intentionally short.** Per-phase steps live in `phases/`; team/workflow/worktree details live in `references/*.md`. When in doubt, the per-phase doc is authoritative for that phase's behavior.

Delete the bulleted restatement.

- [ ] **Step 4: Record the "after" size**

```bash
cd /Users/john/projects/codespaces
wc -l configs/claude/skills/engineering-team/SKILL.md
wc -c configs/claude/skills/engineering-team/SKILL.md
```

Expected: strictly fewer lines and bytes than Task 1 Step 1. Note the delta (target ballpark 40–70 lines).

- [ ] **Step 5: Eyeball diff for accidental rule loss**

```bash
cd /Users/john/projects/codespaces
git diff configs/claude/skills/engineering-team/SKILL.md
```

Expected: every removed line is a *restatement*; no removed line introduces a rule, number, or war-story that appears nowhere else. If a removed line is the ONLY occurrence of some fact, restore it.

- [ ] **Step 6: Commit the shrink**

```bash
cd /Users/john/projects/codespaces
git add configs/claude/skills/engineering-team/SKILL.md
git commit -m "$(cat <<'EOF'
refactor(engineering-team): remove internal repetition from the router

Collapse three restatements in SKILL.md (loaded every invocation) with no
loss of any distinct invariant or war-story: the 4x-stated "$RUN_DIR in the
main checkout", the twice-explained --path-format=absolute gotcha (kept both
commands, one explanation), and the closing block that restated the
cross-cutting references list.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019ThcMGkuQ62hkVHMBSDmLn
EOF
)"
```

---

### Task 3: After-run + functional regression

**Files:**
- Read: `configs/claude/skills/engineering-team/SKILL.md` (now shrunk)
- Read: `<scratchpad>/probes.md` (frozen in Task 1 — reuse verbatim)

**Interfaces:**
- Consumes: the frozen probe set from Task 1 (identical questions + expected keys) and the shrunk router from Task 2.
- Produces: an after-table that must equal the Task 1 baseline (all-PASS), plus green regression output.

- [ ] **Step 1: Run the 10 answerer subagents against the SHRUNK router (parallel)**

Identical to Task 1 Step 3, but each answerer reads `configs/claude/skills/engineering-team/SKILL.md` (the shrunk file) instead of the snapshot. Same 10 questions verbatim. Single message, 10 concurrent synchronous Agent calls.

- [ ] **Step 2: Grade with the independent judge (same rubric)**

Identical to Task 1 Step 4: one judge Agent, same expected keys, new answers → after-table.

- [ ] **Step 3: Gate — after-table must match baseline (all-PASS)**

Expected: P1–P10 all PASS, same as baseline.

- If any probe REGRESSES (PASS in baseline → FAIL now), the judge's reason names the invariant the shrink dropped. **Go back to Task 2, restore that content (it was load-bearing, not repetition), re-commit, and re-run Task 3.** This is the core behavioral test: a regression here means the shrink went too far.

- [ ] **Step 4: Functional regression — the report gate**

```bash
cd /Users/john/projects/codespaces
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
```

Expected: exit 0, self-test passes (the shrink didn't touch the gate, but confirm).

- [ ] **Step 5: Repo CI parity**

```bash
cd /Users/john/projects/codespaces
shellcheck setup.sh deploy-engineering-team-skill.sh scripts/*.sh ci/*.sh
shfmt -i 2 -ci -kp -d setup.sh deploy-engineering-team-skill.sh scripts ci
bash ci/lint-steps.sh
```

Expected: all clean (the shrink is markdown-only; this confirms no collateral).

---

### Task 4: Wrap-up (docs + journal + PR)

**Files:**
- Modify: `docs/superpowers/specs/2026-07-21-engteam-router-shrink-design.md` (stamp result if needed)
- Create: `journal/260721-engteam-router-shrink.md`

**Interfaces:**
- Consumes: baseline + after tables, size deltas.

- [ ] **Step 1: Write the journal entry**

Create `journal/260721-engteam-router-shrink.md` (repo convention: freeform markdown, graded conclusions, a `## What is deliberately not done` section). Record: the three redundancies removed, the before/after size numbers, the baseline-all-pass and after-all-pass probe results (grade: **confirmed** — observed), and that only one file was touched.

- [ ] **Step 2: Ship via /done or manual PR**

Prefer `/done` for the full wrap-up (it re-runs the doc audit, journal check, lint, and opens the PR). If shipping manually: push `feat/engteam-router-shrink`, open a PR summarizing the shrink + probe evidence, watch CI, do not merge without confirmation.

---

## Self-Review

**Spec coverage:** §2 redundancies → Task 2 Steps 1–3. §4.1 size → Task 1 Step 1 + Task 2 Step 4. §4.2 probes/baseline/after → Tasks 1 & 3. §4.3 regression → Task 3 Steps 4–5. §5 harness shape → Task 1 Steps 2–4 (Agent-based, per Global Constraints). §6 deliverables → Tasks 2–4. §7 non-goals → Global Constraints. All covered.

**Placeholder scan:** probe questions and expected keys are concrete (P1–P10); edit sites cite exact line ranges; commands are literal. No TBD/TODO.

**Type consistency:** the probe set (P1–P10, question + expected) is defined once in Task 1 Step 2 and referenced (not redefined) in Task 3. The snapshot path `<scratchpad>/SKILL.original.md` and the live path are used consistently for baseline vs after.
