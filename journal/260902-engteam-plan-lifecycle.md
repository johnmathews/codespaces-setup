# 260902 — engineering-team: the plan is tracked while live, and retired at closeout

> Purpose
>
> Record why the `engineering-team` skill now tracks a run's `improvement-plan.md`
> in git for the life of the run and deletes it at closeout, why run artifacts
> stay untracked, and the citation failure that prompted the second half.

## 1. The ask

From a real repo (`simmons-one/horizons`), after an audit of its
`.engineering-team/runs/` directory found five runs and three untracked plans:

> "if tracked documents are going to refer to the plan then it makes sense that
> the plan should also be tracked, but also we have so much documentation
> already that i dont want to add another class of record keeping … if the plan
> is implemented and documentation created about the features or changes that
> are shipped then we shouldn't need to keep the plan."

## 2. What was already true, and what wasn't

That repo had already done the in-repo half a month earlier: its `.gitignore`
un-ignores `runs/*/improvement-plan.md` (four rules, because git cannot
re-include a file under a recursively excluded parent) and its docs gate checks
that file. Its own verification plan predicted what would happen next:

> **The default has not changed**: the next run still writes to
> `.engineering-team/runs/<timestamp>/`, and moving one document by hand is a
> habit, not a mechanism.

It was right. Five runs later, two plans were tracked and three were not — and
of the two, one had been tracked *retroactively* after a broken link in it
reached `main` unseen, precisely because the file was not in the set CI checks.

The skill was the reason. It said the opposite:

> Add `.engineering-team/` to the project's `.gitignore` if it isn't already
> there: run artifacts are working state, not deliverables.

and `multi-session.md` §10 built on it (*"`$RUN_DIR` is git-untracked"*). Nowhere
did it tell a run to `git add` anything. CI could not compensate: the docs gate
discovers files through `git ls-files` and CI checks out a clean tree, so an
untracked plan is invisible to both. **A gate can only bind a plan someone
already remembered to add.**

## 3. What changed

**`SKILL.md` §"The run directory"** now carries the rule, and it is a lifespan,
not a status: the plan is **tracked while the run is active and deleted at
closeout**. The justification is narrow on purpose — while a run is live its PRs
cite the plan as the authority a reviewer checks them against, and a citation to
a path the repository does not contain cannot be checked at all. That need ends
when the run does.

Three details that were easy to get wrong:

- **Check, don't assume**: `git check-ignore -q "$RUN_DIR/improvement-plan.md"`.
  A project that ignores the path is a legitimate configuration; the run says so
  at the Phase 2 gate rather than tracking against the project's wishes.
- **Commit from the worktree.** `$RUN_DIR` lives in the main checkout, which the
  skill forbids committing in. So the plan is copied to the same repo-relative
  path inside the worktree and committed there.
- **Name which copy wins.** The `$RUN_DIR` copy stays authoritative while the run
  is live; the tracked one is a snapshot for reviewers. Two copies with no stated
  precedence is how they drift.

**"Closing a run" went from three steps to four**, with plan retirement first —
a `git rm` needs the worktree, and step 2 removes it. The reasoning is the user's
and is recorded in the step: a completed plan is a second account of work the
ADRs, spec and journal now own, and a second account drifts. The rule that makes
deletion safe: *anything in it still worth having must already be in one of
those; if it exists only in the plan, that is a gap in the real docs, and the fix
is to write the ADR, not to keep the plan.*

## 4. The second half: an ADR must carry its evidence

Checking which tracked documents actually cite a run turned up that **none cite a
plan**. What they cite is the *evaluation report* — and those are untracked,
deleted with the run, and restored by nothing.

In that repo, two merged ADRs rest on such findings. One of them, ADR-0049, cites
finding F6 of the `manual-20260817T163000Z` evaluation, graded `[VERIFIED]`
against a live database. That run directory is gone from disk and has no git
history. **The evidence behind a merged, authoritative decision cannot be
produced.** The other, ADR-0069, names the hazard inside its own citation,
calling itself "deliberately unlinked" — it is one deletion away from the same
position.

So `references/documentation-model.md` §5 gains: **a finding cited outside its run
is carried, not pointed at.** An ADR or spec states the measurement, the date and
the sha it was read from. A citation is not evidence if the evidence can be
`rm`-ed. This is what lets run directories stay disposable, which is what the
user asked for.

## 5. Deliberately left alone

- **Evaluation reports stay untracked.** They are large, they are working state,
  and §4's convention is what makes discarding them safe. Tracking them would be
  the new class of record-keeping the ask ruled out.
- **`progress.md`, `status-*.md`, `run.yaml`, `current.txt` stay ignored.** They
  are bookkeeping and nothing outside the run cites them.
- **No new gate.** A gate here would have to see untracked files, which CI
  structurally cannot. The enforcement point is the moment the file is written,
  which is the skill.

## 6. Consistency edits `rule-ownership.md` required

Two new load-bearing rules need canonical homes and honest pointers, and the
drift scan checks the index does not lie:

| File | Change |
| --- | --- |
| `references/rule-ownership.md` | rows for both new rules; "Closing a run: three steps" → four |
| `phases/phase-2-planning.md` | pointer to the tracking rule (not a second copy) |
| `phases/phase-4-wrap-up.md` | closeout restated as four steps, retirement first |
| `references/multi-session.md` | §10 said `$RUN_DIR` is git-untracked — now scoped to the bookkeeping, with the residual risk restated |

## 7. Verification

`ci/lint-conventions.sh`, `ci/lint-steps.sh`, `drift_scan.py`,
`check_command_links.py` and `tests/engineering-team-triggering/run.py` all run
green, each with its `--selftest` first so a rule that cannot go red is caught.
