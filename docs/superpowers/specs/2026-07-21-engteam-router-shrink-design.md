# engineering-team router shrink — design

**Status:** active. **Last updated:** 2026-07-21. **Supersedes:** none.

> Purpose: shrink `configs/claude/skills/engineering-team/SKILL.md` (the router, loaded on every invocation) by removing *internal repetition* — without dropping any distinct invariant or war-story — and prove the shrink lost no load-bearing meaning with a reusable comprehension-probe test.

## 1. Problem

The engineering-team skill is ~5,700 lines, of which exactly one file — `SKILL.md`, 394 lines — is loaded on **every** invocation. A router that restates the same rule several times is less legible, not more: past some density the model satisfies the salient imperatives and drops the rest. The goal is legibility (the model can actually hold the router), measured as fewer lines with identical meaning.

This is deliberately **not** a rewrite and **not** a cross-file dedup. Scope is one file, and only its *repetition*.

## 2. Confirmed internal redundancies to collapse

Each is the **same rule stated more than once**, not distinct content:

1. **"$RUN_DIR lives in the main checkout"** — made 4×: `SKILL.md:54`, `:66–71` (the resolution), `:193` ("Either way $RUN_DIR resolves to the main checkout (above)"), `:196–197` ("Remember: the worktree holds code, $RUN_DIR stays in the main checkout (above)"). Keep the statement + the two-reason justification + the resolution snippet **once**; drop the two "(above)" reminders.
2. **The `--path-format=absolute` "flags are load-bearing" lecture** — explained at length twice: `:73–81` (RUN_DIR resolution) and `:171–176` (worktree detection). The two *commands* differ and both stay; the *explanation of why bare git-dir paths render relative-vs-absolute* is one idea — state it once, reference it at the second site.
3. **Closing "What this router does NOT contain"** (`:387–394`) restates the "Cross-cutting references" framing (`:365–385`). Collapse the redundant tail; keep the one-line "per-phase doc is authoritative" pointer.

## 3. Non-goals (YAGNI / risk control)

- **Do not touch the `description:` frontmatter** — triggering is preserved by construction.
- **Do not drop any distinct invariant** — every rule that appears once stays, verbatim in meaning.
- **Do not drop any war-story** ("one repo reached 21", "Five of one repo's 21 run directories…", the observed eval-only-run comparison). These are the justifications that make rules stick; they are the skill's quality, not its fat.
- **No cross-file changes.** Phase docs, references, and the two slash commands are out of scope.

## 4. How we prove it worked (medium rigor)

Three checks; #2 is the real one.

### 4.1 Size (objective)
Record `wc -l` and `wc -c` of `SKILL.md` before and after. Success = strictly smaller. Target ballpark: 40–70 lines (~10–18%). The number is reported, not a pass/fail threshold — a smaller honest cut beats an aggressive one that drops meaning.

### 4.2 Comprehension probes (behavioral, before/after)
A fixed set of ~10 probes, each a question targeting **one distinct invariant** the router must convey. Each probe is answered by a **fresh subagent given only the router file** (no other context), then graded against an expected-answer key derived from the **original** router.

- **Baseline run** against the **original** `SKILL.md`: every probe must be answerable and correct. This validates the probes themselves (a probe the original can't answer is a bad probe, not a shrink failure).
- **After run** against the **shrunk** `SKILL.md`: every probe must still be answered correctly.
- **Pass = after-set matches baseline-set** (all correct). Any probe that regresses names exactly which invariant the shrink dropped → fix the shrink, re-run.

Grading is done by a separate judge subagent per probe (answer + expected key → correct/incorrect + one-line reason), so grading doesn't depend on the shrink author.

Candidate probes (final list lives in the harness):
1. Where must `$RUN_DIR` live, and name the two failures if it lives inside the worktree.
2. You're in a subdirectory of the main checkout — does the **bare** `git rev-parse --git-dir` vs `--git-common-dir` comparison correctly report "not a worktree"? Why/why not?
3. `run.yaml` says `phase: 3` but no `improvement-plan.md` exists. Which wins, and what do you do?
4. What two conditions must both hold for `current.txt` to identify an in-flight run to resume?
5. When exactly can a stale `current.txt` hijack the next invocation?
6. An evaluation-only run finishes. What three things close it, and where are they done — worktree or main checkout?
7. A solo session reaches Phase 2 and writes `progress.md`. What is its role now, and what may it no longer write?
8. The user says "split this across sessions" to a fresh session. Are you the coordinator yet? What do you do with the request?
9. Which scope values run which phases, and when does Phase 4 run?
10. Why is `run.yaml` authoritative for `scope:`/unit `status:` but **not** for `phase:`?

### 4.3 Functional regression
`python3 scripts/check_report.py --selftest`, plus repo CI parity (`shellcheck` / `shfmt` / `ci/lint-steps.sh`) stay green. The shrink touches only prose in `SKILL.md`, so these should be unaffected — running them confirms nothing structural broke.

## 5. Harness shape

A small, self-contained runner (scratchpad, not shipped in the skill unless it proves worth keeping) that:
- holds the 10 probes + expected-answer keys,
- for a given `SKILL.md` path, dispatches one answerer subagent per probe (router as sole context),
- dispatches one judge subagent per (answer, key),
- prints a table: probe | baseline | after | verdict.

Implemented via the `Workflow` tool (parallel fan-out over probes, two stages: answer → judge) or plain parallel Agent calls. Not billed to the user beyond normal subagent cost; ~20 short subagent calls per full before/after cycle.

## 6. Deliverables

1. Shrunk `SKILL.md` (branch `feat/engteam-router-shrink`).
2. Recorded before/after size numbers.
3. Probe results table (baseline all-pass, after all-pass).
4. Green `check_report.py --selftest` + CI parity.
5. A journal entry, per repo convention.

## 7. What is deliberately not done

- **No new shipped test file in the skill.** The probe harness lives in scratchpad for this change. If it proves reusable we can promote it later — but adding a second executable gate is a separate improvement (the "add enforcement gate" direction we did not pick).
- **No phase-doc or reference shrink.** One file, proven, before touching the bigger/redundant-across-files targets.
