# A third gate: the improvement plan

**Date:** 2026-07-22. **PR:** feat/engteam-plan-gate. Third of a run of engineering-team improvements (after the router shrink and the `run.yaml` gate, both merged earlier today as #37/#38). Point-in-time record; authoritative for nothing.

The skill produces two primary artifacts per run — an evaluation report and an improvement plan — plus a `run.yaml` state file. Two of the three had executable gates (`check_report.py`, `check_run.py`); the plan did not. `check_plan.py` closes that.

## What it checks

The plan's frontmatter is load-bearing: it's the machine-readable index of `W<n>` unit IDs that Phase 3 progress reporting *and* `run.yaml` are both keyed on ("The IDs declared here are authoritative"). So the gate checks:

1. **Frontmatter validity** — begins with a `---` block, has a `plan:` name, a non-empty `units:` list, each unit a well-formed `W<n>` id with a title, no duplicate ids.
2. **Index↔body correspondence** — every frontmatter unit has a `##` section in the body and vice versa (the plan analog of `check_report`'s index↔detail check).
3. **No unfilled `<...>` placeholders** left in the frontmatter.
4. **Cross-file** — the genuinely new safety net: a `run.yaml` beside the plan must not name a unit the plan never declared (phantom → hard failure); a plan unit `run.yaml` hasn't mirrored is a warning. This catches drift the `run.yaml` gate structurally cannot: `check_run.py` validates `run.yaml` alone and has no way to know whether `W4` is a real unit.

**What it deliberately does not check:** the ~12 prose fields the spec asks of each unit (Priority, Risk, Size, Files, Reversibility, Acceptance criteria, …). Their formatting varies enough that a presence check would red honest plans — the exact "switch the gate off" failure the design rules warn about. Completeness of those fields is a human-review judgement, not a gate's. Same call `check_report` makes about prose quality.

## The bug the code review caught (again)

Graded **confirmed** — reproduced. The placeholder check (E6) was first written as a *substring* search (`<[^>]+>` anywhere on a frontmatter line). The reviewer pointed out this would red an honest plan whose unit title legitimately contained angle brackets — `Fix Optional<Config> handling`, `List<T>`, an autolink — which is realistic on generics-heavy languages, and precisely the false-positive the gate's own docstring says it must avoid. Fixed to match only when a *whole parsed value* is a placeholder (`^<...>$`), and added `good_generic_title` (a valid plan with `Optional<Config>` / `Repository<Foo>` titles that must stay green) as the guard. Verified: that plan is now green and the real placeholder fixture still reds.

This is the second consecutive gate where the pre-merge review caught a real false-positive/false-negative my own fixtures missed. The pattern is worth naming: **I write fixtures for the failures I designed for, and miss the inputs I didn't imagine** — which is exactly why the adversarial review pass, not the fixtures, is where the correctness comes from.

## A note on a review artifact

The code-review subagent flagged that its Read of `phase-2-planning.md` returned the file content with harness "system-reminder" text appended (a date-change notice, MCP instructions), and it treated that as a possible injection and ignored it. I verified the file itself is clean (`grep` for the markers found nothing but my own `check_plan` note). It was harness-injected context leaking into the subagent's tool output, not a compromised file — but the subagent handling it as suspicious-until-verified was the right instinct, and worth recording.

## Verified

- All three gates green (`check_report`/`check_run`/`check_plan --selftest`; 12 plan fixtures); `ruff` + `py_compile` clean; `shellcheck`/`shfmt`/`lint-steps` green.
- Each failure fixture raises only its intended code (checked individually); the `good` and `good_generic_title` fixtures are green.
- All gate-count references across `CLAUDE.md`, `ci.yml`, `docs/development.md` updated two→three (grepped, none stale).

## What is deliberately not done

- **No per-unit field checks** (see above) — a deliberate scope line, not an omission.
- **The gate is not auto-run** — `phase-2-planning.md` instructs the model to run it before announcing the plan, but nothing forces it, same limitation as the `run.yaml` gate. CI tests the gate's logic; whether a real run invokes it is still prose.
- **Two of the five improvement ideas remain** — #4 (rule-ownership index) and #5 (triggering evals), both deferred to fresh sessions by explicit decision (this session was already long, and #4 needs a systematic full-skill read that's better done unhurried).
