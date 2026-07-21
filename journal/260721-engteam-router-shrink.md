# Shrinking the router, and what the probe test proved instead

**Date:** 2026-07-21. **PR:** feat/engteam-router-shrink. Spec: [docs/superpowers/specs/2026-07-21-engteam-router-shrink-design.md](../docs/superpowers/specs/2026-07-21-engteam-router-shrink-design.md). Plan: [docs/superpowers/plans/2026-07-21-engteam-router-shrink.md](../docs/superpowers/plans/2026-07-21-engteam-router-shrink.md). Point-in-time record; authoritative for nothing.

The goal was legibility: shrink `SKILL.md` — the engineering-team router, the one file loaded on *every* invocation — by removing internal repetition without dropping any distinct invariant or war-story, and **prove** nothing was lost rather than asserting it.

## What was cut

Three genuine restatements, all in `SKILL.md`:

1. The **"$RUN_DIR stays in the main checkout"** reminder, stated a fourth time ("Remember: the worktree holds code…") after the rule, its two-reason justification, and its resolution snippet were already given. Deleted the reminder; kept the rule.
2. The **`--path-format=absolute` gotcha**, explained in full twice (once for `$RUN_DIR` resolution, once for worktree detection). Kept both bash snippets — the commands genuinely differ — but replaced the second full re-explanation with a back-reference to the first, retaining the "normalise both sides" instruction so the second site still stands alone.
3. The closing **"What this router does NOT contain"** block, which re-listed the `phases/` + `references/*.md` split already enumerated just above. Collapsed to the one non-redundant sentence (the per-phase doc is authoritative).

Net: **394 → 388 lines, 20,405 → 20,288 bytes.** Six lines.

## The finding is the smallness

Six lines is far under the 40–70 the spec floated as a ballpark, and that is the actual result worth recording — **graded confirmed, because it was measured, not guessed.** The router's *pure repetition* is minor. Its length is not fat; it is distinct invariants plus the war-stories that justify them ("one repo reached 21", "Five of one repo's 21 run directories…", the observed eval-only-run comparison) — exactly the content the spec forbade touching, and rightly, since those justifications are what make the rules stick.

So the honest conclusion inverts the premise a little: the router is dense but **not redundant**. The real duplication in this skill lives *across* files — the worktree-detection idiom and its "flags are load-bearing" lecture are copy-pasted in `SKILL.md`, `references/worktree.md`, `phases/phase-3-development.md`, and the `/done` and `/merge-push` commands — which a single-file shrink was deliberately scoped not to touch.

## What the test actually bought

The point of the exercise was as much the method as the six lines. A before/after **comprehension-probe harness**: 10 questions, each targeting one distinct invariant, each answered by a **fresh subagent given only the router** and graded by an **independent judge subagent**.

- **Baseline against the original router: 10/10 PASS** — which validated the probes themselves (every invariant is answerable from the file as written) *before* any edit, so a later failure could only be the shrink's fault, not a bad question.
- **After, against the shrunk router: 10/10 PASS** — same questions, same judge, no regression. Probes P2 (the back-referenced `--path-format` explanation) and P6 (the `$RUN_DIR` closing steps, adjacent to redundancy #1) landed in the edited regions and still came back correct, which is the specific evidence that the collapse preserved meaning.

This operationalises "the model can still get the right answer from fewer words" as a runnable check. For a six-line cut it is overkill on paper — meaning-preservation was nearly certain — but the deliverable the user asked for was *a way to test that a shrink works*, and now there is one. It scales to a real cut (the cross-file dedup) unchanged: freeze the probes, cut, re-run.

## Verified

Not reasoned about — run:

- `git diff` reviewed line by line: every removed line is a restatement; the `--path-format` mechanism survives in full under "The run directory"; the `$RUN_DIR`/main-checkout rule and its rationale survive; the "does NOT contain" content survives condensed.
- Baseline 10/10 and after 10/10, both graded by an independent judge subagent.
- `check_report.py --selftest` green (all 13 fixtures), and `shellcheck`/`shfmt`/`lint-steps` green — the shrink is markdown-only and touched nothing structural.

## What is deliberately not done

- **The bigger cut.** Cross-file dedup of the worktree idiom (5 copies across the skill and the two slash commands) is where the real line savings are. Not attempted here: it was scoped out as broader-risk, and one-file-proven-first was the point. The harness is now the tool that would de-risk it.
- **The harness is not shipped.** It lives in the session scratchpad, not in the skill. Promoting it to a permanent, reusable test (a "router comprehension" gate) is a real option but a separate change — and would belong to the "add an enforcement gate" direction, not this one.
- **No probe covers the phase docs or references.** The 10 questions target router invariants only, because the router was the only file edited.
