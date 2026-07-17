# Folding the Horizons workflow lessons back into the engineering-team skill

**Date:** 2026-07-17. **PR:** feat/engineering-team-horizons-lessons. Point-in-time record; authoritative for nothing.

This session started as "suggest improvements to the engineering-team skill based on what Horizons does well, particularly around documentation" and turned into a twelve-change rewrite touching every file in the skill plus all three commands. The full evaluation is in the run dir (`.engineering-team/runs/manual-20260717T000000Z/evaluation-report.md`, untracked) — this entry records what happened and what was learned, not what was decided; the decisions and their rationale (D1–D11) live in the report.

## What prompted it

Horizons has been the proving ground for this skill for two weeks, and it had drifted from it in ways nobody had written down. The clearest signal: **`/done` cannot be run to completion on Horizons at all.** Its Phase 8 merged into local `main` and pushed, which Horizons' Enterprise rulesets forbid outright — so every session there ran `/done`, stopped before Phase 8, and opened the PR by hand. The workaround was cheap enough to keep paying indefinitely, which is exactly why it survived two weeks without being noticed as a defect.

## The three things that were actually wrong

1. **The merge model.** `/merge-push` merged to `main`, pushed, *then* watched CI and fixed forward — so `main` went red by design, and "CI failed, fixed lint error, passed on retry" was listed as a *success* example. The skill had no concept of a pull request anywhere: `/done`'s Phase 9 example output mentioned `"PR #42 created"` but no step in any file created one.
2. **`references/worktree.md` gave advice that can deadlock a repo.** It said to register doc gates as required status checks, with none of the three rules that stop that wedging every open PR at once. Horizons paid for all three (path-filtered ⇒ un-requirable; job key = check context; prove-it-reports-before-requiring).
3. **No claim-strength discipline.** `/done` Phase 9 emits ten `OK`/`Fixed` verdicts. Phase 2 already carried a hand-patched local fix for exactly this failure ("Evidence required — no bare `OK`") — which is Horizons' principle 5, discovered independently, patched in one place, and never generalised to the other nine.

## What surfaced only because of the always-worktree decision

Making the worktree universal exposed a latent bug that had been sitting there the whole time. The skill was inconsistent about where `$RUN_DIR` lives — `worktree.md` said "project root *or worktree root*", Phase 3 mirrored the run pointer *into* the worktree, Phase 4 said clear it "in the project root, *not* the worktree". So on the path where the run dir ended up inside the worktree, **Phase 4's cleanup deleted the evaluation report and the plan** — the artifacts the cycle exists to produce, destroyed by the step that ends it.

Resolved as D11: `$RUN_DIR` always lives in the main checkout, resolved via `git rev-parse --git-common-dir`; worktrees hold code only. This is also what makes multi-session coordination possible at all, since lanes cannot share a run dir that lives inside one lane's worktree. **The bug was pre-existing; the decision just made it unavoidable.** Whether it ever actually bit is unknown — I did not go looking through past runs, so "latent" here is `strongly supported, not confirmed`.

## The NFR research was the most valuable part, and it wasn't the plan

Asking "which of Horizons' non-functional requirements generalise?" turned up better material than the documentation question that prompted the session. Three things:

- **Every Phase 1 evaluation is a cold, experienced engineer reading a project for the first time** — which is precisely the experiment Horizons' "~2 hour cold onboarding" bar describes, and which Horizons invokes to justify real tradeoffs in five places while never once measuring it. The skill had that measurement on tap and threw it away. Now Phase 1 reports against it (Step 2.6). Of everything in this change, this is the idea most likely to still matter in six months.
- **"Make the safe path the only path"** — Horizons' strongest technique, and one I initially wrote up so badly it read as domain-specific. It is not: it is "make illegal states unrepresentable" (Minsky 2010), "parse, don't validate" (King 2019), poka-yoke, least privilege. Its most familiar instance is parameterized SQL queries, which nobody thinks of as a policy. Horizons' telemetry wrapper and `EmailMessage` are *instances* on its own invariants and are deliberately **not** carried into the skill — they'd be noise in a CLI tool.
- **Horizons' own doc-freshness gate doesn't parse dates.** `scripts/check_docs.py` greps for three field labels in the first 15 lines and stops, so `Last verified: 2019-01-01` passes forever and so does `Last verified: banana`. Its own docs promise the gate "flags ones gone stale past a window". In a repo whose marquee post-mortem is *about a stale verification stamp*, the anti-rot gate is decoration with respect to rot. The skill now specifies the gate Horizons meant to build, with a test proving it goes red — the one place the skill is deliberately better than its source.

