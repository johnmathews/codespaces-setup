# A gate for the skill's own state file, and a home for the probe test

**Date:** 2026-07-22. **PR:** feat/engteam-run-gate. Follows [260721-engteam-router-shrink.md](260721-engteam-router-shrink.md) (which built the throwaway probe harness this session promotes). Point-in-time record; authoritative for nothing.

Two improvements to the `engineering-team` skill, from a menu of five. The theme of both: the skill is ~5,700 lines of mostly *unenforceable* prose with one executable gate; these add a second gate and give the probe test a permanent home.

## #1 — a `run.yaml` state gate (`check_run.py`)

The skill keeps a `run.yaml` recording a run's phase, scope, and per-unit status. Every invariant over it was prose the model executed by hand — the exact "a claim with no check behind it" failure the skill warns *projects* about, applied to its own bookkeeping.

`check_run.py` (beside `check_report.py`, stdlib-only, same gate-design rules) checks two things:

1. **Schema** — `run`/`phase`/`scope` enums, unit `status` enum, `abandoned` carries a `why`. Hard failures: unambiguous and mechanically fixable.
2. **Reconciliation** — the skill's own stated invariant: `phase>=2` ⟹ `evaluation-report.md` exists; `phase>=3` ⟹ `improvement-plan.md` exists; the scope-dependent `complete` case (an `evaluate` run that completed never planned, so needs no plan).

**What it does and doesn't do — stated precisely, because the first framing overclaimed.** It does not "keep the file honest." It checks the file is well-formed and *not blatantly contradicted by disk* — a claimed phase whose artifact doesn't exist at all. It cannot see an artifact that exists but is empty, or a unit marked `done` that wasn't. Those are claims about the world no file-existence check can verify. It raises the floor (rules out the crudest lies); it can't make the file true. That distinction is the honest description and is what belongs in the record.

Ships *inside* the skill (via `deploy_skill`'s `cp -a`), which is justified because the skill invokes it during real runs — wired into `SKILL.md`'s `run.yaml` section. That "invoked during use" test is exactly what separates it from #2.

## #2 — the probe test, hosted at repo level (not in the skill)

Last session's comprehension-probe harness (proving the router shrink lost no meaning) was throwaway scratchpad. It's now `tests/engineering-team-probes/` — frozen probes + a README documenting the before/after procedure.

The placement was a real decision, prompted by the user pushing back: wouldn't bundling it into the skill be bloat that only pays off when editing the skill? Correct. The cost model: it wouldn't add per-invocation *context* (scripts ship but aren't loaded), but it *would* ship skill-maintenance material into an artifact copied to every machine — a category error. `check_report.py`/`check_run.py` earn their bundled spot by running during real runs; the probe test runs on *zero* real runs, only on skill edits. So it lives outside the skill, and cannot be headless-CI anyway (it needs answerer + judge subagents). Documented as a manual, on-demand check.

## The bug the code review caught (the point of Phase 5)

Graded **confirmed** — reproduced and fixed. The first `check_run.py` de-commented only scalar *values*, not the `units:` header or unit lines. But the skill's own documented `run.yaml` template (`SKILL.md:115,118`) comments **both**. So a `run.yaml` copied from the example would either:

- **silently drop every unit** (a comment on the `units:` header meant the exact-match `line.strip() == "units:"` failed, the header fell through to the scalar branch, and all unit lines were dropped) — E4/E5/W1 no-op, a file with an invalid status or unexplained abandonment passing clean; or
- **false-flag a valid unit line** as malformed (E4), because the unit regex required `}` at end-of-line.

Both from one root, and *my fixtures missed it* because none used comments — the happy-path blindness the gate's own docstring warns about. Fixed by stripping comments at the line level; guarded by two new fixtures, one of which (`e4_commented_header`) only passes if a unit under a commented header is still parsed. Verified directly: the exact template now yields 3 parsed units and no bogus scalar.

The lesson is the one the skill already preaches and I under-applied: a gate tested only on clean input passes loudest when blind. The review was worth more than the gate.

## Verified

- Both gates green (`check_report.py --selftest`, `check_run.py --selftest`, 15 run fixtures); `ruff` clean; `py_compile` clean; shell CI parity green.
- The reconciliation branches are each red-tested, including the `complete`-scope path a numeric-phase fixture can't reach.
- The documented template parses to 3 units (printed, not assumed).

## What is deliberately not done

- **The gate is not auto-run.** `SKILL.md` instructs the model to run `check_run.py` on resume; nothing forces it. A gate the model can forget to invoke is weaker than one the harness runs — but the skill has no harness hook, and CI has no live run dir to check. The fixtures test the gate's logic; whether a real run *calls* it is still prose.
- **No content checks.** The gate checks artifacts exist, not that they are real (a non-empty plan, a genuinely-done unit). That is not mechanically checkable and is what the human-in-the-loop gates are for.
- **Three of the five suggested improvements are untouched** — a plan-structure gate (#3), a rule-ownership index (#4), triggering evals (#5). #3 is the natural next one (mirrors the report gate).
- **The router shrink (PR #37) is still open.** This branch is independent of it (off `main`, no overlapping regions).
