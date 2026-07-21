# engineering-team router — comprehension probes (frozen)

These are the frozen probe set for the router-shrink regression test described
in [README.md](README.md). Each probe targets **one distinct invariant** the
router (`configs/claude/skills/engineering-team/SKILL.md`) must convey. The
`expected` key is the correct answer, read out of the router as written; it is
the grading rubric.

**When you edit `SKILL.md`, re-run these** (procedure in the README): if a probe
that passed against the old router fails against the new one, the edit dropped a
load-bearing invariant. Extend this set when you add a new invariant to the
router; a probe is only valid if the *current* router can answer it.

---

P1. Where must `$RUN_DIR` live, and what are the two failures if it lives inside the worktree?
expected: In the MAIN CHECKOUT, never inside a worktree. Failure 1: wrap-up removes the worktree, deleting the report/plan. Failure 2: parallel sessions each have their own worktree, so a per-worktree run dir breaks cross-session artifact sharing.

P2. You are in a SUBDIRECTORY of the main checkout. Does comparing BARE `git rev-parse --git-dir` vs `--git-common-dir` correctly report "not a worktree"? Why or why not?
expected: No — it wrongly reports "worktree". From a subdir the bare `--git-dir` renders ABSOLUTE while `--git-common-dir` renders RELATIVE, so the strings differ though the location is the same. Pass `--path-format=absolute` on BOTH sides before comparing.

P3. `run.yaml` says `phase: 3` but no `improvement-plan.md` exists on disk. Which wins, and what do you do?
expected: The ARTIFACTS win. A stale `run.yaml` is corrected to match reality. phase>=3 implies improvement-plan.md exists; if it doesn't, fix the file (a claim can't be stronger than the check behind it).

P4. What TWO conditions must BOTH hold for `current.txt` to identify an in-flight run you should resume?
expected: (1) the named run directory still exists, AND (2) its `run.yaml` has `phase:` other than `complete`. Existence alone is insufficient because a finished run's dir also still exists.

P5. When exactly can a stale `current.txt` hijack the next invocation?
expected: Only when `phase:` is ALSO stale (not `complete`). The resume rule skips a run marked complete, so a leftover pointer to a finished run whose `run.yaml` says complete cannot hijack; the hijack fires only when the phase record is stale too.

P6. An evaluation-only run finishes. What THREE things close it, and are they done in the worktree or the main checkout?
expected: In the MAIN CHECKOUT: (1) remove the worktree this run created if it holds zero commits (and delete the branch); (2) set `phase: complete` in `run.yaml`; (3) `rm -f .engineering-team/current.txt`.

P7. A SOLO session reaches Phase 2 and writes `progress.md`. What is its role now, and what may it no longer write?
expected: Writing `progress.md` promotes it to COORDINATOR. As coordinator it owns the plan, dashboard, and memory, and may NOT write any lane's status file (single-writer: one artifact, one writer).

P8. The user tells a FRESH session "split this across sessions." Are you the coordinator yet, and what do you do with the request?
expected: No — that is a preference, not a role. A fresh session is still SOLO through Phases 1–2. Record the request and raise it at the Phase 2 gate; do not create a dashboard early. Let the plan's footprints decide if the split is real.

P9. Which scope values run which phases, and when does Phase 4 run?
expected: evaluate → Phase 1 only; plan → Phases 1–2; full → Phases 1–4. Phase 4 runs automatically after Phase 3, and ONLY when Phase 3 ran.

P10. Why is `run.yaml` authoritative for `scope:` and unit `status:` but NOT for `phase:`?
expected: Nothing on disk records scope/status, so `run.yaml` is the only source — trust it. But `phase:` can be cross-checked against which artifacts exist; a stale phase "lies with authority," so there the artifacts win. Making `run.yaml` authoritative for everything would reintroduce the inference failure it was added to fix.