## Gotchas worth keeping

- **`pytest -q | tail -25` reports `tail`'s exit code.** The suite fails, the step passes, the summary says green. Horizons hit this *hours after* its verification post-mortem, in the session writing it. Now hard-coded into `/done` Phase 3 as a named rule.
- **Under squash merges, `git branch --merged main` lists nothing.** The squashed commit is a new object, so the branch tip is never an ancestor of `main`. The naive housekeeping check reaps nothing on exactly the repos that squash — which is all of them. The PR state (`gh pr view --json state`) is the authority; `git branch -d` correctly refuses and `-D` is only safe *after* confirming via the PR. This one would have shipped a housekeeping phase that silently did nothing.
- **Pushing to a merged PR's branch succeeds silently** — never merged, no CI, commits stranded, no error. Now a guard in both `/done` 8a and `/merge-push` 2A.

## Dogfooding, and one self-inflicted wound

The report's rev 1 asserted "this report follows Horizons' heading rule, as a sample." It did not — it numbered its H1s and had seven of them, which is the convention the report was arguing *against*. I wrote it because I intended to follow the rule and never checked whether I had: verification applied along the grain of confirmation bias, on the assumption I wanted to be true. That is the exact failure mode the post-mortem this whole change is built on describes, reproduced inside a document proposing the fix for it, within an hour of reading it. **Confidence is the condition under which false claims get written**, and knowing that is not protection.

The housekeeping phase was also exercised for real: `feat/engineering-team-doc-freshness` had been sitting in `/workspaces/dotfiles-wt/` fully merged. All five safety conditions checked, then reaped — `git branch -d` succeeded rather than needing `-D`, which confirmed it was a genuine ancestor merge rather than a squash.

## Six bugs found by review, in the change that fixes the bugs

Two plain questions from John — "what happens if I run engineering-team or /done *in* a worktree?" and "how do I actually start a multi-session run?" — found six real defects in this PR. Not one was found by me re-reading my own work; every one came from someone asking what happens when you *use* the thing.

(This heading said "Two bugs" through the first round and I kept appending under it without fixing the count. Left as a footnote to itself: a heading is a claim too.)

### Round 1 — git plumbing I wrote but never executed

In a change whose headline rule is *a check that cannot fail is not evidence*, I shipped two commands I had not run once.

1. **`git rev-parse --git-common-dir` returns a path relative to the cwd.** `.git` at the repo root, `../../.git` two levels down. The value is right where it is computed and silently wrong after any `cd` — which this flow does constantly, since work happens in a worktree — and a relative path cannot be handed to another session, which is the one thing multi-session needs it for. Fixed with `--path-format=absolute` (git ≥ 2.31). Note the first diagnosis was *also* overstated: I said `dirname` gave the wrong directory, and it doesn't — `../..` from `configs/claude` really is the repo root. The defect is portability, not value. Getting the severity of a bug wrong is the same failure as getting a claim wrong.

2. **Comparing `--git-dir` with `--git-common-dir` to detect a worktree is broken from any subdirectory.** From a subdir of the *main* checkout, `--git-dir` renders **absolute** and `--git-common-dir` renders **relative** — same location, different strings — so the comparison reports "you are in a worktree" whenever you stand one directory below the root. I had written, in `worktree.md`, that this comparison was "safe relative or absolute — they are both rendered the same way." That sentence was pure assertion and it was false. **This one is pre-existing**: `merge-push.md` Step 1b has had it since before this PR, and I propagated it into `/done` Phase 0 by copying the pattern. Fixed in all four sites by normalising both sides.

