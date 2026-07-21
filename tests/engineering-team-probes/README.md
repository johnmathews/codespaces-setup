# engineering-team router — comprehension probe test

A regression test for the `engineering-team` skill's router
(`configs/claude/skills/engineering-team/SKILL.md`). It answers one question:
**did an edit to the router drop a load-bearing invariant?**

It exists because the skill is ~5,700 lines of mostly *unenforceable* prose. The
two shipped gates (`check_report.py`, `check_run.py`) check the artifacts the
skill produces; nothing checks whether the router itself still *says* what it is
supposed to say. This does — behaviourally, by asking a model to recover each
invariant from the router text alone.

## Why this is not in CI

The test is **LLM-in-the-loop**: each probe is answered by a fresh agent that
reads only the router, and the answers are graded by a separate judge agent.
There is no non-model way to run it, so it cannot live in the headless
`shellcheck`/`shfmt`/gate CI. It is a **manual, on-demand check**, run by an
agent (e.g. Claude Code) when the router changes — the same way the router
shrink that introduced it was validated. That is a deliberate limitation, not an
oversight: a probe test wired into CI would need API access and would be flaky;
an on-demand check that a human triggers on router edits is the honest shape.

## What it is

- [`probes.md`](probes.md) — the frozen probe set: 10 questions, each targeting
  one distinct router invariant, each with an `expected` answer key derived from
  the router as written.

## How to run it (before/after an edit)

The test is a **before/after** comparison. Run the baseline *before* you edit
the router, so a later failure can only be the edit's fault, not a bad probe.

1. **Snapshot** the current router: `cp configs/claude/skills/engineering-team/SKILL.md /tmp/SKILL.before.md`.
2. **Baseline.** For each probe in `probes.md`, dispatch a fresh subagent with:
   > Read the file `/tmp/SKILL.before.md` and nothing else. Using ONLY its
   > contents, answer this question concisely. If the file does not contain the
   > answer, respond exactly "NOT IN FILE". Question: `<probe question>`
   Then dispatch one judge subagent: given each `(question, expected, answer)`
   triple, mark PASS if the answer conveys the essential content of the
   `expected` key (wording may differ), else FAIL with a reason.
   **Every probe must PASS.** A FAIL here means the probe is stale (the router no
   longer says that) — fix the probe/expected key in `probes.md`, not the router.
3. **Edit** the router.
4. **After.** Repeat step 2 against the edited `SKILL.md` (the live file). Same
   questions, same judge.
5. **Compare.** The after-set must match the baseline (all PASS). Any probe that
   regressed (PASS → FAIL) names the invariant the edit dropped — restore it and
   re-run.

Dispatch the per-probe answerers concurrently (one message, multiple agent
calls) so a full pass is ~11 short subagent calls per side.

## Maintaining the probe set

- **Add a probe when you add a router invariant.** A probe set that lags the
  router silently stops covering the new rules.
- **A probe is only valid if the *current* router can answer it.** If the
  baseline can't answer a probe, the probe is wrong, not the router.
- Keep each probe to one invariant. A probe that bundles three rules can't tell
  you which one an edit broke.