3. **The nested-worktree gap.** Nothing told the router what to do if the session was *already* in a worktree. It would have created a nested one — which Phase 3 forbids elsewhere, so the skill contradicted itself. The inner tree is orphaned when the outer is removed, and the work splits across two branches so the PR ships half of it. Now checked explicitly before creating anything.

The pattern across all three: **I wrote plumbing, reasoned about what it returns, and did not run it.** Reasoning about `git rev-parse` output is exactly as reliable as reasoning about whether a job that exited 0 called the model. They were fixed only after running the commands from all five locations they can be invoked from (main root, main subdir, main deep, worktree root, worktree subdir) and printing results next to expectations — thirty seconds of work I skipped twice while writing the rule against skipping it.

### Round 2 — the multi-session feature had no working entrance

"How do I start a multi-session run — can I just ask?" turned out to have an embarrassing answer: sort of, by luck, and the first real run would have collided on branch names.

4. **Every lane would compute the same branch name.** Phase 3 told each session to name its worktree `eng-<plan-short-name>` from the plan frontmatter. Every lane reads the *same* plan, so all of them derive the *same* name: the first session takes the branch, the rest collide. `/prompt`'s hand-off did specify a per-lane branch, but Phase 3 didn't say "use the name your prompt gave you" — so two docs contradicted, and the one being read at the deciding moment was the wrong one. Now `eng-<plan-short-name>-<lane>`, stated in all four places that mention naming.
5. **Asking for parallelism up front wasn't routed anywhere.** Role detection was purely on-disk (`progress.md` exists → multi-lane, else solo), so "split this across sessions" had no effect on anything. It would probably have worked anyway — the model would carry the request to the Phase 2 gate — which is exactly the kind of *luck* this change exists to replace with mechanism. Now: user intent is a **preference** recorded for the gate, not a role, because you cannot coordinate a plan that does not exist yet.
6. **The solo → coordinator transition was undefined.** Role was assigned once, at activation, from disk. A fresh run has no `progress.md` → solo. Phase 2 then writes `progress.md` mid-run and nothing anywhere said the session was now the coordinator: it would carry a stale role past the moment the single-writer rule started binding it. Now writing the dashboard **is** the promotion, stated in the router, Phase 2, and `multi-session.md`.

The pattern across round 2: **I specified the steady state and never walked the transition into it.** Every rule about how a multi-lane run *behaves* was right; nothing described how one *starts*. A feature can be entirely correct and still have no working entrance, and re-reading it will not reveal that — only trying to use it will. Which is why the question that found it was not "is this right?" but "how do I do this?"

## What is deliberately not done

- **No RFC/ADR directories for this repo.** The six-type model is now defined for every project, but directories are created on first use — a repo with no hard-to-reverse decisions has no `docs/adr/`, which is different from not having the concept.
- **No SLOs or performance gates.** Horizons has none either; inventing latency budgets for projects that don't have them is ceremony. The NFR register records absence, which is enough.
- **The Discussion workflow is untouched** — out of scope for the brief, and unreviewed.
- **No `check_docs.py` for this repo.** It has two markdown docs. The skill now specifies the gate; this repo doesn't need one yet.
- **The multi-session model is specified but unexercised.** It is lifted from a real Horizons run (one coordinator, three workers, six units, zero conflicts), but nothing in *this* repo has run it. The skill's own rule applies to the skill: **that is a doc-derived claim, not a runtime one**, and the first real multi-lane run is what would confirm it. Round 2 above is the evidence for taking that caveat seriously rather than as boilerplate — three defects sat in the entrance path, and the only reason they were found before a real run is that someone asked how to start one. **Assume there are more.** The first genuine multi-lane run is a test, and should be treated as one.
- **No test that the branch-name collision cannot come back.** The fix is prose in four files saying "append the lane". Prose is enforced by memory, which is the exact failure mode `general-guidelines.md` now warns against — the structural fix would be a naming function with one home. Not done: there is nowhere in a markdown skill to put executable code, and inventing a place is a bigger change than this PR should carry. Recording it as a known gap rather than pretending the prose is a control.
